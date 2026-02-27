---
paths:
  - "**/*.cob"
  - "**/*.cbl"
  - "**/*.cpy"
---

# Regla: Convenciones y Prácticas COBOL
# ── Aplica a todos los proyectos COBOL en este workspace ──────────────────────

## Verificación obligatoria en cada tarea

Antes de dar una tarea por terminada, ejecutar siempre en este orden:

```bash
cobc -x -free programa.cob                    # 1. ¿Compila sin errores?
cobol-check --input programa.cob              # 2. ¿Cumple estándares de testing?
review programa.cob                           # 3. ¿Análisis de código (si disponible)?
```

CRÍTICO: La mayoría de tareas en proyectos COBOL deben ser revisadas y executadas por humano.

## Nota importante sobre COBOL

COBOL es un lenguaje legacy de negocio — usado principalmente en sistemas financieros, gobierno, telecomunicaciones.

- **Modernización:** Preferir GnuCOBOL (compilador moderno, open-source) sobre VS COBOL
- **Paradigma:** Imperativo, procedural, orientado a registros y archivos
- **Contexto de Claude:** Pueden generarse estructuras básicas, pero requieren validación manual
- **CRÍTICO:** El agente NO debe ejecutar cambios en producción sin aprobación humana explícita

## Convenciones de código COBOL

- **Columnas:** Respetar formato de columnas (cols 7-72 son código; 1-6 para etiquetas/área A; 73+ ignoradas)
- **Sintaxis libre (GnuCOBOL):** Usar `cobc -x -free` para code más moderno (sin restricción de columnas)
- **Nombres:** `UPPER-CASE-WITH-HYPHENS` para variables, procedimientos, archivos
- **Secciones:** Organizar en IDENTIFICATION, ENVIRONMENT, DATA, PROCEDURE divisions
- **Variables:** Declarar con tipos explícitos (`PIC 9(5)`, `PIC X(30)`, `PIC 9V99`)
- **Archivos:** Definir estructura con record descriptions en FILE SECTION
- **COPY members:** Reutilizar estructuras de datos comunes desde `copy.lib/`

## Estructura básica

```cobol
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PROGRAMA-EJEMPLO.
       AUTHOR. Equipo de Desarrollo.
       
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ENTRADA-ARCHIVO ASSIGN TO "datos.txt"
               ORGANIZATION IS LINE SEQUENTIAL.
       
       DATA DIVISION.
       FILE SECTION.
       FD  ENTRADA-ARCHIVO.
       01  ENTRADA-RECORD.
           05  ENTRADA-ID    PIC 9(5).
           05  ENTRADA-NOMBRE PIC X(30).
           05  ENTRADA-MONTO PIC 9(7)V99.
       
       WORKING-STORAGE SECTION.
       01  WS-TOTAL          PIC 9(10) VALUE 0.
       01  WS-CONTADOR       PIC 9(5) VALUE 0.
       01  WS-EOF            PIC X VALUE 'N'.
       
       PROCEDURE DIVISION.
           PERFORM INICIALIZAR.
           PERFORM PROCESAR-ARCHIVO.
           PERFORM FINALIZAR.
           STOP RUN.
       
       INICIALIZAR.
           DISPLAY "Iniciando procesamiento..."
           MOVE 0 TO WS-TOTAL
           MOVE 0 TO WS-CONTADOR.
       
       PROCESAR-ARCHIVO.
           OPEN INPUT ENTRADA-ARCHIVO.
           PERFORM UNTIL WS-EOF = 'Y'
               READ ENTRADA-ARCHIVO
                   AT END MOVE 'Y' TO WS-EOF
                   NOT AT END
                       PERFORM PROCESAR-REGISTRO
               END-READ
           END-PERFORM.
           CLOSE ENTRADA-ARCHIVO.
       
       PROCESAR-REGISTRO.
           ADD ENTRADA-MONTO TO WS-TOTAL.
           ADD 1 TO WS-CONTADOR.
       
       FINALIZAR.
           DISPLAY "Total procesado: " WS-TOTAL.
           DISPLAY "Registros: " WS-CONTADOR.
```

## COPY Members (reutilización)

Definir estructuras comunes una sola vez:

```cobol
       *> copy.lib/usuario-record.cpy
       01  USUARIO-RECORD.
           05  USR-ID         PIC 9(8).
           05  USR-NOMBRE     PIC X(50).
           05  USR-EMAIL      PIC X(60).
           05  USR-ACTIVO     PIC X VALUE 'S'.

       *> En programa principal:
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY usuario-record OF copy-lib.
```

## Testing con COBOL-Check

```cobol
       *> Formato de test
       IDENTIFICATION DIVISION.
       PROGRAM-ID. prueba-calcular-interes.
       
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PRINCIPAL     PIC 9(7)V99 VALUE 1000.
       01  WS-TASA          PIC 9V9999 VALUE 0.05.
       01  WS-RESULTADO     PIC 9(7)V99.
       
       PROCEDURE DIVISION.
           CALL "CALCULAR-INTERES" USING WS-PRINCIPAL WS-TASA
                                        RETURNING WS-RESULTADO.
           
           IF WS-RESULTADO = 50
               DISPLAY "PASS: Interes correcto"
           ELSE
               DISPLAY "FAIL: Interes incorrecto, esperaba 50"
           END-IF.
```

## Manejo de archivos

```cobol
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
       
           *> Archivo secuencial de entrada
           SELECT ARCHIVO-ENTRADA ASSIGN TO "entrada.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-STATUS-ENTRADA.
           
           *> Archivo secuencial de salida
           SELECT ARCHIVO-SALIDA ASSIGN TO "salida.txt"
               ORGANIZATION IS LINE SEQUENTIAL.
           
           *> Archivo relativo (acceso por clave)
           SELECT ARCHIVO-RELATIVO ASSIGN TO "datos.rel"
               ORGANIZATION IS RELATIVE
               ACCESS IS RANDOM
               RECORD VARYING FROM WS-REC-LEN
               TO WS-MAX-REC-LEN.
       
       DATA DIVISION.
       FILE SECTION.
       FD  ARCHIVO-ENTRADA.
       01  ENTRADA-REC       PIC X(100).
       
       FD  ARCHIVO-SALIDA.
       01  SALIDA-REC        PIC X(100).
       
       PROCEDURE DIVISION.
           OPEN INPUT ARCHIVO-ENTRADA.
           OPEN OUTPUT ARCHIVO-SALIDA.
           
           PERFORM UNTIL WS-EOF = 'Y'
               READ ARCHIVO-ENTRADA
                   AT END MOVE 'Y' TO WS-EOF
                   NOT AT END
                       MOVE ENTRADA-REC TO SALIDA-REC
                       WRITE SALIDA-REC
               END-READ
           END-PERFORM.
           
           CLOSE ARCHIVO-ENTRADA.
           CLOSE ARCHIVO-SALIDA.
```

## GnuCOBOL — Modernizaciones

```cobol
       *> Sintaxis libre (más legible)
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MODERNO.
       
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 ws-name             PIC X(30).
       01 ws-items            PIC 9(5) VALUE 0.
       
       PROCEDURE DIVISION.
           ACCEPT ws-name FROM KEYBOARD.
           IF ws-name IS NOT EMPTY
               DISPLAY "Hola " ws-name
               PERFORM ADD-ITEM
           ELSE
               DISPLAY "Nombre vacio"
           END-IF.
           STOP RUN.
       
       ADD-ITEM.
           ADD 1 TO ws-items.
           DISPLAY "Items: " ws-items.
```

## Integración con JCL (batch jobs)

```jcl
//JOBNAME  JOB (ACCOUNT,DEPT),PROGRAMMER,NOTIFY=USER
//*
//* Descripcion: Procesar archivo de usuarios diarios
//*
//STEP1    EXEC PGM=PROGRAMA-COBOL
//ENTRADA  DD DSN=PROD.DATA.USUARIOS.ENTRADA,
//            DISP=SHR
//SALIDA   DD DSN=PROD.DATA.USUARIOS.SALIDA,
//            DISP=(NEW,CATLG),
//            SPACE=(TRK,(10,5),RLSE)
//SYSOUT   DD SYSOUT=*
//SYSIN    DD DUMMY
```

## Documentación obligatoria

Cada programa COBOL debe incluir:

```cobol
       IDENTIFICATION DIVISION.
       PROGRAM-ID. NOMBRE-PROGRAMA.
       AUTHOR. Nombre del Desarrollador.
       
       *> ================================================================
       *> Descripcion:
       *>   Procesa archivo de entrada y genera reporte.
       *>
       *> Parametros de entrada:
       *>   - Archivo ENTRADA-ARCHIVO (DSN PROD.DATA.ENTRADA)
       *>   - Variable WS-FECHA (YYYYMMDD)
       *>
       *> Salida:
       *>   - Archivo SALIDA-ARCHIVO (DSN PROD.DATA.SALIDA)
       *>   - Retorno: 0 (exito), 8 (error)
       *>
       *> Historia de cambios:
       *>   2026-02-26: Version inicial (v1.0)
       *>   2026-03-01: Agregado manejo de excepciones (v1.1)
       *> ================================================================
```

## CRÍTICO: Limitaciones del Agente

El agente Claude puede:
- Generar estructuras básicas de COBOL
- Sugerir mejoras de código
- Ayudar con lógica procedural

El agente NO DEBE sin aprobación humana:
- Modificar programas en producción
- Cambiar estructuras de datos heredadas (breaking change)
- Eliminar o alterar COPY members compartidos
- Cambiar lógica de cálculo financiero
- Deployear cambios a mainframe o sistemas batch

## Hooks recomendados para proyectos COBOL

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "cobc -x -free --syntax-only $(pwd)/*.cob 2>&1 | head -20"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "echo 'COBOL commit requires manual validation and testing'"
    }]
  }
}
```
