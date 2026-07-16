import 'package:flutter/material.dart';

import '../models/client_summary.dart';
import '../services/clients_service.dart';
import '../widgets/app_widgets.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final ClientsService clientsService = const ClientsService();
  late Future<List<ClientSummary>> clientsFuture;

  @override
  void initState() {
    super.initState();
    clientsFuture = clientsService.getClientsManagementSummary();
  }

  void _refreshClients() {
    setState(() {
      clientsFuture = clientsService.getClientsManagementSummary();
    });
  }

  Future<void> _openCreateClientDialog() async {
    final formData = await showDialog<_ClientFormData>(
      context: context,
      builder: (context) => const _CreateClientDialog(),
    );

    if (formData == null) {
      return;
    }

    try {
      final createdClient = await clientsService.createClient(
        name: formData.name,
        phone: formData.phone,
        email: formData.email,
        notes: formData.notes,
      );

      if (!mounted) {
        return;
      }

      if (createdClient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo crear el cliente. Verifica tus permisos.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cliente creado: ${createdClient.name}')),
      );
      _refreshClients();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creando cliente: $error')));
    }
  }

  Future<void> _openEditClientDialog(ClientSummary client) async {
    final formData = await showDialog<_ClientFormData>(
      context: context,
      builder: (context) => _EditClientDialog(client: client),
    );

    if (formData == null) {
      return;
    }

    try {
      final updatedClient = await clientsService.updateClient(
        clientId: client.id,
        name: formData.name,
        phone: formData.phone,
        email: formData.email,
        notes: formData.notes,
        active: formData.active,
      );

      if (!mounted) {
        return;
      }

      if (updatedClient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el cliente.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedClient.active
                ? 'Cliente actualizado: ${updatedClient.name}'
                : 'Cliente desactivado: ${updatedClient.name}',
          ),
        ),
      );
      _refreshClients();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error actualizando cliente: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Clientes',
      subtitle: 'Historial, contacto y preferencias de cada cliente.',
      children: [
        const InfoPanel(
          icon: Icons.people_outline,
          title: 'Clientes conectados con Supabase',
          description:
              'Administra datos de contacto y desactiva clientes sin borrar su historial.',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _openCreateClientDialog,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Nuevo cliente'),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<ClientSummary>>(
          future: clientsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                elevation: 1,
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Cargando clientes desde Supabase...'),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los clientes',
                description: snapshot.error.toString(),
              );
            }

            final clients = snapshot.data ?? [];

            if (clients.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin clientes disponibles',
                description: 'No hay clientes registrados en este momento.',
              );
            }

            return Card(
              elevation: 1,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Clientes del centro'),
                    const SizedBox(height: 14),
                    ...clients.map(
                      (client) => ClientRow(
                        client: client,
                        onEdit: () => _openEditClientDialog(client),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CreateClientDialog extends StatefulWidget {
  const _CreateClientDialog();

  @override
  State<_CreateClientDialog> createState() => _CreateClientDialogState();
}

class _CreateClientDialogState extends State<_CreateClientDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final notesController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _ClientFormData(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
        active: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ClientDialogForm(
      title: 'Nuevo cliente',
      formKey: formKey,
      nameController: nameController,
      phoneController: phoneController,
      emailController: emailController,
      notesController: notesController,
      onSubmit: _submit,
      submitLabel: 'Guardar cliente',
    );
  }
}

class _EditClientDialog extends StatefulWidget {
  const _EditClientDialog({required this.client});

  final ClientSummary client;

  @override
  State<_EditClientDialog> createState() => _EditClientDialogState();
}

class _EditClientDialogState extends State<_EditClientDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController notesController;
  late bool active;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.client.name);
    phoneController = TextEditingController(text: widget.client.phone);
    emailController = TextEditingController(text: widget.client.email ?? '');
    notesController = TextEditingController(text: widget.client.notes ?? '');
    active = widget.client.active;
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _ClientFormData(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
        active: active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ClientDialogForm(
      title: 'Gestionar cliente',
      formKey: formKey,
      nameController: nameController,
      phoneController: phoneController,
      emailController: emailController,
      notesController: notesController,
      onSubmit: _submit,
      submitLabel: 'Guardar cambios',
      active: active,
      onActiveChanged: (value) => setState(() => active = value),
    );
  }
}

class _ClientDialogForm extends StatelessWidget {
  const _ClientDialogForm({
    required this.title,
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.notesController,
    required this.onSubmit,
    required this.submitLabel,
    this.active,
    this.onActiveChanged,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController notesController;
  final VoidCallback onSubmit;
  final String submitLabel;
  final bool? active;
  final ValueChanged<bool>? onActiveChanged;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 440,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el nombre del cliente'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Telefono',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el telefono del cliente'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email opcional',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas opcionales',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                if (active != null) ...[
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: active!,
                    onChanged: onActiveChanged,
                    title: Text(
                      active! ? 'Cliente activo' : 'Cliente inactivo',
                    ),
                    subtitle: Text(
                      active!
                          ? 'Puede seleccionarse para nuevos tickets.'
                          : 'Conserva su historial, pero no puede usarse en tickets nuevos.',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: onSubmit,
          icon: const Icon(Icons.save_outlined),
          label: Text(submitLabel),
        ),
      ],
    );
  }
}

class _ClientFormData {
  const _ClientFormData({
    required this.name,
    required this.phone,
    this.email,
    this.notes,
    required this.active,
  });

  final String name;
  final String phone;
  final String? email;
  final String? notes;
  final bool active;
}

class ClientRow extends StatelessWidget {
  const ClientRow({super.key, required this.client, required this.onEdit});

  final ClientSummary client;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: client.active ? 1 : 0.58,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.person_outline,
              size: 22,
              color: Color(0xFF7C3AED),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D1B69),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    client.phone,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  if (client.email != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      client.email!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                  if (!client.active) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Inactivo: no disponible para nuevos tickets',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Gestionar'),
            ),
          ],
        ),
      ),
    );
  }
}
