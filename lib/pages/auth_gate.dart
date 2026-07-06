import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_page.dart';

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
  StreamSubscription<AuthState>? authSubscription;

  @override
  void initState() {
    super.initState();

    isAuthenticated = Supabase.instance.client.auth.currentSession != null;

    authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final hasSession = data.session != null;

        if (!mounted) {
          return;
        }

        setState(() {
          isAuthenticated = hasSession;
        });
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

    setState(() {
      isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isAuthenticated) {
      return widget.authenticatedChild;
    }

    return LoginPage(
      onLoginSuccess: handleLoginSuccess,
    );
  }
}
