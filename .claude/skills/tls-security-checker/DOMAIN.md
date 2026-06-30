# TLS Security Checker — Dominio y Conocimiento

## Por que existe esta skill

TLS mal configurado es invisible para los usuarios pero explotable por atacantes en red. Versiones antiguas (TLS 1.0/1.1), cipher suites débiles, certificados caducados o cabeceras HTTP de seguridad ausentes crean superficies de ataque reales incluso en aplicaciones con lógica correcta.

Este skill analiza la configuración TLS/HTTPS de un host y las cabeceras de seguridad HTTP de su respuesta.

---

## Versiones TLS y estado de seguridad

| Versión | Estado | Acción recomendada |
|---|---|---|
| SSL 3.0 | DEPRECATED (2015) | Deshabilitar inmediatamente |
| TLS 1.0 | DEPRECATED (2021, PCI DSS 3.2) | Deshabilitar — incumple PCI si hay pagos |
| TLS 1.1 | DEPRECATED | Deshabilitar |
| TLS 1.2 | ACTIVO — mínimo aceptable | Mantener con cipher suites fuertes |
| TLS 1.3 | RECOMENDADO | Habilitar; elimina forward secrecy opcional |

---

## Cipher suites — clasificación

### PROHIBIDOS (CRÍTICO)
- `RC4-*`: roto criptográficamente
- `*_NULL_*`: sin cifrado
- `*_EXPORT_*`: claves de 40/56 bits (criptográficamente triviales)
- `*_anon_*`: sin autenticación del servidor
- `DES-*`, `3DES-*`: susceptibles a SWEET32

### DÉBILES (HIGH)
- `*_CBC_*` en TLS < 1.3: susceptibles a BEAST/POODLE si no hay mitigaciones
- RSA key exchange sin forward secrecy (no ECDHE/DHE)

### FUERTES (PASS)
- `ECDHE-RSA-AES256-GCM-SHA384`
- `ECDHE-ECDSA-AES128-GCM-SHA256`
- TLS 1.3 cipher suites (siempre AEAD)

---

## Cabeceras HTTP de seguridad

| Cabecera | Propósito | Valor recomendado |
|---|---|---|
| `Strict-Transport-Security` | Fuerza HTTPS en browsers | `max-age=31536000; includeSubDomains; preload` |
| `Content-Security-Policy` | Mitiga XSS | Política restrictiva por aplicación |
| `X-Frame-Options` | Anti-clickjacking | `DENY` o `SAMEORIGIN` |
| `X-Content-Type-Options` | MIME sniffing | `nosniff` |
| `Referrer-Policy` | Control de referrer | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | Control de APIs browser | Desactivar lo no usado |

HSTS con `preload` requiere registro en https://hstspreload.org — acción irreversible, revisar antes.

---

## Certificados — checks mínimos

- **Expiración**: alertar si < 30 días, CRITICAL si < 7 días
- **Cadena completa**: todos los intermedios presentes (evita errores en clientes móviles)
- **SAN**: el dominio está en Subject Alternative Names (CN deprecated)
- **Transparencia de certificados**: visible en CT logs (señal de emisión legítima)
- **Revocación**: OCSP Stapling habilitado (evita latencia en handshake)

---

## Lo que NO hace este skill

- No modifica configuración de servidores
- No renueva certificados
- Requiere que el host esté accesible desde la máquina que ejecuta el check
- No sustituye un pentest completo de la capa de transporte
