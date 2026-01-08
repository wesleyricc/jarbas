import '../models/quote_model.dart';

class FinancialMetrics {
  final double totalCost;
  final double totalRevenue;
  final double grossProfit;
  final double marginPercent;

  FinancialMetrics({
    required this.totalCost,
    required this.totalRevenue,
    required this.grossProfit,
    required this.marginPercent,
  });
}

class FinancialHelper {
  /// Calcula métricas financeiras completas para um Orçamento (Quote)
  static FinancialMetrics calculateQuoteMetrics(Quote quote) {
    double cost = 0.0;
    
    // Soma o custo de todas as listas
    cost += _sumListCost(quote.blanksList);
    cost += _sumListCost(quote.cabosList);
    cost += _sumListCost(quote.reelSeatsList);
    cost += _sumListCost(quote.passadoresList);
    cost += _sumListCost(quote.acessoriosList);

    // Receita Total (já vem somada no objeto quote, incluindo mão de obra)
    double revenue = quote.totalPrice; 
    
    // Lucro Bruto = Receita - Custo das Peças
    // (Assumindo que a Mão de Obra Extra é 100% margem sobre o serviço, 
    // mas o custo base das peças deve ser abatido).
    double profit = revenue - cost;

    // Margem = (Lucro / Receita) * 100
    double margin = revenue > 0 ? (profit / revenue) * 100 : 0.0;

    return FinancialMetrics(
      totalCost: cost,
      totalRevenue: revenue,
      grossProfit: profit,
      marginPercent: margin,
    );
  }

  /// Helper interno para somar Custo de uma lista de mapas
  static double _sumListCost(List<Map<String, dynamic>> items) {
    return items.fold(0.0, (sum, item) {
      double cost = (item['cost'] ?? 0.0).toDouble();
      int qty = (item['quantity'] ?? 1).toInt();
      return sum + (cost * qty);
    });
  }

  /// Helper interno para somar Venda de uma lista de mapas
  static double sumListPrice(List<Map<String, dynamic>> items) {
    return items.fold(0.0, (sum, item) {
      double price = (item['price'] ?? 0.0).toDouble();
      int qty = (item['quantity'] ?? 1).toInt();
      return sum + (price * qty);
    });
  }

  /// Calcula métricas de um item individual (para linhas de tabela)
  static FinancialMetrics calculateItemMetrics({
    required double costPrice,
    required double sellPrice,
    required int quantity,
  }) {
    double totalCost = costPrice * quantity;
    double totalRevenue = sellPrice * quantity;
    double profit = totalRevenue - totalCost;
    double margin = totalRevenue > 0 ? (profit / totalRevenue) * 100 : 0.0;

    return FinancialMetrics(
      totalCost: totalCost,
      totalRevenue: totalRevenue,
      grossProfit: profit,
      marginPercent: margin,
    );
  }
}