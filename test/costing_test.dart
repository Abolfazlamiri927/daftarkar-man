import 'package:flutter_test/flutter_test.dart';
import 'package:daftarkar_man/costing.dart';

void main() {
  group('calculateCost', () {
    test('calculates batch and unit cost including waste and overhead', () {
      final result = calculateCost(const CostInput(
        batchQuantity: 10,
        materials: [CostLine(name: 'آرد', quantity: 2, unitCost: 100)],
        packagingCost: 50,
        laborCost: 100,
        overheadCost: 50,
        wasteRate: 0.1,
        sellingPrice: 100,
        commissionRate: 0.05,
        targetMarginRate: 0.2,
      ));

      expect(result.materialCost, 200);
      expect(result.wasteCost, 20);
      expect(result.batchCost, 420);
      expect(result.unitCost, 42);
      expect(result.unitProfit, closeTo(53, 0.0001));
      expect(result.marginRate, closeTo(0.53, 0.0001));
      expect(result.breakEvenPrice, closeTo(42 / 0.95, 0.0001));
      expect(result.targetPrice, closeTo(42 / 0.75, 0.0001));
    });

    test('rejects infinite batch quantity', () {
      expect(
        () => calculateCost(CostInput(batchQuantity: double.infinity, materials: const [])),
        throwsArgumentError,
      );
    });

    test('rejects negative material quantity', () {
      expect(
        () => calculateCost(const CostInput(
          batchQuantity: 1,
          materials: [CostLine(name: 'ماده', quantity: -1, unitCost: 100)],
        )),
        throwsArgumentError,
      );
    });

    test('simulates selling price and identifies a loss-making price', () {
      final cost = calculateCost(const CostInput(
        batchQuantity: 1,
        materials: [CostLine(name: 'ماده', quantity: 1, unitCost: 100)],
        commissionRate: 0.1,
      ));
      final loss = simulateSellingPrice(cost, 90);
      expect(loss.unitProfit, -19);
      expect(loss.marginRate, closeTo(-19 / 90, 0.0001));
      expect(loss.belowBreakEven, isTrue);

      final profit = simulateSellingPrice(cost, 150);
      expect(profit.unitProfit, 35);
      expect(profit.belowBreakEven, isFalse);
    });

    test('rejects invalid simulated selling prices', () {
      final cost = calculateCost(const CostInput(batchQuantity: 1, materials: []));
      expect(() => simulateSellingPrice(cost, 0), throwsArgumentError);
      expect(() => simulateSellingPrice(cost, double.infinity), throwsArgumentError);
    });

    test('rejects zero batch quantity', () {
      expect(
        () => calculateCost(const CostInput(batchQuantity: 0, materials: [])),
        throwsArgumentError,
      );
    });

    test('rejects impossible target margin after commission', () {
      expect(
        () => calculateCost(const CostInput(
          batchQuantity: 1,
          materials: [],
          commissionRate: 0.2,
          targetMarginRate: 0.8,
        )),
        throwsArgumentError,
      );
    });
  });
}
