class AnalyticsData {
  const AnalyticsData({
    required this.totalSales,
    required this.totalCogs,
    required this.grossProfit,
    required this.transactionCount,
    required this.salesTrend,
  });

  final double totalSales;
  final double totalCogs;
  final double grossProfit;
  final int transactionCount;
  final List<SalesTrendPoint> salesTrend;

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      totalSales: (json['total_sales'] as num?)?.toDouble() ?? 0.0,
      totalCogs: (json['total_cogs'] as num?)?.toDouble() ?? 0.0,
      grossProfit: (json['gross_profit'] as num?)?.toDouble() ?? 0.0,
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      salesTrend: (json['sales_trend'] as List<dynamic>?)
              ?.map((e) => SalesTrendPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SalesTrendPoint {
  const SalesTrendPoint({
    required this.label,
    required this.amount,
  });

  final String label;
  final double amount;

  factory SalesTrendPoint.fromJson(Map<String, dynamic> json) {
    return SalesTrendPoint(
      label: json['label']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
