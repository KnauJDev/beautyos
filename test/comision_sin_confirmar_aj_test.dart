import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/commission_policy.dart';

/// Hallazgo **AJ**: el salón nace con una comisión del 40% que nadie le pide
/// confirmar, y esa cifra decide lo que gana una persona.
///
/// **Lo que estas pruebas cuidan** es el lado seguro de la lectura: ante
/// cualquier duda sobre si alguien aprobó la cifra, la respuesta es **no**, y
/// se avisa. El error caro aquí no es avisar de más — cuesta un clic —, sino
/// callarse: eso ya pasó y se midió con dinero real, \$7.200 sobre \$18.000
/// generados sin que nadie los aprobara nunca.
///
/// Lo que **no** prueban: que la base marque la fecha al guardar. Eso lo
/// ejercita el control 219 contra la base real (D-245).
void main() {
  group('AJ — una comisión que nadie confirmó', () {
    test('sin fecha, no está confirmada', () {
      final p = CommissionPolicy.fromMap(const {
        'id': 'x',
        'commission_type': 'percentage',
        'commission_percentage': 40,
        'fixed_commission_amount': 0,
        'applies_after_discount': true,
        'notes': null,
      });

      expect(p.confirmedAt, isNull);
      expect(
        p.confirmada,
        isFalse,
        reason: 'es el estado en que estaban las 3 políticas de la base',
      );
      // Y la cifra sigue ahí: AJ no la borra, la saca a la luz.
      expect(p.commissionPercentage, 40);
    });

    test('con fecha, está confirmada', () {
      final p = CommissionPolicy.fromMap(const {
        'id': 'x',
        'commission_type': 'percentage',
        'commission_percentage': 25,
        'fixed_commission_amount': 0,
        'applies_after_discount': true,
        'notes': 'Acordado con el equipo',
        'confirmed_at': '2026-09-20T15:00:00Z',
      });

      expect(p.confirmada, isTrue);
      expect(p.confirmedAt?.year, 2026);
    });

    test('una fecha que no se entiende cuenta como SIN confirmar', () {
      // El lado seguro. Si la base mandara basura en ese campo, lo que no
      // puede pasar es dar por aprobada una cifra que decide un sueldo.
      final p = CommissionPolicy.fromMap(const {
        'id': 'x',
        'commission_type': 'percentage',
        'commission_percentage': 40,
        'fixed_commission_amount': 0,
        'applies_after_discount': true,
        'notes': null,
        'confirmed_at': 'cuando sea',
      });

      expect(p.confirmada, isFalse);
    });

    test('la cifra se sigue leyendo igual: AJ no bloquea nada', () {
      // Se le ofreció al propietario que naciera en 0% hasta confirmarla y lo
      // descartó: 0% también es un número inventado, solo que más barato para
      // el salón. La política sin confirmar se lee y se aplica como siempre.
      final p = CommissionPolicy.fromMap(const {
        'id': 'x',
        'commission_type': 'percentage',
        'commission_percentage': 40,
        'fixed_commission_amount': 0,
        'applies_after_discount': true,
        'notes': null,
      });

      expect(p.commissionValueText, '40% del servicio');
      expect(p.discountText, contains('después'));
    });

    test('un valor fijo sin confirmar también avisa', () {
      final p = CommissionPolicy.fromMap(const {
        'id': 'x',
        'commission_type': 'fixed',
        'commission_percentage': 0,
        'fixed_commission_amount': 5000,
        'applies_after_discount': false,
        'notes': null,
      });

      expect(p.confirmada, isFalse);
      expect(p.commissionValueText, contains('5000'));
    });
  });
}
