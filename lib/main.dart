import 'package:flutter/material.dart';

void main() {
  runApp(const BeautyOSApp());
}

class BeautyOSApp extends StatelessWidget {
  const BeautyOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeautyOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C3AED)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        title: const Text(
          'BeautyOS',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.spa, size: 90, color: Color(0xFF7C3AED)),
                const SizedBox(height: 24),
                const Text(
                  'BeautyOS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D1B69),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sistema de gestión para centros de estética',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, color: Color(0xFF4B5563)),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Organiza citas, servicios, estilistas, clientes y tickets desde una sola plataforma.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.5,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: const [
                    FeatureCard(
                      icon: Icons.calendar_month,
                      title: 'Agenda',
                      description:
                          'Control de citas por día, cliente y estilista.',
                    ),
                    FeatureCard(
                      icon: Icons.content_cut,
                      title: 'Servicios',
                      description: 'Catálogo de servicios, precios y duración.',
                    ),
                    FeatureCard(
                      icon: Icons.people,
                      title: 'Clientes',
                      description:
                          'Historial, contacto y preferencias del cliente.',
                    ),
                    FeatureCard(
                      icon: Icons.confirmation_number,
                      title: 'Tickets',
                      description:
                          'Seguimiento desde solicitud hasta finalización.',
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.rocket_launch),
                  label: Text('MVP en construcción'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        elevation: 2,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(icon, size: 38, color: const Color(0xFF7C3AED)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D1B69),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
