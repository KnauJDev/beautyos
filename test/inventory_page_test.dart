import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/inventory_movement_summary.dart';
import 'package:salonymas/models/product_management_item.dart';
import 'package:salonymas/models/purchase_item_summary.dart';

void main() {
  group('Inventario, Compras y Gastos - Pluralización y Modelos (Paso 4.8 / D-155)', () {
    test('formatUnitQuantity formatea correctamente unidades y medidas métricas', () {
      // 1. Singular
      expect(formatUnitQuantity(1, 'unidad'), '1 unidad');
      expect(formatUnitQuantity(1, 'Unidad'), '1 unidad');

      // 2. Plural
      expect(formatUnitQuantity(3, 'unidad'), '3 unidades');
      expect(formatUnitQuantity(5, 'unidad'), '5 unidades');
      expect(formatUnitQuantity(0, 'unidad'), '0 unidades');
      expect(formatUnitQuantity(2, 'unidades'), '2 unidades');

      // 3. Unidades métricas / técnicas
      expect(formatUnitQuantity(250, 'ml'), '250 ml');
      expect(formatUnitQuantity(500, 'gr'), '500 gr');
      expect(formatUnitQuantity(2, 'l'), '2 l');
      expect(formatUnitQuantity(10, 'sobres'), '10 sobres');
    });

    test('ProductManagementItem formatea stock y mínimos con plurales correctos', () {
      final product = ProductManagementItem(
        id: 'prod-1',
        name: 'Tinte Rubio Cenizo',
        category: 'Tintes',
        brand: 'LOréal',
        productType: 'consumable',
        unit: 'unidad',
        sku: 'TIN-001',
        currentStock: 3,
        minimumStock: 5,
        purchasePrice: 25000,
        salePrice: 0,
        visibleForSale: false,
        active: true,
      );

      expect(product.isLowStock, isTrue);
      expect(product.stockText, '3 unidades');
      expect(product.minimumStockText, '5 unidades');
      expect(product.formattedPurchasePrice, '\$25.000');
    });

    test('ProductManagementItem con 1 unidad muestra singular', () {
      final product = ProductManagementItem(
        id: 'prod-2',
        name: 'Shampoo Profesional',
        category: 'Capilar',
        brand: null,
        productType: 'sale',
        unit: 'unidad',
        sku: null,
        currentStock: 1,
        minimumStock: 1,
        purchasePrice: 30000,
        salePrice: 50000,
        visibleForSale: true,
        active: true,
      );

      expect(product.isLowStock, isTrue);
      expect(product.stockText, '1 unidad');
      expect(product.minimumStockText, '1 unidad');
      expect(product.formattedSalePrice, '\$50.000');
    });

    test('PurchaseItemSummary formatea cantidad y costos correctamente', () {
      final item = PurchaseItemSummary(
        id: 'item-1',
        purchaseId: 'pur-1',
        supplierName: 'Distribuidora Belleza',
        purchaseDate: '2026-08-18',
        invoiceNumber: 'FAC-9988',
        productName: 'Oxigenta 20 Vol',
        productCategory: 'Químicos',
        quantity: 4,
        unit: 'unidad',
        unitCost: 12000,
        lineTotal: 48000,
        notes: null,
      );

      expect(item.quantityText, '4 unidades');
      expect(item.formattedUnitCost, '\$12000');
      expect(item.formattedLineTotal, '\$48000');
    });

    test('InventoryMovementSummary formatea cantidades y movimientos', () {
      final movement = InventoryMovementSummary(
        id: 'mov-1',
        productName: 'Decolorante en Polvo',
        productCategory: 'Químicos',
        movementType: 'consumption',
        quantity: 1,
        unit: 'unidad',
        unitCost: 35000,
        notes: 'Consumo para Balayage',
        createdAt: '2026-08-18T10:00:00Z',
      );

      expect(movement.quantityText, '1 unidad');
      expect(movement.movementTypeText, 'Consumo interno');
      expect(movement.formattedUnitCost, '\$35000');
    });
  });
}
