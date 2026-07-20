# Respaldo y restauración de Supabase

- **Estado:** procedimiento ejecutado y restauración de ensayo aprobada
- **Proyecto de origen:** `beautyos-dev` (`eogppgbdnwxdtcbctaol`)
- **Responsable:** propietario del producto con acompañamiento de Codex

**Primera evidencia aprobada:** `BeautyOS_Backup_2026-07-19_19-12-48`, conservada fuera de Git en la carpeta privada `Documentos/BeautyOS Backups`.

## 1. Objetivo

Producir una copia externa capaz de reconstruir roles, esquema y datos de BeautyOS antes de cualquier migración estructural. La copia no se guarda en Git porque contiene datos personales y operativos.

## 2. Regla del plan gratuito

Supabase realiza copias diarias administradas para proyectos Pro, Team y Enterprise. Para el plan Free recomienda exportar periódicamente con Supabase CLI y conservar copias externas.

Fuente: [Database Backups](https://supabase.com/docs/guides/platform/backups).

## 3. Contenido de cada paquete

Cada respaldo debe contener:

```text
BeautyOS_Backup_YYYY-MM-DD_HH-mm/
  roles.sql
  schema.sql
  data.sql
  hashes.sha256.txt
  MANIFIESTO.md
```

- `roles.sql`: roles y privilegios compatibles.
- `schema.sql`: tablas, funciones, políticas, triggers, índices y demás estructura.
- `data.sql`: datos, incluida la información necesaria de Auth filtrada por Supabase CLI.
- `hashes.sha256.txt`: huellas para detectar corrupción o sustitución.
- `MANIFIESTO.md`: fecha, proyecto, versión Postgres, tamaño, resultado de restauración y responsable; nunca incluye contraseñas.

Los objetos binarios de Supabase Storage requieren una copia separada. Al 19/07/2026 no existen Edge Functions desplegadas; esta condición debe volver a comprobarse en cada respaldo.

## 4. Ubicación y seguridad

Guardar el paquete fuera de `C:\Proyectos\BeautyOS`, en la carpeta personal segura de OneDrive destinada a respaldos. Mantener al menos:

- una copia local cifrada;
- una copia sincronizada fuera del equipo;
- acceso restringido al propietario;
- nunca compartir el archivo por chat ni subirlo a GitHub.

Las contraseñas, cadenas de conexión y llaves no se escriben en documentos, scripts, capturas ni commits.

## 5. Preparación única del equipo

Al 19/07/2026 quedaron instalados y operativos Docker Desktop 4.82.0, Docker Engine 29.6.1, Node.js LTS 24.18.0 y Supabase CLI 2.109.1 mediante `npx`. WSL 2, Plataforma de máquina virtual y la virtualización de firmware quedaron habilitados. También se validó la imagen oficial de Supabase Postgres 17.6.1.143 usada en el ensayo local.

Después del reinicio:

1. Abrir Docker Desktop y esperar a que el motor indique que está listo.
2. Abrir PowerShell y comprobar:

```powershell
docker version
npx --yes supabase@latest --version
```

Supabase CLI necesita Docker para ejecutar una versión compatible de `pg_dump` con filtros propios de Supabase.

Fuentes: [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started), [restauración desde Platform](https://supabase.com/docs/guides/self-hosting/restore-from-platform), [instalación de WSL](https://learn.microsoft.com/windows/wsl/install) y [virtualización en equipos Lenovo](https://support.lenovo.com/es/es/solutions/ht500006).

## 6. Obtener la conexión sin revelar secretos

1. Entrar al Dashboard de Supabase.
2. Abrir el proyecto `beautyos-dev`.
3. Pulsar **Connect**.
4. Copiar la cadena **Session pooler**.
5. Si no se recuerda la contraseña de base de datos, restablecerla en **Database > Settings**.
6. Usarla únicamente en la terminal local. No pegarla en ChatGPT, Codex, GitHub, documentos o capturas.

La cadena tiene esta forma general:

```text
postgresql://postgres.PROJECT-REF:[CONTRASEÑA]@HOST:5432/postgres
```

## 7. Crear el respaldo

### Opción recomendada para BeautyOS

El repositorio incluye `scripts/crear_respaldo_supabase.ps1`. El asistente:

- solicita la conexión de forma oculta;
- no la escribe en archivos ni en Git;
- crea los tres dumps en `Documentos/BeautyOS Backups`;
- excluye `storage.buckets_vectors` y `storage.vector_indexes`, tablas internas protegidas que la guía oficial indica omitir del volcado de datos;
- comprueba que no estén vacíos;
- genera las huellas SHA-256 y el manifiesto.

Desde `C:\Proyectos\BeautyOS` ejecutar:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\crear_respaldo_supabase.ps1
```

### Opción manual

Desde la carpeta segura de respaldos, reemplazar `[CONNECTION_STRING]` localmente:

```powershell
supabase db dump --db-url "[CONNECTION_STRING]" -f roles.sql --role-only
supabase db dump --db-url "[CONNECTION_STRING]" -f schema.sql
supabase db dump --db-url "[CONNECTION_STRING]" -f data.sql --use-copy --data-only -x "storage.buckets_vectors" -x "storage.vector_indexes"
```

Después generar huellas:

```powershell
Get-FileHash roles.sql, schema.sql, data.sql -Algorithm SHA256 | Format-Table Hash, Path
```

Copiar los valores al archivo `hashes.sha256.txt` sin alterar los tres SQL.

Fuente: [Backup and Restore using the CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).

## 8. Comprobación mínima inmediata

Antes de considerar creada la copia:

1. Los tres archivos existen y pesan más de cero bytes.
2. `schema.sql` contiene objetos `public` y políticas.
3. `data.sql` contiene instrucciones `COPY`.
4. Las tres huellas SHA-256 se registraron.
5. Se vuelve a ejecutar `supabase/sql/103_tramo_0_audit_multisite_baseline.sql` y se adjunta el resultado numérico al manifiesto.

Esto comprueba completitud básica, pero todavía no demuestra restaurabilidad.

## 9. Prueba real de restauración

La puerta se cierra únicamente al restaurar en un entorno de ensayo desechable, nunca sobre producción.

Opciones, en orden recomendado:

1. Instancia local completa de Supabase con Docker, preferiblemente Postgres 17.
2. Proyecto temporal separado de Supabase, después de confirmar expresamente cualquier costo.

Restaurar roles, esquema y datos siguiendo la guía oficial y con detención ante el primer error. Luego comprobar:

- existen las 24 tablas públicas esperadas;
- funciones, políticas, triggers e índices están presentes;
- los conteos y totales del Tramo 0 coinciden;
- Auth conserva usuarios sin exponer sus datos en evidencias;
- la app de ensayo puede iniciar sesión y consultar mediante RPC;
- ninguna tabla, archivo o función del origen fue alterada.

No se acepta como prueba abrir el SQL o confiar en que el comando terminó: debe existir una base restaurada y consultable.

### Resultado del ensayo del 19/07/2026

- Se levantó un PostgreSQL 17.6.1.143 local, aislado y desechable mediante Docker.
- Se restauraron roles, esquema y datos dentro de una transacción atómica, deteniéndose ante cualquier error.
- Las tres huellas SHA-256 del paquete original coincidieron antes y después del ensayo.
- El primer intento se revirtió correctamente al encontrar permisos protegidos sobre `storage.buckets_vectors`.
- Se verificó que `storage.buckets_vectors` y `storage.vector_indexes` estaban vacías. Para el segundo intento se generó una copia temporal del volcado omitiendo únicamente esos dos bloques; el respaldo original no fue modificado.
- Se compararon exactamente 51 tablas: **51 coincidentes y 0 diferencias**.
- Auth conservó 2 usuarios y 2 identidades, comprobados solo por conteo y sin exponer datos personales.
- El esquema público restaurado contiene 24 tablas, 54 funciones, 3 triggers, 64 índices, 322 restricciones y 3 políticas RLS.
- Los 17 controles de integridad devolvieron 0 violaciones y los conteos financieros, operativos y de inventario coincidieron con la línea base.

**Resultado:** restauración de ensayo aprobada. El entorno local puede eliminarse porque la evidencia reproducible quedó documentada y el paquete original permanece fuera de Git.

## 10. Criterio GO / NO-GO

**GO** para migrar cuando:

- los tres dumps y sus hashes están almacenados fuera de Git;
- la restauración de ensayo terminó;
- la línea base restaurada coincide;
- se documentó la forma de volver a la versión anterior.

**NO-GO** si falta cualquiera de esos puntos. En ese caso solo se permite diseñar y revisar migraciones, no aplicarlas.

La evidencia del 19/07/2026 satisface esta puerta para iniciar el Tramo A. Cada futura migración seguirá exigiendo revisión, copia previa, pruebas y ruta de reversión propias.

## 11. Frecuencia futura

Mientras BeautyOS continúe en plan Free:

- antes de toda migración estructural;
- semanalmente durante el piloto;
- inmediatamente antes de una publicación importante;
- después de cambios críticos, una vez validada la base.

Antes de operar con clientes reales se reevaluará Pro o una estrategia automatizada, junto con una copia separada de Storage.
