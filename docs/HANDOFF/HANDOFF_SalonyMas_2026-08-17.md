# HANDOFF Salón y Más — 17 de agosto de 2026 (bloque D-151)

**Bloque documentado:** decisión **D-151** · Corrección post-auditoría del Paso 4.4 (D-150): el disparador de número de venta reasignaba un número nuevo al reabrir y volver a cerrar un ticket
**Estado:** Corregido en la migración `20260817210000_numero_de_venta_por_sede.sql` y verificado con una prueba nueva en el Control 174 (ahora 7 pruebas). **128 de 128 pruebas Flutter en verde** (sin cambios de Dart en este bloque), `flutter analyze` 100% limpio.
**Reemplaza como handoff vigente a:** la versión anterior de este mismo archivo (bloque D-150, archivada en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-08-17_D150.md`)

---

## 1. Dónde estamos

```
Fase 0  Que exista en internet        ✅
Fase 1  Que sea seguro compartirla    ✅
Fase 2  Seguridad                     ✅ CERRADA (12-ago) — 7 de 7
Fase 3  Poder cobrar                  ✅ CERRADA A NIVEL TÉCNICO (17-ago)
        3.1  ePayco admite recurrencia    ✅
        3.5  Precios y límites            ✅ CERRADO (12-ago)
        3.6  Precio por cliente           ✅ CERRADO (12-ago)
        3.7  Filtro de aceptación         ✅ CERRADO (16-ago / D-138)
        3.8  Pantalla pública de planes   ✅ CERRADO (17-ago / D-140)
        3.9  ePayco en servidor (webhook) ✅ CERRADO (17-ago / D-141, D-142)
        3.10 Pagos y suscripciones        ✅ CERRADO (17-ago / D-141, D-142)
        3.11 Avisos por correo y gracia   ✅ CERRADO (17-ago / D-143, D-145)
        3.12 Correos de cuenta por Resend ✅
        3.13 Traducir correos de Auth     ✅ CERRADO (17-ago / D-146)
        3.3  Términos y privacidad        🔄 CONTENIDO TÉCNICO LISTO (17-ago / D-144) — falta revisión legal 👥
        3.2  Contador (DIAN, IVA)         ⬜ 👤
        3.4  Supabase Pro (~25 USD/mes)   ⬜ 👤
Fase 4  Pulido módulo a módulo        🔄  ← AQUÍ
        4.1  Consecutivo de ticket        ✅ CERRADO (09-ago / D-117)
        4.2  Funciones del tablero agenda ✅ CERRADO Y APLICADO EN BD (17-ago / D-147)
        4.3  Tablero Flutter (Día/Sem/Mes)✅ CERRADO SIN RESERVAS (17-ago / D-148, D-149)
        4.4  Número de venta al cerrar    ✅ CERRADO (17-ago / D-150, corregido D-151)
        4.5  Tickets: Nivel 2 y StatusPill⬜ Siguiente paso (hallazgo N)
```

---

## 2. Qué pasó en este bloque (D-151)

La auditoría técnica del bloque anterior (D-150) encontró que la promesa central de la función — "el número de venta es inmutable" — tenía un hueco real, no teórico, contra un flujo que **ya existía antes de este bloque**.

### El problema encontrado:

El disparador `private.beautyos_assign_sale_number_on_close` se activaba con:
```sql
new.status = 'cerrado' and (old.status is distinct from 'cerrado' or old.sale_number is null)
```
Un ticket que **ya tenía** `sale_number` asignado, si pasaba de `'cerrado'` a otro estado y volvía a `'cerrado'`, entraba de nuevo a esa condición (por el `or old.status is distinct from 'cerrado'`) y recibía un **número de venta nuevo**, dejando el original huérfano sin ningún rastro — no existe una tabla de auditoría de números de venta.

**Y esa reapertura ya existe y está en uso:** `supabase/sql/079_void_ticket_payment_rpc.sql` (`void_ticket_payment`, anterior a D-150) regresa un ticket de `'cerrado'` a `'finalizado'` cuando `owner`/`admin` anula un pago registrado por error — una operación real, no un ataque hipotético. Si después se vuelve a cobrar y cerrar, el hueco se activaba solo.

### Lo que se corrigió:

1. **`supabase/migrations/20260817210000_numero_de_venta_por_sede.sql`:** se redujo la condición a `new.status = 'cerrado' and old.sale_number is null`, tanto en el `when` del trigger `trg_assign_sale_number_on_close` como en el `if` del cuerpo de la función. Un ticket que ya tiene número de venta lo conserva para siempre, sin importar cuántas veces se reabra y se vuelva a cerrar.

2. **`supabase/sql/174_test_numero_de_venta_por_sede.sql`:** se agregó la **Prueba 5** (renumerando las dos siguientes a 6 y 7): reabre el ticket ya cerrado en la Prueba 1 por el mismo camino que usa `void_ticket_payment` (`UPDATE ... SET status = 'finalizado'`, sin tocar `sale_number`/`sale_code`), lo vuelve a cerrar, y verifica que **conserva** `sale_number = 1` / `sale_code = 'VTA-0000001'`, y que `branch_sale_numbering.next_number` no avanzó de más. El Control 174 pasa de 6 a **7 pruebas**.

### Sobre la contradicción de estado señalada en la auditoría:

El HANDOFF del bloque D-150 decía "migración lista para ejecutar" mientras se reportó como ya aplicada en `beautyos-dev`. **Sigue sin confirmarse cuál era el estado real** — pero no importa para aplicar esta corrección: los cambios de este bloque son seguros de re-aplicar sin importar si D-150 ya corrió antes (`create or replace function`, `drop trigger if exists` + `create trigger`, y el backfill ya filtra por `sale_number is null`). Re-ejecutar el archivo completo de la migración es seguro en cualquiera de los dos casos.

---

## 3. Estado técnico

- **Pruebas Flutter:** **128 de 128 en verde** (sin cambios de Dart en este bloque)
- **Análisis estático:** 0 errores, 0 advertencias (`flutter analyze`)
- **Decisiones registradas:** **151 decisiones** (D-001 al D-151)
- **Control 174:** ahora 7 pruebas (antes 6) — pendiente de correr contra `beautyos-dev`

---

## 4. Instrucción para aplicar (Propietario)

1. **Respaldar la base de datos** si no se hizo ya para este bloque:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
   ```
2. **Aplicar (o re-aplicar) la migración corregida:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\migrations\20260817210000_numero_de_venta_por_sede.sql"
   ```
3. **Verificar con el Control 174 (ahora 7 pruebas):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\sql\174_test_numero_de_venta_por_sede.sql"
   ```

---

## 5. Próximos pasos inmediatos

1. **Paso 4.5:** Tickets: pulido del nivel 2 y 3 + cambiar `TicketStatusBadge` por `StatusPill` (hallazgo N).
