-- Salon y Mas - Corrige un error mio de la migracion de fotos privadas.
--
-- QUE PASO
--
-- En `20260809180000_fotos_privadas_hasta_aprobar.sql` se creo el ayudante
-- `private.beautyos_can_delete_work_photo` y se escribio:
--
--     revoke all on function ... from public, anon, authenticated;
--
-- ...y **nunca se le volvio a conceder a `authenticated`**. Se copio el patron
-- de las funciones normales -- quitar todo y despues conceder -- pero se
-- quedo a mitad.
--
-- CONSECUENCIA REAL, encontrada por el propietario probando en produccion:
-- subir una foto fallaba con
--
--     StorageException: permission denied for function
--     beautyos_can_delete_work_photo, statusCode: 403
--
-- Le paso a un estilista subiendo al almacen privado, aunque esa politica no
-- usa este ayudante: al insertar, Postgres evalua **todas** las politicas de
-- insercion de `storage.objects`, incluida la del almacen publico, que si lo
-- usa. Con dueno o admin habria fallado igual al **publicar** una foto, y
-- tambien al borrarla.
--
-- POR QUE HACE FALTA EL PERMISO
--
-- Una politica de seguridad se evalua **con los permisos de quien hace la
-- operacion**, no con los del dueno de la base. Si la politica llama a una
-- funcion, ese usuario necesita poder ejecutarla. Es distinto de una funcion
-- `security definer` llamada desde la aplicacion, donde la app pide permiso
-- explicito.
--
-- POR QUE NO LO DETECTO NINGUNA VERIFICACION
--
-- Dos motivos, y los dos quedan corregidos:
--
--   1. `162_verify_fotos_privadas.sql` comprobaba que las politicas
--      **existieran**, no que se pudieran **evaluar**. Se le agrega la
--      comprobacion de permisos.
--   2. `163_test_reglas_de_dinero.sql` corre como dueno de la base, que se
--      salta las comprobaciones de permiso de ejecucion. Suplantar a un
--      usuario poniendo su identificador en la sesion **no** cambia los
--      privilegios reales. Es un limite del metodo que conviene tener
--      presente: **hay fallos de permisos que solo aparecen usando la
--      aplicacion de verdad**.
--
-- A `anon` no se le concede nada, a proposito: eso si seria repetir el
-- descuido de H-11.

begin;

grant execute on function private.beautyos_can_delete_work_photo(uuid)
  to authenticated;

commit;
