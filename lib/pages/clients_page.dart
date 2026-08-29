import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../models/client_summary.dart';
import '../services/clients_service.dart';
import '../widgets/app_widgets.dart';
import 'agenda_page.dart' show buildWhatsAppUri;

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final ClientsService clientsService = const ClientsService();
  late Future<List<ClientSummary>> clientsFuture;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSegmentFilter = 'todos'; // 'todos', 'vip', 'en_riesgo', 'recurrente', 'nuevo', 'con_saldo', 'inactivos'

  @override
  void initState() {
    super.initState();
    clientsFuture = clientsService.getClientsManagementSummary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshClients() {
    setState(() {
      clientsFuture = clientsService.getClientsManagementSummary();
    });
  }

  List<ClientSummary> _filterClients(List<ClientSummary> allClients) {
    return allClients.where((client) {
      // 1. Buscador por texto
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final name = client.name.toLowerCase();
        final phone = client.phone.replaceAll(RegExp(r'[^0-9]'), '');
        final queryPhone = query.replaceAll(RegExp(r'[^0-9]'), '');
        final email = (client.email ?? '').toLowerCase();

        final matches = name.contains(query) ||
            (queryPhone.isNotEmpty && phone.contains(queryPhone)) ||
            email.contains(query);

        if (!matches) return false;
      }

      // 2. Filtro por segmento
      if (_selectedSegmentFilter != 'todos') {
        switch (_selectedSegmentFilter) {
          case 'vip':
            if (client.segment != 'vip' || !client.active) return false;
            break;
          case 'en_riesgo':
            if (client.segment != 'en_riesgo' || !client.active) return false;
            break;
          case 'recurrente':
            if (client.segment != 'recurrente' || !client.active) return false;
            break;
          case 'nuevo':
            if (client.segment != 'nuevo' || !client.active) return false;
            break;
          case 'con_saldo':
            if (!client.hasPendingBalance) return false;
            break;
          case 'inactivos':
            if (client.active) return false;
            break;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _openCreateClientDialog() async {
    final formData = await showDialog<_ClientFormData>(
      context: context,
      builder: (context) => const _CreateClientDialog(),
    );

    if (formData == null) return;

    try {
      final createdClient = await clientsService.createClient(
        name: formData.name,
        phone: formData.phone,
        email: formData.email,
        notes: formData.notes,
      );

      if (!mounted) return;

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
      if (!mounted) return;
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

    if (formData == null) return;

    try {
      final updatedClient = await clientsService.updateClient(
        clientId: client.id,
        name: formData.name,
        phone: formData.phone,
        email: formData.email,
        notes: formData.notes,
        active: formData.active,
      );

      if (!mounted) return;

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error actualizando cliente: $error')),
      );
    }
  }

  Future<void> _openClientDetailSheet(ClientSummary client) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClientDetailSheet(
        client: client,
        onEdit: () {
          Navigator.of(context).pop();
          _openEditClientDialog(client);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Clientes',
      subtitle: 'Fidelización, historial de valor, frecuencia de visitas y contacto.',
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _openCreateClientDialog,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Nuevo cliente'),
            ),
            OutlinedButton.icon(
              onPressed: _refreshClients,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Actualizar'),
            ),
          ],
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

            final allClients = snapshot.data ?? [];
            final filteredClients = _filterClients(allClients);

            // Contadores por segmento para los chips
            final vipCount = allClients.where((c) => c.segment == 'vip' && c.active).length;
            final inRiskCount = allClients.where((c) => c.segment == 'en_riesgo' && c.active).length;
            final recurrentCount = allClients.where((c) => c.segment == 'recurrente' && c.active).length;
            final newCount = allClients.where((c) => c.segment == 'nuevo' && c.active).length;
            final withBalanceCount = allClients.where((c) => c.hasPendingBalance).length;
            final inactiveCount = allClients.where((c) => !c.active).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Panel de Búsqueda y Filtros Rápidos (Nivel 2)
                Card(
                  elevation: 1,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Buscador universal
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre, teléfono o email...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // 2. Chips de Segmentación Inteligente
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildSegmentChip('todos', 'Todos (${allClients.length})', null),
                              const SizedBox(width: 8),
                              _buildSegmentChip('vip', '⭐ VIP ($vipCount)', AppColors.brand),
                              const SizedBox(width: 8),
                              _buildSegmentChip('en_riesgo', '⚠️ En riesgo ($inRiskCount)', AppColors.stateToCollect),
                              const SizedBox(width: 8),
                              _buildSegmentChip('recurrente', '🟢 Recurrentes ($recurrentCount)', AppColors.stateConfirmed),
                              const SizedBox(width: 8),
                              _buildSegmentChip('nuevo', '🆕 Nuevos ($newCount)', AppColors.stateInProgress),
                              if (withBalanceCount > 0) ...[
                                const SizedBox(width: 8),
                                _buildSegmentChip('con_saldo', '🔴 Con saldo ($withBalanceCount)', AppColors.danger),
                              ],
                              if (inactiveCount > 0) ...[
                                const SizedBox(width: 8),
                                _buildSegmentChip('inactivos', 'Inactivos ($inactiveCount)', AppColors.textSecondary),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Lista de Clientes (Nivel 2)
                if (filteredClients.isEmpty)
                  Card(
                    elevation: 1,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.person_search_outlined,
                              size: 48,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No se encontraron clientes con los filtros actuales.',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _selectedSegmentFilter = 'todos';
                                });
                              },
                              icon: const Icon(Icons.clear_all),
                              label: const Text('Limpiar filtros'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Card(
                    elevation: 1,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Clientes (${filteredClients.length})',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brandDeep,
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Toca un cliente para ver su ficha de valor',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...filteredClients.map(
                            (client) => ClientRow(
                              client: client,
                              onTap: () => _openClientDetailSheet(client),
                              onEdit: () => _openEditClientDialog(client),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSegmentChip(String value, String label, Color? color) {
    final isSelected = _selectedSegmentFilter == value;
    return ChoiceChip(
      avatar: color != null
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          : null,
      label: Text(label),
      selected: isSelected,
      selectedColor: color?.withValues(alpha: 0.18) ?? AppColors.brandTint,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedSegmentFilter = value;
          });
        }
      },
    );
  }
}

class ClientRow extends StatelessWidget {
  const ClientRow({
    super.key,
    required this.client,
    this.onTap,
    required this.onEdit,
  });

  final ClientSummary client;
  final VoidCallback? onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final (badgeBg, badgeFg) = client.segmentColors;

    // Iniciales para el avatar
    final initials = client.name.trim().isNotEmpty
        ? client.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
            .join()
        : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: client.active ? AppColors.surfaceAlt : AppColors.surfaceAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: client.hasPendingBalance ? AppColors.stateToCollect.withValues(alpha: 0.4) : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar con iniciales
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.brandTint,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDeep,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Datos principales
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              client.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: client.active ? AppColors.brandDeep : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (client.active)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                client.segmentLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: badgeFg,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Teléfono y WhatsApp
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            client.phone,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (client.email != null && client.email!.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            const Text('·', style: TextStyle(color: AppColors.textMuted)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                client.email!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Botón de WhatsApp directo
                if (client.phone.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.whatsapp,
                      size: 20,
                    ),
                    tooltip: 'WhatsApp a ${client.firstName}',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final greeting = client.segment == 'en_riesgo'
                          ? 'Hola ${client.firstName}, ¡te extrañamos en el salón! Queríamos saludarte y saber cómo estás.'
                          : (client.hasPendingBalance
                              ? 'Hola ${client.firstName}, te escribimos para recordarte tu saldo pendiente de ${client.formattedBalanceAmount}.'
                              : 'Hola ${client.firstName}, te escribimos de Salón y Más.');
                      launchUrl(
                        buildWhatsAppUri(client.phone, text: greeting),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Métricas RFM (Visitas, Gasto total, Cadencia, Última visita, Saldo)
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Visitas
                _buildMetricItem(
                  Icons.event_repeat_outlined,
                  '${client.totalVisits} ${client.totalVisits == 1 ? "visita" : "visitas"}',
                ),
                // Gasto Total
                if (client.totalSpent > 0)
                  _buildMetricItem(
                    Icons.payments_outlined,
                    'Gasto: ${client.formattedTotalSpent}',
                    isBold: true,
                    color: AppColors.success,
                  ),
                // Cadencia promedio
                _buildMetricItem(
                  Icons.timelapse_outlined,
                  client.cadenceText,
                ),
                // Última visita
                _buildMetricItem(
                  Icons.history_outlined,
                  'Última: ${client.lastVisitText}',
                  color: client.segment == 'en_riesgo' ? AppColors.stateToCollect : AppColors.textSecondary,
                ),
                // Saldo pendiente
                if (client.hasPendingBalance)
                  _buildMetricItem(
                    Icons.error_outline,
                    'Debe: ${client.formattedBalanceAmount}',
                    isBold: true,
                    color: AppColors.stateToCollect,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(IconData icon, String text, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ClientDetailSheet extends StatelessWidget {
  const _ClientDetailSheet({
    required this.client,
    required this.onEdit,
  });

  final ClientSummary client;
  final VoidCallback onEdit;

  Future<void> _openResetPortalPinDialog(BuildContext context) async {
    final newPin = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPortalPinDialog(clientName: client.name),
    );

    if (newPin == null || !context.mounted) return;

    try {
      await const ClientsService().resetPortalPin(
        clientId: client.id,
        newPin: newPin,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PIN del portal actualizado. Nuevo PIN de ${client.name}: $newPin',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      final message = error is PostgrestException
          ? error.message
          : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo restablecer el PIN: $message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 700;
    final (badgeBg, badgeFg) = client.segmentColors;

    final initials = client.name.trim().isNotEmpty
        ? client.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
            .join()
        : '?';

    return Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.90,
        maxWidth: isDesktop ? 600 : double.infinity,
      ),
      margin: isDesktop ? const EdgeInsets.symmetric(vertical: 24) : null,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: isDesktop
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.brandTint,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDeep,
                    ),
                  ),
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
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              client.segmentLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: badgeFg,
                              ),
                            ),
                          ),
                          if (!client.active) ...[
                            const SizedBox(width: 6),
                            const Text(
                              '(Inactivo)',
                              style: TextStyle(fontSize: 12, color: AppColors.danger),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Datos de Contacto y WhatsApp
                  _buildSectionCard(
                    title: 'Contacto y Comunicación',
                    icon: Icons.contact_phone_outlined,
                    child: Column(
                      children: [
                        _buildDetailRow('Teléfono:', client.phone),
                        if (client.email != null && client.email!.isNotEmpty)
                          _buildDetailRow('Email:', client.email!),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (client.phone.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () {
                                  launchUrl(
                                    buildWhatsAppUri(client.phone),
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 16,
                                  color: AppColors.whatsapp,
                                ),
                                label: const Text(
                                  'WhatsApp',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.whatsapp),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            if (client.phone.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () {
                                  launchUrl(Uri.parse('tel:${client.phone}'));
                                },
                                icon: const Icon(Icons.phone_outlined, size: 16),
                                label: const Text('Llamar'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Tarjetas de Métricas Financieras y Retorno (RFM)
                  _buildSectionCard(
                    title: 'Análisis de Retorno y Valor (RFM)',
                    icon: Icons.insights_outlined,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiBox(
                                label: 'Gasto Histórico',
                                value: client.formattedTotalSpent,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildKpiBox(
                                label: 'Ticket Promedio',
                                value: client.formattedAverageTicket,
                                color: AppColors.brand,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiBox(
                                label: 'Total Visitas',
                                value: '${client.totalVisits}',
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildKpiBox(
                                label: 'Frecuencia Promedio',
                                value: client.cadenceText,
                                color: AppColors.stateConfirmed,
                              ),
                            ),
                          ],
                        ),
                        if (client.hasPendingBalance) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.stateToCollectTint,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.stateToCollect),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: AppColors.stateToCollect, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Saldo en mora:',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.stateToCollect),
                                ),
                                const Spacer(),
                                Text(
                                  client.formattedBalanceAmount,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.stateToCollect),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Frecuencia y Antigüedad
                  _buildSectionCard(
                    title: 'Frecuencia y Tiempos',
                    icon: Icons.access_time_outlined,
                    child: Column(
                      children: [
                        _buildDetailRow('Última visita:', client.lastVisitText),
                        if (client.firstVisitAt != null)
                          _buildDetailRow(
                            'Primera visita:',
                            '${client.firstVisitAt!.day}/${client.firstVisitAt!.month}/${client.firstVisitAt!.year}',
                          ),
                        if (client.createdAt != null)
                          _buildDetailRow(
                            'Registrado desde:',
                            '${client.createdAt!.day}/${client.createdAt!.month}/${client.createdAt!.year}',
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Notas y Preferencias
                  _buildSectionCard(
                    title: 'Notas y Preferencias',
                    icon: Icons.notes_outlined,
                    child: Text(
                      (client.notes != null && client.notes!.trim().isNotEmpty)
                          ? client.notes!
                          : 'Sin notas ni preferencias registradas.',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: (client.notes == null || client.notes!.trim().isEmpty) ? FontStyle.italic : FontStyle.normal,
                        color: (client.notes == null || client.notes!.trim().isEmpty) ? AppColors.textMuted : AppColors.textPrimary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. Botonera de Acciones
                  const Text(
                    'Acciones',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Gestionar / Editar'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openResetPortalPinDialog(context),
                        icon: const Icon(Icons.lock_reset_outlined, size: 16),
                        label: const Text('Restablecer PIN del portal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.brand),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pide el nuevo PIN de 4 dígitos del portal de una clienta (D-167). Sirve
/// tanto para asignarlo la primera vez como para restablecerlo -- el salón
/// es el único que puede hacer cualquiera de las dos cosas (ver la decisión
/// de seguridad en la migración de D-167: el portal nunca deja que alguien
/// se autoasigne un PIN).
class _ResetPortalPinDialog extends StatefulWidget {
  const _ResetPortalPinDialog({required this.clientName});

  final String clientName;

  @override
  State<_ResetPortalPinDialog> createState() => _ResetPortalPinDialogState();
}

class _ResetPortalPinDialogState extends State<_ResetPortalPinDialog> {
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  bool get _esValido => RegExp(r'^[0-9]{4}$').hasMatch(_pinController.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('PIN del portal de ${widget.clientName}'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este PIN reemplaza cualquiera que tuviera antes y cierra su '
              'sesión actual del portal, si tenía una abierta.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'PIN nuevo (4 dígitos)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _esValido
              ? () => Navigator.of(context).pop(_pinController.text)
              : null,
          child: const Text('Guardar PIN'),
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
    if (!formKey.currentState!.validate()) return;

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
    if (!formKey.currentState!.validate()) return;

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
                    labelText: 'Nombre comercial',
                    prefixIcon: Icon(Icons.person_outline),
                    hintText: 'Ej. Camila Restrepo, Dra. Patricia',
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
                    labelText: 'Teléfono / WhatsApp',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el teléfono del cliente'
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
                    labelText: 'Notas y preferencias opcionales',
                    prefixIcon: Icon(Icons.notes_outlined),
                    hintText: 'Alergias a tintes, bebidas favoritas, etc.',
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
                          ? 'Puede seleccionarse para nuevas citas.'
                          : 'Conserva su historial, pero no aparece en citas nuevas.',
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
