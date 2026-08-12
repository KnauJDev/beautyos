# Mapa técnico — dónde está cada cosa y cómo se opera

**Creado:** 11 de agosto de 2026 (D-131) · **Se actualiza cuando cambia un hecho, no cada sesión**

**Para qué sirve:** para **no volver a averiguar** lo que ya se averiguó. Todo
lo de aquí se comprobó ejecutándolo o leyéndolo en el código, no de memoria.

**Lo que este documento NO hace:** no opina sobre qué falta ni en qué orden —
eso lo manda el `PLAN_MAESTRO`, y sigue sin haber un cuarto documento con
opinión sobre el plan (D-126). Este es de la familia de `CORREO_Y_DOMINIO.md`:
se lee **cuando hay que hacer algo**, no para saber qué hacer.

---

## 1. El proyecto en Supabase — y la trampa del nombre

> ⚠️ **El proyecto de PRODUCCIÓN se llama `beautyos-dev`.** No hay ningún otro.
> Ese nombre ya hizo que se archivara un hallazgo falso **dos veces** (D-037 el
> 20-jul, y otra vez en D-118 el 09-ago). **Si ves "dev", no asumas que es un
> entorno de pruebas: es el único que existe y es el real.**

| | |
|---|---|
| Nombre | `beautyos-dev` |
| Identificador (`project-ref`) | `eogppgbdnwxdtcbctaol` |
| Organización | `ffnlzoyeittnjkyiejze` |
| Región | `us-west-2` |
| PostgreSQL | 17.6 |
| Servidor de base de datos | `db.eogppgbdnwxdtcbctaol.supabase.co` |
| Creado | 24 de junio de 2026 |
| Plan | Free — sube a Pro en el paso 3.4 |

**La aplicación se conecta** con la URL y la `publishableKey` escritas en
[`lib/main.dart`](../../lib/main.dart) (líneas 47-50). Esa clave es **pública
por diseño**: va dentro del JavaScript que se sirve al navegador. Las claves
antiguas `anon` y `service_role` están **desactivadas** desde el 09-ago
(D-127); no las reactives sin una razón escrita.

**No existe un segundo proyecto.** Comprobado el 11-ago con `projects list`:
la lista devuelve uno solo. Eso es justamente lo que falta en el **paso 2.2**.

---

## 1-bis. Qué hay REALMENTE dentro de la base

> **Léelo antes de tratar estos datos como sensibles, o de tratarlos como
> desechables.** No son ni una cosa ni la otra, y confundirse en cualquiera de
> las dos direcciones sale caro.

**Hoy, 12 de agosto de 2026:**

| | |
|---|---|
| Negocios | **Uno solo: "Naguara de Uñas"**, marcado `is_demo = true` (D-120) |
| De quién es | **Del propio propietario.** No es un cliente |
| Los 703 tickets, las 36 clientas, los $67 millones | **Sembrados por el asistente** de febrero a agosto (D-112). **No son personas reales ni dinero real** |
| Las cuentas de `auth` | Correos de prueba del propietario (`elboga00X@gmail.com`) y el suyo de plataforma |
| Fotos, reseñas, compras | De prueba también |

**Qué significa esto en la práctica:**

- **Copiar esta base a un proyecto de ensayo NO es exponer datos de terceros.**
  Es mover datos inventados. Pausar o borrar el ensayo es **higiene y ahorro**,
  no una obligación legal.
- **Pero la base ES producción.** Es la única que existe, es la que sirve la
  aplicación publicada, y perderla o corromperla cuesta el trabajo de meses.
  **"De prueba" describe los datos, no la base.**
- Los datos sembrados **no son basura**: son lo que permite ver funcionar las
  comparaciones del Dashboard (D-110) y lo que hizo posible probar todo. Por eso
  D-120 decidió **etiquetarlos, no borrarlos**.

### ⚠️ Qué cambia el día que entre el primer cliente real

**Ese día, todo lo de arriba deja de ser cierto de golpe.** Esta lista existe
para que nadie tenga que acordarse:

1. **Copiar la base a un proyecto de ensayo pasa a mover datos personales de
   terceros** — nombres y teléfonos de las clientas de otro salón. Ahí sí
   aplican la Ley 1581 y el criterio de D-115: el ensayo se borra al terminar,
   sin excepción.
2. **Los respaldos pasan a ser semanales**, no solo antes de cada migración
   (`RESPALDO_Y_RESTAURACION`).
3. **Las cifras del panel de plataforma dejan de ser limpias** si no se
   descuenta el negocio de prueba. Por eso existe la insignia **PRUEBA** y por
   eso los de prueba se ordenan al final (D-120).
4. **El primer ticket real seguiría la numeración sembrada** — sería el 0000704
   o más. Se corrige con `set_ticket_numbering` (D-117, hallazgo P).
5. **Los errores dejan de ser gratis.** Hoy un fallo lo sufre el propietario y
   lo reporta; entonces lo sufre alguien que paga y no vuelve.

---

## 2. Cómo se publica cada cosa

Son **tres caminos distintos** y confundirlos cuesta tiempo.

| Qué | Cómo se publica | Quién |
|---|---|---|
| **La aplicación** (Flutter Web) | `git push` → Cloudflare Pages compila y publica sola. **Comprobar que salió** — ver abajo | Pedir permiso |
| **Las Edge Functions** | CLI de Supabase (abajo) | Sin permiso desde D-131 |
| **Las migraciones** | `aplicar_sql.ps1`, a mano | **Solo el propietario** |

> **Las Edge Functions NO salen del repositorio.** Un `push` no las publica y
> publicarlas no necesita `push`. Son dos mundos separados: por eso el 10-ago
> el repositorio y lo desplegado estuvieron un rato diciendo cosas distintas.

### Cómo comprobar que un cambio de la app SALIÓ de verdad

**Un `push` correcto no garantiza que la app se publicara** (D-133). Sin salir de
la terminal, se busca en el JavaScript publicado algo que solo exista en el
cambio nuevo — el nombre de una función, un texto:

```
curl -s https://salonymas.com/main.dart.js -o /tmp/pub.js
grep -c "get_stylists_for_invitation" /tmp/pub.js
```

`0` significa que **lo publicado es la versión vieja**, aunque GitHub tenga el
commit. Es más fiable que mirar la pantalla: si el cambio también tocó la base
de datos, la mitad de la base sí funciona y **parece que se publicó**.

### La CLI de Supabase

No está instalada de forma permanente: se usa con `npx`, que la descarga a la
caché de Node. Autorizada por el propietario el 11-ago (D-131).

```
npx.cmd supabase@latest login          # lo corre el propietario, abre navegador
npx.cmd supabase@latest logout         # así se corta el acceso
```

**Publicar una función:**

```
npx.cmd supabase@latest functions deploy <nombre> --project-ref eogppgbdnwxdtcbctaol --use-api --workdir C:\Proyectos\salonymas
```

**Cuatro cosas de ese comando que no son opcionales:**

1. **`npx.cmd`, no `npx`.** Windows bloquea los guiones de PowerShell, y `npx`
   a secas resuelve al bloqueado. Es la misma traba por la que los guiones del
   proyecto se llaman con `-ExecutionPolicy Bypass`. **No se arregla con
   `Set-ExecutionPolicy`:** eso baja una defensa del computador entero y para
   siempre, para ahorrarse cuatro letras.
2. **`--use-api`.** Publica sin Docker, que no está instalado (D-111).
3. **`--workdir`.** Las terminales del asistente arrancan en `C:\Proyectos`, no
   en la carpeta del proyecto. Sin esto falla con *"Entrypoint path does not
   exist"*.
4. **El nombre de la función, siempre.** Sin nombre publica **todas**. Nunca se
   usa `--prune`: **borra del servidor las funciones que no estén en la carpeta.**

**Consultar sin cambiar nada:**

```
npx.cmd supabase@latest projects list
npx.cmd supabase@latest functions list --project-ref eogppgbdnwxdtcbctaol
```

### Las funciones que existen

| Función | Estado | Qué manda |
|---|---|---|
| `send-invitation-email` | ✅ v6 desde el 10-ago | Invitación de equipo |
| `send-low-stock-alert` | ✅ v6 desde el 11-ago | Alarma de stock bajo |

**Las dos tienen `verify_jwt = false`** en `supabase/config.toml` y en el
servidor. Significa que cualquiera puede hacerlas ejecutar sin cuenta. **Los
datos siguen protegidos** — quien autoriza es la función de base de datos, no
la puerta — pero la cuota es gastable por cualquiera. Anotado como **hallazgo
U**; nadie lo decidió, lo generó Supabase por defecto el 27-jul.

---

## 3. Los guiones de `scripts/`

| Guion | Qué hace |
|---|---|
| `respaldo_supabase.ps1` | **El respaldo vigente.** Baja la base a un archivo. Antes de cada migración |
| `respaldo_archivos.ps1` | Los archivos (logos, portadas, fotos) — **el otro respaldo no los guarda**, solo su lista |
| `aplicar_sql.ps1` | Ejecuta un archivo SQL contra la base. Hermano del de respaldo: codifica la contraseña igual, que es lo único que funciona con la de este proyecto |
| `diagnostico_pg.ps1` | Solo mira y reporta: por qué esta ventana no encuentra `pg_dump` |
| `instalar_herramientas_postgres.ps1` | Instala solo el cliente de PostgreSQL, sin el servidor |
| `crear_respaldo_supabase.ps1` | **Obsoleto.** Lo reemplazaron los dos primeros (D-111). No usar |

> ⚠️ **Una foto borrada no está en ningún respaldo.** El respaldo de la base
> guarda la *lista* de archivos, no los archivos. Por eso existe
> `respaldo_archivos.ps1` y por eso la pantalla avisa de que borrar no se
> deshace (D-119).

---

## 4. Dónde está cada cosa

| Carpeta | Qué hay | Cuánto |
|---|---|---|
| `lib/pages/` | Una pantalla por módulo | 29 archivos |
| `lib/services/` | Todo lo que llama a la base | 49 |
| `lib/models/` | Cómo se leen los datos que llegan | 54 |
| `lib/widgets/` | Piezas reutilizables | — |
| `lib/theme/` | **El sistema de diseño.** `AppColors`, `AppSpacing`, `AppRadius`, `AppTheme`, `AppBrand` (D-102, D-109) | — |
| `supabase/migrations/` | El historial de la base, en orden de fecha | 73 |
| `supabase/sql/` | Guiones sueltos de verificación y diagnóstico | 155 |
| `supabase/functions/` | Las dos Edge Functions | 2 |
| `test/` | Las pruebas | 10 archivos |

**Los almacenes de archivos** (Storage), verificados en las migraciones:

| Almacén | Público | Para qué |
|---|---|---|
| `work-photos-private` | ❌ | Toda foto de trabajo **nace aquí** |
| `work-photos` | ✅ | Solo las **aprobadas**. Dirección permanente, para que una red social pueda ir a buscarlas |
| `tenant-logos`, `tenant-covers`, `stylist-photos` | ✅ | Material de mercadeo. Públicos **a propósito** (D-119) |

---

## 5. Cómo se nombran las cosas

- **`_v2`** al final de una función de base de datos: la versión que **exige
  sede explícita** y vuelve a autorizar en el servidor (D-017, D-021). Las que
  no lo llevan pueden ser heredadas.
- **`private.beautyos_*`**: ayudantes internos. No los llama la aplicación.
- Las funciones de negocio son **`security definer`** con
  `set search_path = pg_catalog`. Corren con permisos de dueño: **toda la
  autorización va escrita dentro**, casi siempre empezando por
  `private.beautyos_resolve_branch_access(...)`.
- **Nunca se borra un registro físicamente** (D-051, D-056): se marca inactivo
  o eliminado. El historial se conserva.

---

## 6. Las pruebas — y lo que NO cubren

**89 pruebas en 10 archivos.** `flutter analyze` limpio.

| Archivo | Qué vigila |
|---|---|
| `dinero_y_roles_test.dart` (16) | Saldo, estado de pago, y **qué acciones ve cada rol** |
| `periodo_dashboard_test.dart` (29) | Los períodos del Dashboard |
| `dashboard_serie_test.dart` (13) · `dashboard_overview_test.dart` (10) | Gráfico e indicadores |
| `temas_marca_blanca_test.dart` (12) | Los 5 temas más el personalizado |
| `numero_de_ticket_test.dart` (3) | Que el consecutivo llegue intacto a la pantalla |
| `sin_colores_sueltos_test.dart` (1) | **Falla si alguien escribe un color a mano** fuera del tema |
| `branch_context_test.dart` · `tramo_d3_2_...` (2+2) | Contexto de sede |
| `widget_test.dart` (1) | Arranque |

> ### Lo que ninguna prueba cubre, y hay que saberlo
>
> 1. **Las reglas de dinero viven en la base de datos, no en la aplicación.**
>    Se comprueban a mano con `supabase/sql/163_test_reglas_de_dinero.sql`, que
>    **no es una prueba automática**: alguien tiene que ejecutarlo. Lo
>    automático llega con el paso 2.2.
> 2. **Los permisos solo fallan usando la aplicación de verdad.** El guion SQL
>    corre como dueño de la base, que **se salta las comprobaciones de permiso
>    de ejecución** (D-122).
> 3. **Nada comprueba que una función reescrita conserve lo que hacía.** De ahí
>    salieron tres fallos en un solo día (D-119, D-122, D-123), y de ahí la
>    regla de comparar línea por línea.
> 4. **El asistente no ve la interfaz.** Los cinco fallos del 10-ago los
>    encontró el propietario probando.

---

## 7. Las trampas que ya mordieron

Cada una costó tiempo real. Están aquí para que cueste una sola vez.

| Trampa | Qué pasa | Dónde se explicó |
|---|---|---|
| **Dependencia con rango (`^1`)** en una Edge Function | El mismo código se comporta distinto en cada despliegue y revienta **antes** de la primera línea propia. **Siempre versión exacta** | D-128 |
| **El `deno.json` va con el `index.ts`** | Publicar solo el código deja la dependencia rota. La CLI los sube juntos; a mano hay que acordarse | D-128, D-131 |
| **`npx` bloqueado en PowerShell** | Usar `npx.cmd` | D-131 |
| **Un `push` puede no publicar nada, y nadie avisa** | El 11-ago la compilación falló en **3 segundos** al descargarse el código: `server certificate verification failed. CAfile: none`. Es una avería **de la máquina de Cloudflare**, no del proyecto. **El propietario probó la app creyendo que era la versión nueva y no lo era.** Se arregla con **"Retry deployment"** | D-133 |
| **Un `numeric` puede llegar como texto** | Si se lee como número, revienta en producción y en ninguna prueba | D-121 |
| **El contador de tickets está en 701** | Los 700 numerados incluyen los datos sembrados. Al borrar la semilla, el primero real sería el 0000701. Se corrige con `set_ticket_numbering` | D-117, D-118, D-120 |
| **Un usuario con membresía no se puede borrar** desde Supabase | Las llaves tienen `RESTRICT`. La base se defiende sola. Verificado el 10-ago | HANDOFF 10-ago |
| **Ningún módulo se recarga solo** | Entrar a un módulo no refresca sus datos: hay que pulsar Actualizar o F5 | Hallazgo Q |
| **La prueba gratis del propietario vence** | Cuando llegue a cero, su propio negocio deja de aceptar citas y no podrá probar. Se extiende con `platform_extend_trial` | HANDOFF 10-ago |
| **Una foto sin estilista rompía la galería entera** | Faltaban dos textos de respaldo (`coalesce`) al reescribir una función | D-123 |
| **`LowStockAlertService` se traga los errores** a propósito | La app **nunca se queja** si el correo falla. La única prueba válida es que el correo llegue | D-131 |

---

*Si un dato de aquí deja de ser cierto, se corrige aquí mismo. Este documento
no lleva historial: para eso está el `REGISTRO_DE_DECISIONES`.*
