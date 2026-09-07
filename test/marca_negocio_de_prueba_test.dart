// Paso 9.29 / D-225 — la marca de "negocio de ensayo".
//
// POR QUE ESTA PRUEBA, Y QUE NO CUBRE
//
// D-120 creo `tenants.is_demo` en agosto para que los negocios de ensayo no
// ensuciaran las metricas del SaaS, pero la marca se puso con un `update`
// escrito a mano dentro de aquella migracion y **no dejo forma de volver a
// ponerla**. Meses despues, los tres negocios de prueba contaban como salones
// reales y nadie podia arreglarlo sin escribir SQL.
//
// El fallo, por tanto, no fue de logica: **fue que la via para hacerlo dejo de
// existir**. Eso es lo que vigila esta prueba, y solo eso.
//
// Lo que NO cubre, dicho sin adornos:
//   * Que la RPC haga lo correcto. Eso lo prueba el control de base de datos
//     `supabase/sql/207_...` y la propia autorizacion de la funcion, que
//     rechaza a quien no sea dueno de plataforma.
//   * Que el boton del Panel llame al servicio. `PlatformService` usa
//     `Supabase.instance.client` directamente, asi que no se puede sustituir
//     por un doble en una prueba. Para cubrirlo haria falta que el servicio
//     fuera inyectable -- que es justo lo que abriria el paso 9.13.
//
// Una prueba que promete mas de lo que hace es peor que no tenerla.

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/services/platform_service.dart';

void main() {
  test(
    'D-225 — el Panel conserva la via para marcar un negocio de ensayo',
    () {
      // Si alguien renombra o borra `setTenantDemo`, esto se cae. Es el unico
      // guardian contra repetir el agujero de D-120: una marca sin forma de
      // ponerla no es una marca, es un comentario.
      const servicio = PlatformService();
      expect(
        servicio.setTenantDemo,
        isA<Future<void> Function({required String tenantId, required bool isDemo})>(),
        reason:
            'La firma tambien importa: la marca tiene que poder PONERSE y '
            'QUITARSE. Un negocio marcado deja de recibir los avisos de '
            'vencimiento, asi que para probar esos correos hay que poder '
            'desmarcarlo, probar, y volver a marcarlo (D-225).',
      );
    },
  );
}
