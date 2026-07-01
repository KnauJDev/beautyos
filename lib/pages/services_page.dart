import 'package:flutter/material.dart';

import '../models/beauty_service.dart';
import '../services/services_service.dart';
import '../widgets/app_widgets.dart';

class ServiciosPage extends StatefulWidget {
  const ServiciosPage({super.key});

  @override
  State<ServiciosPage> createState() => _ServiciosPageState();
}

class _ServiciosPageState extends State<ServiciosPage> {
  final ServicesService servicesService = const ServicesService();
  late final Future<List<BeautyService>> servicesFuture;

  @override
  void initState() {
    super.initState();
    servicesFuture = servicesService.getActiveVisibleServices();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Servicios',
      subtitle: 'Cat\u00e1logo de servicios le\u00eddo desde Supabase.',
      children: [
        const InfoPanel(
          icon: Icons.cloud_done_outlined,
          title: 'Conexi\u00f3n activa con Supabase',
          description:
              'Este m\u00f3dulo ya consulta la tabla services y muestra los servicios activos y visibles para el cliente.',
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<BeautyService>>(
          future: servicesFuture,
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
                      Text('Cargando servicios desde Supabase...'),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los servicios',
                description: snapshot.error.toString(),
              );
            }

            final services = snapshot.data ?? [];

            if (services.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin servicios disponibles',
                description:
                    'No hay servicios activos y visibles para mostrar en este momento.',
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
                    const SectionTitle('Servicios desde Supabase'),
                    const SizedBox(height: 14),
                    ...services.map((service) => ServiceRow(service: service)),
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

class ServiceRow extends StatelessWidget {
  final BeautyService service;

  const ServiceRow({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 22,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D1B69),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${service.category} \u00b7 ${service.durationMinutes} min \u00b7 ${service.formattedPrice}',
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
