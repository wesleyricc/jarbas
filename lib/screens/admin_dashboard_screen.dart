import 'package:flutter/material.dart';
import '../models/quote_model.dart';
import '../services/quote_service.dart';
import '../utils/app_constants.dart';
import '../utils/financial_helper.dart'; // Import Helper

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final QuoteService _quoteService = QuoteService();
  
  // Lista de status que contam como venda realizada
  final List<String> _activeStatuses = [
    AppConstants.statusAprovado,
    AppConstants.statusProducao,
    AppConstants.statusConcluido,
    AppConstants.statusEnviado
  ];

  late int _selectedMonth;
  late int _selectedYear;
  
  bool _isComparing = false;
  late int _compareMonth;
  late int _compareYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    
    final prevDate = DateTime(now.year, now.month - 1);
    _compareMonth = prevDate.month;
    _compareYear = prevDate.year;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<List<Quote>>(
        stream: _quoteService.getAllQuotesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar dados.', style: TextStyle(color: Colors.red[800])));
          }
          
          final allQuotes = snapshot.data ?? [];
          final mainData = _calculatePeriodData(allQuotes, _selectedMonth, _selectedYear);
          DashboardData? compareData;
          if (_isComparing) {
            compareData = _calculatePeriodData(allQuotes, _compareMonth, _compareYear);
          }
          final chartData = _calculateYearlyData(allQuotes, _selectedYear);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFiltersCard(),
                const SizedBox(height: 24),

                _buildSectionTitle("Resultados Financeiros"),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard(
                        title: "Faturamento",
                        value: mainData.revenue,
                        compareValue: compareData?.revenue,
                        icon: Icons.attach_money,
                        color: Colors.blue[800]!,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildKpiCard(
                        title: "Lucro Líquido",
                        value: mainData.profit,
                        compareValue: compareData?.profit,
                        icon: Icons.trending_up,
                        color: Colors.green[800]!,
                        isProfit: true,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle("Evolução Anual ($_selectedYear)"),
                    Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blueGrey[800], borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 4),
                        const Text("Vendas", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 12),
                _buildScrollableBarChart(chartData),

                const SizedBox(height: 32),

                _buildSectionTitle("Top Itens (${_getMonthName(_selectedMonth)})"),
                const SizedBox(height: 12),
                _buildTopProductsList(mainData.topComponents),
                
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // ... Widgets de UI (KPI Card, Filters, Charts) permanecem iguais ...
  // Incluirei apenas o método de cálculo refatorado abaixo:

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(), 
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey[800], letterSpacing: 0.5)
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.blueGrey[700]),
                const SizedBox(width: 12),
                Text("Período:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey[900])),
                const SizedBox(width: 12),
                _buildMonthDropdown(_selectedMonth, (v) => setState(() => _selectedMonth = v!)),
                const SizedBox(width: 8),
                _buildYearDropdown(_selectedYear, (v) => setState(() => _selectedYear = v!)),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Switch(
                  value: _isComparing, 
                  onChanged: (val) => setState(() => _isComparing = val),
                  activeColor: Colors.blueGrey[800],
                ),
                const Text("Comparar com:", style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                IgnorePointer(
                  ignoring: !_isComparing,
                  child: Opacity(
                    opacity: _isComparing ? 1.0 : 0.4,
                    child: Row(
                      children: [
                        _buildMonthDropdown(_compareMonth, (v) => setState(() => _compareMonth = v!)),
                        const SizedBox(width: 8),
                        _buildYearDropdown(_compareYear, (v) => setState(() => _compareYear = v!)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthDropdown(int value, ValueChanged<int?> onChanged) {
    return DropdownButton<int>(
      value: value,
      isDense: true,
      underline: Container(height: 1, color: Colors.blueGrey[300]),
      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14),
      items: List.generate(12, (index) => DropdownMenuItem(
        value: index + 1,
        child: Text(_getMonthName(index + 1)),
      )),
      onChanged: onChanged,
    );
  }

  Widget _buildYearDropdown(int value, ValueChanged<int?> onChanged) {
    final currentYear = DateTime.now().year;
    return DropdownButton<int>(
      value: value,
      isDense: true,
      underline: Container(height: 1, color: Colors.blueGrey[300]),
      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14),
      items: List.generate(5, (index) => DropdownMenuItem(
        value: currentYear - index,
        child: Text((currentYear - index).toString()),
      )),
      onChanged: onChanged,
    );
  }

  Widget _buildKpiCard({
    required String title, 
    required double value, 
    double? compareValue,
    required IconData icon, 
    required Color color, 
    bool isProfit = false
  }) {
    double? percentChange;
    if (compareValue != null && compareValue != 0) {
      percentChange = ((value - compareValue) / compareValue) * 100;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(color: Colors.blueGrey[700], fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'R\$ ${value.toStringAsFixed(0)}', 
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
          
          if (_isComparing && percentChange != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: percentChange >= 0 ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    percentChange >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: percentChange >= 0 ? Colors.green[800] : Colors.red[800],
                    size: 16,
                  ),
                  Text(
                    '${percentChange.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: percentChange >= 0 ? Colors.green[800] : Colors.red[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildScrollableBarChart(List<MonthlyStat> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    double maxVal = 0;
    for (var d in data) { if (d.total > maxVal) maxVal = d.total; }
    if (maxVal == 0) maxVal = 1;

    return Container(
      height: 220, 
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.map((stat) {
            double percentage = stat.total / maxVal;
            bool isSelected = stat.monthInt == _selectedMonth;
            
            Color barColor = isSelected ? Colors.blueGrey[800]! : Colors.blueGrey[100]!;
            if (stat.total == 0) barColor = Colors.transparent;

            return Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (stat.total > 0)
                    Text(
                      stat.total > 1000 ? '${(stat.total/1000).toStringAsFixed(1)}k' : stat.total.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold, 
                        color: isSelected ? Colors.black87 : Colors.blueGrey[400]
                      ),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    height: 120 * percentage, 
                    width: 24,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stat.monthName.substring(0, 3).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11, 
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.blueGrey[900] : Colors.grey[500]
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopProductsList(List<MapEntry<String, int>> items) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text("Nenhuma venda neste período.", style: TextStyle(color: Colors.grey)),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: items.asMap().entries.map((entry) {
          int index = entry.key;
          String name = entry.value.key;
          int qty = entry.value.value;
          
          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: index < 3 ? Colors.amber[100 + (index * 100)] : Colors.grey[200],
                  child: Text(
                    "${index+1}", 
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey[900])
                  ),
                ),
                title: Text(
                  name, 
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  "$qty un", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey[800])
                ),
              ),
              if (index < items.length - 1) const Divider(height: 1, indent: 56, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  // --- LÓGICA DE CÁLCULO REFATORADA ---

  DashboardData _calculatePeriodData(List<Quote> allQuotes, int month, int year) {
    double revenue = 0;
    double profit = 0;
    Map<String, int> components = {};

    final periodQuotes = allQuotes.where((q) {
      if (!_activeStatuses.contains(q.status.toLowerCase())) return false;
      final d = q.createdAt.toDate();
      return d.month == month && d.year == year;
    });

    for (var quote in periodQuotes) {
      // USAMOS O HELPER AQUI
      final metrics = FinancialHelper.calculateQuoteMetrics(quote);
      
      revenue += metrics.totalRevenue;
      profit += metrics.grossProfit;

      // Logica de Top Items (mantida manual pois depende da contagem)
      void processList(List<Map<String, dynamic>> items) {
        for (var item in items) {
          int qty = ((item['quantity'] ?? 1) as num).toInt();
          String name = item['name'] ?? '';
          if (name.isNotEmpty) {
            components[name] = (components[name] ?? 0) + qty;
          }
        }
      }

      processList(quote.blanksList);
      processList(quote.cabosList);
      processList(quote.reelSeatsList);
      processList(quote.passadoresList);
      processList(quote.acessoriosList);
    }

    var sortedComponents = components.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return DashboardData(revenue: revenue, profit: profit, topComponents: sortedComponents.take(5).toList());
  }

  List<MonthlyStat> _calculateYearlyData(List<Quote> allQuotes, int year) {
    Map<int, double> monthsMap = {};
    for (int i = 1; i <= 12; i++) monthsMap[i] = 0.0;
    final yearQuotes = allQuotes.where((q) {
      return _activeStatuses.contains(q.status.toLowerCase()) && q.createdAt.toDate().year == year;
    });
    for (var q in yearQuotes) {
      int m = q.createdAt.toDate().month;
      monthsMap[m] = (monthsMap[m] ?? 0) + q.totalPrice;
    }
    List<MonthlyStat> result = [];
    monthsMap.forEach((k, v) {
      result.add(MonthlyStat(monthInt: k, monthName: _getMonthName(k), total: v));
    });
    result.sort((a, b) => a.monthInt.compareTo(b.monthInt));
    return result;
  }

  String _getMonthName(int month) => ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'][month - 1];
}

class DashboardData {
  final double revenue;
  final double profit;
  final List<MapEntry<String, int>> topComponents;
  DashboardData({required this.revenue, required this.profit, required this.topComponents});
}

class MonthlyStat {
  final int monthInt;
  final String monthName;
  final double total;
  MonthlyStat({required this.monthInt, required this.monthName, required this.total});
}