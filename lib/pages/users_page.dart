import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stylist_summary.dart';
import '../models/team_invitation.dart';
import '../models/tenant_user.dart';
import '../services/stylists_service.dart';
import '../services/team_invitations_service.dart';
import '../services/tenant_users_service.dart';
import '../widgets/app_widgets.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final TenantUsersService _usersService = const TenantUsersService();
  final TeamInvitationsService _invitationsService =
      const TeamInvitationsService();
  final StylistsService _stylistsService = const StylistsService();

  late Future<List<TenantUser>> _usersFuture;
  late Future<List<TeamInvitation>> _invitationsFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _usersService.getTenantUsers();
    _invitationsFuture = _invitationsService.listInvitations(
      widget.branchId,
    );
  }

  void _refresh() {
    setState(() {
      _usersFuture = _usersService.getTenantUsers();
      _invitationsFuture = _invitationsService.listInvitations(
        widget.branchId,
      );
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

  Future<void> _openInviteDialog() async {
    final stylists = await _stylistsService.getStylistsSummary();
    if (!mounted) return;

    final emailSent = await showDialog<bool>(
      context: context,
      builder: (context) => _InviteUserDialog(
        branchId: widget.branchId,
        stylists: stylists,
        invitationsService: _invitationsService,
      ),
    );

    if (emailSent != null) {
      _refresh();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            emailSent
                ? 'Invitación creada y correo enviado automáticamente.'
                : 'Invitación creada, pero no se pudo enviar el correo '
                      'automático. Avísale tú mismo a la persona que se '
                      'registre en BeautyOS con ese mismo correo.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _cancelInvitation(TeamInvitation invitation) async {
    try {
      await _invitationsService.cancelInvitation(invitation.id);
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar: $error')),
      );
    }
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
              'El propietario o un administrador pueden activar, desactivar o cambiar el rol de cuentas existentes. Las contraseñas no se muestran ni se modifican aquí.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _openInviteDialog,
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('Invitar usuario'),
            ),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Actualizar'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<TeamInvitation>>(
          future: _invitationsFuture,
          builder: (context, snapshot) {
            final invitations = (snapshot.data ?? const <TeamInvitation>[])
                .where((invitation) => invitation.status == 'pending')
                .toList();

            if (invitations.isEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                elevation: 1,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Invitaciones pendientes'),
                      const SizedBox(height: 12),
                      ...invitations.map(
                        (invitation) => _InvitationRow(
                          invitation: invitation,
                          onCancel: () => _cancelInvitation(invitation),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
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

class _InvitationRow extends StatelessWidget {
  const _InvitationRow({required this.invitation, required this.onCancel});

  final TeamInvitation invitation;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.mail_outline, size: 20, color: Color(0xFF7C3AED)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.email,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  invitation.stylistName != null
                      ? '${invitation.roleText} · ${invitation.stylistName}'
                      : invitation.roleText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancelar')),
        ],
      ),
    );
  }
}

class _InviteUserDialog extends StatefulWidget {
  const _InviteUserDialog({
    required this.branchId,
    required this.stylists,
    required this.invitationsService,
  });

  final String branchId;
  final List<StylistSummary> stylists;
  final TeamInvitationsService invitationsService;

  @override
  State<_InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends State<_InviteUserDialog> {
  final emailController = TextEditingController();
  String role = 'assistant';
  String? stylistId;
  bool isSaving = false;
  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() => errorMessage = 'El correo es obligatorio.');
      return;
    }
    if (role == 'stylist' && stylistId == null) {
      setState(
        () => errorMessage = 'Selecciona a qué estilista corresponde.',
      );
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      final emailSent = await widget.invitationsService.createInvitation(
        branchId: widget.branchId,
        email: email,
        role: role,
        stylistId: role == 'stylist' ? stylistId : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(emailSent);
    } on PostgrestException catch (error) {
      setState(() => errorMessage = error.message);
    } catch (error) {
      setState(() => errorMessage = 'Ocurrió un error inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invitar usuario'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: const [
                DropdownMenuItem(value: 'assistant', child: Text('Asistente')),
                DropdownMenuItem(
                  value: 'admin',
                  child: Text('Administrador'),
                ),
                DropdownMenuItem(value: 'stylist', child: Text('Estilista')),
              ],
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          role = value;
                          if (role != 'stylist') stylistId = null;
                        });
                      }
                    },
            ),
            if (role == 'stylist') ...[
              const SizedBox(height: 12),
              if (widget.stylists.isEmpty)
                const Text(
                  'No hay estilistas en el catálogo todavía. Créalo primero '
                  'en "Estilistas".',
                  style: TextStyle(color: Color(0xFFB45309)),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: stylistId,
                  decoration: const InputDecoration(
                    labelText: 'Estilista del catálogo',
                  ),
                  items: widget.stylists
                      .map(
                        (stylist) => DropdownMenuItem(
                          value: stylist.id,
                          child: Text(stylist.name),
                        ),
                      )
                      .toList(),
                  onChanged: isSaving
                      ? null
                      : (value) => setState(() => stylistId = value),
                ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isSaving ? null : save,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar invitación'),
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
