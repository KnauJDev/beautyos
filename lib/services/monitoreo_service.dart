import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Monitoreo de errores (D-115).
///
/// **El problema que resuelve:** hoy, si la aplicación se rompe para una
/// recepcionista en otro salón, nadie se entera. Ella se frustra, deja de
/// usarla, y el negocio cancela meses después sin decir por qué. Con un solo
/// usuario —el propietario— eso no importa, porque él reporta. Con diez
/// negocios, **el silencio no significa que todo funcione: significa que nadie
/// lo está contando**.
///
/// ---
///
/// ## La regla de privacidad, que es lo que gobierna este archivo
///
/// Estas herramientas, sin configurar, envían por defecto correos, nombres, la
/// dirección IP y a veces lo que había escrito en un formulario. Eso seria
/// **sacar datos de las clientas de los negocios a un servidor de otra
/// empresa**, y choca de frente con la Ley 1581 y con lo que le prometemos a
/// cada cliente.
///
/// Aquí se envía **lo mínimo para poder arreglar el fallo y nada más**:
///
/// | Se envía | No se envía |
/// |---|---|
/// | En qué pantalla ocurrió | Nombres de personas |
/// | El mensaje técnico del error | Correos y teléfonos |
/// | El rol: propietario, asistente… | Direcciones IP |
/// | El identificador del negocio | Lo escrito en formularios |
/// | Navegador y sistema | Datos de clientas |
///
/// El identificador de usuario que sí viaja es el UUID de la cuenta: un número
/// aleatorio que **fuera de nuestra base no significa nada**, y que permite
/// saber si un fallo le pasó a una persona o a todas -- que es información
/// distinta y sirve para priorizar.
class MonitoreoService {
  MonitoreoService._();

  static const _dsn =
      'https://c7be6391d3b39ed19738ca6c5dd6eeae@o4511878127288320.ingest.us.sentry.io/4511878160646144';

  /// Arranca la aplicación con el monitoreo puesto.
  ///
  /// **Solo se activa en la versión publicada.** Durante el desarrollo los
  /// errores se ven en la consola, y mandarlos gastaría la cuota gratuita con
  /// fallos que ya estamos viendo.
  static Future<void> arrancar(Widget Function() app) async {
    if (!kReleaseMode) {
      runApp(app());
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = _dsn;

        // **La línea más importante del archivo.** Sin esto se envían correos,
        // nombres e IP por defecto.
        options.sendDefaultPii = false;

        // Sin medición de rendimiento: consume cuota y no responde ninguna
        // pregunta que hoy tengamos.
        options.tracesSampleRate = 0.0;

        options.environment = 'produccion';

        // Segunda red, por si alguna vez un mensaje de error arrastra un dato
        // personal sin que nadie lo previera.
        options.beforeSend = (evento, pista) => _limpiar(evento);
      },
      appRunner: () => runApp(app()),
    );
  }

  /// Deja anotado **quién** y **de qué negocio**, sin decir nombres.
  ///
  /// Se llama al conocer el perfil. Sirve para responder la pregunta que de
  /// verdad importa al priorizar: ¿esto le pasa a una persona o a todo un
  /// negocio?
  static Future<void> anotarContexto({
    required String? userId,
    required String? rol,
    required String? tenantId,
  }) async {
    if (!kReleaseMode) return;

    await Sentry.configureScope((scope) {
      // Solo el identificador. Sin correo, sin nombre, sin IP.
      if (userId != null) scope.setUser(SentryUser(id: userId));
      if (rol != null) scope.setTag('rol', rol);
      if (tenantId != null) scope.setTag('negocio', tenantId);
    });
  }

  /// Borra el rastro al cerrar sesión, para que un fallo posterior no quede
  /// atribuido a quien ya se fue.
  static Future<void> olvidarContexto() async {
    if (!kReleaseMode) return;
    await Sentry.configureScope((scope) => scope.clear());
  }

  /// Registra una excepción capturada manualmente con un motivo/mensaje técnico.
  static Future<void> reportarError(
    dynamic error,
    dynamic stackTrace, {
    String? motivo,
  }) async {
    if (!kReleaseMode) {
      debugPrint('[Monitoreo] $motivo: $error');
      return;
    }
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (motivo != null) scope.setTag('motivo', motivo);
      },
    );
  }

  /// Ejecuta una operación asíncrona registrando cualquier excepción en
  /// MonitoreoService antes de propagarla (`rethrow`).
  ///
  /// Garantiza que el error se reporte una sola vez en el momento exacto en
  /// que ocurre, sin enviar PII (datos personales) y sin re-disparar en
  /// reconstrucciones de la interfaz (rebuilds de Flutter).
  static Future<T> capturar<T>(
    Future<T> Function() accion, {
    required String motivo,
  }) async {
    try {
      return await accion();
    } catch (error, stackTrace) {
      await reportarError(error, stackTrace, motivo: motivo);
      rethrow;
    }
  }

  /// Tapa lo que parezca un correo o un teléfono en cualquier texto del
  /// reporte. **No debería hacer falta nunca**, y precisamente por eso está:
  /// las fugas de datos personales ocurren en el mensaje que nadie revisó.
  static SentryEvent _limpiar(SentryEvent evento) {
    final mensaje = evento.message;
    if (mensaje != null) {
      evento.message = SentryMessage(
        _tapar(mensaje.formatted),
        template: mensaje.template != null ? _tapar(mensaje.template!) : null,
        params: mensaje.params?.map((p) => p is String ? _tapar(p) : p).toList(),
      );
    }

    final exceptions = evento.exceptions;
    if (exceptions != null && exceptions.isNotEmpty) {
      for (final ex in exceptions) {
        if (ex.value != null) {
          ex.value = _tapar(ex.value!);
        }
      }
    }

    final breadcrumbs = evento.breadcrumbs;
    if (breadcrumbs != null && breadcrumbs.isNotEmpty) {
      for (final b in breadcrumbs) {
        if (b.message != null) {
          b.message = _tapar(b.message!);
        }
      }
    }

    return evento;
  }

  static final _correo = RegExp(r'[\w.\-+]+@[\w\-]+\.[\w.\-]+');
  static final _telefonoConEspacios = RegExp(
    r'\b(?:\+?57[\s.-]?)?3\d{2}[\s.-]\d{3}[\s.-]\d{4}\b',
  );
  static final _telefono = RegExp(r'\b\d{7,15}\b');

  /// Oculta correos electrónicos y secuencias telefónicas en cualquier cadena.
  static String taparDatosSensibles(String texto) => _tapar(texto);

  /// Expuesto para pruebas unitarias de sanitización de eventos de Sentry.
  @visibleForTesting
  static SentryEvent limpiarEventoParaPruebas(SentryEvent evento) =>
      _limpiar(evento);

  static String _tapar(String texto) => texto
      .replaceAll(_correo, '[correo oculto]')
      .replaceAll(_telefonoConEspacios, '[número oculto]')
      .replaceAll(_telefono, '[número oculto]');
}
