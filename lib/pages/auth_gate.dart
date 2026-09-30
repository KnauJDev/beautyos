import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/aviso_de_enlace_de_correo.dart';
import '../services/limpiar_direccion.dart';
import 'login_page.dart';
import 'mfa_challenge_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authenticatedChild,
  });

  final Widget authenticatedChild;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late bool isAuthenticated;
  late bool needsMfaChallenge;
  StreamSubscription<AuthState>? authSubscription;

  void _refreshAuthStatus() {
    final session = Supabase.instance.client.auth.currentSession;
    isAuthenticated = session != null;

    if (!isAuthenticated) {
      needsMfaChallenge = false;
      return;
    }

    // Verificacion en dos pasos (D-078 punto 3, opcional por usuario):
    // si tiene un factor TOTP verificado, la sesion de solo
    // correo+contraseña queda en aal1 y falta subir a aal2.
    final aal = Supabase.instance.client.auth.mfa
        .getAuthenticatorAssuranceLevel();
    needsMfaChallenge =
        aal.currentLevel != null &&
        aal.nextLevel != null &&
        aal.currentLevel != aal.nextLevel;
  }

  @override
  void initState() {
    super.initState();

    _refreshAuthStatus();

    // AD (D-299): con la sesión ya abierta no se pasa por la pantalla de
    // acceso, que es la que enseña el aviso de un enlace de correo vencido,
    // así que el error se quita de la dirección aquí. Si se quedaba, cerrar
    // sesión días después lo resucitaba como si acabara de pasar (27-sep).
    if (isAuthenticated) {
      final direccionLimpia = AvisoDeEnlaceDeCorreo.direccionSinElError(
        Uri.base,
      );
      if (direccionLimpia != null) {
        reemplazarDireccionSinRecargar(direccionLimpia);
      }
    }

    authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (!mounted) {
          return;
        }

        setState(_refreshAuthStatus);
      },
    );
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    super.dispose();
  }

  void handleLoginSuccess() {
    if (!mounted) {
      return;
    }

    setState(_refreshAuthStatus);
  }

  @override
  Widget build(BuildContext context) {
    if (!isAuthenticated) {
      return LoginPage(
        onLoginSuccess: handleLoginSuccess,
      );
    }

    if (needsMfaChallenge) {
      return const MfaChallengePage();
    }

    return widget.authenticatedChild;
  }
}
