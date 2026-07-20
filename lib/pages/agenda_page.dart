import 'package:flutter/material.dart';

import '../models/agenda_summary.dart';
import '../services/agenda_service.dart';
import '../widgets/app_widgets.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key, required this.branchId});

  final String? branchId;

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
              return const Card(
                elevation: 1,
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Cargando agenda desde Supabase...'),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudo cargar la agenda',
                description: snapshot.error.toString(),
              );
            }

            final appointments = snapshot.data ?? [];

            if (appointments.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin citas disponibles',
                description:
                    'No hay citas confirmadas o en proceso para mostrar en este momento.',
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
                    const SectionTitle('Citas desde Supabase'),
                    const SizedBox(height: 14),
                    ...appointments.map(
                      (appointment) =>
                          AgendaAppointmentCard(appointment: appointment),
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

class AgendaAppointmentCard extends StatelessWidget {
  final AgendaSummary appointment;

  const AgendaAppointmentCard({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    color: Color(0xFF2D1B69),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  appointment.serviceNames,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Estilista: ${appointment.stylistNames}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${appointment.formattedPrice} \u00b7 ${appointment.totalDurationMinutes} min',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF059669),
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
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            appointment.scheduledTimeText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6D28D9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            appointment.scheduledDateText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
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
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6D28D9),
        ),
      ),
    );
  }
}
