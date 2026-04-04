# Client Profile Manager — Dominio

## Por que existe esta skill

La PM necesita un registro centralizado de clientes con sus datos de contacto, reglas de negocio y proyectos vinculados para contextualizar cualquier decision. Esta skill gestiona el ciclo de vida completo de perfiles de cliente en SaviaHub, proporcionando operaciones CRUD con validacion, indice automatico y sincronizacion con el repositorio remoto.

## Conceptos de dominio

- **SaviaHub**: repositorio git separado donde se almacenan datos reales de clientes y proyectos (nivel N4)
- **Perfil de cliente**: conjunto de ficheros (profile.md, contacts.md, rules.md) que describen identidad, contactos y reglas del cliente
- **Slug**: identificador unico en kebab-case generado a partir del nombre del cliente, usado como nombre del directorio
- **SLA tier**: nivel de servicio del cliente (basic, standard, premium) que puede influir en priorizacion
- **Indice (.index.md)**: tabla auto-mantenida con resumen de todos los clientes para consulta rapida

## Reglas de negocio que implementa

- El slug debe ser unico en clients/ — crear duplicados esta bloqueado
- Los campos name y status son obligatorios; status solo acepta active, inactive o prospect
- Nunca incluir secrets, tokens o passwords en ficheros de cliente
- Confirmar con PM antes de push al remote de SaviaHub
- contacts.md con PII puede excluirse del remote via .gitignore

## Relacion con otras skills

- **Upstream**: savia-hub-sync (inicializacion y sincronizacion del repositorio SaviaHub)
- **Downstream**: backlog-git-tracker (requiere cliente y proyecto existentes), context-interview-conductor (usa perfil para contextualizar entrevistas)
- **Paralelo**: company-messaging (usa datos de contacto para comunicaciones)

## Decisiones clave

- Ficheros markdown separados (profile, contacts, rules) en vez de un solo fichero para permitir gitignore selectivo de PII
- SaviaHub como repositorio separado del workspace para que los datos de clientes nunca contaminen el repo publico
- Indice auto-generado en vez de manual para evitar desincronizacion entre directorios reales y tabla de clientes
