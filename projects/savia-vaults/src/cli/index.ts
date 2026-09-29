#!/usr/bin/env node
// Dispatcher (SE-411 G5, SE-412): `rag` y `search` cargan solo su módulo; el resto, la CLI completa.
if (process.argv[2] === 'rag') await import('./rag.js');
else if (process.argv[2] === 'search') await import('./search.js');
else await import('./main.js');
