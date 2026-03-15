import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { readFileSync, existsSync } from 'fs'
import { join } from 'path'

const pkg = JSON.parse(readFileSync('./package.json', 'utf-8'))

const certDir = join(process.env.HOME || '', '.savia/bridge')
const hasCerts = existsSync(join(certDir, 'cert.pem')) && existsSync(join(certDir, 'key.pem'))

export default defineConfig({
  plugins: [vue()],
  define: {
    __APP_VERSION__: JSON.stringify(pkg.version),
  },
  server: {
    port: 5173,
    https: hasCerts ? {
      cert: readFileSync(join(certDir, 'cert.pem')),
      key: readFileSync(join(certDir, 'key.pem')),
    } : undefined,
    proxy: {
      '/api': {
        target: 'https://localhost:8922',
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path.replace(/^\/api/, '')
      }
    }
  }
})
