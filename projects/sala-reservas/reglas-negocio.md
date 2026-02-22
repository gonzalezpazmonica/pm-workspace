# Reglas de Negocio — Sala Reservas

## Dominio: Gestión de Salas

### RN-SALA-01: Nombre único
El nombre de una sala debe ser único en el sistema. No pueden existir dos salas con el mismo nombre.
- Error: `DuplicateSalaNameException`
- HTTP: 409 Conflict

### RN-SALA-02: Capacidad mínima
La capacidad de una sala debe ser mínimo 1 persona.
- Error: `ValidationException` (campo: Capacidad)
- HTTP: 400 Bad Request

### RN-SALA-03: Capacidad máxima
La capacidad máxima es 200 personas (sala de conferencias más grande).
- Error: `ValidationException` (campo: Capacidad)
- HTTP: 400 Bad Request

### RN-SALA-04: Nombre obligatorio y con longitud
El nombre no puede estar vacío ni tener solo espacios. Longitud: 3-100 caracteres.
- Error: `ValidationException` (campo: Nombre)
- HTTP: 400 Bad Request

### RN-SALA-05: Sala con reservas no se puede eliminar
No se puede eliminar una sala que tenga reservas futuras (fecha ≥ hoy).
- Error: `SalaTieneReservasFuturasException`
- HTTP: 409 Conflict

### RN-SALA-06: Sala desactivada no acepta reservas
Si `Disponible = false`, no se pueden crear nuevas reservas en esa sala.
- Error: `SalaNoDisponibleException`
- HTTP: 409 Conflict

### RN-SALA-07: Ubicación
La ubicación es opcional. Si se provee, longitud máxima: 200 caracteres.

---

## Dominio: Gestión de Reservas

### RN-RESERVA-01: Nombre de empleado obligatorio
El nombre del empleado no puede estar vacío ni tener solo espacios. Longitud: 3-150 caracteres.
- Error: `ValidationException` (campo: NombreEmpleado)
- HTTP: 400 Bad Request

### RN-RESERVA-02: Fecha no puede ser pasada
No se pueden crear reservas para fechas anteriores a hoy (fecha local del servidor).
- Error: `ValidationException` (campo: Fecha)
- HTTP: 400 Bad Request

### RN-RESERVA-03: Hora inicio < Hora fin
La hora de inicio debe ser estrictamente anterior a la hora de fin.
- Error: `ValidationException` (campo: HoraFin)
- HTTP: 400 Bad Request

### RN-RESERVA-04: Duración mínima
La reserva debe durar mínimo 15 minutos.
- Error: `ValidationException`
- HTTP: 400 Bad Request

### RN-RESERVA-05: Duración máxima
La reserva puede durar como máximo 8 horas en un mismo día.
- Error: `ValidationException`
- HTTP: 400 Bad Request

### RN-RESERVA-06: Horario laboral
Las reservas solo se pueden hacer en horario laboral: lunes a viernes, de 08:00 a 20:00.
- Error: `FueraHorarioLaboralException`
- HTTP: 422 Unprocessable Entity

### RN-RESERVA-07: Sin solapamiento (REGLA CLAVE)
Una sala no puede tener dos reservas que se solapen en el tiempo.
Dos reservas se solapan si: `inicio1 < fin2 AND inicio2 < fin1` (para la misma sala y fecha).
- Error: `ConflictoReservaException`
- HTTP: 409 Conflict
- El error debe incluir el detalle de la reserva conflictiva: {reserva_id, nombre_empleado, hora_inicio, hora_fin}

### RN-RESERVA-08: Cancelación solo de reservas futuras
Solo se pueden cancelar reservas cuya fecha y hora de inicio sean futuras (> ahora).
- Error: `ReservaPasadaException`
- HTTP: 409 Conflict

### RN-RESERVA-09: Motivo opcional
El motivo de la reserva es opcional. Si se provee, longitud máxima: 500 caracteres.

---

## Dominio: Lógica de Conflictos (Domain Service)

### ValidarConflictoReservaService

Responsabilidad: verificar si una nueva reserva entra en conflicto con las existentes.

```
Inputs:  SalaId, Fecha, HoraInicio, HoraFin, (ReservaId a excluir para updates)
Output:  Result<bool> — Success si no hay conflicto, Failure con ConflictoReservaException

Query de conflicto:
  SELECT * FROM Reservas
  WHERE SalaId = @SalaId
    AND Fecha = @Fecha
    AND Estado = 'Activa'
    AND HoraInicio < @HoraFin
    AND HoraFin > @HoraInicio
    AND Id != @ExcluirReservaId  -- para ediciones
```

**Esta lógica es exclusiva de la capa de Domain** — no puede duplicarse en Application o Infrastructure.

---

## Estados de una Reserva

| Estado | Descripción | Transiciones permitidas |
|--------|-------------|------------------------|
| `Activa` | Reserva confirmada y vigente | → Cancelada |
| `Cancelada` | Reserva cancelada por el empleado | Estado final |

No existe estado "Completada" — las reservas pasadas simplemente quedan en `Activa` como histórico.

---

## Invariantes del Agregado Reserva

1. Una `Reserva` siempre pertenece a una `Sala` existente
2. Una `Reserva` en estado `Cancelada` no puede volver a `Activa`
3. El campo `FechaCancelacion` solo se rellena cuando `Estado = Cancelada`
4. El `NombreEmpleado` es inmutable una vez creada la reserva (no se puede editar)

---

## Glosario del Dominio

| Término | Definición |
|---------|-----------|
| Sala | Espacio físico reservable (sala de reuniones, sala de formación, etc.) |
| Reserva | Bloqueo de una sala para un periodo de tiempo concreto por un empleado |
| Conflicto | Solapamiento temporal entre dos reservas de la misma sala |
| Horario laboral | Lunes a viernes, 08:00-20:00 (hora local del servidor) |
| Disponible | Atributo de Sala que indica si acepta nuevas reservas |
