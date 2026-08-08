import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import '../models/platform_tenant_detail.dart';
import '../services/platform_tenant_detail_service.dart';

/// Vista de solo lectura para el dueno de plataforma: clientes, tickets,
/// finanzas, equipo, resenas y fotos de CUALQUIER negocio, para dar
/// soporte o resolver problemas. Nunca permite editar ni borrar nada.
class PlatformTenantDetailPage extends StatefulWidget {
  const PlatformTenantDetailPage({
    super.key,
    required this.tenantId,
    required this.tenantName,
  });

  final String tenantId;
  final String tenantName;

  @override
  State<PlatformTenantDetailPage> createState() =>
      _PlatformTenantDetailPageState();
}

class _PlatformTenantDetailPageState extends State<PlatformTenantDetailPage>
    with SingleTickerProviderStateMixin {
  final _service = const PlatformTenantDetailService();
  late final TabController _tabController;

  late Future<List<PlatformClientSummary>> _clientsFuture;
  late Future<List<PlatformTicketSummary>> _ticketsFuture;
  late Future<List<PlatformBranchFinancialSummary>> _financialFuture;
  late Future<List<PlatformTeamMember>> _teamFuture;
  late Future<List<PlatformReviewSummary>> _reviewsFuture;
  late Future<List<PlatformWorkPhotoSummary>> _photosFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAll();
  }

  void _loadAll() {
    _clientsFuture = _service.getClients(widget.tenantId);
    _ticketsFuture = _service.getTickets(widget.tenantId);
    _financialFuture = _service.getFinancialSummary(widget.tenantId);
    _teamFuture = _service.getTeam(widget.tenantId);
    _reviewsFuture = _service.getReviews(widget.tenantId);
    _photosFuture = _service.getWorkPhotos(widget.tenantId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandSurface,
      appBar: AppBar(
        title: Text(
          widget.tenantName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.brandDeep,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => setState(_loadAll),
            icon: const Icon(Icons.refresh_outlined),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Clientes'),
            Tab(text: 'Tickets'),
            Tab(text: 'Finanzas'),
            Tab(text: 'Equipo'),
            Tab(text: 'Reseñas'),
            Tab(text: 'Fotos'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.brandTint,
            padding: const EdgeInsets.all(10),
            child: Text(
              'Solo lectura -- soporte de plataforma. No puedes editar ni '
              'borrar nada desde aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.brandDark,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ClientsTab(future: _clientsFuture),
                _TicketsTab(future: _ticketsFuture),
                _FinancialTab(future: _financialFuture),
                _TeamTab(future: _teamFuture),
                _ReviewsTab(future: _reviewsFuture),
                _PhotosTab(future: _photosFuture),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrError<T> extends StatelessWidget {
  const _EmptyOrError({
    required this.snapshot,
    required this.emptyMessage,
    required this.builder,
  });

  final AsyncSnapshot<List<T>> snapshot;
  final String emptyMessage;
  final Widget Function(BuildContext context, List<T> items) builder;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No se pudo cargar: ${snapshot.error}'),
        ),
      );
    }

    final items = snapshot.data ?? const [];

    if (items.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    return builder(context, items);
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} $hour:$minute';
}

String _formatMoney(double value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    final positionFromEnd = rounded.length - i;
    buffer.write(rounded[i]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }
  return '\$$buffer';
}

class _ClientsTab extends StatelessWidget {
  const _ClientsTab({required this.future});

  final Future<List<PlatformClientSummary>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PlatformClientSummary>>(
      future: future,
      builder: (context, snapshot) => _EmptyOrError(
        snapshot: snapshot,
        emptyMessage: 'Este negocio no tiene clientes todavía.',
        builder: (context, items) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final client = items[index];
            return ListTile(
              title: Text(client.name),
              subtitle: Text(
                '${client.phone ?? "Sin teléfono"} · ${client.email ?? "Sin correo"}',
              ),
              trailing: Text(client.active ? 'Activo' : 'Inactivo'),
            );
          },
        ),
      ),
    );
  }
}

class _TicketsTab extends StatelessWidget {
  const _TicketsTab({required this.future});

  final Future<List<PlatformTicketSummary>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PlatformTicketSummary>>(
      future: future,
      builder: (context, snapshot) => _EmptyOrError(
        snapshot: snapshot,
        emptyMessage: 'Este negocio no tiene tickets todavía.',
        builder: (context, items) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final ticket = items[index];
            return ListTile(
              title: Text('${ticket.clientName} · ${ticket.branchName}'),
              subtitle: Text(
                '${_formatDate(ticket.scheduledAt)} · ${ticket.serviceNames} · ${ticket.stylistNames}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(ticket.status),
                  Text(_formatMoney(ticket.totalPrice)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FinancialTab extends StatelessWidget {
  const _FinancialTab({required this.future});

  final Future<List<PlatformBranchFinancialSummary>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PlatformBranchFinancialSummary>>(
      future: future,
      builder: (context, snapshot) => _EmptyOrError(
        snapshot: snapshot,
        emptyMessage: 'Este negocio no tiene sedes todavía.',
        builder: (context, items) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final branch = items[index];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch.branchName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text('Ventas: ${_formatMoney(branch.totalSales)}'),
                    Text('Compras: ${_formatMoney(branch.totalPurchases)}'),
                    Text('Gastos: ${_formatMoney(branch.totalExpenses)}'),
                    Text(
                      'Comisiones: ${_formatMoney(branch.totalCommissions)}',
                    ),
                    const Divider(),
                    Text(
                      'Resultado neto: ${_formatMoney(branch.netResult)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TeamTab extends StatelessWidget {
  const _TeamTab({required this.future});

  final Future<List<PlatformTeamMember>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PlatformTeamMember>>(
      future: future,
      builder: (context, snapshot) => _EmptyOrError(
        snapshot: snapshot,
        emptyMessage: 'Este negocio no tiene equipo registrado todavía.',
        builder: (context, items) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final member = items[index];
            return ListTile(
              title: Text(member.fullName),
              subtitle: Text(
                '${member.email} · ${member.role}'
                '${member.stylistName != null ? " · ${member.stylistName}" : ""}',
              ),
              trailing: Text(member.active ? 'Activo' : 'Inactivo'),
            );
          },
        ),
      ),
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.future});

  final Future<List<PlatformReviewSummary>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PlatformReviewSummary>>(
      future: future,
      builder: (context, snapshot) => _EmptyOrError(
        snapshot: snapshot,
        emptyMessage: 'Este negocio no tiene reseñas todavía.',
        builder: (context, items) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final review = items[index];
            return ListTile(
              title: Text(
                '${'★' * review.rating}${'☆' * (5 - review.rating)} · ${review.clientName}',
              ),
              subtitle: Text(
                '${review.branchName} · ${review.stylistName} · ${review.serviceName}\n'
                '${review.comment ?? "Sin comentario"}',
              ),
              isThreeLine: true,
              trailing: Text(review.moderationStatus),
            );
          },
        ),
      ),
    );
  }
}

class _PhotosTab extends StatelessWidget {
  const _PhotosTab({required this.future});

  final Future<List<PlatformWorkPhotoSummary>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PlatformWorkPhotoSummary>>(
      future: future,
      builder: (context, snapshot) => _EmptyOrError(
        snapshot: snapshot,
        emptyMessage: 'Este negocio no tiene fotos de trabajo todavía.',
        builder: (context, items) => GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final photo = items[index];
            return Card(
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Image.network(photo.photoUrl, fit: BoxFit.cover),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '${photo.branchName} · ${photo.stylistName}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
