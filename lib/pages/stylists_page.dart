import 'package:flutter/material.dart';

import '../models/stylist_summary.dart';
import '../services/stylists_service.dart';
import '../widgets/app_widgets.dart';

class EstilistasPage extends StatefulWidget {
  const EstilistasPage({super.key});

  @override
  State<EstilistasPage> createState() => _EstilistasPageState();
}

class _EstilistasPageState extends State<EstilistasPage> {
  final StylistsService stylistsService = const StylistsService();
  late final Future<List<StylistSummary>> stylistsFuture;

  @override
  void initState() {
    super.initState();
    stylistsFuture = stylistsService.getStylistsSummary();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Estilistas',
      subtitle: 'Equipo de trabajo, especialidades y contacto.',
      children: [
        const InfoPanel(
          icon: Icons.badge_outlined,
          title: 'Estilistas conectados con Supabase',
          description:
              'Este m\u00f3dulo consulta estilistas activos mediante una funci\u00f3n segura, sin abrir directamente toda la tabla stylists.',
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<StylistSummary>>(
          future: stylistsFuture,
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
                      Text('Cargando estilistas desde Supabase...'),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los estilistas',
                description: snapshot.error.toString(),
              );
            }

            final stylists = snapshot.data ?? [];

            if (stylists.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin estilistas disponibles',
                description:
                    'No hay estilistas activos para mostrar en este momento.',
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
                    const SectionTitle('Estilistas desde Supabase'),
                    const SizedBox(height: 14),
                    ...stylists.map(
                      (stylist) => StylistCard(stylist: stylist),
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

class StylistCard extends StatelessWidget {
  final StylistSummary stylist;

  const StylistCard({super.key, required this.stylist});

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
            Icons.face_retouching_natural_outlined,
            size: 30,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stylist.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D1B69),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  stylist.specialty,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  stylist.phone,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Registrado: ${stylist.createdDateText}',
                  style: const TextStyle(
                    fontSize: 13,
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
