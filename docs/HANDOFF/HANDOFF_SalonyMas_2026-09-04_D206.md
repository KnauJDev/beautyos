# HANDOFF Salón y Más — 4 de septiembre de 2026 ("Fuera las tarjetas del prototipo", D-206)

**Bloque documentado:** decisión **D-206** · Paso **8.29** de la **FASE 8**.

**Estado:** ✅ **CERRADO.** `flutter analyze` 0/0 y **367 de 367 pruebas en
verde** (2 nuevas). Sin migración SQL ni Edge Function.

> El bloque anterior (D-205) está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D205.md`.

---

## 1. Qué se quitó

Nueve `InfoPanel` fijos en la cabecera de nueve pantallas — **66 líneas**.
Ocupaban el alto de una tarjeta, repetían lo que ya dice el subtítulo de
`AppPage`, y en cinco casos le enseñaban a un salón el nombre del proveedor de
base de datos, que no le sirve para nada y sobre el que no puede hacer nada.

---

## 2. Las nueve no eran lo mismo, y por eso no se borraron igual

| Grupo | Cuáles | Qué se hizo |
|---|---|---|
| **Prototipo puro** | Servicios, Estilistas, Inventario, Reseñas, Fotos (todas «conectado a Supabase») | Borradas |
| **Prototipo en futuro** | Configuración: *«aquí **configuraremos** datos del negocio… y reglas **futuras** de WhatsApp e IA»* | Borrada |
| **Con reglas de permisos** | Gastos, Compras, Usuarios | **La regla pasó al subtítulo** |

### Las tres con reglas, en detalle

Lo que decían y el subtítulo no:

- **Gastos:** «Solo el propietario puede editar o anular un gasto ya guardado.»
- **Compras:** «Solo el propietario puede editar el encabezado o anular una
  compra.»
- **Usuarios:** «Las contraseñas no se muestran ni se modifican aquí.»

Esas reglas **las hace cumplir el servidor**. Si la interfaz deja de decirlas,
un administrador que no puede anular un gasto se encuentra la opción ausente
sin explicación. Se le dieron al propietario las tres salidas —mover al
subtítulo, borrar las nueve, o quitar solo las seis— y eligió **mover al
subtítulo**: se recupera todo el espacio vertical y no se pierde información.

---

## 3. Dos correcciones de más, del mismo defecto

**No estaban en el encargo**, y se dicen por eso. Al barrer el resto del código
aparecieron dos textos de carga con la misma jerga:

- `'Cargando clientes desde Supabase...'`
- `'Cargando tickets desde Supabase...'`

Es exactamente el mismo problema que los banners. Dejarlos habría sido
incoherente: retirar *«Reseñas conectadas con Supabase»* y conservar *«Cargando
tickets desde Supabase»*.

---

## 4. Lo que NO se tocó, y tiene que seguir ahí

### 4.1 La mención legal en Términos — **no es un descuido**

`terms_and_privacy_page.dart` nombra a Supabase como **encargado del
tratamiento de datos**, junto a ePayco y Resend:

> «…proveedores que procesan datos en nuestro nombre, bajo instrucciones
> limitadas a esa finalidad: Supabase (hospedaje de la base de datos y
> autenticación)…»

Es una declaración de la **Ley 1581** (D-144). **Quitarla sería una regresión
de cumplimiento, no una limpieza.** La prueba nueva la tiene en su lista de
excepciones con ese motivo escrito.

### 4.2 Siete descripciones de error — anotado, no resuelto

En `settings_page` e `inventory_page` quedan textos como *«Revisa la conexión
con Supabase o la función `get_business_settings`»*. Son **estados de fallo**,
que el encargo pedía preservar — pero le siguen enseñando **nombres de
funciones internas** a un salón. Reescribirlas en su idioma es un trabajo
aparte (regla 18).

---

## 5. Lo que se perdió, dicho claro

- **Inventario** era la única de las cinco «Supabase» con una frase útil de
  verdad: *«el stock sube al registrar una compra y baja al registrar un
  consumo interno»*. Explicaba un mecanismo, no era jerga. Se fue con la
  tarjeta. **Si se echa en falta, el sitio es el subtítulo**, igual que las
  tres reglas de permisos.
- **Usuarios** conservó solo media frase. La otra mitad —«el propietario o un
  administrador pueden activar, desactivar o cambiar el rol»— **es una
  tautología para quien la lee**: ese módulo solo lo ven `owner` y `admin`.

---

## 6. Las 2 pruebas nuevas

**Ninguna prueba existente buscaba las cadenas retiradas** — se comprobó antes
de borrar, así que no hubo que actualizar ninguna.

`test/sin_jerga_tecnica_test.dart` añade:

1. Una prueba que **falla si vuelve a aparecer «Supabase» en texto de
   pantalla**, con una lista corta de excepciones, **cada una con su porqué**.
2. Una segunda que comprueba que **esas excepciones siguen haciendo falta**:
   una excepción muerta hace creer que el texto sigue ahí cuando puede haberse
   borrado hace meses.

Mismo espíritu que D-102 con los colores sueltos: **lo que no tiene guardián,
vuelve.** Estos textos estuvieron meses en producción sin que nadie los viera
como un problema, porque cada uno por separado parece inofensivo. Se verificó
mutándolo: metiendo «Conectado a Supabase» en un subtítulo, falla y señala
archivo, línea y texto.

---

## 7. Qué NO hacer

- **No quitar la mención a Supabase de `terms_and_privacy_page.dart`.** Es la
  declaración de encargado del tratamiento (Ley 1581). La prueba la protege.
- **No añadir excepciones a `permitidos` sin escribir el porqué.** Si esa lista
  crece, la pregunta no es cómo añadir una excepción: es por qué la aplicación
  le está contando a un salón cómo está construida por dentro.
- **No volver a meter una tarjeta fija de cabecera** para explicar lo que hace
  una pantalla. Para eso está el subtítulo de `AppPage`, y para la puesta en
  marcha está «Primeros pasos» (D-186).
- **No confundir estas tarjetas con los `InfoPanel` de error o de lista
  vacía**, que siguen en su sitio y hacen falta: son 46 y no se tocó ninguno.

---

## 8. Lo que sigue abierto

1. **El armazón de navegación de D-201 sigue sin verificarse con los ojos.**
   Van **seis sesiones**. Toca las 16 pantallas y esta semana hubo dos
   incidentes por caminos verificados solo sobre el papel (D-203 tumbó Tickets
   en producción, D-204 encontró dos diferencias silenciosas entre dos RPC).
2. **Nuevo de este bloque:** siete descripciones de error nombran funciones
   internas de la base al salón. Reescribirlas en su idioma.
3. **Nuevo de este bloque:** si se echa en falta la explicación de cómo se
   mueve el stock en Inventario, el sitio es el subtítulo.
4. El tercio de **TL-09**: la consulta de Tickets trae el historial completo.
5. Los tickets con `scheduled_at` nulo desaparecerían de la lista de Tickets en
   silencio. Hoy hay cero (D-204).
6. **HSTS** en el panel de Cloudflare — paso 8.25, 👤 propietario.
7. La otra mitad de **UX-07** (Nequi vs. Daviplata), que **no es interfaz**.
8. Fase 3 con dos casillas de 👤 abiertas (3.2 DIAN/IVA, 3.4 Supabase a Pro).
9. Hallazgos **Z** y **X**.

> **Lo que el propietario tiene que ver con los ojos:** las nueve pantallas
> abren sin la tarjeta y **sin un hueco raro** donde estaba. Y en Gastos,
> Compras y Usuarios, que el subtítulo ahora dice la regla de permisos —son las
> tres que no se borraron del todo.

---

## 9. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-206: fuera las 9 tarjetas
fijas de cabecera heredadas del prototipo; las tres que llevaban reglas de
permisos pasaron al subtítulo en vez de borrarse).

flutter analyze 0/0 y 367/367 pruebas en verde. Sin migración SQL.

Antes de abrir un bloque nuevo, preguntar por lo que lleva SEIS sesiones
pendiente: el armazón de navegación de D-201 sigue sin verificarse con los
ojos. Toca las 16 pantallas y esta semana ya hubo dos incidentes por caminos
verificados solo sobre el papel.

Lo que sigue abierto, por orden de daño:
1. Verificar a mano el armazón de navegación de D-201.
2. Siete descripciones de error nombran funciones internas de la base al
   salón ("Revisa la conexión con Supabase o la función
   get_business_settings"). Reescribirlas en su idioma.
3. El tercio de TL-09: la consulta de Tickets trae el historial completo.
4. HSTS (paso 8.25), del propietario.
5. La otra mitad de UX-07 (Nequi vs Daviplata), que NO es interfaz.

Ojo con lo que NO hay que tocar: la mención a Supabase en
terms_and_privacy_page.dart es la declaración legal de encargado del
tratamiento (Ley 1581). Hay una prueba que la protege, con el motivo escrito.
```
