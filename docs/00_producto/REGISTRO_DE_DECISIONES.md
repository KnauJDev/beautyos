# Registro de decisiones de producto

| ID | Decisión | Estado | Fecha | Consecuencia principal |
|---|---|---|---|---|
| D-001 | BeautyOS será una SaaS para estética, barberías, peluquerías y spas. | Aprobada | 2026-07-19 | Producto vertical multi-tenant. |
| D-002 | Colombia será el mercado del primer piloto. | Aprobada | 2026-07-19 | Moneda COP, zona `America/Bogota` y operadores de pago locales. |
| D-003 | Se soportarán múltiples sedes por tenant desde la arquitectura base. | Aprobada | 2026-07-19 | Todas las entidades operativas deberán considerar sede. |
| D-004 | Planes comerciales: Básico, Business y Profesional. | Aprobada | 2026-07-19 | El acceso a módulos deberá ser configurable por plan. |
| D-005 | Reserva pública: web/QR y WhatsApp; automatización profunda de WhatsApp será posterior. | Aprobada | 2026-07-19 | Se construirá primero un flujo web público sólido. |
| D-006 | Identidad principal del cliente: celular; documento es opcional y sensible. | Aprobada | 2026-07-19 | Requiere consentimiento y protección de datos. |
| D-007 | Compensación de estilistas configurable: porcentaje, monto fijo y salario fijo; con vigencias. | Aprobada | 2026-07-19 | El historial financiero debe conservar condiciones aplicadas. |
| D-008 | Alertas operativas quedan pausadas. | Pausada | 2026-07-19 | No implementar sin autorización expresa. |
| D-009 | Plataforma, tenant y sede son fronteras distintas. | Aprobada | 2026-07-19 | El operador BeautyOS no obtiene acceso implícito a datos del tenant. |
| D-010 | La autorización usa membresías de tenant y sede; `user_profiles` queda como identidad global. | Aprobada | 2026-07-19 | Una cuenta puede pertenecer a varios negocios y sedes. |
| D-011 | Clientes, servicios, profesionales y productos son catálogos del tenant; la operación es de sede. | Aprobada | 2026-07-19 | Precio, duración, capacidad, agenda, caja y stock se configuran por sede. |
| D-012 | Los planes se aplican mediante entitlements verificados en backend. | Aprobada | 2026-07-19 | Ocultar UI no se considera control de acceso. |
| D-013 | Pagos SaaS y pagos del salón son dominios financieros separados. | Aprobada | 2026-07-19 | No comparten tablas, reportes ni conciliación. |
| D-014 | La suspensión por falta de pago es gradual, reversible y sin borrado de datos. | Aprobada | 2026-07-19 | Owner conserva acceso a pago, motivo y exportación esencial. |
| D-015 | La migración multisede será aditiva y por tramos con Sede principal. | Aprobada | 2026-07-19 | No se retiran campos antiguos hasta validar conservación e aislamiento. |
| D-016 | El Tramo B mantiene `branch_id` nullable con triggers privados de compatibilidad hasta que Flutter y las RPC usen sede explícita. | Implementada en producción | 2026-07-20 | Las escrituras heredadas derivan una sede segura; el puente se retira solo en el Tramo D. |
| D-017 | El contexto de sede se selecciona en Flutter pero se resuelve y autoriza nuevamente en cada RPC. | Implementada en C1 de ensayo | 2026-07-20 | Las firmas `_v2` exigen `p_branch_id`; no se confía en JWT, metadatos ni variables de sesión para autorizar. |
