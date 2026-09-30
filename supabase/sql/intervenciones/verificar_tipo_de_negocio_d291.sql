-- ==============================================================================
-- D-291: comprobar que guardar Configuracion sin tocar "Tipo de negocio" NO
-- reescribe el valor guardado.
--
-- POR QUE: desde D-291 la pantalla ensena el texto traducido ("Peluqueria /
-- Salon de Belleza") en vez del codigo guardado ("salon"). Si se guardara lo
-- que se ve, el codigo se reescribiria sin que nadie lo pidiera. La pantalla
-- no puede decir cual de los dos quedo guardado, porque ensena lo mismo en los
-- dos casos. Esta lectura si.
--
-- COMO SE USA: guarda en Configuracion > Datos del negocio (por ejemplo, el
-- mismo WhatsApp de siempre) SIN tocar "Tipo de negocio", y despues corre esto.
-- Lo esperado: la Peluqueria Exito Prueba sigue con business_type = 'salon'.
--
-- NO MODIFICA NADA. Solo lectura.
-- ==============================================================================

select t.name as negocio,
       t.business_type as tipo_guardado
from public.tenants t
order by t.name;
