# Plantillas de las piezas de marca

Cada pieza gráfica de las redes nace aquí, como una página HTML, y se exporta a
PNG con Chrome sin ventana. Sin licencias ni programas de pago.

**Por qué están en el repositorio:** las plantillas de las piezas del 07-sep
quedaron en una carpeta temporal y se perdieron. Para corregir una sola cosa de
la portada hubo que reconstruirla entera el 01-oct, midiendo el PNG.

| Plantilla | Exporta a | Medidas |
|---|---|---|
| `portada_facebook.html` | `../portada.png` | 1640 × 624 |

## Cómo se exporta

Desde la raíz del repositorio, en PowerShell (una sola línea):

```powershell
& "C:\Program Files\Google\Chrome\Application\chrome.exe" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=1640,624 --screenshot="$PWD\docs\00_producto\marca\portada.png" "file:///$PWD/docs/00_producto/marca/plantillas/portada_facebook.html"
```

`--window-size` lleva las medidas de la pieza, y `--force-device-scale-factor=1`
evita que salga al doble en una pantalla de alta resolución.

## Trampas conocidas

- **La bandera de Colombia no se escribe como emoji.** En Chrome sin ventana,
  sobre Windows, 🇨🇴 sale como las letras `co`. Así salió publicada la portada del
  06-sep. Se dibuja con tres franjas (amarillo 50 %, azul 25 %, rojo 25 %): ver la
  clase `.bandera` de `portada_facebook.html`.
- **La letra es Segoe UI, que viene con Windows.** Exportar en otro sistema
  cambia la letra y las medidas.
- **PNG y no JPG** para piezas con texto o logo: lo recomienda la propia ayuda
  de Meta, porque el JPG ensucia los bordes de las letras.
- **Los colores viven en `:root`** al principio de cada plantilla y son los de
  `REDES_SOCIALES.md` §4. Una pieza nueva copia ese bloque y no inventa tonos.
