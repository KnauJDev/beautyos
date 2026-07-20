-- BeautyOS - Reversion del Tramo A EXCLUSIVAMENTE para ensayo desechable.
-- Por seguridad falla salvo que la sesion defina:
--   SET beautyos.allow_destructive_test_rollback = 'yes';

begin;

do $$
begin
  if coalesce(current_setting('beautyos.allow_destructive_test_rollback', true), '') <> 'yes' then
    raise exception 'Rollback bloqueado: solo se permite en ensayo con autorizacion explicita de sesion.';
  end if;
end;
$$;

drop table public.branch_stylist_services;
drop table public.branch_products;
drop table public.branch_stylists;
drop table public.branch_services;
drop table public.branch_memberships;
drop table public.tenant_memberships;
drop table public.branches;

drop function private.beautyos_set_updated_at();

drop index if exists public.products_tenant_id_id_uidx;
drop index if exists public.stylists_tenant_id_id_uidx;
drop index if exists public.services_tenant_id_id_uidx;

commit;
