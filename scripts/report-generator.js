#!/usr/bin/env node
/**
 * report-generator.js — Generador de informes de PM
 * ===================================================
 * Genera informes de imputación de horas (.xlsx) e informes ejecutivos (.pptx/.docx)
 * a partir de datos obtenidos de Azure DevOps.
 *
 * Uso:
 *   node scripts/report-generator.js --type hours --input /tmp/items.json --output ./output/report.xlsx
 *   node scripts/report-generator.js --type executive --format pptx --output ./output/exec.pptx
 *
 * Dependencias (instalar con npm):
 *   npm install exceljs pptxgenjs docx yargs
 *   npm install -g docx    (si se usa el CLI de docx)
 */

'use strict';

// ── CONSTANTES (editar según tu entorno) ──────────────────────────────────────
const CONFIG = {
  // Corporativo
  empresa:             'MI EMPRESA S.L.',        // ← actualizar
  corporateColor:      '0078D4',                  // azul corporativo (hex sin #)
  corporateColorDark:  '003865',                  // azul oscuro cabeceras
  corporateColorLight: 'E6EFF7',                  // azul claro filas alternas
  font:                'Calibri',
  logoPath:            './assets/logo.png',        // logo para informes (opcional)

  // Semáforo
  colorVerde:    '00B050',
  colorAmarillo: 'FFC000',
  colorRojo:     'FF0000',

  // Actividades esperadas (campo Microsoft.VSTS.Common.Activity)
  actividades: ['Development', 'Testing', 'Documentation', 'Meeting', 'Design', 'DevOps'],

  // Rutas
  outputDir: './output',
};

// ── IMPORTS ───────────────────────────────────────────────────────────────────
const fs   = require('fs');
const path = require('path');

// Verificar dependencias
function checkDep(pkg) {
  try { return require(pkg); }
  catch(e) {
    console.error(`[ERROR] Paquete '${pkg}' no instalado. Ejecutar: npm install ${pkg}`);
    process.exit(1);
  }
}

// ── HELPERS ───────────────────────────────────────────────────────────────────
function formatFecha(d) {
  const dt = d ? new Date(d) : new Date();
  return dt.toLocaleDateString('es-ES', { day:'2-digit', month:'2-digit', year:'numeric' });
}

function semaforo(ratio) {
  if (ratio > 1.0) return { texto: 'SOBRE-CARGADO', color: CONFIG.colorRojo };
  if (ratio > 0.85) return { texto: 'AL LÍMITE', color: CONFIG.colorAmarillo };
  return { texto: 'OK', color: CONFIG.colorVerde };
}

function agruparPorPersona(items) {
  const resultado = {};
  for (const item of items) {
    const persona = item.asignado || (item.fields?.['System.AssignedTo']?.displayName) || 'Sin asignar';
    const actividad = item.actividad || item.fields?.['Microsoft.VSTS.Common.Activity'] || 'Sin clasificar';
    const estimado = Number(item.estimado_h || item.fields?.['Microsoft.VSTS.Scheduling.OriginalEstimate'] || 0);
    const completado = Number(item.completado_h || item.fields?.['Microsoft.VSTS.Scheduling.CompletedWork'] || 0);
    const restante = Number(item.restante_h || item.fields?.['Microsoft.VSTS.Scheduling.RemainingWork'] || 0);

    if (!resultado[persona]) resultado[persona] = {};
    if (!resultado[persona][actividad]) resultado[persona][actividad] = { estimado: 0, completado: 0, restante: 0, items: [] };

    resultado[persona][actividad].estimado += estimado;
    resultado[persona][actividad].completado += completado;
    resultado[persona][actividad].restante += restante;
    resultado[persona][actividad].items.push({
      id:         item.id,
      titulo:     item.titulo || item.fields?.['System.Title'],
      tipo:       item.tipo || item.fields?.['System.WorkItemType'],
      estado:     item.estado || item.fields?.['System.State'],
      estimado, completado, restante,
      desviacion: (completado + restante) - estimado,
    });
  }
  return resultado;
}

// ── GENERADOR EXCEL (horas) ───────────────────────────────────────────────────
async function generarExcelHoras(items, outputPath, opciones = {}) {
  const ExcelJS = checkDep('exceljs');
  const wb = new ExcelJS.Workbook();
  wb.creator = CONFIG.empresa;
  wb.created = new Date();

  const proyecto = opciones.proyecto || 'Proyecto';
  const sprint   = opciones.sprint   || 'Sprint actual';
  const agrupado = agruparPorPersona(items);

  // Estilos comunes
  const estiloHeader = {
    font:      { bold: true, color: { argb: 'FFFFFFFF' }, name: CONFIG.font, size: 11 },
    fill:      { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF' + CONFIG.corporateColorDark } },
    alignment: { vertical: 'middle', horizontal: 'center', wrapText: true },
    border:    { top: { style: 'thin', color: { argb: 'FFCCCCCC' } }, bottom: { style: 'thin', color: { argb: 'FFCCCCCC' } } },
  };
  const estiloFilaPar  = { fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF3F3F3' } } };
  const estiloTotal    = { font: { bold: true }, fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF' + CONFIG.corporateColorLight } } };

  // ── PESTAÑA 1: RESUMEN ──────────────────────────────────────────────────────
  const wsResumen = wb.addWorksheet('Resumen');
  wsResumen.columns = [
    { header: 'Persona',       key: 'persona',    width: 25 },
    { header: 'Estimado (h)',  key: 'estimado',   width: 14 },
    { header: 'Imputado (h)', key: 'completado', width: 14 },
    { header: 'Restante (h)', key: 'restante',   width: 14 },
    { header: 'Total real (h)',key: 'total_real', width: 14 },
    { header: 'Desviación (h)',key: 'desviacion', width: 14 },
    { header: '% Desviación',  key: 'desv_pct',   width: 14 },
  ];

  // Título
  wsResumen.spliceRows(1, 0, [`Informe de Imputación de Horas — ${proyecto} — ${sprint}`]);
  wsResumen.spliceRows(2, 0, [`Generado: ${formatFecha(new Date())} | Empresa: ${CONFIG.empresa}`]);
  wsResumen.spliceRows(3, 0, []);

  const headerRow = wsResumen.getRow(4);
  ['Persona','Estimado (h)','Imputado (h)','Restante (h)','Total real (h)','Desviación (h)','% Desviación'].forEach((h, i) => {
    const cell = headerRow.getCell(i + 1);
    cell.value = h;
    Object.assign(cell, estiloHeader);
  });

  let rowIdx = 5;
  let totEstimado = 0, totCompletado = 0, totRestante = 0;

  for (const [persona, actividades] of Object.entries(agrupado)) {
    let pEstimado = 0, pCompletado = 0, pRestante = 0;
    for (const datos of Object.values(actividades)) {
      pEstimado += datos.estimado;
      pCompletado += datos.completado;
      pRestante += datos.restante;
    }
    const totalReal = pCompletado + pRestante;
    const desviacion = totalReal - pEstimado;
    const desvPct = pEstimado > 0 ? (desviacion / pEstimado * 100).toFixed(1) + '%' : 'N/A';

    const row = wsResumen.getRow(rowIdx);
    row.values = [persona, pEstimado, pCompletado, pRestante, totalReal, desviacion, desvPct];
    if (rowIdx % 2 === 0) { row.eachCell(cell => Object.assign(cell, estiloFilaPar)); }
    // Colorear desviación
    const cellDesv = row.getCell(6);
    if (desviacion > 0) cellDesv.font = { color: { argb: 'FF' + CONFIG.colorRojo } };
    else if (desviacion < 0) cellDesv.font = { color: { argb: 'FF' + CONFIG.colorVerde } };

    totEstimado += pEstimado; totCompletado += pCompletado; totRestante += pRestante;
    rowIdx++;
  }

  // Fila de totales
  const totReal = totCompletado + totRestante;
  const totRow = wsResumen.getRow(rowIdx);
  totRow.values = ['TOTAL', totEstimado, totCompletado, totRestante, totReal, totReal - totEstimado,
    totEstimado > 0 ? ((totReal - totEstimado) / totEstimado * 100).toFixed(1) + '%' : 'N/A'];
  totRow.eachCell(cell => Object.assign(cell, estiloTotal));

  // ── PESTAÑA 2: DETALLE ──────────────────────────────────────────────────────
  const wsDetalle = wb.addWorksheet('Detalle por Persona');
  wsDetalle.columns = [
    { header: 'Persona',      key: 'persona',    width: 22 },
    { header: 'ID',           key: 'id',         width: 10 },
    { header: 'Título',       key: 'titulo',     width: 40 },
    { header: 'Tipo',         key: 'tipo',       width: 18 },
    { header: 'Estado',       key: 'estado',     width: 14 },
    { header: 'Actividad',    key: 'actividad',  width: 16 },
    { header: 'Estimado (h)', key: 'estimado',   width: 13 },
    { header: 'Completado (h)',key:'completado', width: 14 },
    { header: 'Restante (h)', key: 'restante',   width: 13 },
    { header: 'Desviación (h)',key:'desviacion', width: 14 },
  ];

  wsDetalle.getRow(1).eachCell(cell => Object.assign(cell, estiloHeader));
  let dRowIdx = 2;

  for (const [persona, actividades] of Object.entries(agrupado)) {
    for (const [actividad, datos] of Object.entries(actividades)) {
      for (const item of datos.items) {
        const row = wsDetalle.getRow(dRowIdx);
        row.values = [persona, `AB#${item.id}`, item.titulo, item.tipo, item.estado, actividad,
          item.estimado, item.completado, item.restante, item.desviacion];
        if (dRowIdx % 2 === 0) row.eachCell(cell => Object.assign(cell, estiloFilaPar));
        dRowIdx++;
      }
    }
  }

  // ── PESTAÑA 3: POR ACTIVIDAD ────────────────────────────────────────────────
  const wsActividad = wb.addWorksheet('Por Actividad');
  wsActividad.columns = [
    { header: 'Actividad',     key: 'actividad',  width: 20 },
    { header: 'Total items',   key: 'items',      width: 14 },
    { header: 'Horas totales', key: 'horas',      width: 16 },
    { header: '% del total',   key: 'pct',        width: 14 },
  ];
  wsActividad.getRow(1).eachCell(cell => Object.assign(cell, estiloHeader));

  const porActividad = {};
  for (const actividades of Object.values(agrupado)) {
    for (const [act, datos] of Object.entries(actividades)) {
      if (!porActividad[act]) porActividad[act] = { items: 0, horas: 0 };
      porActividad[act].items += datos.items.length;
      porActividad[act].horas += datos.completado;
    }
  }
  const totalHoras = Object.values(porActividad).reduce((s, v) => s + v.horas, 0);

  let aRowIdx = 2;
  for (const [act, datos] of Object.entries(porActividad)) {
    const pct = totalHoras > 0 ? (datos.horas / totalHoras * 100).toFixed(1) + '%' : '0%';
    const row = wsActividad.getRow(aRowIdx);
    row.values = [act, datos.items, datos.horas.toFixed(1), pct];
    if (aRowIdx % 2 === 0) row.eachCell(cell => Object.assign(cell, estiloFilaPar));
    aRowIdx++;
  }

  // Guardar
  await wb.xlsx.writeFile(outputPath);
  console.log(`✅ Excel generado: ${outputPath}`);
}

// ── GENERADOR PPTX (ejecutivo) ────────────────────────────────────────────────
async function generarPptxEjecutivo(datosProyectos, outputPath, opciones = {}) {
  const PptxGenJS = checkDep('pptxgenjs');
  const pptx = new PptxGenJS();
  pptx.layout = 'LAYOUT_WIDE';  // 33.87 x 19.05 cm

  const fecha = formatFecha(new Date());

  // ── DIAPOSITIVA 1: PORTADA ──────────────────────────────────────────────────
  const slide1 = pptx.addSlide();
  slide1.background = { color: CONFIG.corporateColor };
  slide1.addText('Estado de Proyectos', {
    x: 1, y: 3, w: '80%', fontSize: 36, bold: true, color: 'FFFFFF', fontFace: CONFIG.font,
  });
  slide1.addText(`Informe Ejecutivo — ${fecha}`, {
    x: 1, y: 5, w: '80%', fontSize: 20, color: 'DDDDDD', fontFace: CONFIG.font,
  });
  slide1.addText(CONFIG.empresa, {
    x: 1, y: 6.5, w: '80%', fontSize: 14, color: 'CCCCCC', fontFace: CONFIG.font,
  });

  // ── DIAPOSITIVA 2: SEMÁFORO GLOBAL ──────────────────────────────────────────
  const slide2 = pptx.addSlide();
  slide2.addText('Resumen de Estado — Todos los Proyectos', {
    x: 0.5, y: 0.3, w: '90%', fontSize: 22, bold: true, color: CONFIG.corporateColorDark, fontFace: CONFIG.font,
  });

  const rows = [
    [
      { text: 'Proyecto', options: { bold: true, color: 'FFFFFF', fill: CONFIG.corporateColorDark } },
      { text: 'Sprint', options: { bold: true, color: 'FFFFFF', fill: CONFIG.corporateColorDark } },
      { text: 'Estado', options: { bold: true, color: 'FFFFFF', fill: CONFIG.corporateColorDark } },
      { text: 'Sprint Goal', options: { bold: true, color: 'FFFFFF', fill: CONFIG.corporateColorDark } },
      { text: 'Días restantes', options: { bold: true, color: 'FFFFFF', fill: CONFIG.corporateColorDark } },
    ],
    ...datosProyectos.map(p => [
      { text: p.nombre || 'Proyecto' },
      { text: p.sprint || '—' },
      { text: p.semaforo || '🟢', options: { align: 'center' } },
      { text: p.goal || '—' },
      { text: String(p.diasRestantes || '—'), options: { align: 'center' } },
    ]),
  ];

  slide2.addTable(rows, {
    x: 0.5, y: 1.2, w: 12, colW: [2, 2.5, 1.5, 4.5, 1.5],
    fontSize: 12, fontFace: CONFIG.font, border: { pt: 1, color: 'CCCCCC' },
    rowH: 0.5,
  });

  slide2.addText(`Generado: ${fecha} | ${CONFIG.empresa}`, {
    x: 0.5, y: 6.8, w: '90%', fontSize: 9, color: '888888', fontFace: CONFIG.font,
  });

  // ── DIAPOSITIVAS POR PROYECTO ────────────────────────────────────────────────
  for (const proyecto of datosProyectos) {
    const slide = pptx.addSlide();
    const semColor = proyecto.semaforo?.includes('🔴') ? CONFIG.colorRojo
                   : proyecto.semaforo?.includes('🟡') ? CONFIG.colorAmarillo
                   : CONFIG.colorVerde;

    slide.addText(proyecto.nombre || 'Proyecto', {
      x: 0.5, y: 0.3, w: '70%', fontSize: 22, bold: true, color: CONFIG.corporateColorDark, fontFace: CONFIG.font,
    });
    slide.addShape(pptx.ShapeType.ellipse, { x: 12, y: 0.2, w: 0.8, h: 0.8, fill: { color: semColor } });

    slide.addText(`Sprint: ${proyecto.sprint || '—'} | Goal: ${proyecto.goal || '—'}`, {
      x: 0.5, y: 1.0, w: '90%', fontSize: 12, color: '555555', fontFace: CONFIG.font,
    });

    // Métricas clave
    const metricas = [
      ['Velocity', `${proyecto.velocityActual || '—'} SP`, `(media: ${proyecto.velocityMedia || '—'} SP)`],
      ['SP Completados', `${proyecto.spCompletados || 0}/${proyecto.spPlanificados || 0}`, ''],
      ['Remaining Work', `${proyecto.remainingWork || '—'}h`, ''],
      ['Días restantes', `${proyecto.diasRestantes || '—'}`, ''],
    ];

    slide.addTable(
      [['Métrica', 'Valor', 'Referencia'], ...metricas],
      { x: 0.5, y: 1.5, w: 5.5, colW: [2, 1.8, 1.7], fontSize: 11, fontFace: CONFIG.font,
        border: { pt: 1, color: 'CCCCCC' }, rowH: 0.4 }
    );

    // Riesgos (si hay)
    if (proyecto.riesgos && proyecto.riesgos.length > 0) {
      slide.addText('Riesgos activos:', { x: 6.5, y: 1.4, w: 6, fontSize: 13, bold: true, color: CONFIG.corporateColorDark });
      proyecto.riesgos.forEach((r, i) => {
        slide.addText(`• ${r}`, { x: 6.5, y: 1.9 + i * 0.4, w: 6, fontSize: 11, color: '333333' });
      });
    }
  }

  // ── DIAPOSITIVA FINAL: PRÓXIMOS PASOS ───────────────────────────────────────
  const slideFinal = pptx.addSlide();
  slideFinal.addText('Próximos Pasos y Decisiones Requeridas', {
    x: 0.5, y: 0.3, w: '90%', fontSize: 22, bold: true, color: CONFIG.corporateColorDark,
  });
  slideFinal.addText('[Añadir acciones y decisiones pendientes]', {
    x: 0.5, y: 1.5, w: '90%', fontSize: 14, color: '555555', italic: true,
  });

  await pptx.writeFile({ fileName: outputPath });
  console.log(`✅ PowerPoint generado: ${outputPath}`);
}

// ── CLI ───────────────────────────────────────────────────────────────────────
async function main() {
  const argv = process.argv.slice(2);
  const opts = {};
  for (let i = 0; i < argv.length; i += 2) {
    opts[argv[i].replace(/^--/, '')] = argv[i + 1];
  }

  const tipo    = opts.type   || 'hours';
  const formato = opts.format || (tipo === 'executive' ? 'pptx' : 'xlsx');
  const input   = opts.input  || '/tmp/sprint-items.json';
  const output  = opts.output || path.join(CONFIG.outputDir,
    `${new Date().toISOString().slice(0,10).replace(/-/g,'')}-${tipo}-report.${formato}`);

  // Crear directorio de salida si no existe
  fs.mkdirSync(path.dirname(output), { recursive: true });

  console.log(`[report-generator] Tipo: ${tipo} | Formato: ${formato}`);
  console.log(`[report-generator] Input: ${input} | Output: ${output}`);

  if (tipo === 'hours') {
    let items = [];
    if (fs.existsSync(input)) {
      const raw = JSON.parse(fs.readFileSync(input, 'utf8'));
      items = Array.isArray(raw) ? raw : (raw.value || []);
    } else {
      console.warn(`[WARN] Fichero de items no encontrado: ${input}. Generando informe vacío.`);
    }
    await generarExcelHoras(items, output, { proyecto: opts.proyecto, sprint: opts.sprint });

  } else if (tipo === 'executive') {
    // Datos de ejemplo (en producción, obtener de Azure DevOps vía azdevops-queries.sh)
    const datosProyectos = [
      {
        nombre: 'Proyecto Alpha', sprint: 'Sprint 2026-04', semaforo: '🟢',
        goal: 'Módulo SSO + Dashboard', diasRestantes: 5,
        velocityActual: 33, velocityMedia: 32, spCompletados: 22, spPlanificados: 30,
        remainingWork: 48, riesgos: ['Integración SSO más compleja de lo previsto'],
      },
      {
        nombre: 'Proyecto Beta', sprint: 'Sprint 2026-04', semaforo: '🟡',
        goal: 'Setup + primera funcionalidad', diasRestantes: 5,
        velocityActual: 11, velocityMedia: 25, spCompletados: 8, spPlanificados: 11,
        remainingWork: 20, riesgos: [],
      },
    ];
    await generarPptxEjecutivo(datosProyectos, output, opts);

  } else {
    console.error(`[ERROR] Tipo desconocido: ${tipo}. Usar: hours | executive`);
    process.exit(1);
  }
}

main().catch(err => {
  console.error('[ERROR]', err.message);
  process.exit(1);
});
