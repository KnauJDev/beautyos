import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import '../models/agenda_summary.dart';
import '../services/agenda_service.dart';
import '../widgets/app_widgets.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late final AgendaService agendaService;
  late Future<List<AgendaSummary>> agendaFuture;

  @override
  void initState() {
    super.initState();
    agendaService = AgendaService(branchId: widget.branchId);
    agendaFuture = agendaService.getAgendaSummary();
  }

  void _refreshAgenda() {
    setState(() {
      agendaFuture = agendaService.getAgendaSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Agenda',
      subtitle: 'Aqu\u00ed veremos las citas por fecha, cliente y estilista.',
      children: [
        const InfoPanel(
          icon: Icons.calendar_month_outlined,
          title: 'Agenda conectada con Supabase',
          description:
              'Este m\u00f3dulo ahora consulta citas reales desde tickets confirmados o en proceso mediante una funci\u00f3n segura.',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _refreshAgenda,
          icon: const Icon(Icons.refresh_outlined),
          label: const Text('Actualizar agenda'),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<AgendaSummary>>(
          future: agendaFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingCard(mensaje: 'Cargando la agenda...');
            }

            // Ahora un fallo se distingue de "todavia no hay nada" (D-107):
            // antes los dos se pintaban con el mismo panel gris y no habia
            // forma de saber si algo se rompio o si el dia esta vacio.
            if (snapshot.hasError) {
              return ErrorState(
                titulo: 'No se pudo cargar la agenda',
                detalle: snapshot.error.toString(),
                onReintentar: _refreshAgenda,
              );
            }

            final appointments = snapshot.data ?? [];

            if (appointments.isEmpty) {
              return const EmptyState(
                icon: Icons.event_available_outlined,
                titulo: 'Sin citas por ahora',
                descripcion:
                    'No hay citas confirmadas ni en proceso para mostrar.',
              );
            }

            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Citas desde Supabase'),
                  const SizedBox(height: AppSpacing.md),
                  ...appointments.map(
                    (appointment) =>
                        AgendaAppointmentCard(appointment: appointment),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class AgendaAppointmentCard extends StatelessWidget {
  final AgendaSummary appointment;

  const AgendaAppointmentCard({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgendaTimeBox(appointment: appointment),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.clientName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDeep,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  appointment.serviceNames,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Estilista: ${appointment.stylistNames}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${appointment.formattedPrice} \u00b7 ${appointment.totalDurationMinutes} min',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AgendaStatusBadge(label: appointment.statusLabel),
        ],
      ),
    );
  }
}

class AgendaTimeBox extends StatelessWidget {
  final AgendaSummary appointment;

  const AgendaTimeBox({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            appointment.scheduledTimeText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.brandDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            appointment.scheduledDateText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class AgendaStatusBadge extends StatelessWidget {
  final String label;

  const AgendaStatusBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.brandDark,
        ),
      ),
    );
  }
}
