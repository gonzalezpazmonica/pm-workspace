# Savia Mobile — Análisis de Mercado

> Actualizado: Marzo 2026. Savia Mobile es la versión móvil de pm-workspace, no solo otro chat de IA.

## 1. Posicionamiento: Savia vs. Competencia

### Propuesta de Valor Diferenciada

Savia Mobile **NO es:**
- Otro chat de IA genérico (como ChatGPT)
- Otro app de project management tradicional (como Asana/Jira)
- Una herramienta standalone desconectada

Savia Mobile **SÍ es:**
- **Extensión móvil de pm-workspace** — acceso a tu propia instancia de Savia en cualquier lugar
- **AI assistant especializado en PM** — entiende sprints, estimación, riesgos, backlog
- **Puente directo a Claude Code CLI** — la inteligencia vive en tu máquina, la app es cliente
- **Respeta tu propiedad de datos** — todo vive en tu infra, opcionalmente en la nube con tu consentimiento

### Matriz Competitiva

| Producto | Tipo | AI Native | PM Specialization | Data Ownership | Mobile First |
|----------|------|-----------|-------------------|-----------------|--------------|
| **Savia Mobile** | PM + AI | ✅ Claude | ✅ Workspace-specific | ✅ 100% your server | Partial (bridge) |
| ChatGPT | Chat | ✅ GPT-4 | ❌ Generic | ❌ OpenAI servers | ✅ Yes |
| Jira Mobile | PM | ❌ Limited | ✅ Full Jira | ❌ Atlassian servers | ✅ Yes |
| Asana Mobile | PM | ❌ Recently added | ✅ Asana-specific | ❌ Asana servers | ✅ Yes |
| Taiga Mobile | PM | ❌ No | ✅ Agile tools | ✅ Self-hosted | Partial |
| Notion Mobile | Wiki + Tasks | ❌ Recently added | ⚠️ Templated | ❌ Notion servers | ✅ Yes |

**Conclusión:** Savia es único en combinar: IA nativa (Claude) + especialización PM profunda + respeto por propiedad de datos + arquitectura descentralizada.

## 2. Mercado Potencial

### Segmentación de Usuarios

#### Segment 1: Technical PMs (Primario)
- Perfil: Directores de Ingeniería, Tech Leads, PMs en startups de software
- Tamaño: ~500K-1M globalmente
- Pain Point: Necesitan IA que entienda técnica, no prompts genéricos
- Disposición a pagar: Alta ($9.99-29.99/mes)
- Características clave: Integración con Azure DevOps/GitHub, SSH tunnel, risk scoring

#### Segment 2: Agile Coaches (Secundario)
- Perfil: Scrum Masters, Agile consultores, coaches organizacionales
- Tamaño: ~200K-400K globalmente
- Pain Point: Necesitan herramientas para entrenar equipos, análisis de sprint
- Disposición a pagar: Media-Alta ($4.99-14.99/mes)
- Características clave: Retrospective automática, team health dashboard

#### Segment 3: Executive Visibility (Terciario)
- Perfil: C-suite, heads of engineering, portfolio managers
- Tamaño: ~50K-100K globalmente (pero alto ALV = Annual Lifetime Value)
- Pain Point: Necesitan insights consolidados, riesgos anticipados
- Disposición a pagar: Muy Alta ($29.99-99.99/mes empresarial)
- Características clave: DORA metrics, portfolio overview, risk exposure

### Mercado Total Direccionable (TAM)

**Global PM software market (2025):** $7.8B, creciendo 10.7% CAGR

**Subtareas de Savia dentro de TAM:**
- AI-augmented PM tools: ~$1.2B (15% del mercado)
- Mobile PM access: ~$900M (12% del mercado)
- Self-hosted/privacy-first tools: ~$200M (2.6% del mercado)

**SAM (Serviceable Addressable Market):** ~$2.1B
- Usuarios que usarían Savia: 2.1M (asumiendo ARPU $12/mes)

**SOM (Serviceable Obtainable Market) — Realista 5 años:**
- Objetivo: 5,000 subscriptores pagos @ $12 ARPU = $720K/año
- Growth path: 10% MoM es realista para SaaS B2B especializado

## 3. Propuesta Diferenciada de Savia Mobile

### vs. ChatGPT Mobile
```
ChatGPT: "¿Cuál es el estado de mi sprint?"
         → Respuesta genérica basada en web search

Savia: "¿Cuál es el estado de mi sprint?"
       → Accede a tu workspace real, Azure DevOps/Jira actual
       → Analiza backlog, velocidad, dependencias
       → Propone mitigaciones con contexto tu equipo
```

### vs. Jira Mobile
```
Jira: "App móvil de Jira, cliente nativo"
      → Duplica UI de Jira
      → Requiere Jira Cloud (no self-hosted)
      → Sin inteligencia, solo gestoría

Savia: "App móvil de PM inteligente"
       → Cliente ligero, brains en Savia
       → Works con cualquier PM tool (Jira, Azure DevOps, Taiga, etc.)
       → Self-hosted o cloud, a tu elección
       → Análisis inteligente, no solo CRUD
```

## 4. Go-to-Market Strategy

### Fase 1: Community (Meses 1-3)
**Objetivo:** Validar product-market fit, ganar early adopters, feedback inicial

- **Open-source el código** en GitHub (MIT License, excepto bridge que es Apache 2.0)
- **Post en comunidades técnicas:**
  - r/projectmanagement (~200K suscriptores)
  - r/agile (~50K)
  - r/android_dev (~500K)
  - Hacker News (si llega a front page)
- **LinkedIn:** Mónica publica journey del desarrollo
- **YouTube:** Tutorial corto: "Savia PM en tu teléfono — Setup en 10 min"
- **Discord/Slack community:** Grupo para users tempranos, feedback directo

**Métricas de éxito:**
- 1K+ GitHub stars
- 500+ Discord members
- 100+ early adopters testando

### Fase 2: Early Adopters (Meses 3-6)
**Objetivo:** Generar tracción, demostrar monetización, refinar product

- **Product Hunt launch:** Bien coordinado, buena landing page
- **Developer & Agile media:**
  - DEV.to artículos: "Building a PM Assistant in Kotlin"
  - Agile.org magazine (si aplican)
  - Podcasts de software (e.g., Software Engineering Daily)
- **Agile community events:**
  - Local agile meetups (presentaciones)
  - Agile coaching seminars
  - Scrum Alliance events
- **Partner outreach:** Hablar con Azure DevOps consultores, Jira partners
- **Closed beta for Pro tier:** Invitation-only, gather feedback antes de public GA

**Métricas de éxito:**
- 250+ Pro subscribers (pagan $9.99/mes)
- 1K+users en beta
- NPS > 50

### Fase 3: Growth (Meses 6-12)
**Objetivo:** Escalar adquisición, viabilidad empresarial

- **Play Store featuring:** Solicitar featured en "Productivity" o "Business" category
- **Partnerships:**
  - Atlassian partners (consultoría, integradores)
  - Azure DevOps community leaders
  - Agile certification bodies (Scrum.org, Agile Alliance)
- **Content marketing:** Blog de Savia sobre PM, AI, agile trends
- **Referral program:** Usuarios existentes invitan a amigos, descuento mutual
- **Enterprise sales:** B2B outreach a startups de serie A-B
- **Team tier:** Expand a accounts collaborativos (5 usuarios min)

**Métricas de éxito:**
- 2,000+ Pro subscribers
- 500+ Team subscribers
- MRR > $30K
- Churn rate < 5% monthly

## 5. Revenue Model (Año 1)

### Tier Pricing

| Tier | Precio | Features | Público |
|------|--------|----------|---------|
| **Free** | $0 | 5 queries/día, historial local, UI básica | Estudiantes, evaluadores |
| **Pro** | $9.99/mes | Unlimited queries (tu API key), cloud sync, 30d history, priority support | Individual PMs, consultores |
| **Team** | $29.99/mes | 5 seats, shared workspace, team dashboard, admin controls, API access | Startups, agencias |
| **Enterprise** | Custom | 100+ seats, on-premise option, SLA, dedicated support | Mid-size companies |

### Proyección Financiera Año 1

**Supuestos (realistas para SaaS especializado):**
- Convertir 1% de early adopters → Pro: 100 usuarios mes 1, 10% MoM growth
- Team tier lanza mes 4: 10 usuarios iniciales, 15% MoM growth
- Enterprise: 1 cliente piloto mes 8, $1K/mes

**Runway:**
```
Mes 1:   100 Pro @ $10   = $1,000
Mes 3:   145 Pro @ $10   = $1,450
Mes 6:   180 Pro + 30 Team @ $30 = $2,880
Mes 12:  300 Pro + 150 Team + 1 Enterprise = $5,300 + $1,000 = $6,300 MRR
```

**Costos Operativos Año 1:**
- Cloud: $500/mes (si usamos cloud para bridge hosting)
- API OpenAI/Anthropic: ~$200/mes (user queries)
- Domain, DNS, monitoring: $50/mes
- Slack, tools: $100/mes
- **Total OpEx:** ~$850/mes = $10,200/año

**Breakeven:** Mes 2-3 (cuando MRR > OpEx)

**Beneficio estimado Año 1:** ~$50-70K (si proyección es optimista)

## 6. Canales de Distribución

| Canal | Primary | Effort | Reach |
|-------|---------|--------|-------|
| Google Play Store | ✅ | Low | 2B+ Android devices |
| GitHub Releases | ✅ | Low | Technical users |
| Sideload APK (via bridge) | ✅ | Low | Existing pm-workspace users |
| Web store (upcoming) | 📋 | Medium | iOS eventually |
| F-Droid (open-source) | 📋 | Medium | Privacy-focused users |

## 7. Marketing Unique Angles

### Narrativa Clave 1: "Your PM Assistant, Offline & Private"
- No vendor lock-in
- Datos en tu control
- Funciona con tu infra existente
- GDPR/LOPD compliant por diseño

### Narrativa Clave 2: "Claude AI for Project Managers"
- Entiende tu workspace (no genérico)
- Responde en tu idioma (ES/EN)
- Integrado con Claude Code CLI
- Mismo LLM que usan las mejores empresas

### Narrativa Clave 3: "Agile Coaching in Your Pocket"
- Retrospective automática
- Risk scoring en tiempo real
- Velocity analysis
- Team health dashboard

## 8. Riesgos & Mitigación

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|--------|-----------|
| Anthropic limita acceso API | Baja | Alto | Arquitectura flexible, soportar otros LLMs |
| Competencia de OpenAI Mobile | Alta | Medio | Especialización PM es diferenciador único |
| Google Play policy issues | Baja | Medio | Cumplir con todos los reqs, legal review |
| SSH tunnel complexity | Baja | Medio | Bridge sencillo en Python, good docs |
| Low retention (churn > 10%) | Media | Medio | Continuous feature updates, community feedback |
| Privacy regulations (DMA, etc.) | Baja | Bajo | Transparencia, open-source, privacy audit |

## 9. Success Metrics (OKRs Año 1)

### O1: Validar product-market fit
- KR1: 500+ DAU en beta
- KR2: NPS > 50 en early adopters
- KR3: MoM retention > 80% en Free tier

### O2: Escalar a viabilidad comercial
- KR1: 500 paying subscribers (Pro + Team)
- KR2: MRR > $5K
- KR3: Customer acquisition cost < $50

### O3: Establecer posición única en mercado
- KR1: 2K GitHub stars
- KR2: Featured en Google Play
- KR3: Partnerships con 5+ Jira/Azure DevOps integrators

## 10. Timeline Realista

| Fase | Meses | Hitos |
|------|-------|-------|
| Validación MVP | 0-3 | Alpha release, 100 beta users, feedback loop |
| Beta público | 3-6 | Product Hunt, primeros paying users, Team tier |
| Growth inicial | 6-12 | 500+ subscriptores, Play Store feature, Enterprise deal |
| Scaling | 12+ | 2K+ subscriptores, iOS (via Flutter), Enterprise contracts |

---

**Conclusión:** Savia Mobile es viable porque ataca un segmento subatendido (PM technical) con una diferenciadora única (propiedad de datos + IA especializada). Los números son conservadores, pero alcanzables con ejecución consistente.
