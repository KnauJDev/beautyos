import 'package:flutter/material.dart';

/// Paleta unica de Salon y Mas (D-097, D-102).
///
/// Antes de esto habia **54 colores distintos escritos a mano en 33 archivos**,
/// con duplicados que nadie decidio: cinco morados claros casi iguales, cuatro
/// verdes de exito, seis ambares y dos grises de texto secundario. Se fue
/// acumulando pantalla por pantalla.
///
/// Regla: **ningun archivo de `lib/` vuelve a escribir un `Color(0xFF...)`.**
/// Si hace falta un tono que no esta aqui, se agrega aqui.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------
  // MARCA. Es lo unico que cambia con la marca blanca (D-093, D-109).
  //
  // **Son los seis unicos valores de este archivo que no son `const`**, y esa
  // es exactamente la funcion que cumplen: los escribe `AppBrand.aplicar()`
  // cuando llegan los datos del negocio, y `MaterialApp` se reconstruye.
  //
  // Arrancan en morado a proposito. Entre que la aplicacion abre y que
  // responde la consulta del negocio pasa medio segundo; durante ese rato se
  // pinta el morado de Salon y Mas, que es lo correcto en la pantalla de
  // login, donde todavia no se sabe de que negocio es quien entra.
  // ---------------------------------------------------------------------

  /// Color principal: barra superior, botones, selecciones. En un tema de dos
  /// colores es el primero (D-109).
  static Color brand = const Color(0xFF7C3AED);

  /// Para estados presionados y superficies fuertes sobre el principal.
  static Color brandDark = const Color(0xFF6D28D9);

  /// Titulos y texto sobre fondos claros de marca. Muy oscuro a proposito:
  /// el morado puro no tiene contraste suficiente para texto largo. En un tema
  /// de dos colores es el segundo (D-109).
  static Color brandDeep = const Color(0xFF2D1B69);

  /// Relleno de pildoras, iconos y selecciones.
  static Color brandTint = const Color(0xFFEDE9FE);

  /// Fondos de tarjeta con acento suave.
  static Color brandTintSoft = const Color(0xFFF5F3FF);

  /// Fondo general de la aplicacion.
  static Color brandSurface = const Color(0xFFF8F5FF);

  // ---------------------------------------------------------------------
  // TEXTO Y SUPERFICIES. Neutrales: no cambian con la marca blanca, porque
  // la legibilidad no es cuestion de gusto.
  // ---------------------------------------------------------------------

  static const textPrimary = Color(0xFF111827);
  static const textStrong = Color(0xFF374151);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const textOnBrand = Color(0xFFFFFFFF);

  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);

  // ---------------------------------------------------------------------
  // ESTADOS DE TICKET. **Fuera de la marca blanca a proposito** (D-097): el
  // ambar significa "pendiente" en todos los negocios. Si el estado cambiara
  // de color con cada tema, dejaria de significar algo.
  // ---------------------------------------------------------------------

  /// Solicitado, cotizado, apartado. Requiere tu atencion.
  static const statePending = Color(0xFFEF9F27);
  static const statePendingTint = Color(0xFFFAEEDA);

  /// Confirmado, en espera. Todo bien.
  static const stateConfirmed = Color(0xFF639922);
  static const stateConfirmedTint = Color(0xFFEAF3DE);

  /// En proceso. Sucediendo ahora.
  static const stateInProgress = Color(0xFF378ADD);
  static const stateInProgressTint = Color(0xFFE6F1FB);

  /// Finalizado sin cobrar. Coral y **no rojo** a proposito: si fuera rojo, un
  /// dia con muchos cobros pendientes pareceria un desastre cuando en realidad
  /// es un buen dia de trabajo sin cerrar caja (D-101).
  static const stateToCollect = Color(0xFFD85A30);
  static const stateToCollectTint = Color(0xFFFAECE7);

  /// Cerrado. Ya no requiere nada.
  static const stateClosed = Color(0xFF888780);
  static const stateClosedTint = Color(0xFFF1EFE8);

  // ---------------------------------------------------------------------
  // MENSAJES AL USUARIO. Distinto de los estados de ticket: esto es para
  // confirmaciones, avisos y errores de la interfaz.
  // ---------------------------------------------------------------------

  static const success = Color(0xFF059669);
  static const successTint = Color(0xFFD1FAE5);

  static const warning = Color(0xFFB45309);
  static const warningTint = Color(0xFFFEF9C3);

  /// Peligro: eliminar, cancelar, no asistio. Nunca se usa para "por cobrar".
  static const danger = Color(0xFFB91C1C);
  static const dangerTint = Color(0xFFFEE2E2);

  static const info = Color(0xFF1D4ED8);
  static const infoTint = Color(0xFFDBEAFE);
}
