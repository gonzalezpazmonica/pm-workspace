// SE-418 — ningún test escribe claves en el HOME real: por defecto, el almacén de claves de
// Savia Files (KEK y claves de firma de receipts) va a un directorio temporal del proceso.
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';

if (!process.env.SAVIA_FILES_KEYS_HOME) {
  process.env.SAVIA_FILES_KEYS_HOME = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-test-keys-'));
}
