import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

export 'app_states.dart';
export 'ticket_status.dart';

class AppPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  /// D-318 (07-oct): las pantallas del salón van **sin título ni
  /// explicación**, en todos los salones. El menú ya dice dónde se está, y en
  /// el celular ocupaban media pantalla antes de lo útil. Lo decidió el
  /// propietario al verlo en la Agenda: *"si estorba acá, estorba en todos"*.
  /// [title] y [subtitle] se quedan como nombre de la pantalla en el código.
  ///
  /// Las de la estilista lo conservan (`true`) hasta que él decida, con la
  /// entrega 3 de los cinco lugares.
  final bool conEncabezado;

  const AppPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.conEncabezado = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (conEncabezado) ...[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDeep,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 17, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
              ],
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String description;

  const MetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
  });

  /// Por debajo de este ancho disponible (un celular), dos por fila.
  static const anchoAngosto = 560.0;

  /// El espacio entre tarjetas en todas las filas que las usan.
  static const separacion = 16.0;

  @override
  Widget build(BuildContext context) {
    // D-318 (07-oct): en el celular cabía una sola de 240 por fila, a dos
    // tercios del ancho, y había que bajar mucho para pasar los números. Lo
    // vio el propietario en Fotos y Reseñas. Ahora, en lo angosto, dos por
    // fila y más compactas; en el computador, igual que siempre.
    return LayoutBuilder(
      builder: (context, c) {
        final angosto = c.maxWidth < anchoAngosto;
        return SizedBox(
          width: angosto ? ((c.maxWidth - separacion) / 2).floorToDouble() : 240,
          child: Card(
            elevation: 2,
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(angosto ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: angosto ? 24 : 34, color: AppColors.brand),
                  SizedBox(height: angosto ? 8 : 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: angosto ? 13 : 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: angosto ? 4 : 8),
                  // Una cifra larga ("$1.280.000") se achica en vez de
                  // partirse en dos renglones.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: angosto ? 24 : 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandDeep,
                      ),
                    ),
                  ),
                  SizedBox(height: angosto ? 4 : 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: angosto ? 12 : 13,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.brandDeep,
      ),
    );
  }
}

class InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const InfoPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 34, color: AppColors.brand),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDeep,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.textStrong,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DemoListCard extends StatelessWidget {
  final String title;
  final List<String> lines;

  const DemoListCard({super.key, required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(title),
            const SizedBox(height: 14),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
