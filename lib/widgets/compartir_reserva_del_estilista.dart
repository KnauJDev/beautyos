import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/enlace_de_reserva.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// El estilista no agenda, pero puede traer clientas (D-266, D-267).
///
/// **Por qué existe.** El propietario decidió el 23-sep que el estilista NO
/// crea citas, para que no pueda llevarse la base de clientas del salón. Y a la
/// vez dijo cómo trae a sus conocidos: *"puede compartir el link del salón o la
/// reserva pública"*. Esta tarjeta le pone ese enlace a mano: lo copia o lo
/// manda por WhatsApp, la clienta escoge servicio y hora, y la cita llega al
/// salón **por confirmar**, como cualquier reserva en línea.
///
/// No le enseña ninguna clienta ni le deja crear ninguna: es justo lo que la
/// decisión quería evitar.
class CompartirReservaDelEstilista extends StatelessWidget {
  const CompartirReservaDelEstilista({super.key, required this.branchId});

  final String branchId;

  String get _enlace => enlaceDeReservaDeSede(branchId);

  Future<void> _copiar(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _enlace));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Enlace copiado.')));
  }

  Future<void> _porWhatsApp() async {
    final mensaje =
        'Reserva tu cita conmigo aquí 👉 $_enlace\n'
        'Escoges el servicio y la hora, y al elegir estilista me buscas a mí.';
    final uri = Uri.https('wa.me', '/', {'text': mensaje});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.brandTintSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_add_alt_1_outlined, color: AppColors.brand),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '¿Tienes una clienta nueva?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Compártele el enlace de reservas de tu sede. Ella escoge el '
            'servicio y la hora, te elige a ti como estilista, y la cita llega '
            'al salón por confirmar.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: _porWhatsApp,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.whatsapp,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Enviar por WhatsApp'),
              ),
              OutlinedButton.icon(
                onPressed: () => _copiar(context),
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copiar enlace'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
