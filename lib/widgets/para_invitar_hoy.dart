import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/enlace_de_reserva.dart';
import '../models/invitacion_a_volver.dart';
import '../models/mensaje_para_la_clienta.dart';
import '../pages/agenda_page.dart' show buildWhatsAppUri;
import '../services/invitar_a_volver_service.dart';
import '../services/slug_del_salon_service.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';

/// Invitar a volver por un servicio (D-314): se registra la invitación y se
/// abre WhatsApp con el mensaje armado. La usan la tarjeta de la Agenda y la
/// pantalla Clientes, para que las dos hagan exactamente lo mismo.
///
/// Se registra ANTES de abrir WhatsApp: si la persona no termina de enviarlo,
/// la invitación ya consta, y nadie le escribe dos veces a la misma clienta
/// creyendo que nadie lo hizo. Devuelve `false` si no se pudo registrar.
Future<bool> invitarAVolver(
  BuildContext context, {
  required InvitarAVolverService servicio,
  required InvitacionAVolver fila,
  String? nombreDelSalon,
  String? enlace,
}) async {
  final avisos = ScaffoldMessenger.of(context);
  try {
    await servicio.registrar(clientId: fila.clientId, serviceId: fila.serviceId);
  } catch (error) {
    avisos.showSnackBar(SnackBar(content: Text(mensajeParaLaClienta(error))));
    return false;
  }
  final texto = mensajeDeInvitacionAVolver(
    nombre: fila.primerNombre,
    servicio: fila.serviceName,
    nombreDelSalon: nombreDelSalon,
    enlace: enlace,
  );
  if (fila.clientPhone.trim().isNotEmpty) {
    await launchUrl(
      buildWhatsAppUri(fila.clientPhone, text: texto),
      mode: LaunchMode.externalApplication,
    );
  }
  return true;
}

/// "Para invitar hoy", arriba de la Agenda (D-314, paso 4B).
///
/// Enseña las parejas clienta-servicio a las que hoy les toca: las que pasó su
/// tiempo de volver y nadie ha invitado, y las invitadas que no volvieron
/// cuando pasa otra vez el tiempo. Cada una con su botón de WhatsApp. Si no
/// hay ninguna, o si no se pudo leer, no ocupa espacio.
class ParaInvitarHoyCard extends StatefulWidget {
  const ParaInvitarHoyCard({
    super.key,
    required this.servicio,
    this.nombreDelSalon,
    this.esSedePrincipal = false,
    this.reloj,
  });

  final InvitarAVolverService servicio;
  final String? nombreDelSalon;
  final bool esSedePrincipal;
  final DateTime Function()? reloj;

  @override
  State<ParaInvitarHoyCard> createState() => _ParaInvitarHoyCardState();
}

class _ParaInvitarHoyCardState extends State<ParaInvitarHoyCard> {
  late Future<List<InvitacionAVolver>> _futuro;
  String? _slug;
  String? _trabajando;

  @override
  void initState() {
    super.initState();
    _futuro = widget.servicio.listar();
    const SlugDelSalonService().leer(widget.servicio.branchId).then((slug) {
      if (mounted && slug != null) setState(() => _slug = slug);
    });
  }

  String get _enlace => enlaceParaCompartir(
    branchId: widget.servicio.branchId,
    esSedePrincipal: widget.esSedePrincipal,
    slugDelSalon: _slug,
  );

  Future<void> _invitar(InvitacionAVolver fila) async {
    final clave = '${fila.clientId}/${fila.serviceId}';
    setState(() => _trabajando = clave);
    await invitarAVolver(
      context,
      servicio: widget.servicio,
      fila: fila,
      nombreDelSalon: widget.nombreDelSalon,
      enlace: _enlace,
    );
    if (!mounted) return;
    setState(() {
      _trabajando = null;
      _futuro = widget.servicio.listar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InvitacionAVolver>>(
      future: _futuro,
      builder: (context, snapshot) {
        final hoy = (snapshot.data ?? const <InvitacionAVolver>[])
            .where((f) => f.tocaHoy)
            .toList();
        if (hoy.isEmpty) return const SizedBox.shrink();

        final ahora = (widget.reloj ?? DateTime.now)();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: const Icon(Icons.forward_to_inbox_outlined),
                title: Text(
                  tituloDeParaInvitarHoy(clientasDe(hoy).length),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Ya les toca volver. Invítalas por WhatsApp.',
                ),
                children: [
                  for (final fila in hoy)
                    ListTile(
                      title: Text(fila.clientName),
                      subtitle: Text(
                        '${fila.serviceName} · ${fila.textoDeEstado(ahora)}',
                      ),
                      trailing: _trabajando == '${fila.clientId}/${fila.serviceId}'
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton.icon(
                              onPressed: _trabajando == null
                                  ? () => _invitar(fila)
                                  : null,
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                color: AppColors.whatsapp,
                                size: 18,
                              ),
                              label: const Text('Invitar'),
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

/// "Para invitar hoy (3 clientas)", con su singular.
String tituloDeParaInvitarHoy(int clientas) => clientas == 1
    ? 'Para invitar hoy (1 clienta)'
    : 'Para invitar hoy ($clientas clientas)';
