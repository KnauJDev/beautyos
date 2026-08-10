# Qué necesitas para salir a producción — guía técnica en lenguaje simple

**Escrito:** 8 de agosto de 2026, a petición del propietario
**Para quién:** el propietario, que no tiene formación técnica
**Complementa a:** `PLAN_DE_LANZAMIENTO_2026-08-06.md`, que dice *qué* se
construye. Esto dice *sobre qué corre*, *cuánto cuesta* y *qué te protege*.

---

## 1. La respuesta corta

**Tu tecnología está bien elegida y no hay que cambiar nada.** Lo que falta no
son herramientas: son **redes de seguridad**, y son baratas.

Hoy tienes un producto que funciona, en internet, con un negocio real
operando encima. Lo que te separa de cobrarle a un cliente son **seis cosas**,
y **dos de ellas no dependen de mí sino de ti**: lo legal y los precios.

> **El error más común en este punto** es creer que falta tecnología y ponerse
> a comprar servidores, contenedores y herramientas. No te falta nada de eso.
> Te falta poder **dormir tranquilo**: saber que si algo se rompe te enteras,
> que si algo se pierde lo recuperas, y que si te demandan estás cubierto.

---

## 2. Lo que ya tienes, y por qué está bien

No lo cambies. Cada pieza está elegida por un motivo y aguanta el crecimiento
que puedes esperar en dos o tres años.

| Pieza | Qué hace | Por qué está bien |
|---|---|---|
| **Flutter Web (PWA)** | La aplicación que ve la gente | Un solo código para computador y celular. Se instala como app sin pasar por tiendas ni revisiones |
| **Cloudflare Pages** | Sirve la aplicación al mundo | **$0 y tráfico ilimitado.** Copias en todo el planeta, así que carga rápido desde cualquier sitio |
| **Supabase** | Base de datos, cuentas, archivos y funciones | Es PostgreSQL, la base de datos más sólida que existe. **Si un día te vas, te llevas todo**: no hay secuestro |
| **GitHub** | Guarda el código y su historia | Cada cambio queda registrado y se puede deshacer |
| **ePayco** | Cobrar en Colombia | Acepta PSE, tarjetas y efectivo, que es como paga la gente aquí |
| **Resend** | Correos automáticos | Gratis hasta 3.000 correos al mes |

**Lo más valioso que tienes no aparece en esa tabla:** el registro de
decisiones y el expediente. Son la razón por la que otra persona podría
retomar este proyecto si un día hiciera falta. Vale más que cualquier
servidor.

---

## 3. Lo que falta, en orden

### 3.1 Bloqueantes de verdad — antes del primer cliente que pague

| # | Qué | Quién | Costo | Por qué bloquea |
|---|---|---|---|---|
| 1 | **Rotar las claves de Supabase** | 👥 | $0 | Estuvieron expuestas el 03-ago. Quien las tenga puede leer y borrar **todos** los datos, saltándose la seguridad |
| 2 | **Restaurar el respaldo una vez** | 👥 | $0 | Hasta que no se restaura, un respaldo es una promesa. Se prueba contra un segundo proyecto gratuito |
| 3 | **Verificar el dominio en Resend** | 👥 | $0 | **Hoy las invitaciones no le llegan a nadie.** Un cliente nuevo no podría sumar a su equipo: lo primero que va a intentar |
| 4 | **Términos y política de privacidad** | 👤 | $0 a 300 USD | Manejas datos de terceros. **Ley 1581 de 2012** te obliga. Sin esto, cobrar es asumir un riesgo legal personal |
| 5 | **Definir los 3 precios** | 👤 | $0 | No se puede cobrar sin saber cuánto |
| 6 | **Supabase Pro** | 👤 | 25 USD/mes | Dos motivos, y el segundo es el que asusta: da respaldos diarios, **y el plan gratis pausa el proyecto por inactividad**. Un cliente podría entrar un lunes y encontrar la app dormida |

### 3.2 Casi bloqueantes — primeros días con clientes reales

| # | Qué | Costo | Por qué |
|---|---|---|---|
| 7 | **Monitoreo de errores** | **$0** | **Esto no estaba en el plan y es lo que más me preocupa.** Hoy si algo falla, te enteras porque tú lo ves. Con diez clientes, el silencio no significa que todo funcione: significa que **nadie te está contando**. Se resuelve con Sentry, gratis hasta 5.000 errores al mes |
| 8 | **Entorno de ensayo** | **$0** | Hoy cada cambio a la base de datos va **directo a producción**. Ha salido bien, pero un error se descubriría con tus datos dentro. Un segundo proyecto gratuito de Supabase resuelve esto **y** sirve de destino para el punto 2 |
| 9 | **Pruebas de las reglas de dinero** | $0 | Hay 70 pruebas y **ninguna toca dinero, roles ni el tamaño de un teléfono**. Los tres fallos del 08-ago los encontró el propietario probando |

### 3.3 Cuando crezcas — no antes

| Qué | Cuándo | Costo |
|---|---|---|
| Dominio propio por cliente | Lo pida un cliente del plan Profesional | **$0 los primeros 100** con Cloudflare for SaaS |
| Más potencia de base de datos | Cuando Supabase avise que va justa | Desde 10 USD/mes adicionales |
| WhatsApp oficial | Cuando el ingreso lo justifique | Requiere verificación de empresa. Es un proyecto en sí mismo |

---

## 4. Cuánto te va a costar de verdad

**La buena noticia de este stack: el costo casi no crece con los clientes.**

| Momento | Costo mensual | Qué incluye |
|---|---|---|
| **Hoy** | **~1 USD** | Solo el dominio (12 USD al año) |
| **Primer cliente que paga** | **~26 USD** | Supabase Pro + dominio |
| **10 clientes** | **~26 USD** | **El mismo.** Supabase Pro aguanta de sobra |
| **50 clientes** | **~50–75 USD** | Pro + algo más de potencia + Resend de pago |
| **200 clientes** | **~150–250 USD** | Ahí sí toca revisar la arquitectura, y para entonces tendrás con qué |

Aparte va la comisión de ePayco por transacción, que **solo pagas cuando cobras**.

> **Léelo así:** si cobras 30 USD al mes por negocio, con **un solo cliente**
> ya cubres toda la infraestructura. Del segundo en adelante, casi todo es
> margen. Ese es el regalo de haber elegido bien: no tienes costos fijos que
> te obliguen a crecer rápido para sobrevivir.

---

## 5. Lo que NO debes hacer

Esto vale tanto como lo anterior. Son los caminos caros que parecen
profesionales y no lo son a tu escala.

| Idea | Por qué no |
|---|---|
| **Contratar un servidor propio** | Pasarías de $0 a pagar por algo que además tendrías que actualizar, vigilar y parchear tú |
| **Kubernetes, Docker en producción** | Herramientas para equipos de diez personas. Aquí solo añaden cosas que se pueden romper |
| **Cambiar de Supabase** | Es PostgreSQL estándar. Si un día te vas, te llevas todo. Cambiar ahora es gastar meses sin ganar nada |
| **Reescribir en otra tecnología** | Sería tirar más de 25.000 líneas probadas |
| **Contratar equipo** | Antes de tener ingresos, un sueldo es el gasto que mata proyectos que iban bien |
| **Apps en las tiendas** | La PWA ya se instala en el celular. Las tiendas cobran, revisan y tardan |

---

## 6. El riesgo que nadie mira

**Todo este proyecto vive en la cabeza de una persona y en un repositorio.**

No es un problema técnico, es de continuidad. Si mañana necesitaras ayuda de
otra persona, ¿podría entender por qué las cosas son como son?

**La respuesta hoy es sí**, y es mérito de haber insistido en documentar cada
decisión con su porqué. El registro de decisiones, el expediente y los
handoffs son exactamente eso.

**Lo que conviene proteger:**

1. Que **la clave de respaldo del 2FA** esté en un sitio físico seguro. Si
   pierdes el teléfono sin ella, pierdes el panel que controla todos los
   negocios.
2. Que las **cuentas críticas** —Cloudflare, Supabase, GitHub, el dominio—
   estén a nombre tuyo y con acceso de recuperación que funcione.
3. Que el **respaldo** salga de tu computador. Hoy vive en OneDrive, que ya es
   otro sitio: bien.

---

## 7. Cuánto falta, siendo honestos

**De trabajo mío:** unas tres o cuatro sesiones. Rotar claves, montar el
ensayo, monitoreo, pruebas de dinero, cobros con ePayco y la pantalla de
planes.

**De trabajo tuyo:** lo legal y los precios. **Eso es lo que de verdad marca
la fecha**, porque no lo puedo hacer yo y no se puede saltar.

**Mi recomendación de orden:**

1. Esta semana: rotar claves, restauración de ensayo, Resend, monitoreo.
   Todo $0 y todo elimina riesgo que hoy está abierto.
2. Mientras tanto, tú: consultar lo legal y decidir precios.
3. Después: Supabase Pro y construir el cobro.
4. Y entonces, el primer cliente.

**No al revés.** Conseguir el cliente primero y montar la red de seguridad
después es exactamente la secuencia con la que se pierden los primeros
clientes, que son los que más cuesta conseguir.

---

*Este documento se revisa al cerrar la Etapa 3. Si cambia una decisión de
infraestructura, se registra primero en `REGISTRO_DE_DECISIONES.md`.*
