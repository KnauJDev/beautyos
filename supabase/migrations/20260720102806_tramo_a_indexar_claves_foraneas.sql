-- BeautyOS - Tramo A: indices de apoyo para claves foraneas multisede.
-- Version local alineada con el historial administrado de Supabase.
--
-- Migracion aditiva y sin cambios de datos. Evita recorridos completos al
-- consultar relaciones o validar actualizaciones y borrados restringidos.

create index if not exists tenant_memberships_tenant_stylist_idx
  on public.tenant_memberships (tenant_id, stylist_id)
  where stylist_id is not null;

create index if not exists tenant_memberships_created_by_idx
  on public.tenant_memberships (created_by)
  where created_by is not null;

create index if not exists branch_memberships_tenant_branch_idx
  on public.branch_memberships (tenant_id, branch_id);

create index if not exists branch_memberships_tenant_membership_idx
  on public.branch_memberships (tenant_id, tenant_membership_id);

create index if not exists branch_memberships_created_by_idx
  on public.branch_memberships (created_by)
  where created_by is not null;

create index if not exists branch_services_tenant_service_idx
  on public.branch_services (tenant_id, service_id);

create index if not exists branch_stylists_tenant_stylist_idx
  on public.branch_stylists (tenant_id, stylist_id);

create index if not exists branch_stylist_services_stylist_fk_idx
  on public.branch_stylist_services (tenant_id, branch_id, branch_stylist_id);

create index if not exists branch_stylist_services_service_fk_idx
  on public.branch_stylist_services (tenant_id, branch_id, branch_service_id);

create index if not exists branch_products_tenant_branch_idx
  on public.branch_products (tenant_id, branch_id);

create index if not exists branch_products_tenant_product_idx
  on public.branch_products (tenant_id, product_id);
