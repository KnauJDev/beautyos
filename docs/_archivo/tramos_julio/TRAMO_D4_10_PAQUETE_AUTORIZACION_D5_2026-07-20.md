# Tramo D4.10 — paquete de autorización D5

**Fecha:** 20 de julio de 2026
**Estado:** preparado; sin ejecución productiva
**Producción modificada:** no
**Base Git:** `b551d14 Documentar fotografia final del Tramo D4.9`

## 1. Objetivo

Preparar la autorización de D5 sin ejecutarla. Este documento define alcance,
orden, evidencias requeridas, reversión y criterios de parada para llevar a
producción los cambios ya ensayados del Tramo D.

D4.10 no autoriza por sí mismo ninguna acción productiva.

## 2. Fuentes de entrada

- D0: inventario productivo previo al retiro de compatibilidad.
- D1: Flutter estricto de sede, sin fallback silencioso.
- D2: migración `branch_id NOT NULL` con precondición de cero nulos.
- D3.2: seis RPC `_v2` por sede para reemplazar lecturas heredadas.
- D3.4: revocación reversible de seis RPC heredadas sustituidas.
- D4.6: alineación de `beautyos-dev` con D3.2 y D3.4 mediante migraciones
  versionadas.
- D4.7: reversibilidad del cliente heredado validada en `beautyos-dev`.
- D4.9: fotografía final no productiva posterior a D4.6/D4.7.
- Procedimiento de respaldo y restauración Supabase.
- Changelog oficial de Supabase revisado el 20/07/2026.

## 3. Alcance propuesto para D5

D5 debe cubrir únicamente estos elementos:

1. respaldo productivo fresco y restauración de ensayo;
2. fotografía productiva read-only inmediatamente antes del cambio;
3. aplicación versionada de migraciones ya revisadas;
4. verificación de permisos, conteos y `branch_id`;
5. auditoría final y publicación del commit;
6. plan de reversión probado para las seis RPC heredadas.

Queda fuera de D5:

- eliminar funciones heredadas;
- retirar triggers temporales de integridad o compatibilidad;
- tocar suscripciones, pagos SaaS o entitlements;
- resolver deuda general de asesores;
- modificar datos manualmente para “hacer pasar” una precondición.

## 4. Orden recomendado

El orden evita dejar clientes sin contrato disponible:

1. Confirmar proyecto productivo exacto y ventana de cambio.
2. Crear respaldo fresco fuera de Git.
3. Restaurar el respaldo en entorno de ensayo y comparar línea base.
4. Tomar fotografía productiva read-only pre-D5.
5. Aplicar D3.2 en producción: crear las seis RPC `_v2` por sede.
6. Confirmar que Flutter estricto de D1 está publicado o disponible para los
   usuarios del entorno productivo.
7. Aplicar D2 en producción: hacer `branch_id NOT NULL` solo si la precondición
   de cero nulos pasa atómicamente.
8. Aplicar D3.4 en producción: revocar `EXECUTE` de las seis RPC heredadas para
   `PUBLIC`, `anon` y `authenticated`, conservando `service_role`.
9. Ejecutar verificaciones de salida y asesores.
10. Documentar resultado y detenerse; no eliminar rutas heredadas en el mismo
    despliegue.

## 5. Migraciones candidatas

| Orden | Archivo local | Propósito |
|---:|---|---|
| 1 | `supabase/migrations/20260720183122_tramo_d3_2_reemplazos_lectura_por_sede.sql` | Agrega las seis RPC `_v2` por sede que reemplazan lecturas heredadas. |
| 2 | `supabase/migrations/20260720175139_tramo_d2_branch_id_not_null.sql` | Exige `branch_id NOT NULL` en las 15 tablas operativas si todas tienen sede. |
| 3 | `supabase/migrations/20260720190528_tramo_d3_4_revocar_rpc_heredadas.sql` | Cierra acceso externo a las seis RPC heredadas sustituidas. |

La ejecución productiva debe confirmar si Supabase registra estos nombres con
sus timestamps locales o con nombres MCP equivalentes. Lo obligatorio es
preservar trazabilidad y orden lógico, no improvisar SQL directo.

## 6. Evidencia mínima GO

Antes de tocar producción deben cumplirse todos estos puntos:

- repositorio limpio y commit local D4.10 disponible para revisión;
- proyecto productivo identificado de forma inequívoca por nombre y ref;
- respaldo fresco creado fuera de Git;
- restauración de ensayo completada con hashes y conteos coincidentes;
- fotografía productiva read-only confirma cero `branch_id` nulos en las 15
  tablas;
- Flutter estricto D1 confirmado para el entorno productivo;
- ventana de cambio aprobada por el propietario;
- plan de reversión leído y aceptado;
- autorización explícita del usuario para D5.

## 7. Criterios NO-GO

D5 debe detenerse sin aplicar cambios si ocurre cualquiera de estos casos:

- el proyecto no puede identificarse inequívocamente como producción;
- falta respaldo fresco o restauración de ensayo;
- aparece cualquier `branch_id` nulo en las 15 tablas operativas;
- D3.2 no está aplicada o no puede verificarse antes de cerrar heredadas;
- Flutter estricto D1 no está disponible para producción;
- asesores muestran una alerta nueva relacionada directamente con los cambios;
- falla cualquier verificación intermedia;
- el usuario no da autorización explícita para producción.

## 8. Reversión prevista

La reversión principal de D3.4 consiste en reotorgar temporalmente `EXECUTE` a
`authenticated` sobre las seis RPC heredadas sustituidas:

- `get_appointment_policy()`;
- `get_business_hours()`;
- `get_dashboard_metrics()`;
- `get_my_stylist_work_photos()`;
- `get_reviews_summary()`;
- `get_work_photos_summary()`.

No se debe abrir `anon`. `service_role` debe conservarse para operación técnica.

La reversión de D2, si fuera imprescindible y autorizada, debe evaluarse como
micro-paso separado: retirar `NOT NULL` es técnicamente posible, pero solo debe
hacerse después de entender qué cliente o escritura volvió a producir un caso
sin sede.

## 9. Verificaciones de salida D5

Después de aplicar D5 deben registrarse:

- historial remoto de migraciones;
- matriz de permisos de las seis RPC heredadas y seis `_v2`;
- conteos y cero `branch_id` nulos en las 15 tablas;
- ejecución de verificaciones SQL locales equivalentes;
- asesores Supabase de seguridad y rendimiento;
- resultado funcional mínimo en Flutter por sede;
- decisión explícita de no eliminar funciones ni triggers en ese despliegue.

## 10. Decisión D4.10

D4.10 deja listo el paquete de autorización, pero D5 sigue pendiente y no
autorizado. El siguiente micro-paso recomendado es D5-pre: confirmar proyecto
productivo, modalidad de respaldo y ventana de ejecución antes de cualquier
consulta o cambio sobre producción.
