# ADR-005 — Contexto de sede efectiva validado en el servidor

**Estado:** aceptada para implementación en el Tramo C  
**Fecha:** 2026-07-20

## Contexto

Los Tramos A y B incorporaron sedes, membresías y `branch_id` a la operación sin romper la aplicación heredada. Flutter todavía opera con un tenant y rol tomados de `user_profiles`, y las RPC actuales derivan silenciosamente la Sede principal. Ese puente no permite operar dos sedes de forma segura.

## Decisión

Toda RPC nueva de operación recibirá `p_branch_id` y resolverá en la base de datos una **sede efectiva**. El identificador enviado por Flutter expresa la selección del usuario, pero nunca constituye autorización.

La resolución comprobará, en este orden:

1. `auth.uid()` válido;
2. membresía de tenant activa y dentro de su vigencia;
3. sede perteneciente al mismo tenant;
4. sede activa cuando la operación cree o modifique actividad;
5. rol admitido para la acción;
6. para `admin`, `assistant` y `stylist`, membresía de sede activa y vigente;
7. para `stylist`, vínculo activo entre profesional y sede;
8. propiedad del registro cuando el permiso sea de alcance propio.

`tenant_owner` puede acceder a todas las sedes de su tenant sin necesitar una fila de `branch_memberships`. Los demás roles solo acceden a sedes asignadas. Un operador de plataforma no recibe acceso operativo implícito.

## Contrato de selección

- Una sola sede accesible: selección automática.
- Varias sedes accesibles: selección explícita antes de entrar a módulos operativos.
- Cero sedes accesibles: acceso operativo bloqueado con mensaje claro.
- Cambiar de sede invalida los datos visibles y recarga todos los módulos.
- La selección vive en memoria de la aplicación; no se guarda como autoridad en metadatos del usuario, JWT ni variables de sesión de PostgreSQL.
- Cada RPC vuelve a validar la sede para que una membresía revocada tenga efecto inmediato.

## Versionado compatible

Las firmas nuevas usarán sufijo `_v2` y `p_branch_id` obligatorio. Se evita crear sobrecargas ambiguas para PostgREST. Las firmas heredadas continúan temporalmente en la Sede principal hasta completar la migración de Flutter y las pruebas de dos sedes. Su retiro corresponde al Tramo D.

## Seguridad de implementación

- Los helpers de autorización viven en el esquema `private`.
- Las RPC públicas sensibles fijan `search_path`, revocan ejecución a `PUBLIC` y conceden solo a `authenticated` y `service_role` cuando corresponda.
- Las tablas nuevas permanecen sin acceso directo para clientes; la primera vía será RPC de dominio.
- Los hijos operativos heredan la sede de su padre y no aceptan una sede independiente.
- Los mensajes de denegación no confirman la existencia de datos de otra sede o tenant.

## Consecuencias

- Flutter necesitará un contexto de sede y refresco coordinado.
- Las RPC se migrarán por familias: contexto, agenda/reservas, caja/reportes y operación administrativa.
- Durante la ventana compatible habrá resultados comparables entre rutas heredadas y `_v2` para la Sede principal.
- El modelo queda preparado para cuentas con acceso a varios tenants sin confiar en un rol único del perfil.

## Alternativas descartadas

- Guardar la sede en el JWT: puede quedar obsoleta después de una revocación.
- Usar una variable de sesión SQL: no es confiable con conexiones agrupadas y reutilizadas.
- Aceptar `tenant_id` y `branch_id` desde Flutter sin resolver membresías: permitiría manipulación del contexto.
- Sustituir de una vez todas las firmas: aumentaría el riesgo y eliminaría la reversión rápida.
