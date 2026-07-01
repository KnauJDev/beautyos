import 'package:flutter/material.dart';

import '../widgets/app_widgets.dart';

class AgendaPage extends StatelessWidget {
  const AgendaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Agenda',
      subtitle: 'Aqu\u00ed veremos las citas por fecha, cliente y estilista.',
      children: const [
        InfoPanel(
          icon: Icons.calendar_month_outlined,
          title: 'Pr\u00f3ximo objetivo',
          description:
              'Mostrar las citas creadas en Supabase y organizarlas por d\u00eda. La agenda nacer\u00e1 desde los tickets confirmados.',
        ),
        SizedBox(height: 16),
        DemoListCard(
          title: 'Cita demo',
          lines: [
            'Cliente: Mar\u00eda Rodr\u00edguez',
            'Servicio: Corte de cabello',
            'Estilista: Sandra G\u00f3mez',
            'Estado: Confirmado',
          ],
        ),
      ],
    );
  }
}
