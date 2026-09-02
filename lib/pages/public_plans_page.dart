import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/public_plan.dart';
import '../services/public_plans_service.dart';
import '../theme/app_theme.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'terms_and_privacy_page.dart';

/// Pantalla pública de Planes y Precios de Salón y Más.
/// Accesible sin autenticación (ej. desde salonymas.com/?planes=1 o desde el login).
class PublicPlansPage extends StatefulWidget {
  const PublicPlansPage({
    super.key,
    this.onLoginSuccess,
  });

  final VoidCallback? onLoginSuccess;

  @override
  State<PublicPlansPage> createState() => _PublicPlansPageState();
}

class _PublicPlansPageState extends State<PublicPlansPage> {
  final PublicPlansService _plansService = const PublicPlansService();
  late Future<List<PublicPlan>> _plansFuture;

  static const String _whatsappNumber = '573159780158';

  @override
  void initState() {
    super.initState();
    _plansFuture = _plansService.getPublicPlans();
  }

  Future<void> _openWhatsApp() async {
    final message = Uri.encodeComponent(
      'Hola equipo de Salón y Más 👋\n'
      'Estuve viendo los planes y precios en la web y me gustaría recibir asesoría para mi negocio. ¡Gracias!',
    );
    final url = Uri.parse('https://wa.me/$_whatsappNumber?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _navigateToRegister([String? planCode]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterPage(
          onRegisterSuccess: () {
            Navigator.of(context).pop();
            widget.onLoginSuccess?.call();
          },
        ),
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          onLoginSuccess: () {
            Navigator.of(context).pop();
            widget.onLoginSuccess?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final hasActiveSession = Supabase.instance.client.auth.currentSession != null;

    return Scaffold(
      backgroundColor: AppColors.brandSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text(
                'S+',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Salón y Más',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.brandDeep,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Hablar con soporte por WhatsApp',
            onPressed: _openWhatsApp,
            icon: const Icon(Icons.chat_outlined, color: AppColors.whatsapp),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: hasActiveSession
                ? TextButton.icon(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        // Si entró directo por URL, refrescar sin ?planes
                        widget.onLoginSuccess?.call();
                      }
                    },
                    icon: const Icon(Icons.dashboard_outlined, size: 18),
                    label: const Text('Ir a mi negocio'),
                  )
                : TextButton.icon(
                    onPressed: _navigateToLogin,
                    icon: const Icon(Icons.login_outlined, size: 18),
                    label: const Text('Iniciar sesión'),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. HERO HEADER
            _buildHeroHeader(context),

            // 2. CONTENIDO PRINCIPAL: PLANES
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 32,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: FutureBuilder<List<PublicPlan>>(
                  future: _plansFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(64),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final plans = snapshot.data ?? PublicPlansService.fallbackPlans;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // La tarjeta unica del plan (D-188). Antes habia
                        // tres columnas comparativas; con un solo plan, una
                        // tabla comparando contra uno mismo no dice nada.
                        _buildPlanHero(
                          plans.isEmpty
                              ? PublicPlansService.fallbackPlans.single
                              : plans.first,
                          isMobile,
                        ),

                        const SizedBox(height: 48),

                        // Banner de Garantía / Prueba Gratis
                        _buildTrialGuaranteeBanner(context),

                        const SizedBox(height: 56),

                        // Comparativa contra el incumbente
                        _buildComparativaAgendaPro(),

                        const SizedBox(height: 56),

                        // Preguntas Frecuentes (FAQ)
                        _buildFaqSection(),

                        const SizedBox(height: 64),
                      ],
                    );
                  },
                ),
              ),
            ),

            // 3. PIE DE PÁGINA
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 32,
        vertical: isMobile ? 40 : 64,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandSurface, Colors.white],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'UN SOLO PLAN. SIN LETRA MENUDA.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.brandDark,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Todo lo que tu salon necesita,\nen un solo plan por sede',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMobile ? 28 : 40,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandDeep,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Agenda, caja, comisiones, inventario, reportes, fotos de '
                'trabajos, resenas y tu pagina web publica. Todo, desde el '
                'primer dia. Pagas por sede, no por funciones.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// La tarjeta unica del plan (D-188).
  ///
  /// Sustituye a las tres columnas comparativas: cuando solo hay un plan, una
  /// tabla de comparacion contra uno mismo no dice nada. Lo que hay que
  /// responder aqui es "cuanto" y "que entra", en ese orden.
  Widget _buildPlanHero(PublicPlan plan, bool isMobile) {
    final lista = plan.priceCop;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.brand, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.10),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
                child: const Text(
                  'PRECIO PIONERO, SOLO PARA LOS PRIMEROS 25 SALONES',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(isMobile ? 24 : 36),
                child: Column(
                  children: [
                    Text(
                      plan.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '\$',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                        Text(
                          '80.000',
                          style: TextStyle(
                            fontSize: isMobile ? 46 : 58,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'por sede, al mes',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          '\$${_milesConPunto(lista)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successTint,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Ahorras 33% de por vida',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Cero limites',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandDeep,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._incluido.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  height: 1.4,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _navigateToRegister(plan.code),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: const Text(
                          'Empezar mi prueba de 21 dias',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sin tarjeta de credito. Te acompanamos a configurarlo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
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

  static const List<String> _incluido = [
    'Estilistas y cuentas de equipo ilimitados',
    'Clientas, citas y tickets sin tope',
    'Caja, cobros, abonos y comisiones automaticas',
    'Inventario, compras y gastos',
    'Reportes financieros y arqueo de caja',
    'Fotos de trabajos, sin limite de fotos',
    'Resenas verificadas de tus clientas',
    'Tu pagina web publica con reserva en linea',
  ];

  /// 120000 -> "120.000". Sin dependencias: es el unico sitio de esta pantalla
  /// que formatea dinero y no vale la pena traerse el formateador entero.
  String _milesConPunto(int valor) {
    final digitos = valor.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      final restantes = digitos.length - i;
      buffer.write(digitos[i]);
      if (restantes > 1 && restantes % 3 == 1) buffer.write('.');
    }
    return buffer.toString();
  }
  Widget _buildTrialGuaranteeBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.handshake_outlined, size: 28, color: AppColors.brand),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nuestra promesa: "Nadie entra solo"',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Al registrarte, tu prueba no empieza a correr hasta que nuestro equipo te da la bienvenida '
                  'y te ayuda a configurar tus servicios y tu agenda. Cuentas con nosotros en cada paso.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// La comparacion que de verdad importa en la primera visita (D-188).
  ///
  /// Los precios de AgendaPro salen del benchmarking del 28-jul, hecho con una
  /// cuenta de prueba real, no de su publicidad. **Su plan de entrada es mas
  /// barato que el nuestro**, y se ensena igual: el que trae lo mismo que
  /// nosotros cuesta mas de cuatro veces. Ensenar las dos cifras es mas
  /// honesto, y mas convincente, que ensenar solo la que nos favorece.
  Widget _buildComparativaAgendaPro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comparalo con lo que hay',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.brandDeep,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Precios de AgendaPro en Colombia, tomados de una cuenta de prueba '
          'real en julio de 2026.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _filaComparativa(
                titulo: 'AgendaPro, plan de entrada',
                precio: '\$99.000',
                detalle: 'Sin inventario ni reportes avanzados.',
                destacada: false,
              ),
              const Divider(height: 1),
              _filaComparativa(
                titulo: 'AgendaPro, plan completo',
                precio: '\$510.000',
                detalle: 'Lo mas parecido a lo que aqui viene de serie.',
                destacada: false,
              ),
              const Divider(height: 1),
              _filaComparativa(
                titulo: 'Salon y Mas, Todo Incluido',
                precio: '\$120.000',
                detalle:
                    'Todo lo de arriba, por sede. \$80.000 si entras como pionero.',
                destacada: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Y una diferencia que no cabe en la tabla: cuando algo se traba '
                'un sabado a las 3 de la tarde, aqui te contesta por WhatsApp '
                'quien hizo el programa, en tu misma hora.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filaComparativa({
    required String titulo,
    required String precio,
    required String detalle,
    required bool destacada,
  }) {
    return Container(
      color: destacada ? AppColors.brandTintSoft : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: destacada ? FontWeight.w800 : FontWeight.w600,
                    color: destacada
                        ? AppColors.brandDeep
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detalle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            precio,
            style: TextStyle(
              fontSize: destacada ? 22 : 18,
              fontWeight: FontWeight.w800,
              color: destacada ? AppColors.brand : AppColors.textStrong,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildFaqSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preguntas frecuentes',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.brandDeep,
          ),
        ),
        const SizedBox(height: 20),
        _buildFaqTile(
          question: 'De verdad, no hay modulos bloqueados?',
          answer:
              'No hay. Antes teniamos tres planes y cada uno escondia cosas: '
              'el pequeno se quedaba sin inventario, sin reportes y sin fotos. '
              'Nos parecio mezquino y lo quitamos. Hoy pagas por sede y tienes '
              'el programa completo desde el primer dia.',
        ),
        _buildFaqTile(
          question: 'Que pasa si abro una segunda sede?',
          answer:
              'Puedes crearla cuando quieras. Cada sede activa suma su cuota '
              'mensual, asi que solo pagas mas cuando tu negocio ya crecio. Si '
              'cierras una sede, dejas de pagarla.',
        ),
        _buildFaqTile(
          question: 'Hay limite de estilistas, de clientas o de fotos?',
          answer:
              'No. Ni de estilistas, ni de cuentas de equipo, ni de clientas, '
              'ni de citas, ni de fotos de trabajos. Lo que se cobra es la '
              'sede, no lo que hagas dentro de ella.',
        ),
        _buildFaqTile(
          question: 'Que es el precio pionero y hasta cuando dura?',
          answer:
              'Los primeros 25 salones pagan 80.000 por sede en vez de '
              '120.000, y ese precio se les congela mientras sigan activos. '
              'No son seis meses: es de por vida.',
        ),
        _buildFaqTile(
          question: 'Tengo que poner una tarjeta para probarlo?',
          answer:
              'No. La prueba de 21 dias no pide tarjeta. Y antes de la prueba '
              'hablamos contigo: no dejamos entrar a nadie sin acompanarlo a '
              'configurar sus servicios, su equipo y su horario.',
        ),
        _buildFaqTile(
          question: 'Como pago y desde donde?',
          answer:
              'Por ePayco, con PSE, Nequi, Daviplata o tarjeta, desde la misma '
              'aplicacion. La factura queda registrada en tu cuenta.',
        ),
        _buildFaqTile(
          question: 'Y si quiero irme?',
          answer:
              'Dejas de pagar y ya. No hay clausula de permanencia ni multa. '
              'Tus datos son tuyos y te los entregamos si los pides.',
        ),
      ],
    );
  }
  Widget _buildFaqTile({required String question, required String answer}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Text(
            answer,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          Text(
            '¿Tienes dudas específicas sobre qué plan se adapta a tu salón?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.brandDeep,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openWhatsApp,
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('Hablar con un asesor por WhatsApp'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.whatsapp,
              side: const BorderSide(color: AppColors.whatsapp),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Salón y Más © 2026 · Software de gestión para centros de estética, barberías y spas en Colombia.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TermsAndPrivacyPage(initialTab: 0),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: const Text('Términos de Servicio'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TermsAndPrivacyPage(initialTab: 1),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: const Text('Política de Privacidad'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

