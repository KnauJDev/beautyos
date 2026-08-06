import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/platform_service.dart';
import 'platform_panel_page.dart';

/// Primera decisión tras autenticar: si el usuario tiene rol de plataforma
/// (platform_owner/platform_operator) va al panel de plataforma; si no,
/// sigue al flujo normal de negocio (que a su vez decide si ya tiene tenant
/// o debe completarlo).
class AuthenticatedRouter extends StatefulWidget {
  const AuthenticatedRouter({super.key, required this.businessApp});

  final Widget businessApp;

  @override
  State<AuthenticatedRouter> createState() => _AuthenticatedRouterState();
}

class _AuthenticatedRouterState extends State<AuthenticatedRouter> {
  final platformService = const PlatformService();

  late Future<String?> platformRoleFuture;

  @override
  void initState() {
    super.initState();
    platformRoleFuture = platformService.getMyPlatformRole();
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: platformRoleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Salón y Más'),
              actions: [
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: signOut,
                  icon: const Icon(Icons.logout_outlined),
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No pudimos verificar tu cuenta.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final platformRole = snapshot.data;

        if (platformRole != null) {
          return PlatformPanelPage(platformRole: platformRole);
        }

        return widget.businessApp;
      },
    );
  }
}
