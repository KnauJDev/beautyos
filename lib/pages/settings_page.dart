import 'package:flutter/material.dart';

import '../models/business_hour.dart';
import '../models/business_settings.dart';
import '../services/business_hours_service.dart';
import '../services/business_settings_service.dart';
import '../widgets/app_widgets.dart';

class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({super.key});

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  final BusinessSettingsService businessSettingsService =
      const BusinessSettingsService();

  final BusinessHoursService businessHoursService =
      const BusinessHoursService();

  late final Future<BusinessSettings> businessSettingsFuture;
  late final Future<List<BusinessHour>> businessHoursFuture;

  @override
  void initState() {
    super.initState();
    businessSettingsFuture = businessSettingsService.getBusinessSettings();
    businessHoursFuture = businessHoursService.getBusinessHours();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Configuración',
      subtitle: 'Reglas generales del centro de estética.',
      children: [
        const InfoPanel(
          icon: Icons.settings_outlined,
          title: 'Módulo base de Configuración',
          description:
              'Aquí configuraremos datos del negocio, horarios, políticas de agenda, anticipos, comisiones y reglas futuras de WhatsApp e IA.',
        ),
        const SizedBox(height: 16),
        const SectionTitle('Datos del negocio'),
        FutureBuilder<BusinessSettings>(
          future: businessSettingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los datos',
                description:
                    'Revisa la conexión con Supabase o la función get_business_settings.',
              );
            }

            if (!snapshot.hasData) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin datos del negocio',
                description:
                    'Todavía no hay información activa para mostrar en Configuración.',
              );
            }

            return BusinessSettingsCard(settings: snapshot.data!);
          },
        ),
        const SizedBox(height: 16),
        const SectionTitle('Horarios de atención'),
        FutureBuilder<List<BusinessHour>>(
          future: businessHoursFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los horarios',
                description:
                    'Revisa la conexión con Supabase o la función get_business_hours.',
              );
            }

            final hours = snapshot.data ?? [];

            if (hours.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin horarios registrados',
                description:
                    'Todavía no hay horarios activos para mostrar en Configuración.',
              );
            }

            return BusinessHoursCard(hours: hours);
          },
        ),
        const SizedBox(height: 16),
        const SectionTitle('Próximas configuraciones'),
        const DemoListCard(
          title: 'Políticas de agenda',
          lines: [
            'Anticipos',
            'Cancelaciones',
            'Reagendamientos y confirmaciones',
          ],
        ),
        const DemoListCard(
          title: 'Comisiones',
          lines: [
            'Reglas de pago para estilistas',
            'Por servicio o porcentaje',
            'Base futura para nómina/comisiones',
          ],
        ),
      ],
    );
  }
}

class BusinessSettingsCard extends StatelessWidget {
  final BusinessSettings settings;

  const BusinessSettingsCard({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settings.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _SettingsLine(label: 'Tipo de negocio', value: settings.businessType),
            _SettingsLine(label: 'Correo', value: settings.contactEmail),
            _SettingsLine(label: 'Teléfono', value: settings.contactPhone),
            _SettingsLine(label: 'WhatsApp', value: settings.whatsapp),
            _SettingsLine(label: 'Instagram', value: settings.instagram),
            _SettingsLine(label: 'Facebook', value: settings.facebook),
          ],
        ),
      ),
    );
  }
}

class BusinessHoursCard extends StatelessWidget {
  final List<BusinessHour> hours;

  const BusinessHoursCard({
    super.key,
    required this.hours,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final hour in hours) _BusinessHourRow(hour: hour),
          ],
        ),
      ),
    );
  }
}

class _BusinessHourRow extends StatelessWidget {
  final BusinessHour hour;

  const _BusinessHourRow({
    required this.hour,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              hour.dayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(hour.scheduleText),
          ),
        ],
      ),
    );
  }
}

class _SettingsLine extends StatelessWidget {
  final String label;
  final String value;

  const _SettingsLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
