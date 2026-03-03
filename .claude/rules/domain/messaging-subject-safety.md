# Regla: Seguridad del Subject en Mensajería Cifrada
# ── Los asuntos NUNCA se cifran — validación obligatoria ─────────────

> REGLA CRÍTICA: El campo `subject:` de un mensaje se almacena SIEMPRE en texto
> claro en el repositorio Git, incluso cuando el body se cifra con `--encrypt`.
> Esto es necesario para mostrar la bandeja de entrada sin descifrar cada mensaje.
> Todo agente o usuario DEBE evitar incluir datos sensibles en el subject.

---

## Comportamiento del sistema

El script `savia-messaging-privacy.sh` ejecuta `check_subject_sensitivity()`
antes de cada envío. Detecta patrones sensibles y emite un **aviso** (warning).
El mensaje se entrega igualmente (no bloquea), pero el aviso queda en la salida
para que el usuario o agente corrija el subject en futuros envíos.

---

## Qué NO poner en el subject

### Datos financieros
- Cantidades de dinero: "Presupuesto 150.000 EUR", "Factura $3,200"
- IBAN: "Transferencia ES76 2100 0418..."
- Términos financieros con cifras concretas

### Datos personales (GDPR/LOPD)
- DNI/NIE: "Contrato 12345678A"
- Email: "Contactar a juan@empresa.com"
- Teléfono: "Llamar al +34 612345678"
- Nombres de empresas con forma jurídica: "Oferta de Ejemplo S.L."

### Credenciales y secretos
- API keys, tokens, passwords
- IPs privadas, connection strings
- Cualquier patrón que detectaría `privacy-check-company.sh`

### Fechas contractuales específicas
- "Vencimiento 15/04/2026" → revela plazos negociables

---

## Qué SÍ poner en el subject

Usar títulos genéricos que indiquen el tema sin revelar detalles:

| En vez de... | Usar... |
|---|---|
| "Oferta 2.5M EUR para Proyecto Atlas" | "Propuesta comercial — Proyecto Atlas" |
| "Contrato vence 15/04/2026" | "Seguimiento de contrato" |
| "Password del servidor: X4k..." | "Credenciales de acceso" |
| "Factura 12345678A por 3.200€" | "Documentación fiscal" |
| "Contactar a juan@empresa.com" | "Datos de contacto" |
| "Deploy key ghp_abc..." | "Claves de despliegue" |

Con `--encrypt`, el subject ideal es simplemente **"Mensaje cifrado"** o
**"Confidencial"**, dejando todo el detalle en el body cifrado.

---

## Instrucciones para agentes Claude

Cuando generes un mensaje con `/savia-send` o `savia-messaging.sh send`:

1. **Siempre** revisa el subject antes de enviar
2. Si el mensaje usa `--encrypt`, usa subjects genéricos ("Confidencial", "Mensaje cifrado")
3. Si el sistema emite un warning de subject sensible, **reformula el subject**
   moviendo los detalles al body
4. Nunca pongas datos que permitan a un tercero con acceso al repo Git
   inferir el contenido sin descifrar el mensaje
5. El subject es metadato de enrutamiento, no contenido — trátalo como
   la línea de asunto de un sobre postal: visible para cualquiera que lo toque

---

## Patrones detectados automáticamente

| Categoría | Patrón | Ejemplo |
|---|---|---|
| Cantidad monetaria | `N EUR`, `$N`, `€N`, `N mill` | "Presupuesto 50.000 EUR" |
| Fecha contractual | `DD/MM/YYYY`, `DD-MM-YY` | "Entrega 15/04/2026" |
| Empresa (forma jurídica) | `S.L.`, `S.A.`, `Ltd`, `GmbH`, `Inc` | "Contrato Acme Ltd" |
| Credencial | `password`, `clave`, `secret` | "Nueva contraseña de..." |
| API key | `ghp_*`, `sk-*`, `AKIA*` | "Token ghp_abc..." |
| IP privada | `10.*`, `192.168.*` | "Acceso a 192.168.1.50" |
| Connection string | `jdbc:`, `mongodb+srv://` | "Config jdbc:mysql://..." |
| Email | `*@*.*` | "Enviar a juan@co.com" |
| Teléfono | `+NN NNNNNNN` | "Llamar +34 612345678" |
| DNI/NIE | `NNNNNNNNA`, `X/Y/Z+7N+A` | "DNI 12345678A" |
| IBAN | `CCNN NNNN...` | "IBAN ES76 2100..." |

---
