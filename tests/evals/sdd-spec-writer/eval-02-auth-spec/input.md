# Eval 02 — Spec de control de acceso con tokens de corta y larga duración

## Contexto

Un microservicio backend necesita gestionar el acceso de usuarios mediante
tokens firmados. El sistema emite dos tipos: uno de vida corta para las
operaciones (15 minutos) y otro de vida larga para renovación automática
(7 días). El sistema detecta y bloquea el uso simultáneo anómalo.

## Tarea para el agente sdd-spec-writer

Crea una spec ejecutable para el módulo de control de acceso con tres operaciones:

1. Verificación de credenciales: recibe email más contraseña, devuelve token corto
   y token largo.
2. Renovación del token corto: recibe el token largo, devuelve nuevo token corto.
3. Cierre de acceso: invalida el token largo del usuario en la base de datos.

Restricciones técnicas que la spec debe reflejar:
- El token largo se persiste en base de datos en formato hash irreversible.
- Si el mismo token largo se presenta desde dos orígenes de red distintos con menos
  de 60 segundos de diferencia, todos los tokens del usuario quedan invalidados.
- El token corto contiene: identificador de usuario, marca de expiración, marca de
  emisión, y rol del usuario. Se firma con clave configurable via variable de entorno.

La spec debe incluir criterios de aceptación verificables para el flujo nominal,
el flujo con token caducado, el flujo con token inválido y el escenario de acceso
simultáneo anómalo. Debe especificar los códigos de respuesta HTTP para cada caso.
