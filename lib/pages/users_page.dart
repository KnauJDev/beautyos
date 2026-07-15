import 'package:flutter/material.dart';

import '../models/tenant_user.dart';
import '../services/tenant_users_service.dart';
import '../widgets/app_widgets.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final TenantUsersService _usersService = const TenantUsersService();
  late Future<List<TenantUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _usersService.getTenantUsers();
  }

  void _refresh() {
    setState(() {
      _usersFuture = _usersService.getTenantUsers();
    });
  }

  Future<void> _manageUser(TenantUser user) async {
    final updated = await showDialog<TenantUser>(
      context: context,
      builder: (context) =>
          _ManageUserDialog(user: user, usersService: _usersService),
    );

    if (updated == null || !mounted) return;

    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Acceso actualizado para ${updated.fullName}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Usuarios',
      subtitle: 'Accesos y roles del equipo del centro.',
      children: [
        const InfoPanel(
          icon: Icons.manage_accounts_outlined,
          title: 'Administración de accesos',
          description:
              'Solo el propietario puede activar, desactivar o cambiar el rol de cuentas existentes. Las contraseñas no se muestran ni se modifican aquí.',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_outlined),
          label: const Text('Actualizar usuarios'),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<TenantUser>>(
          future: _usersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los usuarios',
                description: snapshot.error.toString(),
              );
            }

            final users = snapshot.data ?? [];
            if (users.isEmpty) {
              return const InfoPanel(
                icon: Icons.people_outline,
                title: 'Sin usuarios registrados',
                description:
                    'No hay perfiles activos ni inactivos para mostrar.',
              );
            }

            return _UsersContent(users: users, onManage: _manageUser);
          },
        ),
      ],
    );
  }
}

class _UsersContent extends StatelessWidget {
  const _UsersContent({required this.users, required this.onManage});

  final List<TenantUser> users;
  final ValueChanged<TenantUser> onManage;

  @override
  Widget build(BuildContext context) {
    final activeUsers = users.where((user) => user.active).length;
    final administrators = users
        .where((user) => user.role == 'owner' || user.role == 'admin')
        .length;
    final stylists = users.where((user) => user.role == 'stylist').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            MetricCard(
              icon: Icons.people_outline,
              title: 'Cuentas',
              value: users.length.toString(),
              description: 'Perfiles del centro.',
            ),
            MetricCard(
              icon: Icons.verified_user_outlined,
              title: 'Activas',
              value: activeUsers.toString(),
              description: 'Con acceso habilitado.',
            ),
            MetricCard(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Administración',
              value: administrators.toString(),
              description: 'Propietario y administradores.',
            ),
            MetricCard(
              icon: Icons.badge_outlined,
              title: 'Estilistas',
              value: stylists.toString(),
              description: 'Usuarios con rol estilista.',
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle('Usuarios del centro'),
        const SizedBox(height: 12),
        ...users.map((user) => _UserCard(user: user, onManage: onManage)),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onManage});

  final TenantUser user;
  final ValueChanged<TenantUser> onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFEEE6FF),
            foregroundColor: const Color(0xFF7C3AED),
            child: Icon(
              user.isOwner
                  ? Icons.workspace_premium_outlined
                  : Icons.person_outline,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D1B69),
                  ),
                ),
                if (user.email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    user.email,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _UserTag(label: user.roleText, active: true),
                    _UserTag(
                      label: user.active
                          ? 'Acceso activo'
                          : 'Acceso suspendido',
                      active: user.active,
                    ),
                    if (user.stylistName != null &&
                        user.stylistName!.isNotEmpty)
                      _UserTag(
                        label: 'Estilista: ${user.stylistName}',
                        active: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (user.isOwner)
            const Text(
              'Protegido',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () => onManage(user),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Gestionar'),
            ),
        ],
      ),
    );
  }
}

class _UserTag extends StatelessWidget {
  const _UserTag({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEEE6FF) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active ? const Color(0xFF6D28D9) : const Color(0xFFB91C1C),
        ),
      ),
    );
  }
}

class _ManageUserDialog extends StatefulWidget {
  const _ManageUserDialog({required this.user, required this.usersService});

  final TenantUser user;
  final TenantUsersService usersService;

  @override
  State<_ManageUserDialog> createState() => _ManageUserDialogState();
}

class _ManageUserDialogState extends State<_ManageUserDialog> {
  late String _role;
  late bool _active;
  bool _saving = false;
  String? _error;

  List<String> get _roles {
    final roles = <String>['admin', 'assistant', 'client'];
    if (widget.user.hasStylistLink) roles.insert(1, 'stylist');
    return roles;
  }

  @override
  void initState() {
    super.initState();
    _role = _roles.contains(widget.user.role) ? widget.user.role : 'client';
    _active = widget.user.active;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await widget.usersService.updateTenantUserAccess(
        profileId: widget.user.profileId,
        role: _role,
        active: _active,
      );

      if (mounted) Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gestionar usuario'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.user.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (widget.user.email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.user.email,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Rol de acceso',
                  border: OutlineInputBorder(),
                ),
                items: _roles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(_roleText(role)),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _role = value);
                      },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Acceso activo'),
                subtitle: const Text(
                  'Al suspenderlo, la cuenta no podrá usar las funciones del centro.',
                ),
                value: _active,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _active = value),
              ),
              if (!widget.user.hasStylistLink) ...[
                const SizedBox(height: 8),
                const Text(
                  'El rol Estilista solo aparece cuando el usuario está vinculado a un perfil de estilista.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Guardando...' : 'Guardar acceso'),
        ),
      ],
    );
  }
}

String _roleText(String role) {
  switch (role) {
    case 'admin':
      return 'Administrador';
    case 'stylist':
      return 'Estilista';
    case 'assistant':
      return 'Asistente';
    case 'client':
      return 'Cliente';
    default:
      return 'Usuario';
  }
}
