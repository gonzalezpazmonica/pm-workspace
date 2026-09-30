// SE-413 — CLI de Savia Files. Módulo separado del resto de la CLI (arranque en frío),
// misma capa FilesService que la tool MCP `vault_files`. Uso local del operador: sin ACL de red.
import { Command } from 'commander';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { DomeRegistry } from '../registry/domes.js';
import { FilesService } from '../files/service.js';
import { locatorLabel } from '../files/rag-source.js';
import { FilesError } from '../files/types.js';

const program = new Command();
program.name('savia-vaults');

function filesService(domesFile: string): FilesService {
  const reg = new DomeRegistry(path.resolve(domesFile));
  reg.load();
  return new FilesService({
    domes: () => reg.listActive().map(d => ({ name: d.name, confidentiality: d.confidentiality, files: d.files })),
  });
}

function fail(e: unknown): never {
  console.error(`Error: ${e instanceof Error ? e.message : String(e)}`);
  process.exit(e instanceof FilesError && e.code === 'LOCKED' ? 3 : 1);
}

const print = (v: unknown) => console.log(JSON.stringify(v, null, 2));
const cmd = program.command('files').description('SE-413 Savia Files: originales inmutables, extracción con localizador y RAG con cita');
const domesOpt = ['--domes-file <file>', 'Registry de cúpulas', 'savia-vaults.domes.json'] as const;
const domeOpt = ['--dome <name>', 'Cúpula con files.enabled'] as const;

cmd.command('add <paths...>').description('Guarda uno o varios ficheros, los escanea y extrae su texto')
  .option(...domesOpt).requiredOption(...domeOpt).option('--tags <list>', 'etiquetas a,b')
  .option('--confidentiality <nivel>', 'N1|N2|N3|N4').option('--replaces <documentId>', 'sustituye creando revisión nueva (un solo fichero)')
  .option('--json', 'salida JSON', false)
  .action(async (paths: string[], opts) => {
    try {
      if (opts.replaces && paths.length !== 1) throw new FilesError('INVALID_INPUT', '--replaces admite un solo fichero');
      const svc = filesService(opts.domesFile);
      // SE-415: un solo lote; los ofimáticos se extraen en un único worker.
      const out = await svc.putMany({
        dome: opts.dome,
        files: paths.map((p) => ({ name: path.basename(p), bytes: fs.readFileSync(p), replaces: opts.replaces })),
        tags: opts.tags ? String(opts.tags).split(',').map((t: string) => t.trim()).filter(Boolean) : undefined,
        confidentiality: opts.confidentiality,
      });
      if (!opts.json) {
        for (const r of out) {
          const skipped = r.skipped.map(s => `${s.reason}×${s.count}`).join(', ');
          console.log(`${r.documentId} ${r.revisionId} ${r.status} ${r.extracted}/${r.units} ${r.name}${skipped ? ` [${skipped}]` : ''}${r.error ? ` — ${r.error}` : ''}`);
        }
      }
      if (opts.json) print(out);
    } catch (e) { fail(e); }
  });

cmd.command('list').description('Lista los documentos de la cúpula').option(...domesOpt).requiredOption(...domeOpt)
  .option('--tag <tag>').option('--json', 'salida JSON', false)
  .action(async (opts) => {
    try {
      const res = await filesService(opts.domesFile).list({ dome: opts.dome, tag: opts.tag });
      if (opts.json) return print(res);
      for (const d of res.documents) console.log(`${d.id}  ${d.status.padEnd(12)} ${String(d.size).padStart(10)} B  r${d.revisions}  ${d.name}`);
      if (!res.documents.length) console.log('(sin documentos)');
      if (res.corrupt) console.error(`Aviso: ${res.corrupt} documento(s) con manifiesto corrupto; ver docs/files.md (Operación)`);
    } catch (e) { fail(e); }
  });

cmd.command('show <id>').description('Documento con revisiones y cobertura de extracción').option(...domesOpt).requiredOption(...domeOpt)
  .action(async (id: string, opts) => {
    try { print(await filesService(opts.domesFile).get({ dome: opts.dome, id })); } catch (e) { fail(e); }
  });

cmd.command('text <id>').description('Texto extraído con su localizador').option(...domesOpt).requiredOption(...domeOpt)
  .option('--revision <revisionId>').option('--max-chars <n>', 'caracteres máximos', '12000').option('--json', 'salida JSON', false)
  .action(async (id: string, opts) => {
    try {
      const t = await filesService(opts.domesFile).text({ dome: opts.dome, id, revisionId: opts.revision, maxChars: parseInt(opts.maxChars, 10) });
      if (opts.json) return print(t);
      for (const u of t.units) console.log(`[${locatorLabel(u.locator)}] ${u.text}${u.formula ? `  (${u.formula})` : ''}`);
      if (t.truncated) console.log('… (recortado por --max-chars)');
    } catch (e) { fail(e); }
  });

cmd.command('get <id>').description('Escribe el original (verificado por SHA-256) en un fichero').option(...domesOpt).requiredOption(...domeOpt)
  .option('--revision <revisionId>').requiredOption('-o, --output <file>', 'fichero de salida').option('--force', 'sobrescribir', false)
  .action(async (id: string, opts) => {
    try {
      if (fs.existsSync(opts.output) && !opts.force) throw new FilesError('INVALID_INPUT', `${opts.output} ya existe (usar --force)`);
      const { bytes } = await filesService(opts.domesFile).readBytes({ dome: opts.dome, id, revisionId: opts.revision });
      fs.writeFileSync(opts.output, bytes, { mode: 0o600 });
      console.log(`${bytes.length} bytes → ${opts.output}`);
    } catch (e) { fail(e); }
  });

cmd.command('rm <id>').description('Borrado real: bytes, extracciones y, en el siguiente sync, sus chunks de RAG')
  .option(...domesOpt).requiredOption(...domeOpt)
  .action(async (id: string, opts) => {
    try {
      const r = await filesService(opts.domesFile).delete({ dome: opts.dome, id });
      console.log(`borrado ${r.deleted} (${r.revisions} revisiones)`);
    } catch (e) { fail(e); }
  });

cmd.command('reprocess <id>').description('Repite escaneo y extracción de la revisión vigente (o --revision)')
  .option(...domesOpt).requiredOption(...domeOpt).option('--revision <revisionId>')
  .action(async (id: string, opts) => {
    try { print(await filesService(opts.domesFile).reprocess({ dome: opts.dome, id, revisionId: opts.revision })); } catch (e) { fail(e); }
  });

cmd.command('gc').description('Borra blobs, extracciones y temporales huérfanos').option(...domesOpt).requiredOption(...domeOpt)
  .action(async (opts) => {
    try { print(await filesService(opts.domesFile).gc({ dome: opts.dome })); } catch (e) { fail(e); }
  });

await program.parseAsync(process.argv);
