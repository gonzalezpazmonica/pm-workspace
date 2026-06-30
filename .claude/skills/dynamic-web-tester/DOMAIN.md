# Dynamic Web Security Tester — Dominio y Conocimiento

## Por que existe esta skill

El análisis estático (SAST) detecta vulnerabilidades en el código pero no puede verificar si son explotables en el sistema desplegado con su configuración real. El testing dinámico (DAST) interactúa con la aplicación en ejecución, descubriendo vulnerabilidades que solo emergen en runtime: configuraciones de servidor, lógica de negocio mal implementada, o componentes de terceros con comportamientos inesperados.

Este skill ejecuta análisis DAST básico sobre instancias autorizadas usando nuclei y herramientas de proxy.

---

## OWASP Top 10 Web (2021) — cobertura por tipo de test

| Vulnerabilidad | Detectable con DAST | Método |
|---|---|---|
| A01 Broken Access Control | Parcial | Fuzzing de endpoints, IDOR básico |
| A02 Cryptographic Failures | Sí | TLS check, cabeceras de seguridad |
| A03 Injection (SQLi, SSTI) | Sí | Payloads automáticos en parámetros |
| A04 Insecure Design | No | Requiere revisión manual de arquitectura |
| A05 Security Misconfiguration | Sí | Nuclei templates, cabeceras, métodos HTTP |
| A06 Vulnerable Components | Parcial | Fingerprinting de versiones |
| A07 Auth Failures | Parcial | Password spray (con autorización) |
| A08 Software Integrity Failures | No | Requiere análisis de supply chain |
| A09 Security Logging Failures | No | Requiere acceso a logs del servidor |
| A10 SSRF | Sí | Payloads OOB con callback |

---

## Herramientas y su rol

### Nuclei
Motor de templates para detección de vulnerabilidades conocidas. Templates organizados por:
- **CVEs**: vulnerabilidades específicas en versiones conocidas de software
- **Misconfigurations**: configuraciones incorrectas (ej. panel admin expuesto, .git expuesto)
- **Exposures**: información sensible expuesta (backups, ficheros de configuración)
- **Technologies**: fingerprinting de tecnologías para orientar tests posteriores

### Proxy interceptor (ZAP/Burp en modo pasivo)
Analiza el tráfico de la aplicación en busca de:
- Cabeceras sensibles sin protección
- Tokens en URLs (en lugar de headers)
- Cookies sin flags `Secure`, `HttpOnly`, `SameSite`

---

## Impacto en el sistema objetivo

El DAST genera tráfico real hacia el objetivo. Implicaciones:
- **Logs**: el escaneo aparece en logs de acceso y puede activar alertas IDS/WAF
- **Rate limiting**: puede activar throttling o bloqueo temporal de IP
- **Datos**: los payloads de test pueden crear entradas en bases de datos (tests de inyección)

Por ello, el testing dinámico se ejecuta **siempre en entornos de test o staging**, nunca en producción, salvo autorización explícita documentada.

---

## Lo que NO hace este skill

- No explota vulnerabilidades confirmadas (prueba de concepto o más allá)
- No modifica datos de la aplicación
- No realiza tests de denegación de servicio
- No ejecuta contra producción sin autorización explícita documentada
- No sustituye un pentest manual de un profesional certificado (OSCP, CEH)

Todos los findings son reportados como hallazgos para revisión humana.
