# HANDOFF Salón y Más — 18 de agosto de 2026 (bloque D-153)

**Bloque documentado:** decisión **D-153** · Paso 4.6 cerrado: Clientes con análisis de retorno y valor (RFM), cadencia promedio de visita ("cada ~X días"), segmentación automática de clientes en riesgo / VIP y ficha de Nivel 3
**Estado:** **138 de 138 pruebas unitarias y de widgets en verde** (`flutter test`), `flutter analyze` 100% limpio (0 errores, 0 advertencias).
**Reemplaza como handoff vigente a:** la versión anterior de este archivo (bloque D-152, archivada en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-08-18_D152.md`)

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
        4.5  Tickets: Nivel 2 y 3 + Pill  ✅ CERRADO (18-ago / D-152, hallazgo N)
        4.6  Clientes: retorno y valor    ✅ CERRADO (18-ago / D-153)
        4.7  Reportes: nivel 2 y 3        ⬜ Siguiente paso
        4.8  Inventario, Compras y Gastos ⬜
        4.9  Servicios, Equipo y Galería  ⬜
        4.10 Barra celular con acciones   ⬜ (hallazgo D)
        4.11 Rediseño panel plataforma    ⬜ (hallazgo O)
```

---

## 2. Qué pasó en este bloque (D-153)

Se completó el **Paso 4.6** transformando el directorio de clientes en una herramienta activa de fidelización y métricas de valor:

1. **Decisión de arquitectura sobre nombres:** Se mantiene el campo unificado `name` (nombre comercial del cliente, sin exigir campos separados de Nombre y Apellido para evitar fricción en salones de estética) con un extractor reactivo `firstName` en Flutter para redactar saludos personalizados automáticos en WhatsApp.
2. **Base de datos / RPC:** Migración `20260818140000_clientes_metricas_retorno_y_valor.sql` que actualiza `public.get_clients_management_summary()` para calcular en una sola consulta agregada:
   - `total_visits`: Total de citas finalizadas o cerradas.
   - `total_spent`: Gasto total acumulado en servicios.
   - `average_ticket`: Ticket promedio por visita (`total_spent / total_visits`).
   - `first_visit_at` y `last_visit_at`: Fechas de primera y última atención.
   - `days_since_last_visit`: Días transcurridos desde la última cita.
   - `avg_days_between_visits`: Cadencia promedio de visita (`(last_visit - first_visit) / (total_visits - 1)`).
   - `balance_amount`: Saldo en mora.
   - `segment`: `'vip'` ($\ge 3$ visitas, $\le 35$ días), `'recurrente'` ($\ge 2$ visitas, $\le 45$ días), `'nuevo'` (1 visita), `'en_riesgo'` ($> 45$ días sin visitar), `'sin_visitas'`.
3. **Script de Control 175:** Creado `supabase/sql/175_test_clientes_metricas_retorno_y_valor.sql` con 4 pruebas aisladas en `ROLLBACK`.
4. **Nivel 2 (Listado y Búsqueda):**
   - Buscador universal por texto (nombre, teléfono sanitizado, correo).
   - Chips horizontales de segmentación con contadores en vivo (*Todos*, *⭐ VIP*, *⚠️ En riesgo*, *🟢 Recurrentes*, *🆕 Nuevos*, *🔴 Con saldo*, *Inactivos*).
   - `ClientRow` modernizado: avatar con iniciales, badge de segmento, métricas compactas (visitas, gasto, cadencia promedio `~X días`, última visita), saldo en mora en coral y botón directo de WhatsApp contextualizado.
5. **Nivel 3 (Ficha de Detalle interactiva `_ClientDetailSheet`):**
   - Modal responsivo (BottomSheet en móvil / Drawer centrado en escritorio).
   - 4 tarjetas de KPIs RFM (Gasto Histórico, Ticket Promedio, Total Visitas, Cadencia Promedio).
   - Alerta destacada de saldo en mora con botón directo.
   - Sección de tiempos y frecuencia (última visita, primera visita y fecha de alta).
   - Notas operativas y preferencias de la clienta.
   - Botón de editar y gestionar.
6. **Pruebas y Verificación:**
   - Creado `test/clients_page_test.dart` (6 pruebas unitarias y de widgets).
   - Total de pruebas del proyecto: **138 de 138 en VERDE**.
   - `flutter analyze` 100% limpio (0 errores, 0 advertencias).

---

## 3. Estado técnico

- **Pruebas Flutter:** **138 de 138 en verde** (`flutter test`)
- **Análisis estático:** 0 errores, 0 advertencias (`flutter analyze`)
- **Decisiones registradas:** **153 decisiones** (D-001 al D-153)
- **Base de datos:** Migración `20260818140000_clientes_metricas_retorno_y_valor.sql` y Control 175 listos para aplicar por el propietario

---

## 4. Próximos pasos inmediatos (para la próxima sesión)

1. **Paso 4.7:** Reportes: nivel 2 y 3, métodos de pago, comparación.
2. **Paso 4.8:** Inventario, Compras y Gastos: pulido visual y plural en correos de stock bajo ("3 unidades").
3. **Paso 4.9:** Servicios, Estilistas y Galería: filtrar por cliente/estilista y producción por estilista.
4. **Paso 4.10:** Barra inferior de celular con acciones rápidas (Hallazgo D).
5. **Paso 4.11:** Rediseño del panel de plataforma SaaS (Hallazgo O).
