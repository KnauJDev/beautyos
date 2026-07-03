import 'package:flutter/material.dart';

import '../widgets/app_widgets.dart';

class ConfiguracionPage extends StatelessWidget {
  const ConfiguracionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'Configuración',
      subtitle: 'Reglas generales del centro de estética.',
      children: [
        InfoPanel(
          icon: Icons.settings_outlined,
          title: 'Módulo base de Configuración',
          description:
              'Aquí configuraremos datos del negocio, horarios, políticas de agenda, anticipos, comisiones y reglas futuras de WhatsApp e IA.',
        ),
        SizedBox(height: 16),
        SectionTitle('Próximas configuraciones'),
        DemoListCard(
          title: 'Datos del negocio',
          lines: [
            'Nombre comercial',
            'Tipo de negocio',
            'Teléfono y dirección',
          ],
        ),
        DemoListCard(
          title: 'Horarios de atención',
          lines: [
            'Días laborales',
            'Hora de apertura',
            'Hora de cierre',
          ],
        ),
        DemoListCard(
          title: 'Políticas de agenda',
          lines: [
            'Anticipos',
            'Cancelaciones',
            'Reagendamientos y confirmaciones',
          ],
        ),
        DemoListCard(
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
