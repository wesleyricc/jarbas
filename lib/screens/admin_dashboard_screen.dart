import 'package:flutter/material.dart';
import '../models/quote_model.dart';
import '../services/quote_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final QuoteService _quoteService = QuoteService();
  final List<String> _activeStatuses = ['aprovado', 'producao', 'concluido'];

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
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<List<Quote>>(
        stream: _quoteService.getAllQuotesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
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

                const Text(
                  "Resultados do Período",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
                const SizedBox(height: 16),
                
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
                    Text(
                      "Evolução ($_selectedYear)",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blueGrey[800], borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 4),
                        const Text("Atual", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 16),
                _buildScrollableBarChart(chartData),

                const SizedBox(height: 32),

                Text(
                  "Top Itens (${_getMonthName(_selectedMonth)})",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
                const SizedBox(height: 16),
                _buildTopProductsList(mainData.topComponents),
                
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGETS DE FILTRO ---

  Widget _buildFiltersCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blueGrey[100]!)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.blueGrey),
                const SizedBox(width: 12),
                const Text("Período:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
      underline: Container(height: 1, color: Colors.blueGrey),
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
      underline: Container(height: 1, color: Colors.blueGrey),
      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14),
      items: List.generate(5, (index) => DropdownMenuItem(
        value: currentYear - index,
        child: Text((currentYear - index).toString()),
      )),
      onChanged: onChanged,
    );
  }

  // --- WIDGETS DE DADOS ---

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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(color: Colors.blueGrey[700], fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
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
      height: 240, 
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
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
                        fontSize: 11, 
                        fontWeight: FontWeight.bold, 
                        color: isSelected ? Colors.black87 : Colors.blueGrey[600]
                      ),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    height: 140 * percentage, 
                    width: 32,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stat.monthName.substring(0, 3).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.blueGrey[900] : Colors.grey[600]
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          int index = entry.key;
          String name = entry.value.key;
          int qty = entry.value.value;
          
          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: index == 0 ? Colors.amber[100] : (index == 1 ? Colors.grey[200] : Colors.orange[50]),
                  child: Text(
                    "${index+1}", 
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey[900])
                  ),
                ),
                title: Text(
                  name, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    "$qty un", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey[900])
                  ),
                ),
              ),
              if (index < items.length - 1) const Divider(height: 1, indent: 70, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  // --- LÓGICA DE CÁLCULO (CORRIGIDA) ---

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
      revenue += quote.totalPrice;
      
      double cost = 0;
      
      // Helper para processar listas
      void processList(List<Map<String, dynamic>> items) {
        for (var item in items) {
          double itemCost = (item['cost'] ?? 0.0).toDouble();
          
          // CORREÇÃO AQUI: Cast seguro para num, depois para int
          int qty = ((item['quantity'] ?? 1) as num).toInt();
          
          cost += itemCost * qty;
          
          String name = item['name'] ?? '';
          if (name.isNotEmpty) {
            // CORREÇÃO AQUI: Cast seguro para somar no mapa
            components[name] = (components[name] ?? 0) + qty;
          }
        }
      }

      processList(quote.blanksList);
      processList(quote.cabosList);
      processList(quote.reelSeatsList);
      processList(quote.passadoresList);
      processList(quote.acessoriosList);
      
      profit += (quote.totalPrice - cost);
    }

    var sortedComponents = components.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    return DashboardData(
      revenue: revenue,
      profit: profit,
      topComponents: sortedComponents.take(5).toList(),
    );
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

  String _getMonthName(int month) {
    const months = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    return months[month - 1];
  }
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