import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/my_profile.dart';
import 'models/branch_context.dart';
import 'models/pending_invitation.dart';
import 'models/tenant_entitlements.dart';
import 'models/tenant_subscription_status.dart';
import 'services/branch_context_service.dart';
import 'services/entitlements_service.dart';
import 'models/aviso_de_pago.dart';
import 'services/epayco_checkout_service.dart';
import 'services/monitoreo_service.dart';
import 'services/sesion_supabase.dart';
import 'services/my_profile_service.dart';
import 'services/team_invitations_service.dart';
import 'services/tenant_subscription_service.dart';

import 'pages/accept_invitation_page.dart';
import 'pages/auth_gate.dart';
import 'pages/authenticated_router.dart';
import 'pages/complete_tenant_setup_page.dart';
import 'pages/public_booking_page.dart';
import 'pages/public_partner_page.dart';
import 'pages/public_plans_page.dart';
import 'pages/public_review_page.dart';
import 'pages/public_salon_page.dart';
import 'pages/tenant_approval_status_page.dart';
import 'pages/terms_and_privacy_page.dart';
import 'pages/agenda_page.dart';
import 'pages/blog_page.dart';
import 'pages/clients_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/inventory_page.dart';
import 'pages/my_commission_summary_page.dart';
import 'pages/my_stylist_agenda_page.dart';
import 'pages/my_stylist_reviews_page.dart';
import 'pages/my_stylist_work_photos_page.dart';
import 'pages/plan_locked_page.dart';
import 'pages/work_photos_page.dart';
import 'widgets/security_settings_dialog.dart';
import 'theme/app_theme.dart';
import 'widgets/update_banner.dart';
import 'pages/reviews_page.dart';
import 'pages/purchases_page.dart';
import 'pages/expenses_page.dart';
import 'pages/reports_page.dart';
import 'pages/settings_page.dart';
import 'pages/services_page.dart';
import 'pages/stylists_page.dart';
import 'pages/tickets_page.dart';
import 'pages/users_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://eogppgbdnwxdtcbctaol.supabase.co',
    publishableKey: 'sb_publishable_3MOOddcfu6tga68hPr06gw_IdEJ74Pc',
  );

  // El monitoreo envuelve a la aplicacion entera para poder capturar tambien
  // lo que se rompa al arrancar (D-115). Configurado para **no enviar ningun
  // dato personal**: ver `MonitoreoService`.
  await MonitoreoService.arrancar(() => const BeautyOSApp());
}

class BeautyOSApp extends StatelessWidget {
  const BeautyOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Reserva publica (D-005): enlace sin sesion, ej. "?reservar=<branch_id>".
    // Se resuelve antes de AuthGate a proposito: un cliente anonimo nunca
    // debe pasar por la pantalla de login para reservar.
    final publicBranchId = Uri.base.queryParameters['reservar'];
    // Resena publica (D-058): enlace sin sesion, ej. "?resena=<ticket_id>".
    // Mismo motivo: un cliente anonimo nunca debe pasar por login.
    final publicReviewTicketId = Uri.base.queryParameters['resena'];
    // Planes publicos (Paso 3.8 / D-140): enlace sin sesion, ej. "?planes=1".
    final isPublicPlans =
        Uri.base.queryParameters.containsKey('planes') ||
        Uri.base.queryParameters.containsKey('pricing');
    // Terminos y Privacidad (Paso 3.3): enlace sin sesion, ej. "?terminos=1"
    // o "?privacidad=1". Cada uno abre directo en su pestana.
    final isPublicTerms =
        Uri.base.queryParameters.containsKey('terminos') ||
        Uri.base.queryParameters.containsKey('terms');
    final isPublicPrivacy =
        Uri.base.queryParameters.containsKey('privacidad') ||
        Uri.base.queryParameters.containsKey('privacy');
    // Postulación pública de Partners (Paso 7.3 / D-173): enlace sin sesión,
    // ej. "?partners=1". Mismo motivo que las rutas de arriba.
    final isPublicPartners = Uri.base.queryParameters.containsKey('partners');
    // Pagina publica del negocio por slug (D-098 / D-164): sin sesion, ej.
    // "salonymas.com/naguaradeunas" o, de respaldo, "?salon=<slug>". Mismo
    // motivo que las rutas de arriba: un visitante anonimo nunca debe pasar
    // por login para ver la vitrina de un negocio.
    //
    // Esta lista de rutas reservadas debe coincidir con la del CHECK
    // `tenants_slug_format_check` y las funciones `check_slug_availability`/
    // `update_tenant_slug` en la migracion de D-164 (buscar 'login',
    // 'register', 'auth' ahi para encontrarlas).
    final pathSegments = Uri.base.pathSegments;
    final pathSlug =
        pathSegments.length == 1 && pathSegments.first.trim().isNotEmpty
        ? pathSegments.first.trim().toLowerCase()
        : null;
    final queryParamSlug = Uri.base.queryParameters['salon']
        ?.trim()
        .toLowerCase();
    const rutasReservadas = <String>{
      'login',
      'register',
      'auth',
      'planes',
      'pricing',
      'terminos',
      'privacidad',
      'terms',
      'privacy',
      'admin',
      'dashboard',
      'settings',
      'soporte',
      'api',
      'partners',
    };
    final candidateSlug =
        (pathSlug != null && !rutasReservadas.contains(pathSlug))
        ? pathSlug
        : (queryParamSlug != null && queryParamSlug.isNotEmpty
              ? queryParamSlug
              : null);

    // Un solo sitio decide el aspecto de toda la aplicacion (D-102). El tema
    // del negocio no se conoce al arrancar -- llega con los datos de la sede o
    // de la reserva publica --, asi que `MaterialApp` se reconstruye cuando
    // `AppBrand.aplicar()` cambia la paleta (D-109).
    return ValueListenableBuilder<BrandPalette>(
      valueListenable: AppBrand.activo,
      builder: (context, palette, _) {
        final Widget home;
        if (publicBranchId != null && publicBranchId.trim().isNotEmpty) {
          home = PublicBookingPage(branchId: publicBranchId.trim());
        } else if (publicReviewTicketId != null &&
            publicReviewTicketId.trim().isNotEmpty) {
          home = PublicReviewPage(ticketId: publicReviewTicketId.trim());
        } else if (isPublicPlans) {
          home = const PublicPlansPage();
        } else if (isPublicTerms) {
          home = const TermsAndPrivacyPage(initialTab: 0);
        } else if (isPublicPrivacy) {
          home = const TermsAndPrivacyPage(initialTab: 1);
        } else if (isPublicPartners || pathSlug == 'partners') {
          home = const PublicPartnerPage();
        } else if (candidateSlug != null) {
          home = PublicSalonPage(slug: candidateSlug);
        } else {
          home = const AuthGate(
            authenticatedChild: AuthenticatedRouter(
              businessApp: BeautyOSHome(),
            ),
          );
        }

        return MaterialApp(
          title: 'Salón y Más',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: home,
        );
      },
    );
  }
}

class BeautyOSHome extends StatefulWidget {
  const BeautyOSHome({super.key});

  @override
  State<BeautyOSHome> createState() => _BeautyOSHomeState();
}

class _HomeContextData {
  const _HomeContextData({
    required this.profile,
    required this.branches,
    this.pendingInvitation,
    this.subscriptionStatus,
    this.entitlements = const TenantEntitlements.desconocido(),
  });

  final MyProfile? profile;
  final List<BranchContext> branches;
  final PendingInvitation? pendingInvitation;
  final TenantSubscriptionStatus? subscriptionStatus;

  /// Lo que el plan del negocio permite (TL-19, D-184). Por defecto,
  /// `desconocido()`, que no bloquea nada.
  final TenantEntitlements entitlements;
}

class _BeautyOSHomeState extends State<BeautyOSHome> {
  int selectedIndex = 0;

  /// Modulos que el usuario ya ha abierto en esta sesion, por indice
  /// (TL-10, D-201).
  ///
  /// Antes de esto, `IndexedStack` construia **los 16 modulos a la vez** al
  /// entrar: 16 `initState`, 16 consultas a Supabase, y las 15 pantallas que
  /// nadie estaba mirando cargadas en memoria. Ahora un modulo solo se
  /// construye cuando se entra en el por primera vez; hasta entonces su hueco
  /// en la pila es un `SizedBox.shrink()`.
  ///
  /// Arranca con el indice 0 porque es el que se ensena al abrir sesion.
  final Set<int> _modulosAbiertos = <int>{0};

  /// Cuantas veces se ha entrado a cada modulo, por indice (Hallazgo Q,
  /// D-201).
  ///
  /// Este contador viaja dentro de la llave del `KeyedSubtree` que envuelve
  /// cada pagina: al cambiar, Flutter desmonta el subarbol y lo vuelve a
  /// montar, o sea que `initState` corre otra vez y la pagina recarga sus
  /// datos. Es **el mismo mecanismo que el proyecto ya usaba** para el cambio
  /// de sede -- 17 de los 19 modulos llevan `ValueKey('...-branchId')` desde
  /// antes de este bloque -- aplicado ahora tambien al entrar.
  final Map<int, int> _visitasPorModulo = <int, int>{};

  /// Ticket que Agenda pidio abrir en la pestana de Tickets (D-163). Se
  /// consume una sola vez: `TicketsPage` avisa con `onTicketOpened` y este
  /// campo vuelve a null para no reabrir el mismo ticket despues.
  String? _pendingOpenTicketId;

  /// Igual que `_pendingOpenTicketId`, pero para el boton "Cobrar" de la
  /// tarjeta de Agenda: abre el dialogo de pago directo en vez de la Ficha
  /// Completa (bloque de velocidad de mostrador).
  String? _pendingCollectTicketId;

  final MyProfileService myProfileService = const MyProfileService();
  final BranchContextService branchContextService =
      const BranchContextService();
  final TeamInvitationsService teamInvitationsService =
      const TeamInvitationsService();
  final TenantSubscriptionService tenantSubscriptionService =
      const TenantSubscriptionService();
  final EpaycoCheckoutService epaycoService = const EpaycoCheckoutService();
  final EntitlementsService entitlementsService = const EntitlementsService();

  late Future<_HomeContextData> homeContextFuture;
  BranchContext? selectedBranch;

  /// Aviso que hay que ensenar al volver de la pasarela (D-200).
  ///
  /// Lo escribe `_loadHomeContext`, que corre desde `initState` y por
  /// tanto no puede tocar un `ScaffoldMessenger` todavia: en ese momento
  /// no hay `Scaffold` montado. Se guarda aqui y `build` lo consume una
  /// sola vez, ya con el arbol en pie.
  AvisoDePago? _avisoDePagoPendiente;

  @override
  void initState() {
    super.initState();
    homeContextFuture = _loadHomeContext();
  }

  Future<_HomeContextData> _loadHomeContext() async {
    // Si la URL contiene una confirmación de pago de ePayco (ej. ?ref_payco=...), verificarla.
    //
    // **D-200: el resultado ya no se tira.** Antes esta llamada no dejaba
    // rastro en la pantalla ni cuando iba bien ni cuando iba mal: el dueño
    // acababa de pagar $150.000 y volvía a una aplicación muda. Ahora se
    // traduce a un aviso y `build` lo enseña en cuanto hay árbol montado.
    //
    // El `catch` sigue sin propagar **a propósito, y no es un catch ciego
    // como el de TL-16**: la vía autoritativa de activación es el webhook
    // (D-141), así que un fallo aquí no es un pago perdido. Se reporta a
    // monitoreo para que quede rastro, y al dueño se le dice la verdad --
    // que se está validando-- en vez de un error que no le corresponde.
    final refPayco = Uri.base.queryParameters['ref_payco'];
    if (refPayco != null && refPayco.isNotEmpty) {
      try {
        final respuesta = await Supabase.instance.client.functions.invoke(
          'verify-epayco-transaction',
          // Token fresco (D-207): esta funcion exige sesion desde D-181, y
          // con el token vencido devolvia 401. Aqui el fallo era blando --se
          // convierte en "estamos validando tu pago" (D-200)-- asi que el
          // dueno se quedaba sin confirmacion y nadie sabia por que.
          headers: await cabecerasParaEdgeFunction(),
          body: {'ref_payco': refPayco},
        );
        _avisoDePagoPendiente = AvisoDePago.desdeLaPasarela(respuesta.data);
      } catch (e, st) {
        MonitoreoService.reportarError(
          e,
          st,
          motivo: 'Fallo al verificar confirmación ePayco $refPayco',
        );
        _avisoDePagoPendiente = AvisoDePago.enValidacion();
      }
    }

    final profile = await myProfileService.getMyProfile();

    if (profile == null) {
      final pendingInvitation = await teamInvitationsService
          .getMyPendingInvitation();
      return _HomeContextData(
        profile: null,
        branches: const [],
        pendingInvitation: pendingInvitation,
      );
    }

    // Consultar estado de aprobación / suscripción del negocio (D-125)
    final subscriptionStatus = await tenantSubscriptionService
        .getMyTenantSubscriptionStatus();

    if (subscriptionStatus != null &&
        (subscriptionStatus.isPending || subscriptionStatus.isRejected)) {
      return _HomeContextData(
        profile: profile,
        branches: const [],
        subscriptionStatus: subscriptionStatus,
      );
    }

    final branches = await branchContextService.getAccessibleBranches();

    // Que permite el plan (TL-19, D-184). Nunca lanza: si quien pregunta no
    // tiene membresia de negocio -- el dueno de la plataforma, la clienta
    // final -- devuelve `desconocido()` y no se bloquea nada.
    final entitlements = await entitlementsService.getMyEntitlements();

    // Quien y de que negocio, sin decir nombres (D-115). Sirve para saber si un
    // fallo le pasa a una persona o a un negocio entero.
    await MonitoreoService.anotarContexto(
      userId: Supabase.instance.client.auth.currentUser?.id,
      rol: profile.role,
      tenantId: branches.isEmpty ? null : branches.first.tenantId,
    );

    if (branches.isNotEmpty) {
      final inicial = _initialBranch(branches);
      AppBrand.aplicar(inicial.tenantThemeKey, inicial.tenantBrandColor);
    }

    return _HomeContextData(
      profile: profile,
      branches: branches,
      subscriptionStatus: subscriptionStatus,
      entitlements: entitlements,
    );
  }

  Future<void> signOut() async {
    AppBrand.aplicar(null, null);
    await MonitoreoService.olvidarContexto();
    await Supabase.instance.client.auth.signOut();
  }

  /// **El unico sitio que cambia de pestana** (TL-10 y Hallazgo Q, D-201).
  ///
  /// Antes habia cuatro: los dos menus, el salto de Agenda a Tickets (D-163 y
  /// D-195) y `_irAModulo` (D-168). Cada uno escribia `selectedIndex` por su
  /// cuenta. Con la carga perezosa y el refresco al entrar eso deja de valer:
  /// un camino que se olvide de marcar el modulo como abierto deja la pantalla
  /// en blanco, y uno que se olvide de contar la visita deja los datos viejos.
  /// **Si aparece un quinto camino, tiene que pasar por aqui**; hay una prueba
  /// que lo vigila.
  void _irAIndice(int index) {
    setState(() {
      selectedIndex = index;
      _modulosAbiertos.add(index);
      _visitasPorModulo[index] = (_visitasPorModulo[index] ?? 0) + 1;
    });
  }

  /// Cambia de pestaña buscando el módulo por su título (D-168). Se busca
  /// dinámicamente en vez de fijar un índice: a diferencia de D-163 (que
  /// SÍ podía apoyarse en que Agenda y Tickets son siempre adyacentes),
  /// aquí el llamador puede ser cualquiera de los tres, y fijar tres
  /// índices distintos a mano es más frágil que buscarlos por nombre.
  void _irAModulo(List<BeautyModule> modules, String titulo) {
    final index = modules.indexWhere((m) => m.section.title == titulo);
    if (index == -1) return;
    _irAIndice(index);
  }

  List<BeautyModule> _modulesForProfile(
    MyProfile? profile,
    BranchContext branch,
    List<BranchContext> branches,
    TenantEntitlements entitlements,
  ) {
    final role = profile?.role ?? 'client';

    // Declarada aparte de su valor (D-168): el Dashboard necesita cerrar
    // sobre `modules` en sus callbacks de navegación (_irAModulo), y Dart no
    // permite que una variable se referencie dentro de su propio
    // inicializador aunque sea desde un closure que se ejecuta después.
    late final List<BeautyModule> modules;
    modules = <BeautyModule>[
      // ======================================================================
      // 1. OPERACIÓN DIARIA (La recepcionista y la dueña trabajan aquí)
      // ======================================================================
      BeautyModule(
        section: const BeautySection(
          'Agenda',
          Icons.calendar_month_outlined,
          category: BeautyCategory.operacion,
        ),
        page: AgendaPage(
          key: ValueKey('agenda-${branch.branchId}'),
          branchId: branch.branchId,
          businessName: branch.tenantName,
          // Agenda y Tickets comparten exactamente los mismos allowedRoles
          // y son adyacentes en esta lista: Tickets siempre queda en el
          // indice inmediatamente siguiente al de Agenda, para cualquier
          // rol que vea Agenda (D-163).
          onOpenTicket: (ticketId) {
            setState(() => _pendingOpenTicketId = ticketId);
            _irAIndice(selectedIndex + 1);
          },
          onCollectTicket: (ticketId) {
            setState(() => _pendingCollectTicketId = ticketId);
            _irAIndice(selectedIndex + 1);
          },
        ),
        allowedRoles: const <String>{'owner', 'admin', 'assistant'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Tickets & Caja',
          Icons.confirmation_number_outlined,
          category: BeautyCategory.operacion,
        ),
        page: TicketsPage(
          key: ValueKey('tickets-${branch.branchId}'),
          branchId: branch.branchId,
          isOwnerOrAdmin: role == 'owner' || role == 'admin',
          // Paso 8.14 (D-187): dos acciones sueltas que el plan puede no
          // cubrir, aunque el modulo si funcione.
          puedePortafolio: entitlements.permite(ClaveDeCapacidad.portafolio),
          puedeResenas: entitlements.permite(ClaveDeCapacidad.resenas),
          openTicketId: _pendingOpenTicketId,
          onTicketOpened: () => setState(() => _pendingOpenTicketId = null),
          collectTicketId: _pendingCollectTicketId,
          onCollectTicketOpened: () =>
              setState(() => _pendingCollectTicketId = null),
        ),
        allowedRoles: const <String>{'owner', 'admin', 'assistant'},
      ),
      const BeautyModule(
        section: BeautySection(
          'Clientes',
          Icons.people_outline,
          category: BeautyCategory.operacion,
        ),
        page: ClientesPage(),
        allowedRoles: <String>{'owner', 'admin', 'assistant'},
      ),

      // ======================================================================
      // ESTILISTA PERSONAL
      // ======================================================================
      BeautyModule(
        section: const BeautySection(
          'Mi agenda',
          Icons.event_available_outlined,
          category: BeautyCategory.operacion,
        ),
        page: MyStylistAgendaPage(
          key: ValueKey('my-agenda-${branch.branchId}'),
          branchId: branch.branchId,
          puedePortafolio: entitlements.permite(ClaveDeCapacidad.portafolio),
        ),
        allowedRoles: const <String>{'stylist'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Mis fotos',
          Icons.photo_library_outlined,
          category: BeautyCategory.portafolio,
        ),
        page: MyStylistWorkPhotosPage(
          key: ValueKey('my-photos-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'stylist'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Mis reseñas',
          Icons.star_outline,
          category: BeautyCategory.portafolio,
        ),
        page: MyStylistReviewsPage(
          key: ValueKey('my-reviews-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'stylist'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Mi panel financiero',
          Icons.payments_outlined,
          category: BeautyCategory.finanzas,
        ),
        page: MyCommissionSummaryPage(
          key: ValueKey('my-commissions-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'stylist'},
      ),

      // ======================================================================
      // 2. FINANZAS Y GESTIÓN
      // ======================================================================
      BeautyModule(
        section: const BeautySection(
          'Dashboard',
          Icons.dashboard_outlined,
          category: BeautyCategory.finanzas,
        ),
        page: DashboardPage(
          // Como los otros 17 modulos (D-205). Desde D-201 el modulo visible
          // ya se remonta al cambiar de sede --el contador de visitas se
          // reinicia y con el la llave del `KeyedSubtree`-- asi que esto no
          // arregla un fallo vivo: lo hace explicito y deja de depender de un
          // efecto lateral de la navegacion.
          key: ValueKey('dashboard-${branch.branchId}'),
          branchId: branch.branchId,
          branches: branches,
          // "Tu negocio en palabras" (D-168) saluda al titular; si su
          // perfil no tiene nombre todavía, cae al nombre del negocio.
          nombreParaSaludo: (profile?.fullName.trim().isNotEmpty ?? false)
              ? profile!.fullName
              : branch.tenantName,
          onIrAAgenda: () => _irAModulo(modules, 'Agenda'),
          onIrATickets: () => _irAModulo(modules, 'Tickets & Caja'),
          onIrAClientes: () => _irAModulo(modules, 'Clientes'),
          // Los tres destinos de la lista de Primeros pasos (paso 8.8, D-186).
          onIrAServicios: () => _irAModulo(modules, 'Servicios'),
          onIrAEstilistas: () => _irAModulo(modules, 'Estilistas'),
          onIrAConfiguracion: () => _irAModulo(modules, 'Configuración'),
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Reportes',
          Icons.bar_chart_outlined,
          category: BeautyCategory.finanzas,
        ),
        page: ReportesPage(
          key: ValueKey('reports-${branch.branchId}'),
          branchId: branch.branchId,
          // Para poder alternar entre esta sede y el consolidado (D-194).
          branches: branches,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
        // Sus dos RPC de lectura (`get_sales_report_summary_v2` y
        // `get_branch_financial_summary_v2`) exigen la capacidad, asi que en
        // Basico el modulo ni siquiera cargaba: reventaba al abrirlo.
        requiredFeature: ClaveDeCapacidad.reportesFinancieros,
        lockExplicacion:
            'Los reportes ampliados te dicen cuanto entro de verdad, por metodo '
            'de pago, cuanto se llevo cada estilista en comisiones y que '
            'servicios dejan mas dinero. Tu plan actual ya te muestra la caja '
            'del dia; esto es la vista del mes y la comparacion con el '
            'anterior.',
        lockPlan: 'Business',
      ),
      BeautyModule(
        section: const BeautySection(
          'Inventario',
          Icons.inventory_2_outlined,
          category: BeautyCategory.finanzas,
        ),
        page: InventarioPage(
          key: ValueKey('inventory-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
        requiredFeature: ClaveDeCapacidad.inventario,
        lockExplicacion:
            'Llevar el inventario es saber que productos tienes, cuales se '
            'estan acabando y cuanto te cuesta cada servicio de verdad. '
            'Incluye aviso por correo cuando algo baja del minimo.',
        lockPlan: 'Business',
      ),
      BeautyModule(
        section: const BeautySection(
          'Compras',
          Icons.shopping_cart_outlined,
          category: BeautyCategory.finanzas,
        ),
        page: ComprasPage(
          key: ValueKey('purchases-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
        requiredFeature: ClaveDeCapacidad.inventario,
        lockExplicacion:
            'Registrar las compras a proveedores mantiene el stock al dia solo '
            'y te deja ver en que se va la plata del negocio mes a mes.',
        lockPlan: 'Business',
      ),
      BeautyModule(
        section: const BeautySection(
          'Gastos',
          Icons.payments_outlined,
          category: BeautyCategory.finanzas,
        ),
        page: GastosPage(
          key: ValueKey('expenses-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
        requiredFeature: ClaveDeCapacidad.inventario,
        lockExplicacion:
            'Anotar arriendo, servicios y sueldos es lo que separa "cuanto '
            'vendi" de "cuanto me quedo". Sin esto, la utilidad del mes es una '
            'suposicion.',
        lockPlan: 'Business',
      ),

      // ======================================================================
      // 3. PORTAFOLIO Y REPUTACIÓN
      // ======================================================================
      BeautyModule(
        section: const BeautySection(
          'Fotos de trabajos',
          Icons.photo_library_outlined,
          category: BeautyCategory.portafolio,
        ),
        page: FotosTrabajosPage(
          key: ValueKey('work-photos-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Reseñas',
          Icons.rate_review_outlined,
          category: BeautyCategory.portafolio,
        ),
        page: ResenasPage(
          key: ValueKey('reviews-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Blog',
          Icons.article_outlined,
          category: BeautyCategory.portafolio,
        ),
        // El blog es del negocio completo, no de una sede (paso 6.6,
        // D-171) -- por eso recibe tenantId y no branchId.
        page: BlogPage(
          key: ValueKey('blog-${branch.tenantId}'),
          tenantId: branch.tenantId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),

      // ======================================================================
      // 4. CATÁLOGO Y AJUSTES DEL SALÓN
      // ======================================================================
      BeautyModule(
        section: const BeautySection(
          'Servicios',
          Icons.content_cut_outlined,
          category: BeautyCategory.sistema,
        ),
        page: ServiciosPage(
          key: ValueKey('services-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Estilistas',
          Icons.badge_outlined,
          category: BeautyCategory.sistema,
        ),
        page: EstilistasPage(
          key: ValueKey('stylists-${branch.branchId}'),
          branchId: branch.branchId,
          tenantId: branch.tenantId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Usuarios',
          Icons.manage_accounts_outlined,
          category: BeautyCategory.sistema,
        ),
        page: UsuariosPage(
          key: ValueKey('users-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Configuración',
          Icons.settings_outlined,
          category: BeautyCategory.sistema,
        ),
        page: ConfiguracionPage(
          key: ValueKey('settings-${branch.branchId}'),
          branchId: branch.branchId,
          isOwner: role == 'owner',
        ),
        allowedRoles: const <String>{'owner', 'admin'},
        // La unica excepcion al refresco al entrar (D-201): aqui se escribe
        // a mano en la propia pagina. Ver `BeautyModule.recargaAlEntrar`.
        recargaAlEntrar: false,
      ),
    ];

    return modules
        .where((module) => module.canAccess(role))
        .toList(growable: false);
  }

  /// Ensena el aviso de vuelta de la pasarela, si hay uno pendiente
  /// (D-200). Se consume una sola vez.
  void _mostrarAvisoDePagoSiHayUno(BuildContext context) {
    final aviso = _avisoDePagoPendiente;
    if (aviso == null) return;

    // `maybeOf` y no `of`: si por lo que sea no hubiera un `ScaffoldMessenger`
    // encima, `of` lanzaria **durante el build**, y quien acaba de pagar
    // $150.000 se encontraria una pantalla rota en vez de un aviso. Callarse
    // es el comportamiento que habia antes de D-200; reventar, no.
    final mensajero = ScaffoldMessenger.maybeOf(context);
    if (mensajero == null) return;

    // Se consume aqui y no dentro del callback: `build` puede volver a
    // correr antes de que termine el fotograma, y entonces el mismo aviso
    // se encolaria dos veces. Y despues de resolver el mensajero, para no
    // perder el aviso si todavia no habia donde ensenarlo.
    _avisoDePagoPendiente = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      mensajero.showSnackBar(
        SnackBar(
          content: Text(aviso.mensaje),
          backgroundColor: _colorDeAviso(aviso.tono),
          behavior: SnackBarBehavior.floating,
          // Mas de los 4 segundos por defecto: quien vuelve de pagar
          // esta mirando si le cobraron, no la esquina de la pantalla.
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Entendido',
            textColor: Colors.white,
            onPressed: mensajero.hideCurrentSnackBar,
          ),
        ),
      );
    });
  }

  static Color _colorDeAviso(TonoDeAviso tono) {
    switch (tono) {
      case TonoDeAviso.exito:
        return AppColors.success;
      case TonoDeAviso.advertencia:
        return AppColors.warning;
      case TonoDeAviso.informacion:
        return AppColors.brandDeep;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeContextData>(
      future: homeContextFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.surface,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Antes de la rama de error a proposito: si `_loadHomeContext`
        // reventa despues de volver de la pasarela, el dueno igual tiene
        // derecho a saber que paso con su pago.
        _mostrarAvisoDePagoSiHayUno(context);

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              title: const Text('Salón y Más'),
              actions: [
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: signOut,
                  icon: const Icon(Icons.logout_outlined),
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: const Text(
                  'No pudimos cargar las sedes autorizadas.\nRevisa tu conexión a internet o intenta nuevamente más tarde.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final homeContext = snapshot.data;
        final profile = homeContext?.profile;
        final subscriptionStatus = homeContext?.subscriptionStatus;
        final branches = homeContext?.branches ?? const <BranchContext>[];
        final entitlements =
            homeContext?.entitlements ??
            const TenantEntitlements.desconocido();

        if (profile == null) {
          final pendingInvitation = homeContext?.pendingInvitation;

          if (pendingInvitation != null) {
            return AcceptInvitationPage(
              invitation: pendingInvitation,
              onAccepted: () {
                setState(() {
                  homeContextFuture = _loadHomeContext();
                });
              },
            );
          }

          return CompleteTenantSetupPage(
            onCompleted: () {
              setState(() {
                homeContextFuture = _loadHomeContext();
              });
            },
          );
        }

        if (subscriptionStatus != null &&
            (subscriptionStatus.isPending || subscriptionStatus.isRejected)) {
          return TenantApprovalStatusPage(
            status: subscriptionStatus,
            onRefresh: () async {
              setState(() {
                homeContextFuture = _loadHomeContext();
              });
            },
          );
        }

        if (branches.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              title: const Text('Salón y Más'),
              actions: [
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: signOut,
                  icon: const Icon(Icons.logout_outlined),
                ),
              ],
            ),
            body: const Center(
              child: Text('Tu usuario no tiene una sede operativa asignada.'),
            ),
          );
        }

        final branch = selectedBranch ?? _initialBranch(branches);
        final modules = _modulesForProfile(
          profile,
          branch,
          branches,
          entitlements,
        );

        if (modules.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              title: const Text('Salón y Más'),
              actions: [
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: signOut,
                  icon: const Icon(Icons.logout_outlined),
                ),
              ],
            ),
            body: const Center(
              child: Text('Tu usuario no tiene módulos asignados.'),
            ),
          );
        }

        final currentIndex = selectedIndex >= modules.length
            ? 0
            : selectedIndex;
        // TL-19 (D-184): antes de aquí, la interfaz nunca preguntaba qué
        // permite el plan. El salón en Básico veía Inventario, entraba, y el
        // backend le devolvía una excepción de PostgreSQL en crudo. Ahora el
        // módulo se sigue viendo — con candado, para no matar la venta — pero
        // se abre en una pantalla que explica en vez de reventar.
        final sections = modules
            .map(
              (module) => entitlements.permite(module.requiredFeature)
                  ? module.section
                  : module.section.conCandado(),
            )
            .toList(growable: false);
        final pages = modules
            .map(
              (module) => entitlements.permite(module.requiredFeature)
                  ? module.page
                  : PlanLockedPage(
                      moduleTitle: module.section.title,
                      moduleIcon: module.section.icon,
                      explicacion:
                          module.lockExplicacion ??
                          'Este módulo no está incluido en tu plan actual.',
                      planSugerido: module.lockPlan ?? 'Business',
                      onIrAConfiguracion: () =>
                          _irAModulo(modules, 'Configuración'),
                    ),
            )
            .toList(growable: false);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 850;

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
                    titleSpacing: isWide ? AppSpacing.lg : AppSpacing.md,
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Isotipo / Logo
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.brand, AppColors.brandDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: branch.tenantLogoUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      branch.tenantLogoUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.auto_awesome,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (isWide) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                branch.tenantName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandDeep,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                'BeautyOS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brand,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: AppSpacing.lg),
                        ],
                        // Selector de Sede Pill
                        _BranchSelectorPill(
                          branches: branches,
                          selectedBranch: branch,
                          compact: !isWide,
                          onSelected: (value) {
                            if (value.branchId == branch.branchId) return;
                            AppBrand.aplicar(
                              value.tenantThemeKey,
                              value.tenantBrandColor,
                            );
                            setState(() {
                              selectedBranch = value;
                              // TL-10 (D-201): al cambiar de sede, TODOS los
                              // modulos cambian su `ValueKey` de sede y se
                              // remontan. Si los ya visitados siguieran en la
                              // pila, se recargarian los 16 de golpe sin que
                              // nadie los mire -- exactamente el problema que
                              // este bloque quita. Se vuelve a empezar por el
                              // que se esta viendo.
                              _modulosAbiertos
                                ..clear()
                                ..add(currentIndex);
                              _visitasPorModulo.clear();
                            });
                          },
                        ),
                      ],
                    ),
                    actions: [
                      // Botón de Acción Rápida Global
                      if (profile.role == 'owner' ||
                          profile.role == 'admin' ||
                          profile.role == 'assistant')
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: FilledButton.icon(
                            onPressed: () => openCreateAppointmentDialog(
                              context,
                              branch.branchId,
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(isWide ? 'Nueva Cita' : 'Cita'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                horizontal: isWide
                                    ? AppSpacing.md
                                    : AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      // Badge de Prueba / Gracia discreto
                      if (isWide &&
                          (profile.role == 'owner' || profile.role == 'admin'))
                        _TrialHeaderBadge(
                          subscriptionStatus: subscriptionStatus,
                          onRefresh: () {
                            setState(() {
                              homeContextFuture = _loadHomeContext();
                            });
                          },
                        ),

                      // Avatar de Usuario & Menú de Perfil
                      _UserProfileMenu(profile: profile, onSignOut: signOut),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
              body: Column(
                children: [
                  const UpdateBanner(),
                  Expanded(
                    child: Row(
                      children: [
                        if (isWide)
                          _CategorizedSideMenu(
                            sections: sections,
                            selectedIndex: currentIndex,
                            onDestinationSelected: _irAIndice,
                          ),
                        Expanded(
                          child: IndexedStack(
                            index: currentIndex,
                            children: pilaDeModulos(
                              modules: modules,
                              pages: pages,
                              abiertos: _modulosAbiertos,
                              visitas: _visitasPorModulo,
                              indiceActual: currentIndex,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: isWide
                  ? null
                  : _MobileNavBar(
                      sections: sections,
                      currentIndex: currentIndex,
                      onSelected: _irAIndice,
                      onSignOut: signOut,
                    ),
            );
          },
        );
      },
    );
  }

  BranchContext _initialBranch(List<BranchContext> branches) {
    for (final branch in branches) {
      if (branch.isPrimary) {
        return branch;
      }
    }
    return branches.first;
  }
}

// ============================================================================
// ENUM DE CATEGORÍAS SEMÁNTICAS
// ============================================================================
enum BeautyCategory {
  operacion('OPERACIÓN'),
  finanzas('FINANZAS Y GESTIÓN'),
  portafolio('PORTAFOLIO'),
  sistema('CATÁLOGO Y AJUSTES');

  const BeautyCategory(this.label);
  final String label;
}

class BeautySection {
  final String title;
  final IconData icon;
  final BeautyCategory category;

  /// El plan del negocio no cubre este módulo (TL-19, D-184). Se sigue
  /// mostrando en el menú, con candado: esconderlo arreglaría el error y de
  /// paso mataría la venta.
  final bool bloqueadoPorPlan;

  const BeautySection(
    this.title,
    this.icon, {
    this.category = BeautyCategory.operacion,
    this.bloqueadoPorPlan = false,
  });

  BeautySection conCandado() => BeautySection(
    title,
    icon,
    category: category,
    bloqueadoPorPlan: true,
  );
}

/// Arma los hijos del `IndexedStack` de la pantalla principal (TL-10 y
/// Hallazgo Q, D-201).
///
/// Hace dos cosas que antes no hacia nadie:
///
/// **1. No construye lo que nadie ha abierto.** Un modulo que todavia no se
/// ha visitado ocupa su hueco con un `SizedBox.shrink()`. `IndexedStack`
/// necesita que la lista tenga el mismo largo que los modulos --su `index` es
/// una posicion, no una identidad-- pero nada le obliga a que esos huecos
/// sean la pagina de verdad. Antes de esto se construian los 16 modulos al
/// abrir sesion: 16 `initState`, 16 consultas, 15 pantallas que nadie mira.
///
/// **2. Recarga al entrar.** La llave lleva el contador de visitas, asi que
/// entrar otra vez la cambia, Flutter desmonta el subarbol y `initState`
/// vuelve a correr. Eso es lo que cierra el Hallazgo Q, abierto desde el
/// 09-ago: "entrar a un modulo no recarga sus datos". **Es el mismo
/// mecanismo que el proyecto ya usaba** para el cambio de sede -- 17 de los
/// 19 modulos llevan `ValueKey('...-branchId')` desde antes de este bloque --
/// aplicado ahora tambien al entrar.
///
/// El modulo que declara `recargaAlEntrar: false` se queda con una llave
/// fija: se construye perezosamente igual, pero una vez montado conserva su
/// estado. Hoy solo Configuracion, que tiene siete campos de texto en la
/// propia pagina.
///
/// **[indiceActual] se construye siempre, este o no en [abiertos].** Es una
/// red, no un adorno: si por cualquier camino el indice visible no estuviera
/// marcado como abierto, el usuario veria un `SizedBox.shrink()`, o sea **la
/// pantalla en blanco**, que es el peor final posible de este cambio. Con
/// esta linea eso es imposible por construccion, sin tener que razonar sobre
/// si todos los caminos marcaron bien.
///
/// Esta funcion es de nivel superior, y no un metodo privado del `State`,
/// **para poder probarla**: entra una lista y unos contadores, sale una lista
/// de widgets, sin sesion de Supabase de por medio.
List<Widget> pilaDeModulos({
  required List<BeautyModule> modules,
  required List<Widget> pages,
  required Set<int> abiertos,
  required Map<int, int> visitas,
  required int indiceActual,
}) {
  return <Widget>[
    for (var i = 0; i < pages.length; i++)
      if (i != indiceActual && !abiertos.contains(i))
        const SizedBox.shrink()
      else
        KeyedSubtree(
          key: ValueKey(
            modules[i].recargaAlEntrar
                ? 'modulo-$i-visita-${visitas[i] ?? 0}'
                : 'modulo-$i',
          ),
          child: pages[i],
        ),
  ];
}

class BeautyModule {
  const BeautyModule({
    required this.section,
    required this.page,
    required this.allowedRoles,
    this.requiredFeature,
    this.lockExplicacion,
    this.lockPlan,
    this.recargaAlEntrar = true,
  });

  final BeautySection section;
  final Widget page;
  final Set<String> allowedRoles;

  /// Clave de `public.features` que el plan tiene que incluir para poder usar
  /// este módulo (TL-19, D-184). `null` = lo cubren todos los planes.
  ///
  /// Tiene que coincidir con la que exige `beautyos_require_entitlement` dentro
  /// de las RPC del módulo: el backend es quien manda, esto solo se adelanta
  /// para explicar en vez de dejar que reviente.
  final String? requiredFeature;

  /// Qué hace el módulo, en el idioma del salón, para la pantalla de candado.
  final String? lockExplicacion;

  /// El plan más barato que lo incluye (Plan Maestro, apartado 3).
  final String? lockPlan;

  /// Si al entrar al módulo hay que recargar sus datos (Hallazgo Q, D-201).
  ///
  /// **Por defecto `true`, y ese es el caso normal**: el hallazgo dice, con
  /// razón, que entrar a un módulo tiene que traer datos frescos — quien
  /// cobra un ticket y se pasa a Reportes espera ver ese dinero.
  ///
  /// Recargar significa **remontar**, y remontar borra lo que la persona
  /// tuviera escrito o filtrado en esa pantalla. Por eso hay una excepción, y
  /// solo una: **Configuración**, que tiene siete campos de texto en la propia
  /// página (nombre de contacto, teléfono, WhatsApp, dirección, Instagram,
  /// Facebook). Perder lo escrito por ir a mirar la Agenda es peor que ver un
  /// dato viejo en un formulario que la persona está editando de todas formas.
  ///
  /// **Antes de poner esto en `false` en un módulo nuevo**, comprobar que de
  /// verdad guarda algo que se escribe a mano en la página, no en un diálogo:
  /// un diálogo es una ruta encima y no se pierde al cambiar de pestaña.
  final bool recargaAlEntrar;

  bool canAccess(String role) {
    return allowedRoles.contains(role);
  }
}

// ============================================================================
// SELECTOR DE SEDE TIPO PILL (MODERNO)
// ============================================================================
class _BranchSelectorPill extends StatelessWidget {
  const _BranchSelectorPill({
    required this.branches,
    required this.selectedBranch,
    required this.compact,
    required this.onSelected,
  });

  final List<BranchContext> branches;
  final BranchContext selectedBranch;
  final bool compact;
  final ValueChanged<BranchContext> onSelected;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_outlined, size: 16, color: AppColors.brand),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 110 : 160),
            child: Text(
              selectedBranch.branchName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (branches.length > 1) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );

    if (branches.length <= 1) {
      return content;
    }

    return PopupMenuButton<BranchContext>(
      tooltip: 'Cambiar de sede',
      initialValue: selectedBranch,
      onSelected: onSelected,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      itemBuilder: (context) => branches
          .map(
            (branch) => PopupMenuItem<BranchContext>(
              value: branch,
              child: Row(
                children: [
                  Icon(
                    branch.branchId == selectedBranch.branchId
                        ? Icons.check_circle_outline
                        : Icons.storefront_outlined,
                    size: 18,
                    color: branch.branchId == selectedBranch.branchId
                        ? AppColors.brand
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    branch.branchName,
                    style: TextStyle(
                      fontWeight: branch.branchId == selectedBranch.branchId
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: content,
    );
  }
}

// ============================================================================
// BADGE DE PRUEBA / GRACIA EN HEADER (MINIMALISTA)
// ============================================================================
class _TrialHeaderBadge extends StatelessWidget {
  const _TrialHeaderBadge({
    required this.subscriptionStatus,
    required this.onRefresh,
  });

  final TenantSubscriptionStatus? subscriptionStatus;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (subscriptionStatus == null) return const SizedBox.shrink();

    final status = subscriptionStatus!;
    final epayco = const EpaycoCheckoutService();

    if (status.isGrace) {
      final days = status.graceDaysRemaining ?? 5;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () =>
              epayco.iniciarPago(context, status, onPaymentLaunched: onRefresh),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warningTint,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.warning),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 5),
                Text(
                  '$days ${days == 1 ? "día" : "días"} de gracia · Pagar',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (status.isTrialing) {
      final days = status.trialDaysRemaining;
      if (days != null && days <= 10) {
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => epayco.iniciarPago(
              context,
              status,
              onPaymentLaunched: onRefresh,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.brandTintSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 14, color: AppColors.brand),
                  const SizedBox(width: 5),
                  Text(
                    days == 0
                        ? 'Prueba termina hoy'
                        : 'Prueba: $days d restantes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandDeep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    if (status.isActive) {
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.successTint,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🟢', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 5),
              Text(
                'Plan ${status.planName ?? "Profesional"} · Vence '
                '${_formatFechaCorta(status.currentPeriodEnd)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  static String _formatFechaCorta(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// ============================================================================
// AVATAR DE USUARIO & MENÚ DE PERFIL
// ============================================================================
class _UserProfileMenu extends StatelessWidget {
  const _UserProfileMenu({required this.profile, required this.onSignOut});

  final MyProfile profile;
  final Future<void> Function() onSignOut;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Perfil y cuenta',
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      onSelected: (value) {
        if (value == 'security') {
          showDialog(
            context: context,
            builder: (_) => const SecuritySettingsDialog(),
          );
        } else if (value == 'logout') {
          onSignOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                profile.roleText,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const Divider(),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'security',
          child: Row(
            children: [
              Icon(
                Icons.security_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 10),
              Text('Seguridad de tu cuenta'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_outlined, size: 18, color: AppColors.danger),
              SizedBox(width: 10),
              Text('Cerrar sesión', style: TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.brandTint,
              child: Text(
                _initials(profile.fullName),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SIDEBAR CATEGORIZADO MODERNO (DESKTOP)
// ============================================================================
class _CategorizedSideMenu extends StatelessWidget {
  const _CategorizedSideMenu({
    required this.sections,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<BeautySection> sections;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    // Agrupar las secciones por su categoría
    final grouped = <BeautyCategory, List<MapEntry<int, BeautySection>>>{};
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      grouped.putIfAbsent(section.category, () => []).add(MapEntry(i, section));
    }

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          children: [
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 12, bottom: 6),
                child: Text(
                  entry.key.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              for (final item in entry.value) ...[
                _SideMenuItem(
                  section: item.value,
                  isSelected: item.key == selectedIndex,
                  onTap: () => onDestinationSelected(item.key),
                ),
                const SizedBox(height: 2),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SideMenuItem extends StatelessWidget {
  const _SideMenuItem({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  final BeautySection section;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.brandTintSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                section.icon,
                size: 20,
                color: isSelected ? AppColors.brand : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.brandDeep
                        : AppColors.textStrong,
                  ),
                ),
              ),
              // El modulo se ve, pero con candado (TL-19, D-184): esconderlo
              // arreglaria el error de plan y de paso mataria la venta.
              if (section.bloqueadoPorPlan) ...[
                const Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
              ],
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// NAVEGACIÓN MÓVIL Y HOJA "MÁS" CATEGORIZADA
// ============================================================================
class _MobileNavBar extends StatelessWidget {
  const _MobileNavBar({
    required this.sections,
    required this.currentIndex,
    required this.onSelected,
    required this.onSignOut,
  });

  final List<BeautySection> sections;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final Future<void> Function() onSignOut;

  static const _visibles = 4;

  @override
  Widget build(BuildContext context) {
    final directos = sections.take(_visibles).toList();
    final enMas = sections.length > _visibles;

    final seleccionado = currentIndex < directos.length
        ? currentIndex
        : directos.length;

    return NavigationBar(
      selectedIndex: seleccionado,
      elevation: 2,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.brandTint,
      onDestinationSelected: (index) {
        if (index < directos.length) {
          onSelected(index);
          return;
        }
        _abrirMas(context);
      },
      destinations: [
        for (final section in directos)
          NavigationDestination(
            icon: Icon(section.icon, color: AppColors.textSecondary),
            selectedIcon: Icon(section.icon, color: AppColors.brand),
            label: section.title,
          ),
        NavigationDestination(
          icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
          selectedIcon: Icon(Icons.more_horiz, color: AppColors.brand),
          label: enMas ? 'Más' : 'Cuenta',
        ),
      ],
    );
  }

  Future<void> _abrirMas(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (hoja) {
        final restantes = <MapEntry<int, BeautySection>>[
          for (var i = _visibles; i < sections.length; i++)
            MapEntry(i, sections[i]),
        ];

        final groupedRestantes =
            <BeautyCategory, List<MapEntry<int, BeautySection>>>{};
        for (final entry in restantes) {
          groupedRestantes
              .putIfAbsent(entry.value.category, () => [])
              .add(entry);
        }

        final alto = MediaQuery.of(hoja).size.height;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: alto * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final group in groupedRestantes.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Text(
                        group.key.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1.1,
                      children: [
                        for (final entrada in group.value)
                          _AccesoMas(
                            icon: entrada.value.icon,
                            label: entrada.value.title,
                            activo: entrada.key == currentIndex,
                            bloqueado: entrada.value.bloqueadoPorPlan,
                            onTap: () {
                              Navigator.of(hoja).pop();
                              onSelected(entrada.key);
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.security_outlined),
                    title: const Text('Seguridad de tu cuenta'),
                    onTap: () {
                      Navigator.of(hoja).pop();
                      showDialog(
                        context: context,
                        builder: (_) => const SecuritySettingsDialog(),
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.logout_outlined,
                      color: AppColors.danger,
                    ),
                    title: const Text(
                      'Cerrar sesión',
                      style: TextStyle(color: AppColors.danger),
                    ),
                    onTap: () {
                      Navigator.of(hoja).pop();
                      onSignOut();
                    },
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

class _AccesoMas extends StatelessWidget {
  const _AccesoMas({
    required this.icon,
    required this.label,
    required this.activo,
    required this.onTap,
    this.bloqueado = false,
  });

  final IconData icon;
  final String label;
  final bool activo;
  final VoidCallback onTap;

  /// El plan del negocio no cubre este modulo (TL-19, D-184). Se sigue
  /// pudiendo tocar: abre la pantalla que explica que se gana al subir.
  final bool bloqueado;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        decoration: BoxDecoration(
          color: activo ? AppColors.brandTint : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: activo ? AppColors.brand : AppColors.border,
            width: activo ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: activo
                      ? AppColors.brand
                      : (bloqueado
                            ? AppColors.textMuted
                            : AppColors.textStrong),
                  size: 22,
                ),
                if (bloqueado)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Icon(
                      Icons.lock,
                      size: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color: activo
                    ? AppColors.brandDeep
                    : (bloqueado ? AppColors.textMuted : AppColors.textStrong),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
