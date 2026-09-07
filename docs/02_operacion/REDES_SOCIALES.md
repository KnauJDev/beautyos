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

---

## 4. Los activos de marca

Viven en **`docs/00_producto/marca/`**, versionados con el código. No en la raíz
del proyecto y no solo en el disco: se perdieron una vez por estar sin commitear.

| Archivo | Medidas | Para qué |
|---|---|---|
| `marca.svg` / `marca-maskable.svg` | vectorial | El isotipo `S+`, origen de todo lo demás |
| `perfil.png` | 512 × 512 | Foto de perfil, con margen para el recorte circular |
| `portada.png` | 1640 × 624 | Portada de Facebook — *"Menos cuaderno, más control de tu salón"* |
| `post_instagram_1.png` | 1080 × 1080 | Post de lanzamiento |

Se componen en HTML/CSS con los colores de marca y se exportan a PNG con Chrome
headless. Sin licencias ni herramientas de pago.

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
