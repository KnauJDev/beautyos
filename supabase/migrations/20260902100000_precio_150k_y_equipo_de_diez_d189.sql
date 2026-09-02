-- BeautyOS / Salón y Más — Precio de lista $150.000 y equipo de 10 (D-189)
--
-- **Corrige a D-188**, que es de ayer: ajusta el precio de catálogo y pone un
-- tope de equipo donde D-188 había dejado "sin límite".
--
-- QUÉ CAMBIA
--
-- 1. **Precio de lista: $120.000 → $150.000 por sede al mes.** El argumento de
--    venta pasa a ser el precio diario: **$5.000 al día** por llevar el salón
--    entero. La cuenta es exacta: 150.000 / 30 = 5.000.
--
-- 2. **El equipo deja de ser ilimitado y queda en 10 personas por negocio.**
--
-- LA CUENTA DEL EQUIPO, QUE NO ES OBVIA
--
-- El encargo pedía "hasta 10 miembros de equipo (1 dueño + hasta 9)". Ese "1 +
-- 9" importa, porque **el propietario no cuenta contra el tope**: lo dejó
-- escrito D-136 al construir `create_team_invitation` — *"su cuenta no es de
-- equipo, es el negocio"* — y ese contador tampoco ha cambiado.
--
-- Así que `limit_value = 10` habría dado **once personas**. El tope va en
-- **9**, que son las nueve cuentas de equipo más el dueño: diez personas, que
-- es lo que se quiso decir.
--
-- ⚠️ **Y el tope es POR NEGOCIO, no por sede.** `create_team_invitation` cuenta
-- las cuentas del tenant entero, no las de una sede. Para el salón de una sola
-- sede es lo mismo; para el de dos, no. Que sea "10 por sede" solo será cierto
-- cuando la Etapa 2 haga la suscripción por sede. Hasta entonces, la promesa
-- comercial y lo que hace el código no coinciden del todo para multi-sede — y
-- como la segunda sede tampoco se puede vender todavía (D-188), no hay nadie a
-- quien se le pueda quedar corto.
--
-- POR QUÉ UN TOPE Y NO "ILIMITADO"
--
-- D-188 lo dejó sin límite. Diez cubre al salón de barrio, que es el cliente
-- objetivo del apartado 1 del Plan Maestro, y deja una palanca de negociación
-- para el centro grande: el panel de plataforma concede la excepción con
-- `tenant_feature_overrides`, que existe desde julio con motivo, vigencia y
-- autor. Es mejor tener que conceder algo que no tener nada que conceder.
--
-- EL PRECIO PIONERO SALE DEL CATÁLOGO
--
-- D-188 lo fijó en $80.000 para los pioneros existentes. **Eso no se toca**:
-- sigue siendo un precio pactado por cliente, que es justo el mecanismo que
-- ahora se quiere usar con libertad. Lo que cambia es que **ya no se publica
-- ninguna cifra pionera en la web** ni el límite de 25 salones: el descuento se
-- negocia uno a uno y se fija desde el panel al aprobar a cada cliente.

begin;

-- ---------------------------------------------------------------------------
-- 1. Precio de lista
-- ---------------------------------------------------------------------------

update public.plans
set price_cop = 150000,
    updated_at = now()
where code = 'pro' and version = 1;

comment on column public.plans.price_cop is
  'Precio de lista en PESOS COLOMBIANOS ENTEROS (150000 = $150.000). No son centavos (D-136). '
  'Es el precio POR SEDE ACTIVA del plan unico Todo Incluido (D-188), fijado en 150.000 por D-189. '
  'El descuento pionero NO vive aqui: es un precio pactado por cliente en tenant_subscriptions.';

-- ---------------------------------------------------------------------------
-- 2. El tope de equipo
-- ---------------------------------------------------------------------------
--
-- 9 cuentas de equipo + el dueño = 10 personas. Ver la cuenta en la cabecera.

update public.plan_features pf
set limit_value = 9
from public.plans p, public.features f
where pf.plan_id = p.id
  and pf.feature_id = f.id
  and p.code = 'pro'
  and f.key = 'team_members';

comment on column public.plan_features.limit_value is
  'Tope de la capacidad. Null = sin limite. Para team_members son CUENTAS DE EQUIPO: el propietario no '
  'cuenta contra el tope (D-136), asi que 9 aqui significa 10 personas en el salon (D-189).';

-- Las sedes siguen sin tope: se cobran, no se limitan (D-188).
update public.plan_features pf
set limit_value = null
from public.plans p, public.features f
where pf.plan_id = p.id
  and pf.feature_id = f.id
  and p.code = 'pro'
  and f.key = 'branches';

commit;
