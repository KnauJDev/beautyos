import 'package:flutter/material.dart';

import '../widgets/app_widgets.dart';

class TicketsPage extends StatelessWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Tickets',
      subtitle:
          'Seguimiento de cada solicitud desde WhatsApp hasta finalizaci\u00f3n.',
      children: const [
        DemoListCard(
          title: 'Ticket demo',
          lines: [
            'Canal: Manual',
            'Cliente: Mar\u00eda Rodr\u00edguez',
            'Servicio: Corte de cabello',
            'Estado: Confirmado',
          ],
        ),
        SizedBox(height: 16),
        InfoPanel(
          icon: Icons.confirmation_number_outlined,
          title: 'Coraz\u00f3n operativo de BeautyOS',
          description:
              'El ticket ser\u00e1 la pieza central: de aqu\u00ed saldr\u00e1 la agenda, el historial, el estado del servicio y los reportes.',
        ),
      ],
    );
  }
}
