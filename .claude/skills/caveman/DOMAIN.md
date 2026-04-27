# Caveman — Dominio

## Por qué existe esta skill

Hay sesiones donde el coste por token importa más que la prosa: móvil con bandwidth limitado, dictado por voz (Voicebox SE-075), sesiones largas donde acumular caveman ahorra ~75% del contexto, debugging rápido donde Mónica no necesita la explicación completa. Sin un modo explícito, cada respuesta arrastra filler que no aporta señal.

## Conceptos de dominio

- **Filler**: lenguaje de cortesía/transición sin valor informativo ("claro", "en seguida", "perfecto")
- **Hedging**: cualificadores defensivos que diluyen la afirmación ("podría ser", "tal vez")
- **Auto-clarity exception**: ventana donde el modo se apaga porque la compresión arriesga malinterpretación (security warnings, ops irreversibles)
- **Fragmentos**: oraciones sin verbo cuando el contexto los recupera ("Bug auth. Fix:")

## Reglas de negocio que implementa

- Activación explícita: Mónica debe decirlo (no auto-detect del agente — es preferencia humana)
- Persistencia hasta apagado explícito ("stop caveman", "modo normal")
- Sustancia técnica intacta: identificadores, errores literales, code blocks no se comprimen
- Exception en operaciones irreversibles (NUNCA arriesgar misread en `rm -rf` o `git push --force`)

## Relación con otras skills

- **Upstream**: ninguna — es trigger humano puro
- **Downstream**: cualquier skill que el agente invoque sigue produciendo su output normal; caveman se aplica a la respuesta agregada al usuario
- **Paralelo**: alineada con `docs/rules/domain/radical-honesty.md` Rule #24 (zero filler) — caveman es el mismo principio en versión extrema

## Decisiones clave

- Trigger explícito en vez de auto-detect: la intuición del agente sobre "cuánto contexto necesita el humano" es ruidosa; mejor que Mónica decida
- Auto-clarity exception explícita: comprimir un warning de seguridad es worse-of-both (ahorra 50 tokens, arriesga incidente irreversible)
- Atribución MIT a Pocock en SKILL.md, prosa propia: el patrón es universal pero el texto se reescribe para el tono Savia

## Limitaciones conocidas

- No comprime markdown estructural (headings, code blocks) — sólo prosa
- No funciona bien para explicaciones pedagógicas (Mónica aprendiendo algo nuevo) — ella sale del modo manualmente cuando lo necesita
- Atajos en español a veces chocan con tecnicismos en inglés (DB vs base de datos) — preferencia: inglés técnico para código, español para prosa
