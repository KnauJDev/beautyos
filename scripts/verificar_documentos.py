#!/usr/bin/env python3
"""Guardian de la documentacion de Salon y Mas.

POR QUE EXISTE (07-sep-2026, D-223)

En una sola sesion se colaron cuatro fallos del mismo tipo: afirmaciones hechas
desde una senal (un nombre de archivo, una coincidencia de grep) en vez de desde
el contenido. Tres de ellos dejaban rastro medible en los documentos:

  * un caracter de control BEL invisible, de escribir "scripts\aplicar_sql.ps1"
    a traves de tres capas de escapado
  * el indice del registro sin la linea de D-213, que es justo lo que D-129 y
    D-131 mandan vigilar
  * dos sistemas de bloques encimados en la misma fase

Este guion los caza en segundos. No sustituye leer: sustituye confiar.

COMO SE USA
    python scripts/verificar_documentos.py

Devuelve 0 si todo esta bien, 1 si algo falla. Sirve igual en el CI.
"""
import glob
import os
import re
import sys

# La documentacion esta llena de emoji y la consola de Windows es cp1252 por
# defecto: sin esto, el guardian revienta al IMPRIMIR el fallo que acaba de
# encontrar, que es la peor forma posible de fallar.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fallos: list[str] = []
avisos: list[str] = []


def _columnas(linea: str) -> int:
    r"""Cuenta las columnas reales de una fila de tabla markdown.

    Un `|` no separa celdas si va escapado (`\|`) o dentro de un tramo de
    codigo entre acentos graves. Contarlos daba falsos positivos: el registro
    usa `image/jpeg\|png\|webp` dentro de una celda y son pipes literales.
    """
    sin_codigo = re.sub(r"`[^`]*`", "CODIGO", linea)
    sin_escapados = sin_codigo.replace(chr(92) + "|", "ESCAPADO")
    return len(sin_escapados.strip().strip("|").split("|"))


def ruta(p: str) -> str:
    return os.path.relpath(p, RAIZ).replace("\\", "/")


# --- 1. Caracteres de control invisibles ------------------------------------
for f in glob.glob(os.path.join(RAIZ, "docs", "**", "*.md"), recursive=True) + glob.glob(
    os.path.join(RAIZ, "supabase", "migrations", "*.sql")
):
    texto = open(f, encoding="utf-8", errors="replace").read()
    for n, linea in enumerate(texto.split("\n"), 1):
        malos = [c for c in linea if ord(c) < 32 and c != "\t"]
        if malos:
            fallos.append(f"{ruta(f)}:{n} tiene un caracter de control {hex(ord(malos[0]))}")
            break
    if texto.startswith("\ufeff"):
        fallos.append(f"{ruta(f)} empieza con BOM")

# --- 2. El registro: indice completo y sin huecos ---------------------------
reg = os.path.join(RAIZ, "docs", "00_producto", "REGISTRO_DE_DECISIONES.md")
if os.path.exists(reg):
    s = open(reg, encoding="utf-8").read()
    indice = {int(x) for x in re.findall(r"^\| \*\*D-(\d+)\*\*", s, re.M)}
    cuerpo = {int(x) for x in re.findall(r"^\| D-(\d+) \|", s, re.M)}
    for d in sorted(cuerpo - indice):
        fallos.append(f"D-{d:03d} esta en el cuerpo del registro pero NO en el indice (D-129, D-131)")
    for d in sorted(indice - cuerpo):
        fallos.append(f"D-{d:03d} esta en el indice pero NO en el cuerpo")
    if cuerpo:
        huecos = sorted(set(range(1, max(cuerpo) + 1)) - cuerpo)
        if huecos:
            avisos.append(f"faltan numeros de decision: {huecos[:10]}")
    cab = re.search(r"## Índice — las (\d+) decisiones", s)
    if cab and int(cab.group(1)) != len(cuerpo):
        fallos.append(f"la cabecera del indice dice {cab.group(1)} decisiones y hay {len(cuerpo)}")

# --- 3. Tablas con filas de distinto ancho ---------------------------------
for f in glob.glob(os.path.join(RAIZ, "docs", "**", "*.md"), recursive=True):
    lineas = open(f, encoding="utf-8").read().split("\n")
    bloque: list[tuple[int, int]] = []
    for n, l in enumerate(lineas + [""], 1):
        if l.startswith("|"):
            bloque.append((n, _columnas(l)))
        else:
            if len(bloque) >= 3:
                anchos = [c for _, c in bloque]
                comun = max(set(anchos), key=anchos.count)
                for ln, c in bloque:
                    if c != comun:
                        avisos.append(f"{ruta(f)}:{ln} fila de tabla con {c} columnas; el resto tiene {comun}")
            bloque = []

# --- 3-bis. Marcadores de estado que se contradicen -------------------------
# El paso 9.2 arreglo filas de la Fase 8 que empezaban en "en curso" y
# terminaban diciendo "CERRADO". El 09-sep se vio que el 9.29 tenia el mismo
# defecto, metido el dia anterior: la contradiccion se cuela al anadir el
# cierre al final de la celda sin tocar el marcador del principio.
#
# Nadie va a buscar lo que el marcador dice que no esta hecho (D-129).
ABIERTOS = (chr(0x2B1C), chr(0x1F504))  # cuadro vacio, y flechas de "en curso"
CERRADOS = ("CERRAD", "RESUELTA", "VERIFICADO")
plan_md = os.path.join(RAIZ, "docs", "00_producto", "PLAN_MAESTRO.md")
if os.path.exists(plan_md):
    for n, l in enumerate(open(plan_md, encoding="utf-8").read().splitlines(), 1):
        if not l.startswith("|"):
            continue
        celdas = [c.strip() for c in l.strip().strip("|").split("|")]
        if len(celdas) < 2:
            continue
        estado = celdas[-1]
        if estado.startswith(ABIERTOS) and any(k in estado for k in CERRADOS):
            fallos.append(
                ruta(plan_md) + ":" + str(n)
                + " el marcador dice abierto y el texto dice cerrado: "
                + estado[:70]
            )

# --- 4. Un solo HANDOFF vigente --------------------------------------------
vig = glob.glob(os.path.join(RAIZ, "docs", "HANDOFF", "*.md"))
if len(vig) != 1:
    fallos.append(
        f"docs/HANDOFF/ tiene {len(vig)} archivos y solo puede tener el vigente: "
        + ", ".join(os.path.basename(v) for v in vig)
    )

# --- 5. El Plan Maestro no cita decisiones que no existen ------------------
plan = os.path.join(RAIZ, "docs", "00_producto", "PLAN_MAESTRO.md")
if os.path.exists(plan) and os.path.exists(reg):
    citadas = {int(x) for x in re.findall(r"\bD-(\d{3})\b", open(plan, encoding="utf-8").read())}
    for d in sorted(citadas - cuerpo):
        fallos.append(f"el Plan Maestro cita D-{d:03d}, que no existe en el registro")

# --- Resultado --------------------------------------------------------------
for a in avisos:
    print(f"  aviso  {a}")
for f_ in fallos:
    print(f"  FALLO  {f_}")

if fallos:
    print(f"\n{len(fallos)} fallo(s). La documentacion no esta consistente.")
    sys.exit(1)
print(f"\nDocumentacion consistente. {len(avisos)} aviso(s).")
sys.exit(0)
