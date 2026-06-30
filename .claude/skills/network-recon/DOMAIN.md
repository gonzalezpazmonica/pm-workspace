# Network Recon — Dominio y Conocimiento

## Por que existe esta skill

El reconocimiento de red es la fase inicial de cualquier evaluación de seguridad: entender qué sistemas están activos, qué servicios exponen, y qué tecnologías usan. Sin esta información de base, las fases posteriores (análisis de vulnerabilidades, explotación) son ineficientes o directamente imposibles.

Este skill ejecuta reconocimiento de red básico sobre objetivos autorizados: descubrimiento de hosts, escaneo de puertos, y fingerprinting de servicios.

---

## Fases del reconocimiento de red

### 1. Descubrimiento de hosts (host discovery)
Determinar qué IPs del rango objetivo tienen hosts activos, antes de escanear puertos (más costoso).

Técnicas:
- **ICMP ping sweep**: rápido, bloqueado por firewalls que filtran ICMP
- **TCP SYN ping** (puerto 443, 80): más fiable en redes con ICMP filtrado
- **ARP scan** (solo en red local): muy fiable, no filtrable en LAN

### 2. Escaneo de puertos
Determinar qué puertos TCP/UDP tienen servicios activos.

| Técnica | Velocidad | Detectabilidad | Uso |
|---|---|---|---|
| SYN scan (`-sS`) | Alta | Media | Default para TCP |
| Connect scan (`-sT`) | Media | Alta | Sin privilegios root |
| UDP scan (`-sU`) | Baja | Baja | Servicios UDP críticos |
| FIN/Xmas/Null | Variable | Baja | Evasión IDS (no fiable en Windows) |

### 3. Fingerprinting de servicios y versiones
Identificar qué software y versión hay detrás de cada puerto. Basis para buscar CVEs específicos.

Nmap `-sV` con `--version-intensity 5` ofrece buena cobertura sin ser excesivamente ruidoso.

### 4. OS detection
Inferir el sistema operativo del objetivo mediante análisis de la pila TCP/IP. Útil para priorizar vectores de ataque específicos de plataforma.

---

## Puertos de alto interés por categoría

| Categoría | Puertos | Riesgo si expuesto a internet |
|---|---|---|
| Administración remota | 22 (SSH), 23 (Telnet), 3389 (RDP), 5900 (VNC) | CRÍTICO — fuerza bruta, exploits |
| Bases de datos | 1433, 3306, 5432, 6379, 27017 | CRÍTICO — acceso directo a datos |
| Administración web | 8080, 8443, 9090, 9200 (Elasticsearch) | HIGH — paneles admin expuestos |
| Servicios de directorio | 389 (LDAP), 636 (LDAPS), 445 (SMB) | CRÍTICO — lateral movement |
| Servicios de aplicación | 80, 443, 8000, 8888 | MEDIUM — según aplicación |

---

## Diferencia con attack-surface-mapper

| Skill | Foco | Técnicas |
|---|---|---|
| `network-recon` | Red interna / host específico / rangos IP | Port scan, service detection, OS fingerprint |
| `attack-surface-mapper` | Superficie externa completa de un dominio | DNS, subdominios, Shodan, reconocimiento pasivo |

En una evaluación completa, se usan ambos: `attack-surface-mapper` para el reconocimiento externo inicial, `network-recon` para profundizar en hosts específicos identificados.

---

## Marco legal y ético

El escaneo de puertos sin autorización es ilegal en España (art. 197 bis CP — acceso no autorizado a sistemas) y en la mayoría de países. El fichero de autorización en `output/security/authorization-{target}.txt` es obligatorio antes de ejecutar cualquier scan activo.

Dentro de una red propia o de un cliente con contrato firmado de pentest, el escaneo es legal y esperado como parte de la evaluación.
