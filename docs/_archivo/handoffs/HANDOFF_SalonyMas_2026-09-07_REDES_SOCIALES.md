# HANDOFF Salón y Más — 7 de septiembre de 2026 ("Apertura y puesta en marcha de Redes Sociales oficiales: Facebook e Instagram")

**Bloque documentado:** Redes sociales oficiales de Salón y Más (Facebook Page & Instagram Business) + Campaña de captación de los 10 salones pioneros.

**Estado:** ✅ **Cerrado y verificado en vivo.** Ambas cuentas creadas, vestidas con activos de marca, configuradas como perfiles de empresa y con sus primeras publicaciones de lanzamiento al aire.

---

## 1. Por qué se hizo este bloque

De cara a la **Fase 9 ("Puesta a punto antes del cliente cero")**, el sistema requería sus canales oficiales de comunicación comercial y soporte para:
1. Dar respaldo institucional y credibilidad de marca a `salonymas.com`.
2. Lanzar la convocatoria orgánica para captar a los **primeros 10 salones / barberías / spas piloto** en Colombia.
3. Establecer el canal de entrada por WhatsApp Business para demostraciones y atención a los dueños de negocios.

---

## 2. Activos gráficos generados y disponibles en el repositorio

Para no depender de herramientas externas ni pagar licencias de diseño, los activos se compusieron en HTML/CSS con los colores corporativos de la marca (morado `#7C3AED`, degradados `#4C1D95` a `#7C3AED`, acentos `#F472B6` / `#FBBF24` y el isotipo oficial `S+` de `docs/00_producto/marca/`) y se renderizaron a PNG en alta definición mediante Chrome headless.

| Archivo | Medidas | Uso |
|---|---|---|
| `c:\Proyectos\salonymas\perfil.png` | 512 × 512 px | Foto de perfil oficial para Facebook e Instagram (diseñada con padding seguro para recorte circular). |
| `c:\Proyectos\salonymas\portada.png` | 1640 × 624 px | Portada panorámica de Facebook con el eslogan *"Menos cuaderno, más control de tu salón"*, 3 pilares clave y márgenes seguros para móvil/PC. |
| `c:\Proyectos\salonymas\post_instagram_1.png` | 1080 × 1080 px | Post cuadrado oficial de lanzamiento con bandera tricolor de Colombia en vector, 4 tarjetas de valor (Agenda, Caja/Comisiones, Privacidad y seguridad, Multi-sede) y llamado a 21 días gratis. |

> *Nota técnica:* Las plantillas fuente de estos diseños quedaron archivadas en el scratchpad para poder reutilizarlas o generar nuevos posts con idéntico estilo visual.

---

## 3. Estado de los Canales Oficiales

### A. Facebook: Página Oficial
* **Nombre:** `Salón y Más`
* **Categoría:** `Empresa de software`
* **Datos de contacto:**
  * Teléfono / WhatsApp: `+57 315 978 0158`
  * Correo: `hola@salonymas.com`
  * Web: `https://salonymas.com`
* **Biografía:** *"El software de gestión para peluquerías, barberías y spas de uñas en Colombia. Controla tu agenda, caja, comisiones y citas públicas en un solo lugar. 🚀"*
* **Botón de acción principal:** Configurado hacia WhatsApp Business.
* **Publicación 1 (Feed):** Post de bienvenida nativo con tarjeta destacada de botón de WhatsApp (`[ WhatsApp ]`) para contacto directo en un clic.
* **Acción de captación de campo:** Publicación realizada en el grupo público **"Peluquerías Bogotá"** invitando a 10 salones pioneros (oferta: 21 días de prueba gratis + acompañamiento 1 a 1 + tarifa preferencial congelada de por vida a cambio de feedback operativo).

### B. Instagram: Cuenta Empresarial
* **Nombre de usuario (Handle):** **`@salon_y_mas`**  
  *(Se aseguró con check verde ✅. `@salonymas` a secas ya estaba tomado por un salón de uñas externo).*
* **Nombre comercial (SEO):** `Salón y Más - APP para salones` (optimizado con palabras clave para el motor de búsqueda interno de Instagram).
* **Tipo de cuenta:** Cuenta profesional / empresarial (**Empresa de software**).
* **Foto de perfil:** `perfil.png` con el isotipo `S+`.
* **Biografía (exactamente 138 de 150 caracteres permitidos):**
  ```text
  🇨🇴 Software para peluquerías, barberías y spas.
  ✂️ Agenda online sin cruces
  💰 Caja y comisiones en segundos
  👇 Prueba 21 días gratis:
  ```
* **Publicación 1 (Lanzamiento):** Publicada y verificada en vivo con la imagen `post_instagram_1.png` y copy comercial completo con hashtags estratégicos del sector belleza en Colombia (`#peluqueriascolombia`, `#barberiascolombia`, `#spascolombia`, etc.).

---

## 4. Decisiones tomadas y aprendizajes del bloque

1. **Selección del handle de Instagram:** Se investigó la disponibilidad autoritativa de `@salonymas`. Al estar tomado por un tercero inactivo, se probó la variante con guiones bajos **`@salon_y_mas`**, la cual fue aprobada por Instagram. Es fonéticamente idéntica, altamente legible y oficial.
2. **Bandera de Colombia en motores de render:** El emoji nativo `🇨🇴` en Windows/Chrome headless se degradaba al texto de código de país `co`. Se resolvió sustituyendo el carácter por un componente vectorial puro con las tres franjas exactas (amarillo 50%, azul 25%, rojo 25%), garantizando nitidez perfecta.
3. **Pivote del mensaje de protección de datos (decisión del propietario):** En la tarjeta del post de Instagram se cambió el texto inicial de "Fotos protegidas" por **"Privacidad y seguridad: Total protección y tratamiento de datos de tus clientes bajo la normatividad colombiana"** con el ícono de escudo 🛡️. Esto profesionaliza la percepción del software, alineándolo formalmente con la Ley 1581 de 2012 (Habeas Data) implementada en el paso 5.7 / D-167 del backend.
4. **Enlaces en biografía de Instagram:** Instagram Web inhabilita la edición de enlaces externos por navegador de escritorio (*"Solo puedes editar tus enlaces en móviles"*). Se instruyó al propietario para agregarlo directamente desde la app móvil.

---

## 5. Dónde seguir

| Tarea | Qué | Quién |
|---|---|---|
| 1 | Fijar la primera publicación en el perfil de Instagram (*Pin to profile* vía `...`) | 👤 |
| 2 | Agregar `https://salonymas.com` en la sección de enlaces de la app de Instagram móvil | 👤 |
| 3 | Monitorear comentarios de "YO" y solicitudes en el grupo de "Peluquerías Bogotá" | 👤 |
| 4 | Continuar con la hoja de ruta técnica de la Fase 9 (bloque B: pagos, CI y verificación TL-01) | 🤖 / 👤 |

---

## 6. Lo que NO hay que hacer

- **No pagar anuncios todavía en Meta (Facebook/Instagram Ads).** Primero hay que validar la respuesta orgánica de los grupos y el cierre manual de los primeros salones pioneros para afinar el discurso de ventas.
- **No cambiar el nombre de usuario `@salon_y_mas`** en Instagram: ya quedó indexado y coincide con la marca.
- **No borrar los archivos PNG de la raíz (`perfil.png`, `portada.png`, `post_instagram_1.png`):** son los assets gráficos oficiales y sirven de base para futuras piezas.
