import 'package:flutter/material.dart';

import '../widgets/app_widgets.dart';

class ClientesPage extends StatelessWidget {
  const ClientesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Clientes',
      subtitle: 'Historial, contacto y preferencias de cada cliente.',
      children: const [
        DemoListCard(
          title: 'Clientes demo',
          lines: [
            'Mar\u00eda Rodr\u00edguez \u00b7 +57 310 444 1111',
            'Laura Mart\u00ednez \u00b7 +57 310 444 2222',
          ],
        ),
        SizedBox(height: 16),
        InfoPanel(
          icon: Icons.people_outline,
          title: 'Visi\u00f3n comercial',
          description:
              'Este m\u00f3dulo ayudar\u00e1 al negocio a no perder clientes y recordar su historial de servicios.',
        ),
      ],
    );
  }
}
