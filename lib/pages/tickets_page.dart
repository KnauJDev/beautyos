import 'package:flutter/material.dart';

import '../models/ticket_summary.dart';
import '../services/tickets_service.dart';
import '../widgets/app_widgets.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  final TicketsService ticketsService = const TicketsService();
  late Future<List<TicketSummary>> ticketsFuture;

  @override
  void initState() {
    super.initState();
    ticketsFuture = ticketsService.getTicketsSummary();
  }

  void _refreshTickets() {
    setState(() {
      ticketsFuture = ticketsService.getTicketsSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Tickets',
      subtitle:
          'Seguimiento de cada solicitud desde WhatsApp hasta finalizaci\u00f3n.',
      children: [
        const InfoPanel(
          icon: Icons.confirmation_number_outlined,
          title: 'Tickets conectados con Supabase',
          description:
              'Este m\u00f3dulo ahora consulta tickets resumidos mediante una funci\u00f3n segura, sin abrir directamente las tablas sensibles.',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _refreshTickets,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Actualizar tickets'),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<TicketSummary>>(
          future: ticketsFuture,
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
                      Text('Cargando tickets desde Supabase...'),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los tickets',
                description: snapshot.error.toString(),
              );
            }

            final tickets = snapshot.data ?? [];

            if (tickets.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin tickets disponibles',
                description:
                    'No hay tickets para mostrar en este momento.',
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
                    const SectionTitle('Tickets desde Supabase'),
                    const SizedBox(height: 14),
                    ...tickets.map((ticket) => TicketRow(ticket: ticket)),
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

class TicketRow extends StatelessWidget {
  final TicketSummary ticket;

  const TicketRow({super.key, required this.ticket});

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
          const Icon(
            Icons.receipt_long_outlined,
            size: 28,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.clientName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D1B69),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ticket.serviceNames,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Estilista: ${ticket.stylistNames}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Fecha: ${ticket.scheduledAtText} \u00b7 Canal: ${ticket.channel}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${ticket.formattedPrice} \u00b7 ${ticket.totalDurationMinutes} min',
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
          TicketStatusBadge(label: ticket.statusLabel),
        ],
      ),
    );
  }
}

class TicketStatusBadge extends StatelessWidget {
  final String label;

  const TicketStatusBadge({super.key, required this.label});

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


