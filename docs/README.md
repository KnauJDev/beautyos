# Documentación de Salón y Más

> **Nota de nombre.** El producto se llama **Salón y Más** de cara al cliente
> desde D-089. El código, el repositorio (`KnauJDev/beautyos`) y el proyecto de
> Supabase siguen diciendo `beautyos` **a propósito**: no lo lee ningún usuario
> y renombrarlos costaría más de lo que aporta.

---

## 1. Si llegas nuevo, lee en este orden

Da igual si eres una persona o una inteligencia artificial. **Con tres
documentos entiendes el proyecto entero.**

| # | Documento | Te responde |
|---|---|---|
| 1 | `HANDOFF/` — **el más reciente por fecha** | ¿Dónde quedamos? Trae el prompt exacto para retomar |
| 2 | **`00_producto/PLAN_MAESTRO.md`** | **¿Qué es, qué falta y en qué orden?** El único que manda sobre el plan |
| 3 | `00_producto/REGISTRO_DE_DECISIONES.md` | **¿Por qué está hecho así?** Empieza por el final |

**No empieces por el código.** Este proyecto tiene más de doscientas decisiones registradas
con su porqué; leer el código sin ellas es reconstruir a ciegas razonamientos
que ya están escritos.

> **Si encuentras un cuarto documento opinando sobre el plan, está mal.** Siete
> documentos compitiendo entre sí causaron dos desviaciones reales (D-063,
> D-118). Se fundieron en el Plan Maestro el 09-ago (D-126) y lo anterior vive
> en `_archivo/`, que **no manda sobre nada**.

---

## 2. Qué significan los códigos

Verás referencias como `D-102`, `H-09` o "hallazgo G" dentro del código, en los
mensajes de commit y en los documentos. **Son sistemas distintos:**

| Código | Qué es | Dónde vive |
|---|---|---|
| **D-001 en adelante** | **Decisiones.** El porqué de cada cosa, con lo que se descartó y por qué | `00_producto/REGISTRO_DE_DECISIONES.md` |
| **H-01 … H-13** | **Hallazgos** de la auditoría integral del 6 de agosto | `01_arquitectura/auditorias/AUDITORIA_INTEGRAL_2026-08-06.md` |
| **A … Z** | **Anotado en el camino** | `PLAN_MAESTRO`, sección 7 |
| **I-01 … I-14** | **Buzón de ideas**: lo que aún no tiene fase | `PLAN_MAESTRO`, sección 6 |
| **F3.7, 4.10…** | **Números de paso** del Plan Maestro | `PLAN_MAESTRO`, sección 5 |
| **Tramo A, D3.5.2…** | Trabajo de arquitectura multisede de julio | `01_arquitectura/auditorias/` |

> **Cuando el código cita un código, no lo inventes: búscalo.** Un comentario
> que dice `(D-097, D-102)` está señalando dónde está el razonamiento completo.
> Que una cita no tuviera respaldo fue exactamente el fallo de D-102, que el
> código citaba y el registro no tenía.

---

## 3. Qué documento manda sobre qué

**Tres documentos vivos, tres trabajos que no se pisan** (D-063, D-126).

| Documento | Responde | ¿Crece o se reemplaza? |
|---|---|---|
| **PLAN_MAESTRO** | ¿Qué es, qué falta y en qué orden? | Se actualiza al cerrar cada paso |
| **REGISTRO_DE_DECISIONES** | ¿Por qué es así? | **Solo crece.** Nunca se borra ni se resume una fila |
| **HANDOFF** | ¿Dónde quedamos hoy? | **Se reemplaza.** Cada uno sustituye al anterior |

**Y tres de apoyo, que no opinan sobre el plan:**

| Documento | Responde |
|---|---|
| `ESPECIFICACION_*` | ¿Cómo debe funcionar exactamente? Contrato de una tarea |
| `AUDITORIA_INTEGRAL_2026-08-06` | ¿Qué está mal hoy? Foto de un momento |
| `ADR/` | ¿Por qué la arquitectura es así? No se reescriben |

---

## 4. Cómo se trabaja aquí

> ### 👉 Las reglas están en **`00_producto/PLAN_MAESTRO.md`, apartado 8.**
>
> **Aquí no se copian, a propósito.** Hasta el 11-ago estaban escritas en seis
> sitios y ya decían cosas distintas: el Plan Maestro tenía 11 reglas y este
> README tenía 8, y a este le faltaba justo *"comparar línea por línea al
> reescribir una función"* — la que nació de tres fallos en un mismo día
> (D-119, D-122, D-123).
>
> Una regla copiada en seis sitios no está reforzada: **está a punto de
> contradecirse.** Es lo mismo que pasó con los siete planes (D-126).
> Corregido en **D-131**.

---

## 5. Estructura de carpetas

- `00_producto/` — **el Plan Maestro**, las decisiones y las especificaciones
- `01_arquitectura/` — modelo multisede, roles, suscripciones, ADR y auditorías
- `02_operacion/` — respaldo, restauración, **correo y dominio**, **el mapa
  técnico** (dónde está cada cosa y cómo se publica), procedimientos
- `03_referencias/` — benchmarking y fuentes externas
- `04_pruebas/` — criterios de salida y evidencias
- `HANDOFF/` — el punto de retomada (solo el vigente)
- `_archivo/` — **documentos históricos.** No mandan sobre nada; guardan el porqué

---

## 6. La historia de cada archivo la lleva `git`

Hasta el 06-sep esta sección era un **registro cronológico de 248 entradas escrito a mano**.
Se archivó en `_archivo/REGISTRO_CRONOLOGICO_HASTA_2026-09-06.md` (D-216, paso 9.1) porque
había que actualizarlo en cada cambio y ya se había desincronizado: marcaba dos handoffs
distintos como vigente, y ninguno lo era.

**Un registro duplicado no se refuerza: diverge.** Es lo mismo que pasó con los siete planes
(D-126) y con las reglas copiadas en seis sitios (D-131), aplicado esta vez al índice.

Para saber cuándo nació un archivo y por qué, hay tres preguntas y tres órdenes:

| Quiero saber… | Orden |
|---|---|
| Cuándo nació un archivo y con qué decisión | `git log --diff-filter=A -- <ruta>` |
| Todo lo que le ha pasado desde entonces | `git log --follow -- <ruta>` |
| Qué archivos tocó una decisión | `git log --stat --grep "D-214"` |

Los mensajes de commit de este proyecto citan su `D-XXX`, así que la tercera es la que más
sirve: enlaza el porqué del `REGISTRO_DE_DECISIONES.md` con los archivos que lo materializan.


Los ADR dentro de `01_arquitectura/ADR/` explican por qué se tomó cada decisión
estructural. No se reescriben para ocultar el pasado: una decisión futura la
reemplaza mediante otro ADR.

## Regla de actualización

Una modificación de arquitectura, alcance, rol, plan o flujo exige actualizar el
**Plan Maestro**, el registro de decisiones y el documento especializado
correspondiente **en el mismo cambio**.

*(Hasta el 06-sep esta regla decía "plan de lanzamiento", que fue archivado el 09-ago
por D-126. Una regla que apunta a un documento que ya no manda es peor que no tenerla.)*

Los respaldos, capturas y exportaciones se conservan además en la carpeta
personal de OneDrive del proyecto.
