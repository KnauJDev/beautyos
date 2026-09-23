import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../models/branch_subscription.dart';
import '../models/platform_partner.dart';
import '../models/platform_saas_metrics.dart';
import '../models/platform_tenant_feature_override.dart';
import '../models/platform_tenant_summary.dart';
import '../models/tenant_subscription_history_entry.dart';
import '../models/ticket_board.dart' show formatCOP;
import '../services/platform_service.dart';
import '../widgets/security_settings_dialog.dart';
import '../widgets/update_banner.dart';
import 'agenda_page.dart' show buildWhatsAppUri;
import 'platform_tenant_detail_page.dart';

class PlatformPanelPage extends StatefulWidget {
  const PlatformPanelPage({super.key, required this.platformRole});

  final String platformRole;

  @override
  State<PlatformPanelPage> createState() => _PlatformPanelPageState();
}

class _PlatformPanelPageState extends State<PlatformPanelPage>
    with SingleTickerProviderStateMixin {
  final platformService = const PlatformService();

  late Future<List<PlatformTenantSummary>> tenantsFuture;
  late Future<PlatformSaasMetrics> saasMetricsFuture;
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String selectedFilter =
      'todos'; // 'todos', 'pendientes', 'activos', 'trialing', 'demo', 'suspendidos'

  /// El negocio abierto en el panel de la derecha (D-239, paso 9.39).
  ///
  /// **Solo manda en pantalla ancha.** Por debajo de [_anchoParaDosColumnas] la
  /// ficha se sigue abriendo como hoja emergente: dos columnas en 400 px no son
  /// dos columnas, son dos columnas ilegibles.
  ///
  /// Guarda el negocio y no su identificador porque la lista se recarga tras
  /// cada acción, y el objeto guardado envejece. Ver `_vigente`.
  PlatformTenantSummary? _seleccionado;

  /// Ancho a partir del cual caben las dos columnas.
  ///
  /// 400 de lista + 1 de separador + lo que quede para la ficha, que necesita
  /// unos 600 para no romper sus filas de botones.
  static const double _anchoParaDosColumnas = 1000;

  /// Ancho fijo de la columna de la lista.
  ///
  /// Fijo y no proporcional: la lista siempre muestra lo mismo, así que
  /// estirarla en un monitor grande solo deja aire dentro de cada tarjeta.
  /// Lo que debe crecer es la ficha, que sí tiene más que enseñar.
  static const double _anchoDeLaLista = 470;

  /// El negocio seleccionado **tal y como está en la última carga**.
  ///
  /// Tras aprobar, suspender o cambiar un precio, `reload()` trae objetos
  /// nuevos y el que guardamos queda viejo: seguiría diciendo "POR APROBAR"
  /// después de aprobarlo. Se vuelve a buscar por identificador en cada
  /// construcción.
  ///
  /// Se busca en la lista **sin filtrar** a propósito: si filtras por "Activos"
  /// con un negocio en prueba abierto, la ficha se queda donde está en vez de
  /// vaciarse sin avisar.
  PlatformTenantSummary? _vigente(List<PlatformTenantSummary> todos) {
    final id = _seleccionado?.tenantId;
    if (id == null) return null;
    for (final t in todos) {
      if (t.tenantId == id) return t;
    }
    return null;
  }

  bool get isOwner => widget.platformRole == 'platform_owner';

  @override
  void initState() {
    super.initState();
    tenantsFuture = platformService.listTenants();
    saasMetricsFuture = platformService.getSaasMetrics();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void reload() {
    setState(() {
      tenantsFuture = platformService.listTenants();
      saasMetricsFuture = platformService.getSaasMetrics();
    });
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<String?> askReason(
    String title, {
    String hint = 'Motivo (obligatorio)',
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> handleApprove(PlatformTenantSummary tenant) async {
    String selectedPlan = tenant.planCode ?? 'pro';
    if (selectedPlan == 'profesional' ||
        selectedPlan == 'basico' ||
        selectedPlan == 'business') {
      selectedPlan = 'pro';
    }
    bool isFounder = tenant.isFounder;
    int trialDays = 21;
    // AG: este precio ya no es el del negocio, es el que se va a pactar en su
    // sede principal. Se prellena con el del negocio por comodidad cuando lo
    // hubiera, pero no se vuelve a guardar ahí.
    final priceController = TextEditingController(
      text: tenant.priceCop != null ? tenant.priceCop.toString() : '',
    );
    final reasonController = TextEditingController();
    // AG: el descuento porcentual desapareció de esta ventana, así que ya no
    // cuenta como tarifa especial. La marca un precio, y un pionero la exige.
    bool customPricing = tenant.priceCop != null || tenant.isFounder;

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Aprobar solicitud: ${tenant.tenantName}'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contacto: ${tenant.contactEmail} · ${tenant.whatsapp ?? "Sin WhatsApp"}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (tenant.city != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ciudad: ${tenant.city} · Sedes: ${tenant.realBranchesCount} · Equipo: ${tenant.realTeamCount}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  const Text(
                    'Plan a asignar:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPlan,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'pro',
                        child: Text('Todo Incluido — \$150.000/mes por sede'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedPlan = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Marcar como pionero (solo etiqueta)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // Este subtítulo decía la verdad de D-221 desde el 07-sep,
                    // y tres líneas más abajo el código hacía
                    // `discountPercent = 50.0`. El texto se actualizó y el
                    // código no. Corregido con AG.
                    subtitle: const Text(
                      'NO aplica ningún descuento (D-221). Es solo una marca para reconocer '
                      'después a los primeros. La tarifa se pacta abajo, una a una.',
                    ),
                    value: isFounder,
                    onChanged: (val) {
                      setModalState(() {
                        isFounder = val;
                        // AG: marcar pionero ya NO esconde el precio. Antes lo
                        // ocultaba y el código le metía un 50% en silencio; el
                        // servidor ahora exige que se diga cuánto paga.
                        if (isFounder) customPricing = true;
                      });
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tarifa especial personalizada'),
                    subtitle: isFounder
                        ? const Text(
                            'Obligatoria para un pionero: no hay tarifa de '
                            'pionero por defecto, se negocia una a una.',
                          )
                        : null,
                    value: customPricing,
                    onChanged: isFounder
                        ? null
                        : (val) =>
                              setModalState(() => customPricing = val ?? false),
                  ),
                  if (customPricing) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        // AG: este precio ya no es del negocio. Va a su sede
                        // principal, que es quien cobra desde D-239.
                        labelText: 'Precio mensual de su sede, en COP',
                        hintText: 'Ej. 75000',
                        helperText:
                            'Es lo que pagará su sede principal cada mes. Si '
                            'abre más sedes, cada una se pacta por separado.',
                        helperMaxLines: 3,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Motivo del precio especial *',
                        helperText:
                            'Queda escrito junto al precio de la sede, para '
                            'saber después de dónde salió esa cifra.',
                        helperMaxLines: 2,
                        hintText: 'Ej. Tarifa acordada en WhatsApp / Amigo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Días de prueba gratis:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: trialDays,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('7 días')),
                      DropdownMenuItem(value: 14, child: Text('14 días')),
                      DropdownMenuItem(
                        value: 21,
                        child: Text('21 días (Estándar)'),
                      ),
                      DropdownMenuItem(value: 30, child: Text('30 días')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => trialDays = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '⚠️ La prueba gratis arranca en este momento exacto.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (customPricing) {
                  final price = priceController.text.trim();
                  final reason = reasonController.text.trim();

                  // AG: un pionero sin precio ya no se puede aprobar. El
                  // servidor lo niega, y decírselo aquí evita mandarlo a
                  // estrellarse contra un error que no eligió.
                  if (isFounder && price.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Un pionero necesita su precio pactado: no hay '
                          'tarifa de pionero por defecto.',
                        ),
                      ),
                    );
                    return;
                  }

                  if (price.isNotEmpty && reason.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Debes ingresar un motivo para el precio especial.',
                        ),
                      ),
                    );
                    return;
                  }
                }
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.check_circle_outlined),
              label: const Text('Aprobar y Activar'),
            ),
          ],
        ),
      ),
    );

    if (approved != true || !mounted) return;

    try {
      int? priceCop;
      String? priceReason;

      // AG: aquí estaba `if (isFounder) discountPercent = 50.0;`, **el mismo
      // 50% que D-221 quitó del servidor el 07-sep** y que el interruptor de
      // arriba ya prometía no aplicar. Ahora el precio se escribe, no se
      // deduce, y **el descuento porcentual no se manda**: el precio de una
      // sede se pacta en pesos.
      if (customPricing) {
        priceCop = int.tryParse(priceController.text.trim());
        priceReason = reasonController.text.trim();
      }

      await platformService.approveTenant(
        tenantId: tenant.tenantId,
        planCode: selectedPlan,
        isFounder: isFounder,
        priceCop: priceCop,
        priceReason: priceReason,
        trialDays: trialDays,
      );

      reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡"${tenant.tenantName}" ha sido aprobado y su prueba de $trialDays días está activa!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> handleUpdatePricing(PlatformTenantSummary tenant) async {
    String selectedPlan = tenant.planCode ?? 'pro';
    if (selectedPlan == 'profesional' ||
        selectedPlan == 'basico' ||
        selectedPlan == 'business') {
      selectedPlan = 'pro';
    }
    bool isFounder = tenant.isFounder;

    // AG: esta ventana ya no lleva precio, descuento ni motivo. Tenía tres
    // campos y los tres escribían en el negocio, que desde D-239 no cobra.
    //
    // Se va con ellos una precaución de D-230 que conviene no perder de
    // vista: el motivo NO se autorellenaba, porque prellenar un texto
    // genérico y guardar sobrescribía el pactado — a *Exportadora* le habría
    // borrado su «Pionero fundador: 80.000 por sede» con un clic. **Esa misma
    // precaución vive ahora en el diálogo de precio de la sede**, que es
    // donde se escribe el motivo.

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Plan y etiqueta: ${tenant.tenantName}'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ajusta el plan asignado y la etiqueta de pionero. '
                    'El precio se pacta en cada sede.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Plan Asignado:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPlan,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'pro',
                        child: Text('Todo Incluido — \$150.000/mes por sede'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedPlan = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Marcar como pionero (solo etiqueta)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      // D-252 quitó el precio de esta ventana y el subtítulo siguió
                      // diciendo "se pacta abajo": el quinto letrero rancio, visto en
                      // la revisión del 23-sep (D-254). Regla 16-ter.
                      'NO aplica ningún descuento (D-221). Es solo una marca para reconocer '
                      'después a los primeros. La tarifa se pacta en cada sede, una a una.',
                    ),
                    value: isFounder,
                    onChanged: (val) => setModalState(() => isFounder = val),
                  ),
                  const SizedBox(height: 16),
                  // Hallazgo AG: aquí había un precio y un descuento **del
                  // negocio**. Desde D-239 quien cobra es la sede, así que ese
                  // precio no cobraba nada — y el servidor ya lo rechaza.
                  // En su lugar se dice dónde se pacta de verdad.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.infoTint,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: const Text(
                      'El precio se pacta en cada sede, no aquí: es la sede '
                      'quien cobra. Cierra esta ventana y usa el botón Pago '
                      'de la sede que quieras cambiar.\n\n'
                      'Un negocio con varias sedes puede tener un precio '
                      'distinto en cada una, que es como se negocia en la '
                      'realidad.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar plan y etiqueta'),
            ),
          ],
        ),
      ),
    );

    if (updated != true || !mounted) return;

    try {
      // AG: el segundo escondite del 50%. Aquí estaba
      // `if (isFounder) discountPercent = 50.0;`, igual que en el diálogo de
      // aprobar y con el mismo interruptor prometiendo justo lo contrario.
      // Esta ventana ya no manda ningún precio: el servidor los rechaza
      // porque el precio vive en la sede.
      await platformService.updateTenantPricing(
        tenantId: tenant.tenantId,
        planCode: selectedPlan,
        isFounder: isFounder,
      );

      reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Tarifa de "${tenant.tenantName}" actualizada exitosamente!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on PostgrestException catch (error) {
      _showError(error.message);
    } catch (e) {
      _showError('No se pudo actualizar la tarifa: $e');
    }
  }

  Future<void> handleUpdateContact(PlatformTenantSummary tenant) async {
    final nameController = TextEditingController(
      text: tenant.contactName ?? '',
    );
    final emailController = TextEditingController(text: tenant.contactEmail);
    final whatsappController = TextEditingController(
      text: tenant.whatsapp ?? '',
    );
    final businessTypeController = TextEditingController(
      text: tenant.businessType ?? '',
    );
    final cityController = TextEditingController(text: tenant.city ?? '');

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Contacto: ${tenant.tenantName}'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de contacto titular *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo de contacto *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: businessTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de negocio',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'Ciudad',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (nameController.text.trim().isEmpty ||
                  emailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'El nombre de contacto y el correo no pueden estar vacíos.',
                    ),
                  ),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar Contacto'),
          ),
        ],
      ),
    );

    if (updated != true || !mounted) return;

    try {
      await platformService.updateTenantContact(
        tenantId: tenant.tenantId,
        contactName: nameController.text.trim(),
        contactEmail: emailController.text.trim(),
        whatsapp: whatsappController.text.trim(),
        businessType: businessTypeController.text.trim(),
        city: cityController.text.trim(),
      );

      reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Contacto de "${tenant.tenantName}" actualizado exitosamente!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on PostgrestException catch (error) {
      _showError(error.message);
    } catch (e) {
      _showError('No se pudo actualizar el contacto: $e');
    }
  }

  Future<void> handleReject(PlatformTenantSummary tenant) async {
    final reason = await askReason(
      'Rechazar solicitud: "${tenant.tenantName}"',
      hint: 'Motivo del rechazo (ej. No cumple requisitos del piloto)',
    );
    if (reason == null || reason.isEmpty || !mounted) {
      return;
    }

    try {
      await platformService.rejectTenant(
        tenantId: tenant.tenantId,
        reason: reason,
      );
      reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solicitud de "${tenant.tenantName}" rechazada.'),
        ),
      );
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> handleSuspend(PlatformTenantSummary tenant) async {
    final reason = await askReason('Suspender "${tenant.tenantName}"');
    if (reason == null || reason.isEmpty || !mounted) {
      return;
    }

    try {
      await platformService.suspendTenant(
        tenantId: tenant.tenantId,
        reason: reason,
      );
      reload();
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> handleReactivate(PlatformTenantSummary tenant) async {
    final reason = await askReason('Reactivar "${tenant.tenantName}"');
    if (reason == null || reason.isEmpty || !mounted) {
      return;
    }

    try {
      await platformService.reactivateTenant(
        tenantId: tenant.tenantId,
        reason: reason,
      );
      reload();
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  /// Marca o desmarca un negocio como de ensayo (D-225, paso 9.29).
  ///
  /// Hasta el 07-sep esta marca solo se podia poner escribiendo SQL a mano:
  /// D-120 la creo con un `update` dentro de una migracion y no dejo forma de
  /// volver a ponerla. Resultado: tres negocios de prueba contaban como
  /// salones reales en las metricas durante meses.
  Future<void> handleToggleDemo(PlatformTenantSummary tenant) async {
    final marcar = !tenant.isDemo;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          marcar
              ? 'Marcar como negocio de ensayo'
              : 'Quitar la marca de ensayo',
        ),
        content: Text(
          marcar
              ? '"${tenant.tenantName}" dejara de contar en las metricas de la '
                    'plataforma y dejara de recibir los avisos de vencimiento.\n\n'
                    'Se puede deshacer cuando quieras.'
              : '"${tenant.tenantName}" volvera a contar como un salon real en '
                    'las metricas y recibira los avisos de vencimiento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(marcar ? 'Marcar como ensayo' : 'Quitar la marca'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) {
      return;
    }

    try {
      await platformService.setTenantDemo(
        tenantId: tenant.tenantId,
        isDemo: marcar,
      );
      reload();
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> handleExtendTrial(PlatformTenantSummary tenant) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 21)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Nueva fecha de fin de prueba',
    );
    if (newDate == null || !mounted) {
      return;
    }

    final reason = await askReason('Extender prueba de "${tenant.tenantName}"');
    if (reason == null || reason.isEmpty || !mounted) {
      return;
    }

    try {
      await platformService.extendTrial(
        tenantId: tenant.tenantId,
        newTrialEndsAt: newDate,
        reason: reason,
      );
      reload();
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  Future<void> handleAssignPartner(PlatformTenantSummary tenant) async {
    List<PlatformPartner> partners;
    try {
      partners = await platformService.listPartners();
    } on PostgrestException catch (error) {
      _showError(error.message);
      return;
    }
    if (!mounted) return;

    String? selectedPartnerId = tenant.partnerId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Partner de "${tenant.tenantName}"'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: DropdownButtonFormField<String?>(
                initialValue: selectedPartnerId,
                decoration: const InputDecoration(
                  labelText: 'Partner vinculado',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin partner'),
                  ),
                  ...partners.map(
                    (p) => DropdownMenuItem<String?>(
                      value: p.partnerId,
                      child: Text('${p.fullName} (${p.referralCode})'),
                    ),
                  ),
                ],
                onChanged: (v) => setModalState(() => selectedPartnerId = v),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await platformService.setTenantPartner(
        tenantId: tenant.tenantId,
        partnerId: selectedPartnerId,
      );
      reload();
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  /// Borra un negocio de PRUEBA y todo lo suyo (D-246, paso 9.47).
  ///
  /// **Hay que escribir el nombre del negocio para que el boton se active.**
  /// No es teatro: un "Estas seguro? Si/No" se contesta con el raton en piloto
  /// automatico, y esto no tiene deshacer. Escribir el nombre obliga a mirar
  /// cual es la fila antes de destruirla.
  ///
  /// El seguro de verdad vive en el servidor --la RPC se niega si el negocio
  /// no es demo--. Esto es la segunda puerta, no la unica.
  Future<void> handleDeleteDemo(PlatformTenantSummary tenant) async {
    final escrito = TextEditingController();
    final coincide = ValueNotifier<bool>(false);
    escrito.addListener(
      () => coincide.value = escrito.text.trim() == tenant.tenantName,
    );

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar este negocio de prueba'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se borra "${tenant.tenantName}" y TODO lo suyo: sus sedes, su '
                'equipo, sus clientas, sus tickets, sus pagos y sus fotos.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              const Text(
                'Esto no se puede deshacer.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Queda un resumen de lo borrado --cuantas filas y cuanto '
                'dinero-- porque estos negocios llevan pagos reales. Las '
                'cuentas de correo y los archivos de fotos NO se borran.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                'Escribe el nombre exacto para confirmar:',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: escrito,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: tenant.tenantName,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: coincide,
            builder: (context, puede, _) => FilledButton(
              onPressed: puede ? () => Navigator.of(context).pop(true) : null,
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Borrar definitivamente'),
            ),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    try {
      final borrado = await platformService.deleteDemoTenant(tenant.tenantId);
      if (!mounted) return;

      final total = borrado.values.fold<int>(0, (a, b) => a + b);
      setState(() => _seleccionado = null);
      reload();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Borrado "${tenant.tenantName}": $total '
            '${total == 1 ? "fila" : "filas"} en ${borrado.length} '
            '${borrado.length == 1 ? "tabla" : "tablas"}.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } on PostgrestException catch (error) {
      // El mensaje viene del servidor, que es quien conoce el seguro: por
      // ejemplo, que el negocio no esta marcado como de prueba.
      if (mounted) _showError(error.message);
    }
  }

  /// La ficha del negocio, construida **una sola vez para sus dos casas**
  /// (D-239): la hoja emergente de siempre y la columna derecha nueva.
  ///
  /// [cerrarAntes] es lo que hay que hacer justo antes de cada acción. Como
  /// hoja emergente es cerrarla —si no, el diálogo de la acción sale detrás de
  /// la hoja y no se ve—; empotrada **no hace nada**, porque no hay nada que
  /// estorbe y cerrar sería perder de vista al negocio sobre el que actúas.
  ///
  /// La `ValueKey` no es decorativa: al pasar de un negocio a otro sin ella,
  /// Flutter reaprovecha el estado anterior y `initState` no vuelve a correr,
  /// así que verías **las sedes y el historial del negocio anterior** bajo el
  /// nombre del nuevo. Es el mismo fallo que D-211.
  Widget _fichaDeNegocio(
    PlatformTenantSummary tenant, {
    required bool embebido,
    required VoidCallback cerrarAntes,
    required VoidCallback onCerrar,
  }) {
    return _TenantDetailSheet(
      key: ValueKey('ficha-${tenant.tenantId}'),
      tenant: tenant,
      isOwner: isOwner,
      platformService: platformService,
      embebido: embebido,
      onCerrar: onCerrar,
      onApprove: (t) {
        cerrarAntes();
        handleApprove(t);
      },
      onReject: (t) {
        cerrarAntes();
        handleReject(t);
      },
      onSuspend: (t) {
        cerrarAntes();
        handleSuspend(t);
      },
      onReactivate: (t) {
        cerrarAntes();
        handleReactivate(t);
      },
      onExtendTrial: (t) {
        cerrarAntes();
        handleExtendTrial(t);
      },
      onUpdatePricing: (t) {
        cerrarAntes();
        handleUpdatePricing(t);
      },
      onUpdateContact: (t) {
        cerrarAntes();
        handleUpdateContact(t);
      },
      onAssignPartner: (t) {
        cerrarAntes();
        handleAssignPartner(t);
      },
      onToggleDemo: (t) {
        cerrarAntes();
        handleToggleDemo(t);
      },
      onDeleteDemo: (t) {
        cerrarAntes();
        handleDeleteDemo(t);
      },
      onViewSupportData: (t) {
        cerrarAntes();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlatformTenantDetailPage(
              tenantId: t.tenantId,
              tenantName: t.tenantName,
            ),
          ),
        );
      },
    );
  }

  /// Abre la ficha como hoja emergente. **Solo en pantalla estrecha** desde
  /// D-239; en ancha la ficha vive fija en la columna derecha.
  void _openTenantDetail(PlatformTenantSummary tenant) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _fichaDeNegocio(
        tenant,
        embebido: false,
        cerrarAntes: () => Navigator.of(sheetContext).pop(),
        onCerrar: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandSurface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.brand, AppColors.brandDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Panel de Plataforma',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'BeautyOS SaaS Global',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Actualizar listado',
                onPressed: reload,
                icon: const Icon(
                  Icons.refresh_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
              IconButton(
                tooltip: 'Seguridad de tu cuenta',
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const SecuritySettingsDialog(),
                ),
                icon: const Icon(
                  Icons.security_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: signOut,
                icon: const Icon(
                  Icons.logout_outlined,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          const UpdateBanner(),
          FutureBuilder<PlatformSaasMetrics>(
            future: saasMetricsFuture,
            builder: (context, metricsSnapshot) {
              return _SaasMetricsHeader(
                metrics: metricsSnapshot.data,
                isLoading:
                    metricsSnapshot.connectionState == ConnectionState.waiting,
              );
            },
          ),
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.brand,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.brand,
              tabs: const [
                Tab(text: '🏪 Salones Clientes'),
                Tab(text: '🤝 Partners y Referidos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTenantsTab(),
                _PartnersTab(
                  platformService: platformService,
                  isOwner: isOwner,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantsTab() {
    return FutureBuilder<List<PlatformTenantSummary>>(
      future: tenantsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 40,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No pudimos cargar los negocios.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: reload,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final allTenants = snapshot.data ?? const <PlatformTenantSummary>[];

        // Métricas para los contadores de las píldoras de filtro.
        final pendingCount = allTenants.where((t) => t.isPending).length;
        final activeCount = allTenants
            .where((t) => t.isActive && !t.isDemo)
            .length;
        // Hallazgo AR: esta línea no excluía los ensayos y la de arriba sí.
        // La tarjeta de métricas (que viene del servidor, `where not
        // t.is_demo`) decía 0 y esta píldora 1. Los ensayos tienen su propia
        // píldora, *Demos*: aquí se cuentan las pruebas de verdad.
        final trialCount = allTenants
            .where((t) => t.isTrialing && !t.isDemo)
            .length;

        // Filtrar por texto
        var filtered = allTenants.where((t) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase().trim();
            final name = t.tenantName.toLowerCase();
            final email = t.contactEmail.toLowerCase();
            final city = (t.city ?? '').toLowerCase();
            final phone = (t.whatsapp ?? '').replaceAll(RegExp(r'[^0-9]'), '');
            final qPhone = q.replaceAll(RegExp(r'[^0-9]'), '');

            final matches =
                name.contains(q) ||
                email.contains(q) ||
                city.contains(q) ||
                (qPhone.isNotEmpty && phone.contains(qPhone));

            if (!matches) return false;
          }

          // Filtrar por categoría
          if (selectedFilter == 'pendientes') return t.isPending;
          if (selectedFilter == 'activos') {
            return t.isActive && !t.isDemo;
          }
          if (selectedFilter == 'trialing') return t.isTrialing && !t.isDemo;
          if (selectedFilter == 'demo') return t.isDemo;
          if (selectedFilter == 'suspendidos') return t.isSuspended;

          return true;
        }).toList();

        // D-239: en pantalla ancha, maestro-detalle. En estrecha, exactamente
        // lo de antes. El ancho lo mide `LayoutBuilder` y no `MediaQuery`
        // porque lo que importa es **el espacio de esta pestaña**, no el de la
        // ventana: el Panel vive dentro de un `TabBarView` con su propio ancho.
        return LayoutBuilder(
          builder: (context, constraints) {
            final dosColumnas = constraints.maxWidth >= _anchoParaDosColumnas;
            final vigente = dosColumnas ? _vigente(allTenants) : null;

            final lista = filtered.isEmpty
                ? Center(
                    child: Text(
                      selectedFilter == 'pendientes'
                          ? 'No hay solicitudes pendientes de aprobación.'
                          : 'No hay negocios que coincidan con la búsqueda.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final negocio = filtered[index];
                      return _TenantCard(
                        tenant: negocio,
                        isOwner: isOwner,
                        compacto: dosColumnas,
                        seleccionado: negocio.tenantId == vigente?.tenantId,
                        onTap: () {
                          if (dosColumnas) {
                            setState(() => _seleccionado = negocio);
                          } else {
                            _openTenantDetail(negocio);
                          }
                        },
                        onApprove: handleApprove,
                        onReject: handleReject,
                        onUpdatePricing: handleUpdatePricing,
                        onViewSupportData: (t) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlatformTenantDetailPage(
                                tenantId: t.tenantId,
                                tenantName: t.tenantName,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );

            return Column(
              children: [
                // 1. Buscador y Filtros. Se quedan arriba de las dos columnas
                // a propósito: filtran la lista, no la ficha.
                _buildSearchAndFilters(pendingCount, activeCount, trialCount),
                Expanded(
                  child: dosColumnas
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: _anchoDeLaLista, child: lista),
                            const VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: AppColors.border,
                            ),
                            Expanded(
                              child: vigente == null
                                  ? _sinNegocioElegido()
                                  : _fichaDeNegocio(
                                      vigente,
                                      embebido: true,
                                      // Empotrada no se cierra nada antes de
                                      // actuar: perder de vista al negocio
                                      // sobre el que actúas es justo lo que
                                      // esta pantalla viene a evitar.
                                      cerrarAntes: () {},
                                      onCerrar: () =>
                                          setState(() => _seleccionado = null),
                                    ),
                            ),
                          ],
                        )
                      : lista,
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Lo que ocupa la columna derecha mientras no has elegido a nadie.
  ///
  /// Un hueco en blanco parecería una pantalla rota o a medio cargar. Esto
  /// dice qué hacer, en una línea.
  Widget _sinNegocioElegido() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 44,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Elige un negocio de la izquierda',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Aquí verás sus sedes con el estado de pago de cada una, '
              'su plan y su historial.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(int pending, int active, int trialing) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText:
                  'Buscar por salón, titular, correo, WhatsApp o ciudad...',
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: AppColors.textSecondary,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  label: const Text('Todos'),
                  selected: selectedFilter == 'todos',
                  onSelected: (val) {
                    if (val) setState(() => selectedFilter = 'todos');
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                ChoiceChip(
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  avatar: const Icon(
                    Icons.hourglass_top,
                    size: 14,
                    color: AppColors.statePending,
                  ),
                  label: Text('Por Aprobar ($pending)'),
                  selected: selectedFilter == 'pendientes',
                  selectedColor: AppColors.statePendingTint,
                  onSelected: (val) {
                    if (val) setState(() => selectedFilter = 'pendientes');
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                ChoiceChip(
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  avatar: const Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: AppColors.success,
                  ),
                  label: Text('Activos ($active)'),
                  selected: selectedFilter == 'activos',
                  selectedColor: AppColors.successTint,
                  onSelected: (val) {
                    if (val) setState(() => selectedFilter = 'activos');
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                ChoiceChip(
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  avatar: Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: AppColors.brand,
                  ),
                  label: Text('En Prueba ($trialing)'),
                  selected: selectedFilter == 'trialing',
                  selectedColor: AppColors.brandTintSoft,
                  onSelected: (val) {
                    if (val) setState(() => selectedFilter = 'trialing');
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                ChoiceChip(
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  avatar: const Icon(
                    Icons.science_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  label: const Text('Demos'),
                  selected: selectedFilter == 'demo',
                  onSelected: (val) {
                    if (val) setState(() => selectedFilter = 'demo');
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                ChoiceChip(
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  avatar: const Icon(
                    Icons.pause_circle_outline,
                    size: 14,
                    color: AppColors.danger,
                  ),
                  label: const Text('Suspendidos'),
                  selected: selectedFilter == 'suspendidos',
                  onSelected: (val) {
                    if (val) setState(() => selectedFilter = 'suspendidos');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CABECERA EJECUTIVA DEL SAAS (D-172, paso 7.4)
// ============================================================================
class _SaasMetricsHeader extends StatelessWidget {
  const _SaasMetricsHeader({required this.metrics, required this.isLoading});

  final PlatformSaasMetrics? metrics;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final m = metrics ?? PlatformSaasMetrics.empty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand, AppColors.brandDark],
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 62,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SaasMetricTile(
                    icon: Icons.trending_up,
                    label: 'MRR estimado',
                    value: m.formattedMrr,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _SaasMetricTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Cobrado histórico',
                    value: m.formattedTotalCollected,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _SaasMetricTile(
                    icon: Icons.storefront_outlined,
                    label: 'En pago / prueba',
                    value: '${m.activeCount} / ${m.trialingCount}',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _SaasMetricTile(
                    icon: Icons.swap_horiz,
                    label: 'Conversión prueba→pago',
                    value: m.formattedConversionRate,
                  ),
                ],
              ),
            ),
    );
  }
}

class _SaasMetricTile extends StatelessWidget {
  const _SaasMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TARJETA DE NEGOCIO / SALÓN
// ============================================================================
class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenant,
    required this.isOwner,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
    required this.onUpdatePricing,
    required this.onViewSupportData,
    this.compacto = false,
    this.seleccionado = false,
  });

  final PlatformTenantSummary tenant;
  final bool isOwner;
  final VoidCallback onTap;

  /// La tarjeta vive en la columna izquierda del maestro-detalle (D-239).
  ///
  /// Esconde los botones de **gestión** —aprobar, rechazar, precio, ver
  /// ficha— y deja solo los de **contacto**. No es por espacio, aunque
  /// también: en una pantalla partida en dos, la lista sirve para ELEGIR y
  /// la derecha para ACTUAR. Un botón que toca dinero desde una fila de
  /// lista no te deja ver a quién se lo estás tocando.
  final bool compacto;

  /// Es el negocio abierto ahora mismo en el panel derecho.
  final bool seleccionado;
  final ValueChanged<PlatformTenantSummary> onApprove;
  final ValueChanged<PlatformTenantSummary> onReject;
  final ValueChanged<PlatformTenantSummary> onUpdatePricing;
  final ValueChanged<PlatformTenantSummary> onViewSupportData;

  Color _statusColor(PlatformTenantSummary item) {
    if (item.isTrialExpired) {
      return AppColors.warning;
    }
    if (item.isPeriodExpired) {
      return AppColors.danger;
    }
    switch (item.subscriptionStatus) {
      case 'pending':
        return AppColors.statePending;
      case 'trialing':
        return AppColors.info;
      case 'active':
        return AppColors.success;
      case 'past_due':
      case 'grace':
        return AppColors.warning;
      case 'suspended':
      case 'rejected':
        return AppColors.danger;
      case 'cancelled':
        return AppColors.textStrong;
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(PlatformTenantSummary item) => item.estadoLegible;

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _pluralizeMeses(int count) => count == 1 ? 'mes' : 'meses';

  String _cobranzaMessage(PlatformTenantSummary tenant) {
    final nombre = tenant.contactName ?? tenant.tenantName;
    return 'Hola $nombre, te escribimos de Salón y Más respecto a la cuenta de '
        '"${tenant.tenantName}". Notamos un saldo pendiente de ${tenant.formattedDebtAmount}. '
        '¿Podemos ayudarte a ponerte al día?';
  }

  @override
  Widget build(BuildContext context) {
    final isPending = tenant.isPending;

    // El seleccionado manda sobre el pendiente en el borde: es el que estás
    // mirando ahora, y sin esa señal la columna izquierda no dice cuál de sus
    // filas produjo lo que hay a la derecha.
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: seleccionado
              ? AppColors.brand
              : (isPending ? AppColors.statePending : AppColors.border),
          width: seleccionado ? 2.0 : (isPending ? 1.5 : 1.0),
        ),
      ),
      color: seleccionado
          ? AppColors.brandTint.withValues(alpha: 0.35)
          : (isPending
                ? AppColors.statePendingTint.withValues(alpha: 0.35)
                : AppColors.surface),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila 1: **la persona**, y debajo su negocio (D-243).
              //
              // Antes mandaba el nombre del negocio. Pero esta columna es la
              // lista de CLIENTES, y un cliente es una persona: Yelimar
              // Rodriguez, no "Naguara de Unas". El negocio baja a segunda
              // linea y se repite en la tarjeta de cada sede, que es donde
              // importa saber de quien es el local que estas mirando.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant.contactName ?? tenant.tenantName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        // El nombre del negocio NO sale en la columna
                        // estrecha (D-244): vive en la ficha de cada sede.
                        // "La informacion debajo del nombre de mi cliente son
                        // los datos de una SEDE, no del propietario."
                        if (!compacto && tenant.contactName != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            tenant.tenantName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandDeep,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          compacto
                              ? tenant.contactEmail
                              : '${tenant.contactEmail} ${tenant.city != null ? "· 📍 ${tenant.city}" : ""}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        // Los dos telefonos de la PERSONA, que es con lo que
                        // de verdad se la localiza (D-244).
                        if (compacto &&
                            (tenant.contactPhone != null ||
                                tenant.whatsapp != null))
                          Text(
                            [
                              if (tenant.contactPhone != null)
                                'Cel. ${tenant.contactPhone}',
                              if (tenant.whatsapp != null)
                                'WhatsApp ${tenant.whatsapp}',
                            ].join('  ·  '),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (tenant.isDemo) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'DEMO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  if (tenant.isFounder) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandTint,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '★ PIONERO',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandDeep,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(tenant).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      _statusLabel(tenant),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(tenant),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Fila 2: Plan, Tarifa y Vigencia.
              //
              // **Fuera de la columna estrecha** (D-243). Desde D-239 el
              // precio se pacta POR SEDE, asi que una tarifa a nombre del
              // negocio en la lista de clientes dice algo que ya no decide
              // nada -- y era justo lo que hacia que Naguara pareciera costar
              // $10.000 mientras su propia sede decia $80.000. Cada sede lleva
              // el suyo en su ficha.
              if (!compacto)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sell_outlined,
                        size: 15,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Plan ${tenant.planNameFormatted} (${tenant.formattedEffectivePrice})',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        tenant.subscriptionStatus == 'pending'
                            ? 'Solicitado: ${_formatDate(tenant.createdAt)}'
                            : tenant.subscriptionStatus == 'trialing'
                            ? 'Prueba: ${_formatDate(tenant.createdAt)} al ${_formatDate(tenant.trialEndsAt)}'
                            : tenant.isPeriodExpired
                            ? 'Venció: ${_formatDate(tenant.currentPeriodEnd)}'
                            : 'Vence: ${_formatDate(tenant.currentPeriodEnd)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.sm),

              // Fila 2.5: Antigüedad, períodos pagados/LTV, mora y overrides (D-172, paso 7.1)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // En la columna estrecha, donde iba el dinero van las
                  // SEDES (D-244). El dinero se pacta por sede desde D-239, asi
                  // que un LTV a nombre del negocio ya no decide nada -- y un
                  // "2 sedes" a secas ensenyaba igual a quien tiene las dos al
                  // dia que a quien tiene una en mora.
                  if (compacto) ...[
                    Text(
                      '${tenant.realBranchesCount} '
                      '${tenant.realBranchesCount == 1 ? "sede" : "sedes"}'
                      '${tenant.branchesBreakdown != null ? "  ·  ${tenant.branchesBreakdown}" : ""}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Registrado el ${_formatDate(tenant.createdAt)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ] else
                    Text(
                      '${tenant.ageLabel} · ${tenant.paidPeriodsCount} ${_pluralizeMeses(tenant.paidPeriodsCount)} pagados · ${tenant.formattedTotalPaid} LTV',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (tenant.activeOverridesCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandTintSoft,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '⚙️ ${tenant.activeOverridesCount} ${tenant.activeOverridesCount == 1 ? "límite especial" : "límites especiales"}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandDeep,
                        ),
                      ),
                    ),
                ],
              ),
              if (tenant.isInDebt) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'En mora: ${tenant.formattedDebtAmount}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                      if (tenant.whatsapp != null &&
                          tenant.whatsapp!.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () {
                            final uri = buildWhatsAppUri(
                              tenant.whatsapp!,
                              text: _cobranzaMessage(tenant),
                            );
                            launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(
                            Icons.chat_outlined,
                            size: 14,
                            color: AppColors.danger,
                          ),
                          label: const Text('Cobrar por WhatsApp'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),

              // Fila 3: Botones de Acción Rápida (WhatsApp, Llamar, Modificar Tarifa, Ver Ficha)
              Row(
                children: [
                  if (tenant.whatsapp != null &&
                      tenant.whatsapp!.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        final uri = buildWhatsAppUri(tenant.whatsapp!);
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(
                        Icons.chat_outlined,
                        size: 15,
                        color: AppColors.success,
                      ),
                      label: const Text('WhatsApp'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    OutlinedButton.icon(
                      onPressed: () {
                        final uri = Uri.parse('tel:${tenant.whatsapp}');
                        launchUrl(uri);
                      },
                      icon: const Icon(
                        Icons.phone_outlined,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      label: const Text('Llamar'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // En la columna izquierda del maestro-detalle no hay botones
                  // de gestion: esos viven a la derecha, junto a la ficha que
                  // dice a quien le estas tocando el dinero (D-239).
                  if (compacto)
                    const SizedBox.shrink()
                  else if (isPending && isOwner) ...[
                    FilledButton.icon(
                      onPressed: () => onApprove(tenant),
                      icon: const Icon(Icons.check_circle_outlined, size: 16),
                      label: const Text('Aprobar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    OutlinedButton.icon(
                      onPressed: () => onReject(tenant),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ] else ...[
                    if (isOwner) ...[
                      OutlinedButton.icon(
                        onPressed: () => onUpdatePricing(tenant),
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text('Precio / Plan'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    TextButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('Ver Ficha →'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// FICHA COMPLETA DEL NEGOCIO / TENANT (NIVEL 3 - SEGÚN BOSQUEJO A MANO)
// ============================================================================
class _TenantDetailSheet extends StatefulWidget {
  const _TenantDetailSheet({
    super.key,
    required this.tenant,
    required this.isOwner,
    required this.platformService,
    required this.onApprove,
    required this.onReject,
    required this.onSuspend,
    required this.onReactivate,
    required this.onExtendTrial,
    required this.onUpdatePricing,
    required this.onUpdateContact,
    required this.onViewSupportData,
    required this.onAssignPartner,
    required this.onToggleDemo,
    required this.onDeleteDemo,
    required this.onCerrar,
    this.embebido = false,
  });

  /// Qué hacer al pulsar la X.
  ///
  /// Como hoja emergente es cerrarla; empotrada en el panel derecho es soltar
  /// la selección. **Obligatorio y sin valor por defecto a propósito:** si
  /// fuera opcional y cayera en `Navigator.pop()`, la versión empotrada
  /// cerraría el Panel de Plataforma entero (D-239).
  final VoidCallback onCerrar;

  /// Se dibuja dentro de la columna derecha en vez de flotar sobre todo.
  ///
  /// Quita las esquinas redondeadas de arriba y el tope de altura del 92 %:
  /// empotrada ocupa lo que le den, y una hoja que se queda al 92 % de su
  /// columna deja una franja muerta abajo.
  final bool embebido;

  final PlatformTenantSummary tenant;
  final bool isOwner;
  final PlatformService platformService;
  final ValueChanged<PlatformTenantSummary> onApprove;
  final ValueChanged<PlatformTenantSummary> onReject;
  final ValueChanged<PlatformTenantSummary> onSuspend;
  final ValueChanged<PlatformTenantSummary> onReactivate;
  final ValueChanged<PlatformTenantSummary> onExtendTrial;
  final ValueChanged<PlatformTenantSummary> onUpdatePricing;
  final ValueChanged<PlatformTenantSummary> onUpdateContact;
  final ValueChanged<PlatformTenantSummary> onViewSupportData;
  final ValueChanged<PlatformTenantSummary> onAssignPartner;
  final ValueChanged<PlatformTenantSummary> onToggleDemo;

  /// Borra el negocio y todo lo suyo (D-246). Solo se ensenya en los que
  /// estan marcados como prueba.
  final ValueChanged<PlatformTenantSummary> onDeleteDemo;

  @override
  State<_TenantDetailSheet> createState() => _TenantDetailSheetState();
}

class _TenantDetailSheetState extends State<_TenantDetailSheet> {
  late final Future<List<TenantSubscriptionHistoryEntry>> _historyFuture;
  late Future<List<BranchSubscription>> _branchesFuture;

  /// Que pestana de sede esta abierta (D-241). Se guarda el identificador y no
  /// la sede: `_recargarSedes()` trae objetos nuevos tras cada cambio, y el
  /// guardado seguiria ensenando el precio anterior. Mismo cuidado que la
  /// seleccion de negocio en D-240.
  String? _sedeElegida;

  @override
  void initState() {
    super.initState();
    _historyFuture = widget.platformService.getTenantSubscriptionHistory(
      widget.tenant.tenantId,
    );
    // En initState y no en el build: un FutureBuilder que crea su futuro al
    // construirse lo relanza en cada repintado (D-211).
    _branchesFuture = widget.platformService.getTenantBranches(
      widget.tenant.tenantId,
    );
  }

  void _recargarSedes() {
    setState(() {
      _branchesFuture = widget.platformService.getTenantBranches(
        widget.tenant.tenantId,
      );
    });
  }

  /// Cambia el estado de pago de UNA sede (D-236, paso 9.36).
  ///
  /// La RPC existe desde D-190 y no la llamaba nadie. Sin esto, el precio de
  /// una sede solo se podia tocar escribiendo SQL, y D-222 promete que "las
  /// sedes adicionales van a tarifa vigente" -- imposible de cumplir para los
  /// negocios cuyas sedes heredaron el precio del negocio en el sembrado de
  /// D-190.
  ///
  /// El dialogo muestra el estado, el precio y el motivo REALES. No se
  /// autorellena nada: en D-230 un prellenado generico casi borro un acuerdo
  /// documentado de un cliente.
  Future<void> _editarSede(BranchSubscription sede) async {
    const estados = <String>[
      'pending',
      'trialing',
      'active',
      'past_due',
      'grace',
      'suspended',
      'cancelled',
    ];

    var estado = estados.contains(sede.status) ? sede.status : estados.first;
    // Solo se prellena si hay un precio PACTADO. `precioCop` es el efectivo:
    // sin acuerdo trae el de lista, y prellenarlo haria que guardar sin tocar
    // nada congelara ese precio como si alguien lo hubiera negociado (D-237).
    final precioCtrl = TextEditingController(
      text: sede.tienePrecioPactado ? sede.precioCop.toString() : '',
    );
    // "Precio de lista" es el relleno que pone el servidor cuando NO hay precio
    // pactado. Prellenarlo como si fuera un motivo escrito por alguien seria
    // mentir en el unico campo que documenta el acuerdo.
    final motivoCtrl = TextEditingController(
      text: sede.tienePrecioPactado ? sede.motivoPrecio : '',
    );
    final venceOriginal = sede.currentPeriodEnd;
    var vence = sede.currentPeriodEnd;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Sede: ${sede.branchName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: estado,
                  decoration: const InputDecoration(
                    labelText: 'Estado de pago de la sede',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final e in estados)
                      DropdownMenuItem(value: e, child: Text(e)),
                  ],
                  onChanged: (v) => setModalState(() => estado = v ?? estado),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: precioCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Precio mensual de ESTA sede, en COP',
                    helperText:
                        'Vacio = tarifa vigente del plan. No es el precio del negocio.',
                    helperMaxLines: 2,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: motivoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Motivo del precio *',
                    helperText:
                        'Obligatorio si pones precio. Queda escrito con el acuerdo.',
                    helperMaxLines: 2,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Vence: ${_formatDate(vence)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final elegida = await showDatePicker(
                          context: context,
                          initialDate: vence ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 3),
                          ),
                          helpText: 'Hasta cuando esta pagada esta sede',
                        );
                        if (elegida != null) {
                          setModalState(() => vence = elegida);
                        }
                      },
                      child: const Text('Cambiar fecha'),
                    ),
                  ],
                ),
                if (vence != venceOriginal)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Estás cambiando hasta cuándo está pagada la sede. Eso le regala o le quita días de servicio a un cliente.',
                      style: TextStyle(fontSize: 11, color: AppColors.danger),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (guardar != true || !mounted) return;

    final precioTexto = precioCtrl.text.trim();
    final precio = precioTexto.isEmpty ? null : int.tryParse(precioTexto);
    final motivo = motivoCtrl.text.trim();

    try {
      await widget.platformService.setBranchSubscription(
        branchId: sede.branchId,
        status: estado,
        priceCop: precio,
        priceReason: motivo.isEmpty ? null : motivo,
        periodEnd: vence,
        // Dejar el campo vacio significa "a tarifa vigente", y hace falta
        // decirlo explicitamente: mandar el precio en null NO lo borra
        // (D-237). Solo cuenta si ANTES habia un precio pactado.
        limpiarPrecio: precio == null && sede.tienePrecioPactado,
      );
      if (mounted) _recargarSedes();
    } on PostgrestException catch (error) {
      // El mensaje viene del servidor, que es quien conoce la regla que se
      // incumplio: por ejemplo, precio sin motivo (D-136).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// Las sedes del negocio, en pestañas (D-235, D-241).
  ///
  /// **Por qué pestañas y no una lista.** Hasta D-241 esto era un renglón por
  /// sede con un lápiz al lado: bastaba mientras lo único propio de una sede
  /// fuera su precio. Ahora una sede tiene encargado, contacto y dirección
  /// propios, y apilarlas obliga a bajar por pantallazos para comparar dos.
  /// Con pestañas ves de golpe cuántas hay y **cuál está en mora**, por el
  /// punto de color, sin abrir ninguna.
  ///
  /// Se muestra "al día" y no "activa" porque no son lo mismo: una sede puede
  /// estar operando y en mora. Lo calcula el servidor con la misma regla que
  /// ve el salón en su Configuración (D-190), para que no signifiquen cosas
  /// distintas a cada lado del teléfono.
  Widget _buildSedes() {
    return FutureBuilder<List<BranchSubscription>>(
      future: _branchesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Consultando el estado de las sedes...',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          );
        }
        if (snapshot.hasError) {
          // Sin nombrarle funciones de la base a nadie (D-208).
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'No pudimos consultar el estado de las sedes ahora mismo.',
              style: TextStyle(fontSize: 11, color: AppColors.danger),
            ),
          );
        }

        final sedes = snapshot.data ?? const <BranchSubscription>[];
        if (sedes.isEmpty) return const SizedBox.shrink();
        return _buildFichaDeSede(_sedeVigente(sedes));
      },
    );
  }

  /// La sede elegida **buscada por identificador en cada construcción**.
  ///
  /// No se guarda el objeto: `_recargarSedes()` trae objetos nuevos tras cada
  /// cambio y el guardado seguiría enseñando el precio viejo. Es el mismo
  /// cuidado que la selección de negocio en D-240.
  BranchSubscription _sedeVigente(List<BranchSubscription> sedes) {
    for (final sede in sedes) {
      if (sede.branchId == _sedeElegida) return sede;
    }
    return sedes.first;
  }

  /// Las pestañas de sede, **en la cabecera** (D-244).
  ///
  /// Estaban dentro de una tarjeta, a media ficha. El propietario pidió lo
  /// contrario: *"quisiera tener una lista con las sedes, o botón por sede,
  /// para que debajo me muestre los datos informativos y de pago de la SEDE
  /// seleccionada"*. Arriba y fijas, todo lo de abajo pasa a ser de la sede que
  /// elijas; dentro de una tarjeta eran una sección más entre seis.
  ///
  /// Comparten el mismo `Future` que la ficha, así que no se consulta dos veces.
  Widget _buildPestanasDeSedes() {
    return FutureBuilder<List<BranchSubscription>>(
      future: _branchesFuture,
      builder: (context, snapshot) {
        final sedes = snapshot.data ?? const <BranchSubscription>[];
        if (sedes.isEmpty) return const SizedBox.shrink();
        final elegida = _sedeVigente(sedes);

        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                sedes.length == 1 ? 'SEDE' : 'SEDES',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sede in sedes)
                      _buildPestanaDeSede(
                        sede,
                        sede.branchId == elegida.branchId,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Una pestaña. Lleva el punto de color **antes** del nombre a propósito:
  /// se lee primero el estado y después de quién es, que es el orden en que se
  /// mira una lista de sedes cuando lo que buscas es quién no ha pagado.
  Widget _buildPestanaDeSede(BranchSubscription sede, bool elegida) {
    // `estaAlDia` y no `alDia`: la bandera del servidor no mira la fecha (BI).
    final color = sede.estaAlDia ? AppColors.success : AppColors.danger;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: () => setState(() => _sedeElegida = sede.branchId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: elegida ? AppColors.brandTint : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: elegida ? AppColors.brand : AppColors.border,
            width: elegida ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Icon(
              sede.isPrimary ? Icons.home_outlined : Icons.storefront_outlined,
              size: 14,
              color: elegida ? AppColors.brandDeep : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              sede.branchName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: elegida ? FontWeight.w800 : FontWeight.w600,
                color: elegida ? AppColors.brandDeep : AppColors.textPrimary,
              ),
            ),
            if (!sede.branchActive) ...[
              const SizedBox(width: 5),
              const Text(
                'cerrada',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// La sede elegida, entera. **Esto es lo que pidió el propietario**: no una
  /// fila con un precio, sino la sede con su propia vida — porque en la
  /// realidad tendrá otro encargado, otro teléfono y otra dirección que el
  /// negocio que la contiene (D-241).
  Widget _buildFichaDeSede(BranchSubscription sede) {
    // Hallazgo BI: el 23-sep esta ficha decía *Al día · Pagada hasta 22/09*
    // un día después de vencer. `al_dia` solo mira el estado, y nada lo mueve
    // cuando la fecha pasa.
    final etiqueta = sede.estaAlDia
        ? 'Al día'
        : sede.periodoVencido && sede.alDia
        ? 'Vencida sin pagar'
        : (sede.status == 'pending' ? 'Sin pagar' : 'En mora');
    final color = sede.estaAlDia ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sede.branchName +
                          (sede.isPrimary ? '  ·  sede principal' : ''),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    // De que negocio es. Se repite en cada sede a proposito
                    // (D-243): la columna izquierda ya no lo dice, porque alli
                    // manda el nombre de la persona.
                    Text(
                      widget.tenant.tenantName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Solo el dueño de plataforma. Las dos RPC lo comprueban igual
              // por dentro, pero enseñar un botón que va a rechazar es cruel.
              if (widget.isOwner) ...[
                OutlinedButton.icon(
                  onPressed: () => _editarDatosDeSede(sede),
                  icon: const Icon(Icons.badge_outlined, size: 15),
                  label: const Text('Datos'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.brand,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: () => _editarSede(sede),
                  icon: const Icon(Icons.payments_outlined, size: 15),
                  label: const Text('Pago'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.brand,
                  ),
                ),
              ],
            ],
          ),
          const Divider(height: 18),

          _buildSubsectionLabel('A. Estado de pago DE ESTA SEDE'),
          const SizedBox(height: 6),
          _buildInfoRow('Estado:', etiqueta),
          _buildInfoRow('Cuota mensual:', _formatCop(sede.precioCop)),
          _buildInfoRow(
            'Ese precio es:',
            // No se deduce comparando el texto del motivo: el servidor lo dice
            // (D-237). Una cadena pensada para leerse no decide sobre dinero.
            sede.tienePrecioPactado
                ? 'Un acuerdo — ${sede.motivoPrecio}'
                : 'La tarifa vigente del plan',
          ),
          _buildInfoRow('Pagada hasta:', _formatDate(sede.currentPeriodEnd)),
          _buildInfoRow(
            'Primera activación:',
            sede.nuncaActivada
                ? 'Nunca se ha activado'
                : _formatDate(sede.activatedAt),
          ),

          const Divider(height: 18),
          _buildSubsectionLabel('B. Quién la lleva y dónde está'),
          const SizedBox(height: 6),
          if (!sede.tieneDatosPropios)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Esta sede todavía no tiene datos propios. Hasta ahora solo se '
                'podían guardar los del negocio.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            )
          else ...[
            _buildInfoRow('Encargado:', sede.managerName ?? 'Sin registrar'),
            _buildInfoRow('Correo:', sede.contactEmail ?? 'Sin registrar'),
            _buildInfoRow('Teléfono:', sede.contactPhone ?? 'Sin registrar'),
            _buildInfoRow('WhatsApp:', sede.whatsapp ?? 'Sin registrar'),
            _buildInfoRow('Dirección:', sede.address ?? 'Sin registrar'),
            _buildInfoRow('Ciudad:', sede.city ?? 'Sin registrar'),
            _buildInfoRow('Departamento:', sede.department ?? 'Sin registrar'),
          ],

          const SizedBox(height: 6),
          Text(
            sede.branchActive
                ? 'La sede está abierta y operando.'
                : 'La sede está cerrada. Ojo: cerrada y en mora no son lo mismo '
                      '— esta puede estar pagada igual.',
            style: TextStyle(
              fontSize: 11,
              color: sede.branchActive ? AppColors.textMuted : color,
            ),
          ),
        ],
      ),
    );
  }

  /// Escribe los datos propios de una sede (D-241, paso 9.42).
  ///
  /// **Manda los siete campos siempre.** La RPC no conserva nada: vacío
  /// significa vacío. Es lo contrario de lo que hacía la de precios antes de
  /// D-237, y a propósito — allí `null` conservaba, y por eso se podía poner
  /// un precio y cambiarlo pero nunca quitarlo.
  ///
  /// Por eso el formulario **se prellena con lo que hay de verdad**: si
  /// enseñara menos campos de los que escribe, guardar borraría en silencio lo
  /// que no se ve. En D-230 un prellenado genérico estuvo a un clic de borrar
  /// el acuerdo documentado de un cliente.
  Future<void> _editarDatosDeSede(BranchSubscription sede) async {
    final encargado = TextEditingController(text: sede.managerName ?? '');
    final correo = TextEditingController(text: sede.contactEmail ?? '');
    final telefono = TextEditingController(text: sede.contactPhone ?? '');
    final whatsapp = TextEditingController(text: sede.whatsapp ?? '');
    final direccion = TextEditingController(text: sede.address ?? '');
    final ciudad = TextEditingController(text: sede.city ?? '');
    final departamento = TextEditingController(text: sede.department ?? '');

    Widget campo(
      TextEditingController c,
      String etiqueta, {
      String? ayuda,
      TextInputType? teclado,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: teclado,
          decoration: InputDecoration(
            labelText: etiqueta,
            helperText: ayuda,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }

    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Datos de ${sede.branchName}'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Son los datos de ESTA sede, no los del negocio. Déjalos '
                    'vacíos si no aplican: lo que borres aquí se borra.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                campo(
                  encargado,
                  'Encargado de la sede',
                  ayuda: 'Quien la lleva. Puede no ser el dueño del negocio.',
                ),
                campo(
                  correo,
                  'Correo de la sede',
                  teclado: TextInputType.emailAddress,
                  ayuda: 'Si lo pones, tiene que llevar arroba.',
                ),
                campo(telefono, 'Teléfono', teclado: TextInputType.phone),
                campo(whatsapp, 'WhatsApp', teclado: TextInputType.phone),
                campo(direccion, 'Dirección'),
                campo(ciudad, 'Ciudad'),
                campo(departamento, 'Departamento'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (guardar != true || !mounted) return;

    String? limpio(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    try {
      await widget.platformService.updateBranchInfo(
        branchId: sede.branchId,
        managerName: limpio(encargado),
        contactEmail: limpio(correo),
        contactPhone: limpio(telefono),
        whatsapp: limpio(whatsapp),
        address: limpio(direccion),
        city: limpio(ciudad),
        department: limpio(departamento),
      );
      if (mounted) _recargarSedes();
    } on PostgrestException catch (error) {
      // El mensaje viene del servidor, que es quien conoce la regla que se
      // incumplió: por ejemplo, un correo sin arroba.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    final fecha = _formatDate(local);
    final hora =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$fecha $hora';
  }

  String _formatCop(int cop) => '${formatCOP(cop)} COP';

  String _pluralize(int count, String singular, String plural) =>
      count == 1 ? singular : plural;

  Widget _buildSubsectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenant = widget.tenant;
    final isOwner = widget.isOwner;
    final platformService = widget.platformService;
    final onApprove = widget.onApprove;
    final onReject = widget.onReject;
    final onSuspend = widget.onSuspend;
    final onReactivate = widget.onReactivate;
    final onExtendTrial = widget.onExtendTrial;
    final onUpdatePricing = widget.onUpdatePricing;
    final onUpdateContact = widget.onUpdateContact;
    final onViewSupportData = widget.onViewSupportData;
    final onAssignPartner = widget.onAssignPartner;
    final onToggleDemo = widget.onToggleDemo;
    final onDeleteDemo = widget.onDeleteDemo;

    final status = tenant.subscriptionStatus;
    final isPending = tenant.isPending;

    final embebido = widget.embebido;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: embebido
            ? null
            : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: !embebido,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: embebido
                ? double.infinity
                : MediaQuery.of(context).size.height * 0.92,
          ),
          child: Column(
            children: [
              // Header del Sheet
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      tenant.tenantName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  if (tenant.isFounder)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.brandTint,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.pill,
                                        ),
                                      ),
                                      child: Text(
                                        '★ PIONERO',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.brandDeep,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                'Estado: ${tenant.estadoLegible} · Creado el ${_formatDate(tenant.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: embebido ? 'Soltar este negocio' : 'Cerrar',
                          icon: const Icon(Icons.close),
                          onPressed: widget.onCerrar,
                        ),
                      ],
                    ),
                    // D-244: elegir sede aqui arriba manda sobre todo lo de
                    // abajo. Es lo que pidio el propietario tras verlas
                    // enterradas en una tarjeta a media ficha.
                    _buildPestanasDeSedes(),
                  ],
                ),
              ),

              // Contenido con Scroll
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // TARJETA 1: LA SEDE ELEGIDA ARRIBA.
                    //
                    // Manda sobre la ficha entera (D-244). Antes era la tarjeta
                    // 2 y sus pestanyas vivian dentro; ahora las pestanyas estan
                    // en la cabecera y esto es lo primero que se lee, porque
                    // desde D-239 **es donde vive el dinero**.
                    _buildSectionCard(
                      title: '1. Esta sede',
                      icon: Icons.storefront_outlined,
                      children: [_buildSedes()],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // TARJETA 2: DATOS DEL NEGOCIO (IDENTIFICACIÓN Y CONTACTO)
                    _buildSectionCard(
                      title: '2. Datos del negocio: identificación y contacto',
                      icon: Icons.badge_outlined,
                      children: [
                        _buildSubsectionLabel('A. Contacto Administrativo'),
                        const SizedBox(height: 6),
                        _buildInfoRow('Negocio:', tenant.tenantName),
                        _buildInfoRow(
                          'Tipo de Negocio:',
                          tenant.businessType ?? 'Peluquería / Salón',
                        ),
                        _buildInfoRow(
                          'Contacto Titular:',
                          tenant.contactName ?? 'Sin registrar',
                        ),
                        _buildInfoRow(
                          'WhatsApp:',
                          tenant.whatsapp ?? 'Sin registrar',
                          action: tenant.whatsapp != null
                              ? OutlinedButton.icon(
                                  onPressed: () {
                                    final uri = buildWhatsAppUri(
                                      tenant.whatsapp!,
                                    );
                                    launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.chat_outlined,
                                    size: 14,
                                    color: AppColors.success,
                                  ),
                                  label: const Text('Abrir WhatsApp'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    foregroundColor: AppColors.success,
                                  ),
                                )
                              : null,
                        ),
                        _buildInfoRow('Correo:', tenant.contactEmail),
                        _buildInfoRow(
                          'Teléfono:',
                          tenant.contactPhone ?? 'Sin registrar',
                        ),
                        _buildInfoRow(
                          'Ciudad:',
                          tenant.city ?? 'Sin registrar',
                        ),
                        _buildInfoRow(
                          'Instagram:',
                          tenant.instagram ?? 'Sin registrar',
                        ),
                        _buildInfoRow(
                          'Facebook:',
                          tenant.facebook ?? 'Sin registrar',
                        ),
                        if (isOwner) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () => onUpdateContact(tenant),
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              label: const Text('Editar Contacto'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: AppColors.brand,
                              ),
                            ),
                          ),
                        ],
                        _buildInfoRow(
                          'Negocio de ensayo:',
                          tenant.isDemo
                              ? 'Si. Fuera de las metricas y sin avisos de vencimiento'
                              : 'No. Cuenta como salon real',
                          action: isOwner
                              ? OutlinedButton.icon(
                                  onPressed: () => onToggleDemo(tenant),
                                  icon: Icon(
                                    tenant.isDemo
                                        ? Icons.check_circle_outline
                                        : Icons.science_outlined,
                                    size: 14,
                                  ),
                                  label: Text(
                                    tenant.isDemo
                                        ? 'Quitar la marca'
                                        : 'Marcar como ensayo',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: AppColors.brand,
                                  ),
                                )
                              : null,
                        ),
                        const Divider(height: 24),
                        _buildSubsectionLabel(
                          'B. Capacidad Operativa Real (en vivo)',
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          'Equipo Activo:',
                          '${tenant.realTeamCount} ${_pluralize(tenant.realTeamCount, 'colaborador activo', 'colaboradores activos')}: '
                              '${tenant.teamBreakdown ?? 'Sin colaboradores activos'}',
                        ),
                        _buildInfoRow(
                          'Origen / Registro:',
                          tenant.referralSource ?? 'Registro directo web',
                        ),
                        const Divider(height: 24),
                        _buildSubsectionLabel('C. Partner (D-173)'),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          'Partner Vinculado:',
                          tenant.partnerName ?? 'Sin partner asignado',
                          action: isOwner
                              ? OutlinedButton.icon(
                                  onPressed: () => onAssignPartner(tenant),
                                  icon: const Icon(
                                    Icons.handshake_outlined,
                                    size: 14,
                                  ),
                                  label: Text(
                                    tenant.partnerId == null
                                        ? 'Asignar'
                                        : 'Cambiar',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    foregroundColor: AppColors.brand,
                                  ),
                                )
                              : null,
                        ),
                        if (tenant.referralCodeUsed != null)
                          _buildInfoRow(
                            'Código Usado al Registrarse:',
                            tenant.referralCodeUsed!,
                          ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // TARJETA 3: PLAN Y TARIFA MENSUAL ACTUAL (SEGÚN BOSQUEJO)
                    _buildSectionCard(
                      title: '3. Plan del negocio',
                      icon: Icons.sell_outlined,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Plan Asignado:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    'Plan ${tenant.planNameFormatted}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandTintSoft,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.control,
                                ),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Hallazgo AG. Decía "Precio Mensual
                                  // Fijado", y desde D-239 no fija nada:
                                  // quien cobra es cada sede. El número se
                                  // queda porque sirve para negociar, pero
                                  // rotulado con lo que es.
                                  const Text(
                                    'Acuerdo del negocio:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    tenant.formattedEffectivePrice,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const Text(
                                    'no se cobra',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Hallazgo AG: el aviso que dice dónde vive el dinero
                        // de verdad. Va aquí, pegado al número, y no al pie de
                        // la tarjeta: debajo de los datos parecería una nota.
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.infoTint,
                            borderRadius: BorderRadius.circular(
                              AppRadius.control,
                            ),
                          ),
                          child: Text(
                            tenant.tieneAcuerdo
                                ? 'Este acuerdo es histórico: desde D-239 lo que '
                                      'se cobra es cada sede, con su propio precio. '
                                      'Míralo en la tarjeta de sedes.'
                                : 'Este negocio no tiene acuerdo: sus sedes van a '
                                      'la tarifa vigente del plan. Lo que se cobra '
                                      'es cada sede.',
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (isOwner)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () => onUpdatePricing(tenant),
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              label: const Text('Cambiar plan o etiqueta'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: AppColors.brand,
                              ),
                            ),
                          ),
                        const Divider(height: 20),
                        _buildInfoRow(
                          'Prueba Gratis:',
                          'Desde el ${_formatDate(tenant.createdAt)} hasta el ${_formatDate(tenant.trialEndsAt)}',
                        ),
                        _buildInfoRow(
                          'Periodo Activo:',
                          tenant.currentPeriodEnd != null
                              ? (tenant.isPeriodExpired
                                    ? 'Venció el ${_formatDate(tenant.currentPeriodEnd)} y no se ha renovado'
                                    : 'Válido hasta el ${_formatDate(tenant.currentPeriodEnd)}')
                              : 'Pendiente de primer pago tras finalizar prueba',
                        ),
                        if (tenant.graceEndsAt != null)
                          _buildInfoRow(
                            'Periodo de Gracia:',
                            'Hasta el ${_formatDate(tenant.graceEndsAt)}',
                          ),
                        const Divider(height: 20),
                        _buildInfoRow('Antigüedad:', tenant.ageLabel),
                        _buildInfoRow(
                          'Períodos Pagados:',
                          '${tenant.paidPeriodsCount} ${_pluralize(tenant.paidPeriodsCount, "mes pagado", "meses pagados")}',
                        ),
                        _buildInfoRow(
                          'LTV (total pagado):',
                          '${_formatCop(tenant.totalPaidCop)}${tenant.isFounder ? " · Pionero" : ""}',
                        ),
                        if (tenant.isInDebt)
                          _buildInfoRow(
                            'Estado de Cartera:',
                            'EN MORA · ${_formatCop(tenant.debtAmountCop)} adeudados',
                            action:
                                tenant.whatsapp != null &&
                                    tenant.whatsapp!.isNotEmpty
                                ? OutlinedButton.icon(
                                    onPressed: () {
                                      final nombre =
                                          tenant.contactName ??
                                          tenant.tenantName;
                                      final mensaje =
                                          'Hola $nombre, te escribimos de Salón y Más respecto a la cuenta de '
                                          '"${tenant.tenantName}". Notamos un saldo pendiente de ${_formatCop(tenant.debtAmountCop)}. '
                                          '¿Podemos ayudarte a ponerte al día?';
                                      final uri = buildWhatsAppUri(
                                        tenant.whatsapp!,
                                        text: mensaje,
                                      );
                                      launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.chat_outlined,
                                      size: 14,
                                      color: AppColors.danger,
                                    ),
                                    label: const Text('Cobrar por WhatsApp'),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      foregroundColor: AppColors.danger,
                                    ),
                                  )
                                : null,
                          ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // TARJETA 3: BOTONERA DE GESTIÓN Y ACCIONES
                    _buildSectionCard(
                      title: '4. Acciones de Gestión de Plataforma',
                      icon: Icons.settings_suggest_outlined,
                      children: [
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            if (isPending && isOwner) ...[
                              FilledButton.icon(
                                onPressed: () => onApprove(tenant),
                                icon: const Icon(
                                  Icons.check_circle_outlined,
                                  size: 18,
                                ),
                                label: const Text('Aprobar Negocio'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => onReject(tenant),
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  size: 18,
                                ),
                                label: const Text('Rechazar Solicitud'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                ),
                              ),
                            ],
                            OutlinedButton.icon(
                              onPressed: () => onViewSupportData(tenant),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 18,
                              ),
                              label: const Text('Ver Datos (Soporte)'),
                            ),
                            if (!isPending && isOwner) ...[
                              OutlinedButton.icon(
                                onPressed: () => onUpdatePricing(tenant),
                                icon: const Icon(
                                  Icons.price_change_outlined,
                                  size: 18,
                                ),
                                label: const Text('Cambiar Tarifa / Plan'),
                              ),
                              if (status == 'rejected')
                                FilledButton.icon(
                                  onPressed: () => onApprove(tenant),
                                  icon: const Icon(
                                    Icons.restart_alt_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Reconsiderar / Aprobar'),
                                ),
                              if (status == 'trialing')
                                OutlinedButton.icon(
                                  onPressed: () => onExtendTrial(tenant),
                                  icon: const Icon(
                                    Icons.schedule_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Extender Prueba'),
                                ),
                              if (status != 'suspended' &&
                                  status != 'cancelled' &&
                                  status != 'rejected')
                                OutlinedButton.icon(
                                  onPressed: () => onSuspend(tenant),
                                  icon: const Icon(
                                    Icons.pause_circle_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Suspender'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                  ),
                                ),
                              if (status == 'suspended')
                                OutlinedButton.icon(
                                  onPressed: () => onReactivate(tenant),
                                  icon: const Icon(
                                    Icons.play_circle_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Reactivar'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.success,
                                  ),
                                ),
                            ],
                          ],
                        ),

                        // Zona aparte, y solo para los negocios de prueba
                        // (D-246). Separada del resto a proposito: las demas
                        // acciones se deshacen --suspender, reactivar, cambiar
                        // un precio--; esta no. No deberia estar a un dedo de
                        // distancia de ellas.
                        if (isOwner && tenant.isDemo) ...[
                          const Divider(height: 28),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Negocio de prueba',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.danger,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Puedes borrarlo con todo lo suyo. No se '
                                  'puede deshacer, y solo funciona mientras '
                                  'siga marcado como prueba.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: () => onDeleteDemo(tenant),
                                  icon: const Icon(
                                    Icons.delete_forever_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Borrar negocio de prueba'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: BorderSide(color: AppColors.danger),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // TARJETA 4: HISTORIAL COMPLETO DE TRANSACCIONES Y PERÍODOS
                    _buildSectionCard(
                      title: '5. Historial de Periodos Registrados',
                      icon: Icons.history,
                      children: [
                        FutureBuilder<List<TenantSubscriptionHistoryEntry>>(
                          future: _historyFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Text(
                                'No se pudo cargar el historial: ${snapshot.error}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
                                ),
                              );
                            }

                            final history = snapshot.data ?? const [];
                            if (history.isEmpty) {
                              return const Text(
                                'Sin eventos registrados todavía.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              );
                            }

                            return Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.control,
                                ),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 14,
                                  horizontalMargin: 10,
                                  headingRowHeight: 36,
                                  dataRowMinHeight: 38,
                                  dataRowMaxHeight: 48,
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'Fecha y Hora',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Plan',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Período Comprometido',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Valor / Medio / Ref',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: history.map((entry) {
                                    final periodo =
                                        entry.periodStart != null &&
                                            entry.periodEnd != null
                                        ? '${_formatDate(entry.periodStart)} al ${_formatDate(entry.periodEnd)}'
                                        : (entry.periodEnd != null
                                              ? 'Hasta ${_formatDate(entry.periodEnd)}'
                                              : '—');
                                    final detalle =
                                        entry.paymentDetail ??
                                        entry.description ??
                                        '—';
                                    final valor = entry.amountCop != null
                                        ? '${_formatCop(entry.amountCop!)} · $detalle'
                                        : detalle;
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            _formatDateTime(entry.createdAt),
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            entry.planName ?? '—',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            periodo,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            valor,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // TARJETA 5: LÍMITES Y EXCEPCIONES DEL SALÓN (OVERRIDES)
                    _TenantOverridesCard(
                      tenant: tenant,
                      isOwner: isOwner,
                      platformService: platformService,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.brand),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }
}

// ============================================================================
// TARJETA 5: LÍMITES Y EXCEPCIONES DEL SALÓN (D-172, paso 7.2)
// ============================================================================
class _TenantOverridesCard extends StatefulWidget {
  const _TenantOverridesCard({
    required this.tenant,
    required this.isOwner,
    required this.platformService,
  });

  final PlatformTenantSummary tenant;
  final bool isOwner;
  final PlatformService platformService;

  @override
  State<_TenantOverridesCard> createState() => _TenantOverridesCardState();
}

class _TenantOverridesCardState extends State<_TenantOverridesCard> {
  late Future<List<PlatformTenantFeatureOverride>> _future;

  static const _featureOptions = [
    {'key': 'branches', 'label': 'Sedes'},
    {'key': 'team_members', 'label': 'Cuentas de equipo'},
  ];

  @override
  void initState() {
    super.initState();
    _future = widget.platformService.getTenantFeatureOverrides(
      widget.tenant.tenantId,
    );
  }

  void _reload() {
    setState(() {
      _future = widget.platformService.getTenantFeatureOverrides(
        widget.tenant.tenantId,
      );
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _featureLabel(String key) {
    for (final opt in _featureOptions) {
      if (opt['key'] == key) return opt['label']!;
    }
    return key;
  }

  Future<void> _grantOverride() async {
    String selectedKey = _featureOptions.first['key']!;
    final limitController = TextEditingController();
    final reasonController = TextEditingController();
    DateTime? endsAt;

    final granted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Conceder excepción de límite'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Capacidad:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedKey,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: _featureOptions
                        .map(
                          (opt) => DropdownMenuItem(
                            value: opt['key'],
                            child: Text(opt['label']!),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedKey = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: limitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nuevo límite (número)',
                      hintText: 'Ej. 3',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Motivo (obligatorio)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          endsAt == null
                              ? 'Sin fecha de expiración'
                              : 'Expira el ${_formatDate(endsAt)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                            firstDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 3650),
                            ),
                          );
                          if (picked != null) {
                            setModalState(() => endsAt = picked);
                          }
                        },
                        child: Text(
                          endsAt == null ? 'Elegir fecha' : 'Cambiar',
                        ),
                      ),
                      if (endsAt != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setModalState(() => endsAt = null),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El motivo es obligatorio.')),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Conceder'),
            ),
          ],
        ),
      ),
    );

    if (granted != true) return;

    try {
      await widget.platformService.setTenantFeatureOverride(
        tenantId: widget.tenant.tenantId,
        featureKey: selectedKey,
        enabled: true,
        limitValue: int.tryParse(limitController.text.trim()),
        reason: reasonController.text.trim(),
        endsAt: endsAt,
      );
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Excepción concedida.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo conceder la excepción: $e')),
        );
      }
    }
  }

  Future<void> _revokeOverride(String overrideId) async {
    try {
      await widget.platformService.deleteTenantFeatureOverride(overrideId);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Excepción revocada.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo revocar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, size: 18, color: AppColors.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '6. Límites y Excepciones del Salón (Overrides)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (widget.isOwner)
                  TextButton.icon(
                    onPressed: _grantOverride,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Conceder Excepción'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            FutureBuilder<List<PlatformTenantFeatureOverride>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    'No se pudo cargar: ${snapshot.error}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  );
                }
                final overrides = snapshot.data ?? const [];
                if (overrides.isEmpty) {
                  return const Text(
                    'Sin excepciones registradas. Este negocio usa los límites estándar de su plan.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  );
                }
                return Column(
                  children: overrides.map((o) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: o.isActive
                            ? AppColors.brandTintSoft
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_featureLabel(o.featureKey)}: hasta ${o.limitValue ?? "sin límite"}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  o.reason,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  o.endsAt != null
                                      ? '${o.isActive ? "Vigente" : "Finalizó"} hasta el ${_formatDate(o.endsAt)}'
                                      : (o.isActive
                                            ? 'Vigente sin fecha de expiración'
                                            : 'Finalizada'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: o.isActive
                                        ? AppColors.brandDeep
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.isOwner && o.isActive)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.danger,
                              ),
                              tooltip: 'Revocar',
                              onPressed: () => _revokeOverride(o.overrideId),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PESTAÑA "PARTNERS Y REFERIDOS" (D-173, paso 7.3)
// ============================================================================
class _PartnersTab extends StatefulWidget {
  const _PartnersTab({required this.platformService, required this.isOwner});

  final PlatformService platformService;
  final bool isOwner;

  @override
  State<_PartnersTab> createState() => _PartnersTabState();
}

class _PartnersTabState extends State<_PartnersTab> {
  late Future<PlatformPartnersSummary> _summaryFuture;
  late Future<List<PlatformPartner>> _partnersFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _summaryFuture = widget.platformService.getPartnersSummary();
      _partnersFuture = widget.platformService.listPartners();
    });
  }

  void _openPartnerDetail(PlatformPartner partner) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PartnerDetailSheet(
        partner: partner,
        isOwner: widget.isOwner,
        platformService: widget.platformService,
        onChanged: _reload,
      ),
    );
  }

  Future<void> _copyConsolidatedSummary(PlatformPartnersSummary summary) async {
    final partners = await _partnersFuture;
    final pendientes = partners
        .where((p) => p.pendingCommissionsCop > 0)
        .toList();

    if (!mounted) return;

    if (pendientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay comisiones pendientes por pagar.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final buffer = StringBuffer()
      ..writeln('RESUMEN DE COMISIONES PENDIENTES -- SALÓN Y MÁS')
      ..writeln(
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
      )
      ..writeln('');

    for (final p in pendientes) {
      buffer.writeln(
        '${p.fullName} (${p.referralCode}) -- ${p.payoutChannelLabel}: ${p.payoutAccount} -- ${p.formattedPending}',
      );
    }

    buffer
      ..writeln('')
      ..writeln('Total a transferir: ${summary.formattedPending}');

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resumen consolidado copiado.')),
    );
  }

  Future<void> _showCreatePartnerDialog() async {
    final fullNameController = TextEditingController();
    final documentIdController = TextEditingController();
    final referralCodeController = TextEditingController();
    final phoneController = TextEditingController();
    final whatsappController = TextEditingController();
    final emailController = TextEditingController();
    final payoutAccountController = TextEditingController();
    final valueController = TextEditingController(text: '15');
    final durationMonthsController = TextEditingController();
    final notesController = TextEditingController();

    String payoutChannel = 'bre_b';
    String commissionType = 'percentage';
    String commissionDuration = 'first_payment_only';
    String? error;
    bool isSubmitting = false;

    final createdId = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Nuevo Partner'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (error != null) ...[
                    Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: documentIdController,
                    decoration: const InputDecoration(
                      labelText: 'Cédula / NIT (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: referralCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Código de referido',
                      hintText: 'Ej. CARLOS',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: whatsappController,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Divider(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: payoutChannel,
                    decoration: const InputDecoration(
                      labelText: 'Canal de pago',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'bre_b',
                        child: Text('Llave Bre-B'),
                      ),
                      DropdownMenuItem(
                        value: 'daviplata',
                        child: Text('Daviplata'),
                      ),
                      DropdownMenuItem(value: 'nequi', child: Text('Nequi')),
                      DropdownMenuItem(
                        value: 'bancolombia',
                        child: Text('Bancolombia'),
                      ),
                      DropdownMenuItem(value: 'otro', child: Text('Otro')),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => payoutChannel = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: payoutAccountController,
                    decoration: const InputDecoration(
                      labelText: 'Llave o número de cuenta',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Esquema de comisión',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: commissionType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'percentage',
                              child: Text('Porcentaje'),
                            ),
                            DropdownMenuItem(
                              value: 'fixed_cop',
                              child: Text('Valor fijo COP'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() => commissionType = v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: valueController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: commissionType == 'percentage'
                                ? '%'
                                : '\$ COP',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: commissionDuration,
                    decoration: const InputDecoration(
                      labelText: 'Duración',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'first_payment_only',
                        child: Text('Solo el primer pago'),
                      ),
                      DropdownMenuItem(
                        value: 'first_n_months',
                        child: Text('Primeros N meses'),
                      ),
                      DropdownMenuItem(
                        value: 'recurring_lifetime',
                        child: Text('Recurrente, mientras pague'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setModalState(() => commissionDuration = v);
                      }
                    },
                  ),
                  if (commissionDuration == 'first_n_months') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationMonthsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad de meses',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (fullNameController.text.trim().isEmpty ||
                          referralCodeController.text.trim().isEmpty ||
                          payoutAccountController.text.trim().isEmpty) {
                        setModalState(
                          () => error =
                              'Nombre, código y cuenta de pago son obligatorios.',
                        );
                        return;
                      }
                      setModalState(() {
                        isSubmitting = true;
                        error = null;
                      });
                      try {
                        final id = await widget.platformService.createPartner(
                          fullName: fullNameController.text.trim(),
                          referralCode: referralCodeController.text.trim(),
                          payoutChannel: payoutChannel,
                          payoutAccount: payoutAccountController.text.trim(),
                          documentId: documentIdController.text.trim().isEmpty
                              ? null
                              : documentIdController.text.trim(),
                          phone: phoneController.text.trim().isEmpty
                              ? null
                              : phoneController.text.trim(),
                          whatsapp: whatsappController.text.trim().isEmpty
                              ? null
                              : whatsappController.text.trim(),
                          email: emailController.text.trim().isEmpty
                              ? null
                              : emailController.text.trim(),
                          commissionType: commissionType,
                          commissionValue:
                              double.tryParse(valueController.text.trim()) ??
                              15.0,
                          commissionDuration: commissionDuration,
                          durationMonths: commissionDuration == 'first_n_months'
                              ? int.tryParse(
                                  durationMonthsController.text.trim(),
                                )
                              : null,
                          notes: notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
                        );
                        if (context.mounted) Navigator.of(context).pop(id);
                      } on PostgrestException catch (e) {
                        setModalState(() {
                          isSubmitting = false;
                          error = e.message;
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear Partner'),
            ),
          ],
        ),
      ),
    );

    if (createdId == null) return;
    _reload();

    if (!mounted) return;
    final whatsapp = whatsappController.text.trim();
    final code = referralCodeController.text.trim().toUpperCase();
    final link = '${Uri.base.origin}/?ref=$code';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Partner creado. Enlace: $link'),
        action: whatsapp.isNotEmpty
            ? SnackBarAction(
                label: 'Bienvenida',
                onPressed: () {
                  final mensaje =
                      'Hola ${fullNameController.text.trim()}, ¡bienvenido como Partner de Salón y Más! '
                      'Este es tu enlace para recomendarnos y ganar comisión: $link';
                  launchUrl(
                    buildWhatsAppUri(whatsapp, text: mensaje),
                    mode: LaunchMode.externalApplication,
                  );
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlatformPartnersSummary>(
      future: _summaryFuture,
      builder: (context, summarySnapshot) {
        final summary = summarySnapshot.data ?? PlatformPartnersSummary.empty;

        return Column(
          children: [
            _PartnersKpiRow(summary: summary),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _showCreatePartnerDialog,
                      icon: const Icon(
                        Icons.person_add_alt_1_outlined,
                        size: 18,
                      ),
                      label: const Text('Nuevo Partner'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => _copyConsolidatedSummary(summary),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const Text('Copiar Resumen'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<PlatformPartner>>(
                future: _partnersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'No pudimos cargar los partners.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final partners = snapshot.data ?? const <PlatformPartner>[];
                  if (partners.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Todavía no hay partners registrados.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: partners.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _PartnerCard(
                      partner: partners[index],
                      isOwner: widget.isOwner,
                      platformService: widget.platformService,
                      onTap: () => _openPartnerDetail(partners[index]),
                      onChanged: _reload,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PartnersKpiRow extends StatelessWidget {
  const _PartnersKpiRow({required this.summary});

  final PlatformPartnersSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _PartnerStatChip(
              icon: Icons.groups_outlined,
              label: 'Partners activos',
              value: '${summary.activePartnersCount}',
              color: AppColors.brand,
            ),
            const SizedBox(width: AppSpacing.sm),
            _PartnerStatChip(
              icon: Icons.storefront_outlined,
              label: 'Salones vinculados',
              value: '${summary.linkedTenantsCount}',
              color: AppColors.info,
            ),
            const SizedBox(width: AppSpacing.sm),
            _PartnerStatChip(
              icon: Icons.hourglass_top_outlined,
              label: 'Por pagar',
              value: summary.formattedPending,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.sm),
            _PartnerStatChip(
              icon: Icons.check_circle_outline,
              label: 'Pagado histórico',
              value: summary.formattedPaid,
              color: AppColors.success,
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerStatChip extends StatelessWidget {
  const _PartnerStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partner,
    required this.isOwner,
    required this.platformService,
    required this.onTap,
    required this.onChanged,
  });

  final PlatformPartner partner;
  final bool isOwner;
  final PlatformService platformService;
  final VoidCallback onTap;
  final VoidCallback onChanged;

  Future<void> _settle(BuildContext context) async {
    final result = await showSettlePartnerCommissionsDialog(
      context: context,
      platformService: platformService,
      partner: partner,
    );
    if (result == null) return;

    onChanged();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Liquidado ${result.formattedAmount} (${result.settledCount} comisiones).',
        ),
        action: (partner.whatsapp != null && partner.whatsapp!.isNotEmpty)
            ? SnackBarAction(
                label: 'Notificar',
                onPressed: () {
                  final mensaje =
                      'Hola ${partner.fullName}, te confirmamos el pago de tu comisión de Salón y Más: '
                      '${result.formattedAmount}. ¡Gracias por ser nuestro aliado!';
                  launchUrl(
                    buildWhatsAppUri(partner.whatsapp!, text: mensaje),
                    mode: LaunchMode.externalApplication,
                  );
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      color: partner.active ? AppColors.surface : AppColors.surfaceAlt,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner.fullName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Código: ${partner.referralCode} · ${partner.payoutChannelLabel}: ${partner.payoutAccount}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!partner.active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'INACTIVO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Text(
                  partner.commissionLabel,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${partner.linkedTenantsCount} ${partner.linkedTenantsCount == 1 ? "salón" : "salones"}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const Spacer(),
                  if (partner.pendingCommissionsCop > 0)
                    Text(
                      'Pendiente: ${partner.formattedPending}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
              if (isOwner && partner.pendingCommissionsCop > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _settle(context),
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text('Liquidar Comisiones'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<PlatformPartnerSettlementResult?> showSettlePartnerCommissionsDialog({
  required BuildContext context,
  required PlatformService platformService,
  required PlatformPartner partner,
}) {
  String method = partner.payoutChannel;
  final referenceController = TextEditingController();
  final notesController = TextEditingController();
  bool isSubmitting = false;
  String? error;

  return showDialog<PlatformPartnerSettlementResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => AlertDialog(
        title: Text('Liquidar comisiones de ${partner.fullName}'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Se marcarán como pagadas TODAS sus comisiones pendientes: ${partner.formattedPending}.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                if (error != null) ...[
                  Text(
                    error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Medio de pago',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'bre_b',
                      child: Text('Llave Bre-B'),
                    ),
                    DropdownMenuItem(
                      value: 'daviplata',
                      child: Text('Daviplata'),
                    ),
                    DropdownMenuItem(value: 'nequi', child: Text('Nequi')),
                    DropdownMenuItem(
                      value: 'bancolombia',
                      child: Text('Bancolombia'),
                    ),
                    DropdownMenuItem(value: 'otro', child: Text('Otro')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => method = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Referencia bancaria',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: isSubmitting
                ? null
                : () async {
                    setModalState(() {
                      isSubmitting = true;
                      error = null;
                    });
                    try {
                      final result = await platformService
                          .settlePartnerCommissions(
                            partnerId: partner.partnerId,
                            payoutMethod: method,
                            payoutReference:
                                referenceController.text.trim().isEmpty
                                ? null
                                : referenceController.text.trim(),
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                          );
                      if (context.mounted) Navigator.of(context).pop(result);
                    } on PostgrestException catch (e) {
                      setModalState(() {
                        isSubmitting = false;
                        error = e.message;
                      });
                    }
                  },
            child: isSubmitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirmar Liquidación'),
          ),
        ],
      ),
    ),
  );
}

class _PartnerDetailSheet extends StatefulWidget {
  const _PartnerDetailSheet({
    required this.partner,
    required this.isOwner,
    required this.platformService,
    required this.onChanged,
  });

  final PlatformPartner partner;
  final bool isOwner;
  final PlatformService platformService;
  final VoidCallback onChanged;

  @override
  State<_PartnerDetailSheet> createState() => _PartnerDetailSheetState();
}

class _PartnerDetailSheetState extends State<_PartnerDetailSheet> {
  late Future<PlatformPartnerDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.platformService.getPartnerDetail(widget.partner.partnerId);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.partner.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Código ${widget.partner.referralCode} · ${widget.partner.commissionLabel}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<PlatformPartnerDetail>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('No se pudo cargar: ${snapshot.error}'),
                      );
                    }

                    final detail = snapshot.data!;
                    return ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        _sectionLabel(
                          'Salones vinculados (${detail.linkedTenants.length})',
                        ),
                        const SizedBox(height: 8),
                        if (detail.linkedTenants.isEmpty)
                          const Text(
                            'Todavía no ha traído ningún salón.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          ...detail.linkedTenants.map(
                            (t) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      t.tenantName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    t.subscriptionStatus ?? '—',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        _sectionLabel(
                          'Comisiones (${detail.commissions.length})',
                        ),
                        const SizedBox(height: 8),
                        if (detail.commissions.isEmpty)
                          const Text(
                            'Sin comisiones generadas todavía.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          ...detail.commissions.map(
                            (c) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: c.isPending
                                    ? AppColors.warningTint
                                    : AppColors.successTint,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.control,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.tenantName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          c.isPaid
                                              ? 'Pagada el ${_formatDate(c.paidAt)}${c.payoutReference != null ? " · Ref: ${c.payoutReference}" : ""}'
                                              : 'Generada el ${_formatDate(c.createdAt)}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    c.formattedAmount,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: c.isPending
                                          ? AppColors.warning
                                          : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
