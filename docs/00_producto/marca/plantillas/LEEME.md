# Plantillas de las piezas de marca

Cada pieza gráfica de las redes nace aquí, como una página HTML, y se exporta a
PNG con Chrome sin ventana. Sin licencias ni programas de pago.

**Por qué están en el repositorio:** las plantillas de las piezas del 07-sep
quedaron en una carpeta temporal y se perdieron. Para corregir una sola cosa de
la portada hubo que reconstruirla entera el 01-oct, midiendo el PNG (D-305).

| Plantilla | Para qué | Medidas |
|---|---|---|
| `portada_facebook.html` | Portada de la página de Facebook. Es la fuente de `../portada.png` | 1640 × 624 |
| `post_vertical.html` | Post del feed de Instagram y Facebook | 1080 × 1440 (3:4) |
| `historia.html` | Historia de Instagram y Facebook, y estado de WhatsApp | 1080 × 1920 (9:16) |
| `carrusel.html` | Carrusel: varias diapositivas en un solo post | 1080 × 1440 cada una |
| `marca.css` | Lo común: colores, fondo, bandera, etiqueta, logo, tarjeta | — |

**El texto de las plantillas es de ejemplo** y sale de piezas ya publicadas y
aprobadas. Cada pieza nueva cambia el texto, y **nada se publica sin el visto
bueno del propietario** (D-305).

## Cómo se exporta

Desde la raíz del repositorio, en PowerShell (una sola línea):

```powershell
powershell -ExecutionPolicy Bypass -File docs\00_producto\marca\plantillas\exportar.ps1 -Plantilla post_vertical
```

- El tamaño lo lee de la plantilla: `<meta name="pieza" content="1080x1440">`.
- Un carrusel lleva además `<meta name="diapositivas" content="5">` y sale una
  imagen por diapositiva: `carrusel-1.png`, `carrusel-2.png`…
- Los PNG salen a `%TEMP%\salonymas_piezas\`, **no al repositorio**. Al
  repositorio solo se copia una pieza aprobada y publicada (como `../portada.png`).

## Las medidas, y por qué

- **Post en 3:4 y no cuadrado.** Desde 2025, la cuadrícula del perfil de
  Instagram enseña cada post en un rectángulo 3:4 y recorta lo que no cabe.
  Medido en `@salon_y_mas` el 01-oct: el cuadro mide 0,750. El post cuadrado del
  07-sep pierde los bordes en el perfil. Lo importante queda además a más de
  45 px de arriba y de abajo, para que un recorte a 4:5 no corte nada.
- **Historia:** los 270 px de arriba y los 340 px de abajo no se usan, porque ahí
  Instagram pone la foto de perfil, la barra de avance y "Enviar mensaje".
- **Carrusel:** todas las diapositivas con la misma medida, como pide Instagram,
  y **una idea por diapositiva**: en el celular no se leen dos.
- **Portada:** la ayuda de Meta se contradice sobre cómo la recorta (D-305). En
  la página real, en computador, la de 1640 × 624 se ve entera.

## Trampas conocidas

- **La bandera de Colombia no se escribe como emoji dentro de una imagen.** En
  Chrome sin ventana, sobre Windows, 🇨🇴 sale como las letras `co`. Así salió
  publicada la portada del 06-sep. Se usa la clase `.bandera` de `marca.css`.
  *(En un texto, como la biografía de Instagram, el emoji sí sirve: en el
  celular sale la bandera. Solo en un computador con Windows se ve "co", porque
  Windows no dibuja banderas.)*
- **La letra es Segoe UI, que viene con Windows.** Exportar en otro sistema
  cambia la letra y las medidas.
- **PNG y no JPG** para piezas con texto o logo: lo recomienda la propia ayuda
  de Meta, porque el JPG ensucia los bordes de las letras.
- **En PowerShell 5.1, Chrome avisa "bytes written to file" por la salida de
  errores**, y con `$ErrorActionPreference = "Stop"` eso corta el guion aunque
  la imagen sí se escribió. `exportar.ps1` ya lo tiene en cuenta.
- **Los colores viven solo en `marca.css`.** Si una plantilla los repite, dos
  copias acaban diciendo cosas distintas (D-131). La portada pasó a usarlo el
  01-oct y se comprobó que la imagen sale idéntica, byte por byte.
