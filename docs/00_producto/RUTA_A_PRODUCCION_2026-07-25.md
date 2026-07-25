# Ruta a producción: de app en construcción a negocio real

**Fecha:** 25 de julio de 2026
**Contexto:** el propietario no tiene formación técnica ni de programación
y es el único responsable de la parte de negocio de BeautyOS. Este
documento consolida, en lenguaje simple, todo lo que falta fuera del
código para convertir BeautyOS en un negocio real que le cobre a clientes
reales, y la decisión tomada sobre "marca blanca" (branding por negocio).
Ningún punto de este documento estaba implementado ni decidido antes de
esta fecha; el propietario confirmó que no tiene nada de lo listado abajo
todavía (sin empresa constituida, sin dominio, sin precios definidos).

## 1. Objetivo de este documento

Servir de mapa permanente para cualquier chat nuevo que ayude al
propietario con la parte de negocio/lanzamiento (no solo código), y para
que el propietario mismo tenga claridad de qué falta y en qué orden.

## 2. Mapa completo, en tres fases

### Fase 1 — Dejar el producto listo para usarse de verdad

1. Terminar y pulir la app (features pendientes + apariencia visual).
2. Sacar la app de "solo corre en una computadora" y ponerla en
   internet de forma permanente (hospedaje/hosting) para que cualquier
   cliente entre desde su navegador a cualquier hora.
3. Comprar un nombre de dominio propio de BeautyOS (necesario también
   para la marca blanca por subdominio, ver sección 3).
4. Subir el proyecto de Supabase (la base de datos) de su plan gratis
   actual a un plan pago -- ya identificado antes (D-042) como
   requisito obligatorio antes de aceptar el primer cliente que pague
   de verdad (el plan gratis no hace respaldos diarios y se pausa por
   inactividad).
5. Decidir los precios reales de los 3 planes comerciales (Básico,
   Business, Profesional) -- el sistema ya tiene la estructura lista
   (D-044), solo faltan los números, que son una decisión de negocio
   del propietario, no técnica.

### Fase 2 — Quedar listo para operar legalmente y cobrar

6. Constituir la empresa (si no existe formalmente todavía) --
   necesaria para facturar y para abrir la cuenta comercial de la
   pasarela de pagos.
7. Redactar términos de servicio y política de privacidad -- obligatorio
   porque la app maneja datos personales de los clientes de cada
   negocio (nombre, celular, a veces documento; ver D-006).
8. Pasarela de pago Wompi -- ya bloqueada desde D-046 hasta que el
   propietario tenga la cuenta comercial lista (trámite presencial). Una
   vez lista, la integración técnica la hace el chat de código.

### Fase 3 — Conseguir clientes

9. Una página web simple (distinta de la app) que explique qué es
   BeautyOS, para que un negocio que nunca la ha visto entienda qué
   hace y quiera probarla.
10. Un plan simple de cómo se van a enterar los negocios de belleza de
    que esto existe (redes sociales, referidos, contacto directo). La
    ejecución de marketing/ventas no la puede hacer el chat de código
    por el propietario.
11. Cómo se va a atender a un cliente cuando tenga una duda o un
    problema (aunque sea solo WhatsApp al principio).

## 3. Decisión: marca blanca (branding por negocio)

El propietario preguntó si cada negocio podría tener su propio look
(logo, colores) y, idealmente, su propio dominio tipo
`www.naguaradeuñas.com`.

### 3.1 Opciones evaluadas para el dominio

- **Dominio 100% propio de cada negocio** (ej. `naguaradeuñas.com`):
  técnicamente posible, pero cada negocio tendría que comprar su propio
  dominio y alguien debe conectarlo técnicamente a BeautyOS (configurar
  DNS), un paso que un dueño de salón normalmente no puede hacer solo.
  Es una carga operativa real por cada negocio nuevo.
- **Subdominio de un dominio propio de BeautyOS** (ej.
  `naguaradeunas.beautyos.app`): no requiere que el negocio haga nada
  técnico, se puede asignar automáticamente al registrarse (el sistema
  ya tiene un concepto parecido: `branch.slug`). Mucho más simple de
  construir y mantener.

### 3.2 Decisión

Empezar con **subdominios automáticos** (Opción B) cuando se aborde el
tema de dominios (Fase 1, punto 3 de este documento). El dominio 100%
propio por negocio (Opción A) queda como posible función futura de pago
("plan empresarial"), a ofrecer más adelante a negocios grandes que lo
pidan explícitamente, no desde el lanzamiento.

### 3.3 Logo y colores por negocio: sí se construye ya

Independiente de la decisión de dominio, que cada negocio pueda subir su
logo y elegir su paleta de colores es una función normal de construir
(reutiliza la misma infraestructura de Supabase Storage ya construida
para fotos de trabajo, D-060). Se agrega a la lista de bloques técnicos
pendientes en `PROMPT_MAESTRO_IA.md` -- ver D-062.

## 4. Qué NO cubre este documento

Este documento no reemplaza `PROMPT_MAESTRO_IA.md` (arranque técnico de
cada bloque) ni `REGISTRO_DE_DECISIONES.md` (historial de decisiones).
Es un mapa de negocio/lanzamiento; las decisiones técnicas puntuales que
se desprendan de él (ej. logo y colores por negocio) se documentan como
su propio bloque cuando se construyan.
