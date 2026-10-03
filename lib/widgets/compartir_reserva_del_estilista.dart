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
/// salón **por confirmar**, como cualquier reserva en línea. En un negocio
/// con la agenda de tres estados (D-312) llega ya confirmada, y la tarjeta
/// lo dice.
///
/// No le enseña ninguna clienta ni le deja crear ninguna: es justo lo que la
/// decisión quería evitar.
class CompartirReservaDelEstilista extends StatelessWidget {
  const CompartirReservaDelEstilista({
    super.key,
    required this.branchId,
    this.citasNacenConfirmadas = false,
    this.nombreDelSalon,
    this.slugDelSalon,
    this.esSedePrincipal = false,
  });

  final String branchId;
  final bool citasNacenConfirmadas;

  /// 03-oct: el mensaje nombra el salón y, si se puede, el enlace lleva su
  /// nombre (`enlaceParaCompartir`, D-313).
  final String? nombreDelSalon;
  final String? slugDelSalon;
  final bool esSedePrincipal;

  String get _enlace => enlaceParaCompartir(
    branchId: branchId,
    esSedePrincipal: esSedePrincipal,
    slugDelSalon: slugDelSalon,
  );

  Future<void> _copiar(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _enlace));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Enlace copiado.')));
  }

  Future<void> _porWhatsApp() async {
    final mensaje = mensajeDeLaEstilista(
      enlace: _enlace,
      nombreDelSalon: nombreDelSalon,
    );
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
          Text(
            textoDeCompartirReserva(
              citasNacenConfirmadas: citasNacenConfirmadas,
            ),
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

/// Lo que la tarjeta le explica a la estilista. D-312: en un negocio con la
/// agenda de tres estados la cita no llega "por confirmar".
String textoDeCompartirReserva({required bool citasNacenConfirmadas}) =>
    citasNacenConfirmadas
    ? 'Compártele el enlace de reservas de tu sede. Ella escoge el servicio y '
          'la hora, te elige a ti como estilista, y la cita queda confirmada '
          'en tu agenda.'
    : 'Compártele el enlace de reservas de tu sede. Ella escoge el servicio y '
          'la hora, te elige a ti como estilista, y la cita llega al salón por '
          'confirmar.';

/// El WhatsApp que manda la estilista. 03-oct: nombra el salón, para que la
/// clienta sepa de dónde viene el enlace.
String mensajeDeLaEstilista({required String enlace, String? nombreDelSalon}) {
  final nombre = nombreDelSalon?.trim() ?? '';
  final donde = nombre.isEmpty ? '' : ' en $nombre';
  return 'Reserva tu cita conmigo$donde aquí 👉 $enlace\n'
      'Escoges el servicio y la hora, y al elegir estilista me buscas a mí.';
}
