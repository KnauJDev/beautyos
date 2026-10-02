# Redes sociales y canales de captación

> **Qué es este documento.** Dónde están las cuentas oficiales de Salón y Más,
> con qué datos están configuradas y qué no hay que tocar. Es un documento
> **vivo**: se actualiza cuando cambia un canal, no se reemplaza.
>
> El **porqué** de cada elección está en `REGISTRO_DE_DECISIONES.md` (D-217).
> Lo que falta por hacer está en `PLAN_MAESTRO.md`, Fase 9.

Abiertas el **7 de septiembre de 2026**.

---

## 1. Por qué existen

Tres trabajos, en este orden:

1. **Dar respaldo a `salonymas.com`.** Un software que cobra 150.000 al mes y no
   tiene ni una cuenta pública no inspira confianza a nadie.
2. **Captar los 10 salones piloto** de forma orgánica, sin pagar publicidad.
3. **Abrir la puerta de WhatsApp** para demostraciones y soporte, que es por
   donde se habla en Colombia.

---

## 2. Facebook

| Campo | Valor |
|---|---|
| Nombre | `Salón y Más` |
| Dirección | `https://www.facebook.com/profile.php?id=61593977672817` |
| Se administra desde | La cuenta de Facebook de **Juan Rodriguez**, abierta en el perfil de Chrome **"J"**. El otro perfil de Chrome (IL Profumo) **no** administra esta página |
| Categoría | Empresa de software |
| Teléfono / WhatsApp | `+57 315 978 0158` |
| Correo | `hola@salonymas.com` (Cloudflare Email Routing → Gmail, D-180) |
| Web | `https://salonymas.com` |
| Botón principal | WhatsApp Business |

**Biografía:** *"El software de gestión para peluquerías, barberías y spas de
uñas en Colombia. Controla tu agenda, caja, comisiones y citas públicas en un
solo lugar."*

**Publicado:** post de bienvenida con tarjeta de WhatsApp, y la convocatoria de
los 10 pioneros en el grupo público **"Peluquerías Bogotá"**.

---

## 3. Instagram

| Campo | Valor |
|---|---|
| Usuario | **`@salon_y_mas`** |
| Nombre comercial | `Salón y Más - APP para salones` |
| Tipo | Cuenta profesional — Empresa de software |
| Foto de perfil | `docs/00_producto/marca/perfil.png` |

**Por qué `@salon_y_mas` y no `@salonymas`:** el segundo ya estaba tomado por un
salón de uñas ajeno. Se comprobó antes de decidir. La variante con guiones bajos
suena idéntica y quedó aprobada.

**Biografía** (138 de 150 caracteres):

```text
🇨🇴 Software para peluquerías, barberías y spas.
✂️ Agenda online sin cruces
💰 Caja y comisiones en segundos
👇 Prueba 21 días gratis:
```

**La 🇨🇴 de la biografía se ve como *"co"* en un computador con Windows, y no es un fallo:** Windows
no dibuja banderas. En el celular sale la bandera. Comprobado el 01-oct; no se "arregla". Distinto es
meter el emoji **dentro de una imagen**: ahí queda "co" para todo el mundo (§4).

---

## 4. Los activos de marca

Viven en **`docs/00_producto/marca/`**, versionados con el código. No en la raíz
del proyecto y no solo en el disco: se perdieron una vez por estar sin commitear.

| Archivo | Medidas | Para qué |
|---|---|---|
| `marca.svg` / `marca-maskable.svg` | vectorial | El isotipo `S+`, origen de todo lo demás |
| `perfil.png` | 512 × 512 | Foto de perfil, con margen para el recorte circular |
| `portada.png` | 1640 × 624 | Portada de Facebook — *"Menos cuaderno, más control de tu salón"*. **Rehecha el 01-oct:** la del 06-sep decía *"co Software para Colombia"* (la trampa de abajo). **Subida a Facebook el mismo día** y comprobada recargando la página; Facebook publicó solo el aviso *"ha actualizado su foto de portada"* |
| `post_instagram_1.png` | 1080 × 1080 | Post de lanzamiento |

Se componen en HTML/CSS con los colores de marca y se exportan a PNG con Chrome
headless. Sin licencias ni herramientas de pago. **Las fuentes HTML viven en
`marca/plantillas/`, con el comando para exportarlas** (desde el 01-oct). Las
del 07-sep quedaron en una carpeta temporal y se perdieron; por eso la portada
hubo que reconstruirla midiendo el PNG.

**Colores:** morado `#7C3AED`, degradado `#4C1D95` → `#7C3AED`, acentos `#F472B6`
y `#FBBF24`.

**Trampa conocida:** el emoji 🇨🇴 se degrada a las letras `co` en Chrome headless
sobre Windows. Se dibuja como tres franjas vectoriales (amarillo 50%, azul 25%,
rojo 25%), no como emoji.

---

## 5. La oferta de los 10 pioneros

Lo que se prometió **en público**, y por tanto hay que cumplir:

- **21 días de prueba gratis.** ✅ Coincide con el producto: `register_tenant`
  crea la suscripción con `now() + interval '21 days'`. Verificado el 07-sep.
- **Acompañamiento uno a uno.**
- **Tarifa preferencial congelada de por vida**, a cambio de contar cómo les va.

> **Respuesta, al 01-oct: ninguna.** Ni comentarios, ni mensajes, ni WhatsApp en 24 días, según el
> propietario. La página de Facebook tiene 4 seguidores y la cuenta de Instagram, 1 (vistos ese día).

> 🔴 **La cifra de esa tarifa no está decidida.** El anuncio dice "preferencial"
> sin decir cuánto, y la lista es de 150.000 por sede (D-189). Hay diez personas
> que pueden escribir mañana esperando un descuento que nadie ha fijado.
> **Decisión pendiente del propietario**, anotada en la Fase 9.
>
> El mecanismo para aplicarla ya existe: precio pactado por negocio con historial
> (D-158, D-160), y tiene precedencia sobre la lista.

---

## 6. Lo que NO hay que hacer

- **No pagar publicidad en Meta todavía.** Primero validar la respuesta orgánica
  y cerrar a mano los primeros salones. Pagar por difundir un discurso que aún no
  se ha probado es quemar plata.
- **No cambiar `@salon_y_mas`.** Ya está indexado y coincide con la marca.
- **No borrar los PNG de `docs/00_producto/marca/`.** Son la base de las piezas
  futuras.

---

## 7. El mensaje para pedir entrevistas (aprobado el 01-oct, D-306)

Para escribir **nosotros** a un salón, uno por uno (Instagram, WhatsApp). El de cuando ellos
escriben primero está en `PROTOCOLO_DE_BIENVENIDA_SOCIOS_DE_DISENO.md` §2.

> Hola, ¿cómo estás? Te escribo de **Salón y Más**. Soy ingeniero industrial y trabajé varios años en
> almacenes, desde colaborador de tienda hasta orientador de operaciones. Cuando esa empresa cerró,
> decidí crear algo propio: una app colombiana para administrar salones de belleza, sencilla y a buen precio.
>
> La estoy afinando con los primeros salones, y antes de seguir quiero aprender de quienes conocen el
> oficio de verdad. ¿Me regalarías **20 minutos** para contarme cómo manejas tu salón en el día a día?
> No te voy a vender nada en esa charla: solo quiero escucharte.
>
> A los primeros que nos ayuden les daremos condiciones especiales para siempre.
>
> ¿Te queda bien esta semana, en persona o por videollamada?

- **Si se lo escribes a un salón que viste en Instagram**, una línea al principio con algo concreto
  de ese salón. Personalizado se contesta mucho más.
- **Sin precio y sin el nombre del propietario**, a propósito (D-306). La cifra de los socios de diseño
  ($50.000, D-222) se dice **al final de la entrevista**, con el mensaje del protocolo §2.
- **En la entrevista manda el guion** (`03_referencias/GUION_ENTREVISTA_SALONES_9.24.txt`): no enseñar
  la app, preguntar por la última vez y anotar sus palabras exactas.
