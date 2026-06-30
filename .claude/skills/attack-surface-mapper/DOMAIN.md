# Attack Surface Mapper — Dominio y Conocimiento

## Por que existe esta skill

El attack surface mapping es el inventario de todos los puntos donde un atacante puede interactuar con un sistema. Sin ese inventario, los esfuerzos de hardening son ciegos: se protege lo que se conoce y se ignora lo que no. El 60% de las brechas explotan activos que el equipo de seguridad no sabía que existían.

Este skill genera un mapa de la superficie de ataque de un objetivo autorizado: subdominios, puertos abiertos, servicios expuestos, y tecnologías identificables.

---

## Componentes de la superficie de ataque

### Superficie externa (internet-facing)
- **Subdominios**: subdominios olvidados o de staging expuestos a internet
- **Puertos/servicios**: servicios administrativos expuestos (SSH, RDP, bases de datos)
- **APIs**: endpoints no documentados, versiones antiguas activas
- **Activos olvidados**: servidores de desarrollo, instancias de test, backups accesibles

### Superficie interna (post-compromiso inicial)
- Servicios en red interna accesibles desde DMZ
- Credenciales reutilizadas entre sistemas
- Rutas de escalada de privilegios

### Superficie de terceros
- Proveedores con acceso a sistemas internos
- Integraciones SaaS con permisos excesivos
- DNS/CDN con configuraciones que filtran información

---

## Técnicas de reconocimiento pasivo vs. activo

| Técnica | Tipo | Impacto en objetivo | Ejemplo |
|---|---|---|---|
| DNS enumeration (public) | Pasivo | Ninguno | crt.sh, dnsdumpster |
| WHOIS / ASN lookup | Pasivo | Ninguno | whois, bgp.he.net |
| Shodan/Censys | Pasivo | Ninguno | búsqueda de IPs/servicios indexados |
| Certificate Transparency | Pasivo | Ninguno | crt.sh para subdominios |
| Port scan (SYN) | Activo | Detectable en IDS | nmap -sS |
| Service detection | Activo | Detectable | nmap -sV |
| Web crawling | Activo | Genera tráfico | gospider, katana |
| DNS brute force | Activo | Detectable | gobuster dns |

Este skill solo ejecuta técnicas activas contra objetivos con fichero de autorización explícita.

---

## Información que NO se captura

Por política, el mapper NO recoge ni almacena:
- Credenciales o secretos descubiertos durante el reconocimiento
- Datos personales identificables encontrados en servicios expuestos
- Vulnerabilidades específicas explotables (eso es labor del pentester)
- Cualquier dato que implique acceso no autorizado

El output es un inventario de superficie, no un exploit.

---

## Formato de output

```yaml
attack_surface:
  target: "example.com"
  scan_date: "2026-01-15"
  authorization_file: "output/security/authorization-example.com.txt"
  
  subdomains:
    - host: "api.example.com"
      resolved_ip: "1.2.3.4"
      status: active
    - host: "staging.example.com"
      resolved_ip: "1.2.3.5"
      status: active
      risk_note: "entorno staging expuesto a internet"
  
  open_ports:
    - host: "1.2.3.4"
      port: 443
      service: "https"
      banner: "nginx/1.24.0"
    - host: "1.2.3.4"
      port: 22
      service: "ssh"
      risk_note: "SSH expuesto — verificar si es necesario"
```

---

## Principio de autorización explícita

Ejecutar reconocimiento activo contra sistemas sin autorización es ilegal en la mayoría de jurisdicciones (Computer Fraud and Abuse Act en EE.UU., art. 197 CP en España). El fichero de autorización en `output/security/authorization-{target}.txt` documenta el alcance acordado y debe existir antes de cualquier scan activo.
