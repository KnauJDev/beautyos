import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/public_plan.dart';
import '../services/public_plans_service.dart';
import '../theme/app_theme.dart';
import 'login_page.dart';
import 'register_page.dart';

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
            child: TextButton.icon(
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
                        // Tarjetas de Planes
                        if (isMobile)
                          _buildMobilePlansList(plans)
                        else
                          _buildDesktopPlansGrid(plans),

                        const SizedBox(height: 48),

                        // Banner de Garantía / Prueba Gratis
                        _buildTrialGuaranteeBanner(context),

                        const SizedBox(height: 56),

                        // Tabla Comparativa Detallada
                        _buildDetailedComparison(plans),

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
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.card_giftcard_outlined, size: 16, color: AppColors.brandDeep),
                const SizedBox(width: 8),
                Text(
                  '21 DÍAS DE PRUEBA GRATIS · SIN TARJETA DE CRÉDITO',
                  style: TextStyle(
                    color: AppColors.brandDeep,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Planes simples y transparentes\npara hacer crecer tu centro de belleza',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.brandDeep,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: const Text(
              'Agenda inteligente, tickets de venta, control de clientes, comisiones e inventario '
              'diseñados exclusivamente para centros de estética, peluquerías, barberías y spas en Colombia.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: const [
              _HeroCheckItem(label: 'Acompañamiento humano'),
              _HeroCheckItem(label: 'Facturación en pesos COP'),
              _HeroCheckItem(label: 'Sin permanencia mínima'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopPlansGrid(List<PublicPlan> plans) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: plans.map((plan) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _buildPlanCard(plan),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobilePlansList(List<PublicPlan> plans) {
    return Column(
      children: plans.map((plan) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _buildPlanCard(plan),
        );
      }).toList(),
    );
  }

  Widget _buildPlanCard(PublicPlan plan) {
    final isPopular = plan.isPopular;
    final isElite = plan.isElite;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isPopular ? AppColors.brand : AppColors.border,
          width: isPopular ? 2 : 1,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Badge "MÁS ELEGIDO" o "ÉLITE"
          if (isPopular || isElite)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPopular ? AppColors.brand : AppColors.brandDeep,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    isPopular ? '★ MÁS ELEGIDO' : '👑 PLAN ÉLITE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                // Nombre del Plan
                Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isPopular ? AppColors.brand : AppColors.brandDeep,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getPlanTagline(plan.code),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),

                // Precio
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      plan.formattedPrice,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'COP / ${plan.periodLabel}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 20),

                // Resumen de límites clave
                _buildLimitHighlightRow(
                  icon: Icons.storefront_outlined,
                  text: plan.branchesLabel,
                  isBold: true,
                ),
                const SizedBox(height: 10),
                _buildLimitHighlightRow(
                  icon: Icons.people_outline,
                  text: plan.teamMembersLabel,
                  isBold: true,
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 18),

                // Lista de características
                ..._buildPlanFeatureItems(plan),

                const SizedBox(height: 28),
                const Spacer(),

                // Botón CTA
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: isPopular
                      ? FilledButton(
                          onPressed: () => _navigateToRegister(plan.code),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.control),
                            ),
                          ),
                          child: const Text(
                            'Comenzar prueba gratis',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: () => _navigateToRegister(plan.code),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brandDeep,
                            side: const BorderSide(color: AppColors.border, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.control),
                            ),
                          ),
                          child: const Text(
                            'Comenzar prueba gratis',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '21 días gratis · Cancela cuando quieras',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitHighlightRow({
    required IconData icon,
    required String text,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.brandTintSoft,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: AppColors.brand),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPlanFeatureItems(PublicPlan plan) {
    final items = _getPlanKeyFeatures(plan.code);
    return items.map((item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.stateConfirmed,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textStrong,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _getPlanTagline(String code) {
    switch (code.toLowerCase()) {
      case 'basico':
        return 'Para salones o barberías independientes que buscan orden y control total.';
      case 'business':
        return 'Para centros en crecimiento que necesitan controlar stock, compras y rentabilidad.';
      case 'profesional':
        return 'Para marcas consolidadas y cadenas multisede con máxima visibilidad tecnológica.';
      default:
        return 'Gestión integral para tu negocio.';
    }
  }

  List<String> _getPlanKeyFeatures(String code) {
    switch (code.toLowerCase()) {
      case 'basico':
        return [
          'Agenda digital y tickets de cobro',
          'Ficha de clientes e historial',
          'Enlace web de reservas sin cuenta',
          'Cálculo automático de comisiones',
          'Cierre diario de caja por sede',
        ];
      case 'business':
        return [
          'Todo lo del plan Básico',
          'Control completo de inventario y stock',
          'Registro de compras y gastos operativos',
          'Alarmas automáticas de stock bajo',
          'Reportes financieros ampliados por estilista',
        ];
      case 'profesional':
        return [
          'Todo lo del plan Business',
          'Galería de fotos de trabajo por estilista',
          'Página pública de reseñas verificadas',
          'Herramientas de IA y publicación social',
          'Soporte prioritario y onboarding VIP',
        ];
      default:
        return ['Gestión y agenda'];
    }
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

  Widget _buildDetailedComparison(List<PublicPlan> plans) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comparativa detallada de características',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Revisa qué incluye cada nivel para elegir el plan ideal para tu salón.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _buildComparisonRow('Sedes incluidas', '1', 'Hasta 3', 'Ilimitadas'),
          _buildComparisonRow('Cuentas de equipo', 'Hasta 5', 'Hasta 15', 'Ilimitadas'),
          _buildComparisonRow('Agenda y citas ilimitadas', '✓', '✓', '✓'),
          _buildComparisonRow('Enlace público de reservas', '✓', '✓', '✓'),
          _buildComparisonRow('Tickets y cobros diarios', '✓', '✓', '✓'),
          _buildComparisonRow('Fichas y saldo de clientes', '✓', '✓', '✓'),
          _buildComparisonRow('Inventario, compras y gastos', '—', '✓', '✓'),
          _buildComparisonRow('Reportes financieros avanzados', '—', '✓', '✓'),
          _buildComparisonRow('Fotos de trabajos por estilista', '—', '—', '✓'),
          _buildComparisonRow('Reseñas públicas verificadas', '—', '—', '✓'),
          _buildComparisonRow('Herramientas de IA / Redes', '—', '—', '✓'),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String feature, String basico, String business, String profesional) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              basico,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: basico == '—' ? AppColors.textMuted : AppColors.brandDeep,
                fontWeight: basico == '✓' ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              business,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: business == '—' ? AppColors.textMuted : AppColors.brand,
                fontWeight: business == '✓' ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              profesional,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: profesional == '—' ? AppColors.textMuted : AppColors.brandDeep,
                fontWeight: profesional == '✓' ? FontWeight.w900 : FontWeight.w700,
              ),
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
        const Text(
          'Preguntas frecuentes',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildFaqTile(
          question: '¿Cómo funciona la prueba gratis de 21 días?',
          answer:
              'Al registrar tu negocio, tu solicitud entra a revisión humana. '
              'Tus 21 días de prueba empiezan a contar únicamente cuando te contactamos '
              'y activamos tu cuenta. Tienes acceso completo para probar todo el potencial de Salón y Más sin prisas.',
        ),
        _buildFaqTile(
          question: '¿Necesito ingresar tarjeta de crédito para registrarme?',
          answer:
              'No. No te solicitamos tarjeta de crédito ni datos bancarios para comenzar tu prueba. '
              'Solo necesitas los datos básicos de tu negocio.',
        ),
        _buildFaqTile(
          question: '¿Cómo pago mi suscripción al terminar la prueba?',
          answer:
              'Aceptamos todos los medios de pago locales en Colombia (PSE, tarjetas débito/crédito, '
              'y transferencias) a través de pasarela de pago segura con facturación transparente.',
        ),
        _buildFaqTile(
          question: '¿Puedo cambiar de plan o cancelar en cualquier momento?',
          answer:
              'Sí. No existe contrato de permanencia mínima. Puedes subir o ajustar tu plan '
              'a medida que tu equipo o tus sedes crezcan.',
        ),
        _buildFaqTile(
          question: '¿Qué es el beneficio de "Pionero"?',
          answer:
              'Los primeros 25 centros de belleza que se registran y activan con Salón y Más '
              'reciben una tarifa especial de Pionero con un 50% de descuento vitalicio en su suscripción.',
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
        ],
      ),
    );
  }
}

class _HeroCheckItem extends StatelessWidget {
  const _HeroCheckItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline, size: 16, color: AppColors.stateConfirmed),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
