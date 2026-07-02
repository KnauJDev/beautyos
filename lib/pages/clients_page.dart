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
  late final Future<List<ClientSummary>> clientsFuture;

  @override
  void initState() {
    super.initState();
    clientsFuture = clientsService.getClientsSummary();
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
              'Este m\u00f3dulo ahora consulta clientes activos mediante una funci\u00f3n segura, sin abrir directamente toda la tabla clients.',
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
                description:
                    'No hay clientes activos para mostrar en este momento.',
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
                    const SectionTitle('Clientes desde Supabase'),
                    const SizedBox(height: 14),
                    ...clients.map((client) => ClientRow(client: client)),
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

class ClientRow extends StatelessWidget {
  final ClientSummary client;

  const ClientRow({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
