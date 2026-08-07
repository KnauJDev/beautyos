import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import '../services/app_version_service.dart';
import '../services/page_reloader.dart';

/// Version con la que arranco esta pestana. La guarda el propio aviso en
/// cuanto consigue leerla, y la lee Configuracion para mostrar el sello.
///
/// Es un `ValueNotifier` y no un campo suelto porque la consulta al servidor
/// tarda: si Configuracion se dibuja antes de que llegue la respuesta, con un
/// campo suelto se quedaba mostrando "En desarrollo" para siempre aunque el
/// dato llegara un segundo despues.
class AppVersionHolder {
  AppVersionHolder._();

  static final ValueNotifier<AppVersion?> bootVersion =
      ValueNotifier<AppVersion?>(null);
}

/// Avisa cuando hay una version nueva publicada.
///
/// Por que existe (D-099): los archivos de Flutter Web no llevan huella en el
/// nombre, asi que una recepcionista que deja la pestana abierta toda la
/// semana sigue ejecutando el codigo del lunes. Las cabeceras de D-096 evitan
/// que el navegador se quede pegado al recargar, pero nadie recarga si no sabe
/// que hay algo nuevo.
///
/// **Avisa, no recarga.** Recargar por su cuenta le borraria a quien esta
/// atendiendo el ticket que tiene a medio escribir.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner>
    with WidgetsBindingObserver {
  static const _servicio = AppVersionService();

  /// Cada cinco minutos es suficiente: un despliegue no es urgente, y
  /// preguntar mas seguido solo gasta bateria y datos sin ganar nada.
  static const _intervalo = Duration(minutes: 5);

  Timer? _timer;
  bool _hayVersionNueva = false;
  bool _consultando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _consultar();
    _timer = Timer.periodic(_intervalo, (_) => _consultar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a la pestana. Es el momento mas util para comprobar: alguien
    // que retoma el trabajo despues de un rato es justo quien mas probable
    // tiene una version vieja.
    if (state == AppLifecycleState.resumed) {
      _consultar();
    }
  }

  Future<void> _consultar() async {
    if (_consultando || _hayVersionNueva) return;
    _consultando = true;

    try {
      final publicada = await _servicio.fetchPublishedVersion();
      if (publicada == null || !mounted) return;

      final arranque = AppVersionHolder.bootVersion.value;

      // Primera lectura: no hay con que comparar todavia, solo se anota.
      if (arranque == null) {
        AppVersionHolder.bootVersion.value = publicada;
        return;
      }

      if (publicada.commit != arranque.commit) {
        setState(() => _hayVersionNueva = true);
      }
    } finally {
      _consultando = false;
    }
  }

  void _actualizar() {
    // Recarga del navegador, no navegacion interna: lo que hay que reemplazar
    // es el codigo que el navegador ya tiene descargado.
    AppVersionHolder.bootVersion.value = null;
    recargarPagina();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hayVersionNueva) return const SizedBox.shrink();

    return Material(
      color: AppColors.brandTint,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.rocket_launch_outlined,
              size: 20,
              color: AppColors.brand,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Hay una versión nueva de Salón y Más.',
                style: TextStyle(
                  color: AppColors.brandDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _actualizar,
              child: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}
