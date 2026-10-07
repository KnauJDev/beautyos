import '../models/avisos_de_hoy.dart';
import '../models/invitacion_a_volver.dart';
import 'branch_subscriptions_service.dart';
import 'dashboard_service.dart';
import 'invitar_a_volver_service.dart';
import 'products_service.dart';

/// Carga lo que dice la campana (D-318), sede por sede.
///
/// **Cada parte por su cuenta y sin reventar:** si una consulta falla (o la
/// persona no tiene permiso para ella), esa parte cuenta cero y las demás
/// siguen. Una campana que se rompe por el inventario y se calla las citas sin
/// confirmar sería peor que no tener campana.
class AvisosService {
  const AvisosService({required this.branchId});

  final String branchId;

  Future<AvisosDeHoy> cargar({
    required bool conCaja,
    required bool conInventario,
    required bool esDuena,
  }) async {
    Future<int> seguro(Future<int> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return 0;
      }
    }

    final sinConfirmar = conCaja
        ? seguro(() async {
            final hoy = await DashboardService(
              branchId: branchId,
            ).getHoy(branchIds: [branchId]);
            return hoy.sinConfirmar;
          })
        : Future.value(0);

    final paraInvitar = seguro(() async {
      final filas = await InvitarAVolverService(branchId: branchId).listar();
      return clientasDe(filas.where((f) => f.tocaHoy)).length;
    });

    final inventario = conInventario
        ? seguro(() async {
            final productos = await ProductsService(
              branchId: branchId,
            ).getProductsForManagement();
            return productos.where((p) => p.active && p.isLowStock).length;
          })
        : Future.value(0);

    Future<List<SedePorVencer>> sedes() async {
      if (!esDuena) return const <SedePorVencer>[];
      try {
        final todas = await const BranchSubscriptionsService()
            .getBranchSubscriptions();
        return [
          for (final s in todas)
            if (s.periodoVencido || s.puedeRenovarAntes)
              SedePorVencer(
                nombre: s.branchName,
                dias: s.diasParaVencer,
                vencida: s.periodoVencido,
              ),
        ];
      } catch (_) {
        return const <SedePorVencer>[];
      }
    }

    final resultados = await Future.wait([sinConfirmar, paraInvitar, inventario]);
    return AvisosDeHoy(
      sinConfirmar: resultados[0],
      paraInvitar: resultados[1],
      inventarioBajo: resultados[2],
      sedes: await sedes(),
    );
  }
}
