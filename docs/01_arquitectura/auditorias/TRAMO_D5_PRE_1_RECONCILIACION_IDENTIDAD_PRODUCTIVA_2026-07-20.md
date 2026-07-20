# Tramo D5-pre.1 — reconciliación de identidad productiva

**Fecha:** 20 de julio de 2026
**Estado:** completado localmente; D5 permanece en NO-GO
**Producción modificada:** no
**Conexiones remotas realizadas:** ninguna
**Base Git:** `002d437 Preparar paquete de autorizacion D5`

## 1. Objetivo

Determinar, usando únicamente evidencia local versionada, si el proyecto
productivo puede identificarse inequívocamente antes de crear un respaldo,
consultar el remoto o aplicar D5.

## 2. Evidencia coincidente

- Flutter apunta a `https://eogppgbdnwxdtcbctaol.supabase.co`.
- El procedimiento de respaldo identifica `beautyos-dev`
  (`eogppgbdnwxdtcbctaol`) como proyecto de origen.
- El despliegue productivo del Tramo C documenta el ref
  `eogppgbdnwxdtcbctaol` como producción.
- La modalidad de respaldo aprobada es el asistente local
  `scripts/crear_respaldo_supabase.ps1`, con salida privada fuera de Git y
  restauración obligatoria en un entorno aislado.

## 3. Inconsistencia bloqueante

D4.2 seleccionó el mismo proyecto `beautyos-dev`
(`eogppgbdnwxdtcbctaol`) como candidato **no productivo** y D4.3–D4.9
continuaron tratándolo con esa clasificación. Esto contradice la evidencia
anterior que lo identifica como producción.

La documentación local no permite determinar si:

1. el proyecto cambió de finalidad después del Tramo C;
2. el nombre `beautyos-dev` se usa para el proyecto productivo;
3. la cuenta conectada no expuso un proyecto productivo separado; o
4. la clasificación no productiva de D4.2 fue incorrecta.

No se debe resolver esta contradicción por inferencia.

## 4. Estado de la compuerta D5

| Requisito | Estado |
|---|---|
| Nombre y ref productivos inequívocos | **Bloqueado por contradicción documental** |
| Respaldo fresco posterior a D4 | Pendiente |
| Restauración del respaldo fresco | Pendiente |
| Ventana de ejecución aprobada | Pendiente |
| Flutter D1 publicado para usuarios productivos | Pendiente de confirmación |
| Autorización explícita para cambios productivos D5 | No otorgada en este micro-paso |

**Resultado:** D5 permanece en **NO-GO**. No se realizó ninguna conexión,
consulta, migración, respaldo ni cambio productivo.

## 5. Confirmación requerida del propietario

Antes del siguiente micro-paso el propietario debe declarar explícitamente:

- nombre y ref exactos del proyecto que hoy es producción;
- si `beautyos-dev` (`eogppgbdnwxdtcbctaol`) es producción, ensayo o cambió de
  finalidad;
- ventana de cambio autorizada, con fecha y hora en `America/Bogota`;
- que Flutter D1 está publicado o disponible para los usuarios productivos.

Con esa declaración, el siguiente micro-paso podrá preparar el respaldo fresco
y su restauración sin aplicar todavía las migraciones D5.
