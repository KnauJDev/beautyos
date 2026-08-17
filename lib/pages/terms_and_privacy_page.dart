import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Términos de Servicio y Política de Privacidad / Habeas Data (Paso 3.3).
///
/// Accesible sin sesión desde `?terminos=1` / `?terms=1` y
/// `?privacidad=1` / `?privacy=1` (ver `main.dart`), desde el registro
/// (checkbox obligatorio) y desde el pie de página de Login y Planes.
class TermsAndPrivacyPage extends StatefulWidget {
  const TermsAndPrivacyPage({super.key, this.initialTab = 0});

  /// 0 = Términos de Servicio, 1 = Política de Privacidad.
  final int initialTab;

  @override
  State<TermsAndPrivacyPage> createState() => _TermsAndPrivacyPageState();
}

class _TermsAndPrivacyPageState extends State<TermsAndPrivacyPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == 1 ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandSurface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Términos y Privacidad'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.brand,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.brand,
          tabs: const [
            Tab(text: 'Términos de Servicio'),
            Tab(text: 'Privacidad (Habeas Data)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _LegalDocument(sections: _termsSections),
          _LegalDocument(sections: _privacySections),
        ],
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection(this.title, this.body);

  final String title;
  final String body;
}

class _LegalDocument extends StatelessWidget {
  const _LegalDocument({required this.sections});

  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Última actualización: 17 de agosto de 2026',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final section in sections) ...[
                    Text(
                      section.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      section.body,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppColors.textStrong,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TÉRMINOS DE SERVICIO
// =============================================================================

const _termsSections = <_LegalSection>[
  _LegalSection(
    '1. Aceptación de los términos',
    'Al registrar tu negocio o usar Salón y Más aceptas estos Términos de '
        'Servicio en su totalidad. Si no estás de acuerdo con alguna parte, no '
        'debes usar la plataforma. Si aceptas en nombre de un negocio, declaras '
        'tener la facultad para representarlo.',
  ),
  _LegalSection(
    '2. Qué es Salón y Más',
    'Salón y Más es un software como servicio (SaaS) para la gestión de '
        'centros de estética, barberías, peluquerías y spas en Colombia: agenda, '
        'clientes, equipo, inventario, caja, reportes y reserva pública en línea. '
        'Cada negocio ("tenant") opera de forma aislada y segura dentro de la '
        'plataforma.',
  ),
  _LegalSection(
    '3. Responsabilidad del negocio (tenant)',
    'Cada negocio es el único responsable de la veracidad de la información '
        'que ingresa a la plataforma, de la relación con sus propios clientes y '
        'empleados, del cumplimiento de sus obligaciones legales, tributarias y '
        'laborales frente a ellos, y de mantener la confidencialidad de las '
        'credenciales de acceso de su equipo. Salón y Más no es parte de la '
        'relación comercial entre el negocio y sus clientes finales.',
  ),
  _LegalSection(
    '4. Disponibilidad del servicio',
    'Trabajamos para que la plataforma esté disponible de forma continua, '
        'pero no garantizamos una disponibilidad del 100%. Puede haber '
        'interrupciones por mantenimiento programado, fallas técnicas propias o '
        'de nuestros proveedores de infraestructura, pagos o correo. '
        'Notificaremos los mantenimientos programados con la anticipación '
        'razonable cuando sea posible.',
  ),
  _LegalSection(
    '5. Planes, precios y pagos',
    'El acceso a Salón y Más se ofrece mediante planes de suscripción mensual '
        'cuyos precios y funcionalidades se muestran en la pantalla pública de '
        'planes. Tras el periodo de prueba gratuita, el cobro se procesa de '
        'forma recurrente a través de una pasarela de pago segura (ePayco). Si '
        'un cobro no se completa, tu cuenta entra a un periodo de gracia antes '
        'de suspenderse; puedes reactivarla en cualquier momento poniéndote al '
        'día con tu pago.',
  ),
  _LegalSection(
    '6. Propiedad intelectual',
    'El software, el diseño, la marca "Salón y Más" y el código de la '
        'plataforma son propiedad de Salón y Más y están protegidos por las '
        'leyes de propiedad intelectual. Tu negocio conserva en todo momento la '
        'propiedad de sus propios datos: clientes, citas, catálogo de servicios, '
        'fotos de trabajos y demás información que registres.',
  ),
  _LegalSection(
    '7. No reventa de tus datos',
    'Salón y Más no vende, alquila ni cede a terceros los datos de tu negocio '
        'ni de tus clientes finales para fines publicitarios o comerciales '
        'ajenos a la prestación del servicio. Los datos solo se comparten con '
        'los proveedores estrictamente necesarios para operar la plataforma '
        '(hosting, pagos, correo), descritos en la Política de Privacidad.',
  ),
  _LegalSection(
    '8. Uso aceptable',
    'No está permitido usar la plataforma para actividades ilegales, enviar '
        'contenido ofensivo o fraudulento a través de reseñas o notificaciones, '
        'intentar vulnerar la seguridad del sistema, realizar ingeniería '
        'inversa del software, ni acceder a datos de otro negocio distinto al '
        'propio.',
  ),
  _LegalSection(
    '9. Terminación de la cuenta',
    'Puedes cancelar tu suscripción en cualquier momento. Si tu cuenta se '
        'suspende por falta de pago prolongada, conservamos tu información por '
        'un periodo razonable para permitir la reactivación antes de proceder '
        'según lo dispuesto en nuestra Política de Privacidad.',
  ),
  _LegalSection(
    '10. Limitación de responsabilidad',
    'Salón y Más se ofrece "tal cual" (as is). En la medida permitida por la '
        'ley colombiana, no seremos responsables por pérdidas indirectas, lucro '
        'cesante, ni por decisiones comerciales tomadas por tu negocio con base '
        'en la información de la plataforma.',
  ),
  _LegalSection(
    '11. Cambios a estos términos',
    'Podemos actualizar estos Términos de Servicio para reflejar mejoras del '
        'producto o cambios normativos. Los cambios relevantes se anunciarán '
        'dentro de la plataforma o por correo electrónico con antelación '
        'razonable a su entrada en vigencia.',
  ),
  _LegalSection(
    '12. Ley aplicable y contacto',
    'Estos términos se rigen por las leyes de la República de Colombia. Para '
        'cualquier duda, escríbenos a hola@salonymas.com.',
  ),
];

// =============================================================================
// POLÍTICA DE PRIVACIDAD / HABEAS DATA (LEY 1581 DE 2012)
// =============================================================================

const _privacySections = <_LegalSection>[
  _LegalSection(
    '1. Responsable del tratamiento',
    'Salón y Más es responsable del tratamiento de los datos personales que '
        'se recolectan a través de la plataforma, en los términos de la Ley '
        '1581 de 2012, el Decreto 1377 de 2013 y demás normas que las '
        'modifiquen o reglamenten. Canal de contacto: hola@salonymas.com.',
  ),
  _LegalSection(
    '2. Qué datos recolectamos',
    'Recolectamos datos del negocio y su equipo (nombre, correo, teléfono, '
        'rol), y los datos que cada negocio registra sobre sus propios clientes '
        'finales (nombre, teléfono, historial de citas y servicios) para poder '
        'prestarle el servicio de agenda y gestión. También recolectamos datos '
        'técnicos básicos de uso de la plataforma para monitoreo de errores, '
        'sin incluir información personal identificable en esos registros.',
  ),
  _LegalSection(
    '3. Finalidad del tratamiento',
    'Tus datos se usan para: crear y administrar tu cuenta y la de tu '
        'negocio; prestar las funciones de agenda, clientes, equipo, '
        'inventario y reportes; procesar pagos de la suscripción; enviar '
        'notificaciones operativas (vencimientos, confirmaciones, alertas de '
        'stock) y de soporte; y cumplir obligaciones legales aplicables a '
        'Salón y Más. No usamos tus datos para fines distintos a los aquí '
        'descritos sin tu autorización.',
  ),
  _LegalSection(
    '4. Tus derechos (Derechos ARCO)',
    'Como titular de tus datos personales tienes derecho a: Conocer qué '
        'datos tuyos tenemos; Actualizarlos cuando cambien; Rectificarlos si '
        'son inexactos o incompletos; Suprimirlos cuando ya no exista una '
        'razón legal para conservarlos; y Revocar la autorización que nos '
        'diste para tratarlos, en cualquier momento.',
  ),
  _LegalSection(
    '5. Cómo ejercer tus derechos',
    'Puedes ejercer cualquiera de estos derechos escribiendo a '
        'hola@salonymas.com describiendo tu solicitud. Atenderemos consultas en '
        'un plazo máximo de 10 días hábiles y reclamos en un plazo máximo de '
        '15 días hábiles, según lo establece la Ley 1581 de 2012. Si el plazo '
        'no es suficiente, te informaremos las razones antes de que venza.',
  ),
  _LegalSection(
    '6. Seguridad de la información',
    'Tus datos se almacenan con controles de acceso por negocio (aislamiento '
        'estricto entre tenants) y políticas de seguridad a nivel de base de '
        'datos, de forma que ningún negocio puede ver la información de otro. '
        'La comunicación entre la aplicación y nuestros servidores viaja '
        'cifrada.',
  ),
  _LegalSection(
    '7. Encargados del tratamiento',
    'Para operar la plataforma trabajamos con proveedores que procesan datos '
        'en nuestro nombre, bajo instrucciones limitadas a esa finalidad: '
        'Supabase (hospedaje de la base de datos y autenticación), ePayco '
        '(procesamiento de pagos de la suscripción) y Resend (envío de '
        'correos transaccionales). Ninguno de ellos está autorizado a usar tus '
        'datos para fines propios.',
  ),
  _LegalSection(
    '8. Transferencia y transmisión de datos',
    'Nuestra infraestructura de hospedaje puede procesar datos en servidores '
        'ubicados fuera de Colombia. En esos casos, exigimos a nuestros '
        'proveedores estándares de seguridad y confidencialidad acordes con la '
        'normativa colombiana de protección de datos.',
  ),
  _LegalSection(
    '9. Menores de edad',
    'Salón y Más está dirigido a negocios y a personas mayores de edad. Si un '
        'negocio registra datos de un cliente menor de edad, debe contar con la '
        'autorización de su representante legal, conforme a la ley.',
  ),
  _LegalSection(
    '10. Conservación y retención de datos',
    'Los datos personales se conservarán mientras la cuenta del negocio permanezca '
        'activa y durante el tiempo estrictamente necesario para cumplir con las '
        'finalidades del tratamiento y las obligaciones legales, contables y tributarias '
        'aplicables en Colombia, o hasta que el titular solicite su supresión o revoque '
        'su autorización conforme a la Ley 1581 de 2012.',
  ),
  _LegalSection(
    '11. Almacenamiento local y cookies técnicas',
    'La plataforma web utiliza almacenamiento local en el navegador (localStorage) '
        'exclusivamente para fines técnicos esenciales, como mantener la sesión de usuario '
        'activa de forma segura y recordar preferencias visuales. No utilizamos cookies de '
        'rastreo de terceros con fines publicitarios.',
  ),
  _LegalSection(
    '12. Vigencia y cambios',
    'Esta política rige desde su fecha de publicación. Si la modificamos de '
        'forma sustancial, lo anunciaremos dentro de la plataforma o por '
        'correo electrónico con antelación razonable.',
  ),
  _LegalSection(
    '13. Contacto',
    'Para consultas, reclamos o para ejercer tus derechos de Habeas Data, '
        'escríbenos a hola@salonymas.com. También puedes contactarnos por '
        'WhatsApp desde la sección de Soporte dentro de la plataforma.',
  ),
];
