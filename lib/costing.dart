/// Deterministic cost and price calculations for the focused product-cost MVP.
class CostLine {
  final String name;
  final double quantity;
  final double unitCost;

  const CostLine({
    required this.name,
    required this.quantity,
    required this.unitCost,
  });
}

class CostBreakdown {
  final double materialCost;
  final double wasteCost;
  final double packagingCost;
  final double laborCost;
  final double overheadCost;
  final double batchCost;
  final double unitCost;
  final double commissionRate;
  final double? sellingPrice;
  final double? unitProfit;
  final double? marginRate;
  final double breakEvenPrice;
  final double targetPrice;

  const CostBreakdown({
    required this.materialCost,
    required this.wasteCost,
    required this.packagingCost,
    required this.laborCost,
    required this.overheadCost,
    required this.batchCost,
    required this.unitCost,
    required this.commissionRate,
    required this.sellingPrice,
    required this.unitProfit,
    required this.marginRate,
    required this.breakEvenPrice,
    required this.targetPrice,
  });
}

class CostInput {
  final double batchQuantity;
  final List<CostLine> materials;
  final double packagingCost;
  final double laborCost;
  final double overheadCost;
  final double wasteRate;
  final double commissionRate;
  final double? sellingPrice;
  final double targetMarginRate;

  const CostInput({
    required this.batchQuantity,
    required this.materials,
    this.packagingCost = 0,
    this.laborCost = 0,
    this.overheadCost = 0,
    this.wasteRate = 0,
    this.commissionRate = 0,
    this.sellingPrice,
    this.targetMarginRate = 0.25,
  });
}

CostBreakdown calculateCost(CostInput input) {
  if (!input.batchQuantity.isFinite || input.batchQuantity <= 0) {
    throw ArgumentError.value(input.batchQuantity, 'batchQuantity', 'باید بیشتر از صفر باشد');
  }
  for (final value in [
    input.packagingCost,
    input.laborCost,
    input.overheadCost,
    input.wasteRate,
    input.commissionRate,
    input.targetMarginRate,
    if (input.sellingPrice != null) input.sellingPrice!,
  ]) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError('هزینه‌ها، قیمت و درصدها باید عدد معتبر و نامنفی باشند.');
    }
  }
  if (input.wasteRate >= 1 || input.commissionRate >= 1 || input.targetMarginRate >= 1) {
    throw ArgumentError('درصد ضایعات، کارمزد و حاشیه سود باید کمتر از ۱۰۰٪ باشند.');
  }

  var materialCost = 0.0;
  for (final line in input.materials) {
    if (!line.quantity.isFinite || !line.unitCost.isFinite ||
        line.quantity < 0 || line.unitCost < 0) {
      throw ArgumentError('مقدار مواد و قیمت واحد باید معتبر و نامنفی باشند.');
    }
    materialCost += line.quantity * line.unitCost;
  }

  final wasteCost = materialCost * input.wasteRate;
  final batchCost = materialCost + wasteCost + input.packagingCost +
      input.laborCost + input.overheadCost;
  final unitCost = batchCost / input.batchQuantity;
  final commissionFactor = 1 - input.commissionRate;
  final targetFactor = commissionFactor - input.targetMarginRate;

  if (commissionFactor <= 0 || targetFactor <= 0) {
    throw ArgumentError('ترکیب کارمزد و حاشیه سود هدف قابل محاسبه نیست.');
  }

  final price = input.sellingPrice;
  final profit = price == null ? null : price - unitCost - (price * input.commissionRate);
  final margin = price == null || price == 0 ? null : profit! / price;

  return CostBreakdown(
    materialCost: materialCost,
    wasteCost: wasteCost,
    packagingCost: input.packagingCost,
    laborCost: input.laborCost,
    overheadCost: input.overheadCost,
    batchCost: batchCost,
    unitCost: unitCost,
    commissionRate: input.commissionRate,
    sellingPrice: price,
    unitProfit: profit,
    marginRate: margin,
    breakEvenPrice: unitCost / commissionFactor,
    targetPrice: unitCost / targetFactor,
  );
}
