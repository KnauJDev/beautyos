# HANDOFF Salón y Más — 22 de agosto de 2026 (bloques D-157 y D-158)

**Bloques documentados:**
- **D-157:** Paso 4.10 cerrado · Rediseño integral de Navegación, Header blanco minimalista y Sidebar categorizado estilo WeiBook/Fresha (Hallazgo D).
- **D-158:** Paso 4.11 cerrado · Rediseño del Panel de Plataforma SaaS (Hallazgo O) + Ficha Completa Nivel 3 de Negocio (bosquejo del propietario) y selector interactivo de planes en Checkout ePayco.

**Estado:** **156 de 156 pruebas unitarias y de widgets en verde** (`flutter test`), `flutter analyze` 100% limpio (0 errores, 0 advertencias), `test/sin_colores_sueltos_test.dart` en verde.
**Hito mayor alcanzado:** 🎉 **FASE 4: PULIDO MÓDULO A MÓDULO — 100% CERRADA (11 DE 11 PASOS)**.

---

## 1. Dónde estamos

```
Fase 0  Que exista en internet        ✅ CERRADA
Fase 1  Que sea seguro compartirla    ✅ CERRADA
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
Fase 4  Pulido módulo a módulo        ✅ 100% CERRADA (11 de 11 pasos)
        4.1  Consecutivo de ticket        ✅ CERRADO (09-ago / D-117)
        4.2  Funciones del tablero agenda ✅ CERRADO Y APLICADO EN BD (17-ago / D-147)
        4.3  Tablero Flutter (Día/Sem/Mes)✅ CERRADO SIN RESERVAS (17-ago / D-148, D-149)
        4.4  Número de venta al cerrar    ✅ CERRADO (17-ago / D-150, corregido D-151)
        4.5  Tickets: Nivel 2 y 3 + Pill  ✅ CERRADO (18-ago / D-152, hallazgo N)
        4.6  Clientes: retorno y valor    ✅ CERRADO (18-ago / D-153)
        4.7  Reportes: nivel 2 y 3        ✅ CERRADO (18-ago / D-154)
        4.8  Inventario, Compras y Gastos ✅ CERRADO (18-ago / D-155)
        4.9  Servicios, Equipo y Galería  ✅ CERRADO (18-ago / D-156)
        4.10 Rediseño Shell / Navegación  ✅ CERRADO (22-ago / D-157, hallazgo D)
        4.11 Rediseño panel plataforma    ✅ CERRADO (22-ago / D-158, hallazgo O)
Fase 5  La cara pública (Reservas Web) ⬜ Siguiente fase
```

---

## 2. Qué pasó en este bloque (D-157 y D-158)

### Paso 4.10 — Rediseño integral de Shell, Header blanco y Navegación (D-157):
1. **Header Blanco Minimalista (`lib/main.dart`):** `AppBar` blanco (`AppColors.surface`) con borde sutil, isotipo degradado de BeautyOS, selector de sede en píldora interactiva (`_BranchSelectorPill`), botón de Acción Rápida Global destacada (`+ Nueva Cita`), badge de prueba/gracia minimalista (`_TrialHeaderBadge`) y avatar de usuario con popup de seguridad/cierre de sesión.
2. **Sidebar de Escritorio Categorizado (`_CategorizedSideMenu`):** 4 grupos semánticos (`OPERACIÓN`, `FINANZAS Y GESTIÓN`, `PORTAFOLIO`, `CATÁLOGO Y AJUSTES`), items ergonómicos redondeados con indicador activo.
3. **Navegación Móvil (`_MobileNavBar`):** Barra inferior con 4 destinos clave (`Agenda`, `Tickets`, `Clientes`, `Dashboard`) y modal "Más" categorizado.

### Paso 4.11 — Rediseño del Panel de Plataforma SaaS y Ficha Completa Nivel 3 (D-158):
1. **Cabina de Plataforma (`PlatformPanelPage` / `lib/pages/platform_panel_page.dart`):**
   - Header blanco limpio con isotipo de plataforma.
   - **Banner superior de 5 KPIs cuantitativos:** *Total salones*, *🟡 Por aprobar*, *🟢 Clientes activos*, *⏱️ En prueba*, *⚠️ Gracia/Mora*, que filtran el listado en 1 toque.
   - **Buscador universal en vivo:** salón, titular, WhatsApp/teléfono, correo o ciudad, con chips de filtrado rápido (*Todos*, *Por Aprobar*, *Activos*, *En Prueba*, *Demos*, *Suspendidos*).
   - **Tarjetas `_TenantCard`:** badges de estado, tarifa mensual fijada y botones directos de WhatsApp y llamada telefónica.
2. **Ficha Completa Nivel 3 (`_TenantDetailSheet` — según bosquejo del propietario):**
   - **Sección 1: Identificación y Contacto:** Negocio, titular, tipo de centro, sedes, equipo, origen/referido, con botones directos para chatear por WhatsApp y llamada telefónica.
   - **Sección 2: Plan y Tarifa Mensual:** Plan asignado, precio mensual efectivo en COP y fechas de vigencia.
   - **Sección 3: Botonera de Gestión:** Aprobar, Rechazar, Suspender, Reactivar, Extender prueba y Ver datos de soporte.
   - **Sección 4: Historial de Periodos:** Tabla de eventos de suscripción y pagos registrados.
3. **Selector Interactivo de Planes en Checkout ePayco (`EpaycoCheckoutService`):**
   - Cuando el dueño del salón presiona "Activar plan" o "Pagar", ahora dispone de un selector dinámico (Básico $160k, Business $200k, Profesional $240k) con cálculo automático del 50% Pionero ($80k, $100k, $120k) antes de abrir ePayco.

---

## 3. Estado técnico

- **Pruebas Flutter:** **156 de 156 en verde** (`flutter test`)
- **Análisis estático:** 0 errores, 0 advertencias (`flutter analyze`)
- **Decisiones registradas:** **158 decisiones** (D-001 al D-158 en `REGISTRO_DE_DECISIONES.md`)
- **Base de datos de producción:** 100% sincronizada (Controles 170 al 177 verificados en verde).
- **Git:** Rama `main` sincronizada con `origin/main`.

---

## 4. Próximo hito: FASE 5 — La Cara Pública (Reservas Web)

- **Paso 5.1:** Identificador único por negocio sin ñ ni tildes (`salonymas.com/naguaradeunas`).
- **Paso 5.2:** Función pública que lo resuelva sin sesión.
- **Paso 5.3:** Enrutado por ruta en Flutter y `_redirects`.
- **Paso 5.4:** Edición de slug desde Configuración.
- **Paso 5.5:** Página pública del negocio: portafolio, equipo, reseñas y reserva 24/7 sin choques de agenda.
- **Paso 5.6:** Portal de la clienta final: historial de visitas y fotos de trabajos.
