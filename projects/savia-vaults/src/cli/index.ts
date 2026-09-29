#!/usr/bin/env node
// SE-411 G5: dispatcher. `rag` carga solo su módulo; el resto de comandos, la CLI completa.
if (process.argv[2] === 'rag') await import('./rag.js');
else await import('./main.js');
