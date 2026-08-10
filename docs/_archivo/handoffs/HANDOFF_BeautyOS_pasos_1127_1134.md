# HANDOFF BeautyOS — pasos 1127–1134

**Fecha:** 20 de julio de 2026  
**Bloque documentado:** diseño técnico del Tramo B — contexto operacional por sede  
**Estado:** diseño cerrado; implementación y producción pendientes  
**Modelo recomendado:** GPT-5.6 Sol, esfuerzo Alto, solo para la futura migración; Terra Medio es suficiente para revisión documental y pruebas guiadas

## Resumen ejecutivo

Se diseñó el Tramo B sin modificar la base de producción. El alcance comprende 15 tablas y 139 filas actuales. Cada registro operativo recibirá sede mediante la Sede principal o su padre natural (ticket, servicio de ticket o compra). Se añadió al diseño un puente temporal para evitar que la aplicación heredada siga creando filas sin sede antes del Tramo C.

## Pasos registrados

**1127.** Se confirmó que el Tramo A estaba publicado, el repositorio limpio y la siguiente compuerta era exclusivamente el diseño del Tramo B.

**1128.** Se releyeron las reglas del repositorio y las prácticas vigentes de Supabase para RLS, claves foráneas, restricciones, índices y exposición mediante Data API.

**1129.** Se inventarió el esquema vivo: tablas, conteos, RLS, claves, triggers y funciones dependientes. Se identificaron 15 tablas objetivo y 139 filas operativas.

**1130.** Se ejecutaron comprobaciones de coherencia entre tenant, ticket, servicio, estilista, compra y producto. Todas devolvieron cero violaciones en la línea base actual.

**1131.** Se clasificaron seis raíces por tenant y nueve grupos heredados por ticket, servicio de ticket o compra. Se excluyeron catálogos tenant, políticas de comisión y auditorías globales que no pertenecen directamente a una sede.

**1132.** Se diseñó el puente temporal de compatibilidad: triggers privados derivarán la Sede principal para escrituras heredadas y la sede del padre para hijos, rechazando cruces de tenant o sede.

**1133.** Se fijaron claves compuestas, índices, secuencia atómica, invariantes financieras, pruebas negativas, respaldo fresco y reversión protegida. El Tramo B no hará `branch_id NOT NULL` ni cambiará Flutter.

**1134.** Se actualizó el expediente rector, el plan de migración, los criterios de salida y la auditoría técnica. No se creó migración, no se ejecutó Docker y no se mutó Supabase.

## Decisiones cerradas

- `branch_id` se agregará nullable en el Tramo B y será obligatorio solo en el Tramo D.
- La aplicación heredada seguirá operativa mediante un puente temporal seguro.
- Los hijos no confiarán en una sede enviada por el cliente; la heredarán de su padre.
- Pagos, comisiones, stock y auditorías conservarán exactamente sus valores.
- Las reseñas históricas sin ticket se asignarán a la Sede principal, dejando evidencia.
- Las restricciones heredadas de horario y política por tenant se conservarán hasta habilitar una segunda sede en el Tramo C.
- Alertas operativas continúan pausadas.

## Próxima compuerta

Crear, sin tocar producción:

1. migración administrada del Tramo B;
2. script de auditoría antes/después;
3. reversión protegida para ensayo;
4. pruebas negativas multisede;
5. respaldo fresco y restauración aislada.

Después se aplicará, revertirá y reaplicará en ensayo. El despliegue vivo requerirá una autorización separada.
