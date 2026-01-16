import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_constants.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');
  bool _isLoading = true;

  // Filtro de Datas
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  // Variáveis de Dados
  double _totalRevenue = 0.0;
  double _totalMaterialCost = 0.0;
  double _totalLaborRevenue = 0.0;
  int _salesCount = 0;
  Map<String, int> _topItems = {};
  List<Map<String, dynamic>> _monthlyStats = [];

  final Set<String> _salesStatuses = {
    AppConstants.statusAprovado,
    AppConstants.statusProducao,
    AppConstants.statusConcluido,
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDashboardData());
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? newRange = await showDateRangePicker(
      context: context,
      locale: const Locale("pt", "BR"), // <--- ADICIONE ESTA LINHA
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blueGrey[800],
            colorScheme: ColorScheme.light(primary: Colors.blueGrey[800]!),
          ),
          child: child!,
        );
      },
    );

    if (newRange != null) {
      setState(() {
        _dateRange = newRange;
      });
      _fetchDashboardData();
    }
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      
      final snapshot = await db.collection(AppConstants.colQuotes)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_dateRange.start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_dateRange.end))
          .get();

      double revenue = 0.0;
      double materialCost = 0.0;
      double labor = 0.0;
      int count = 0;
      Map<String, int> itemsCounter = {};
      Map<String, Map<String, double>> monthsMap = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? '';

        if (_salesStatuses.contains(status)) {
          count++;
          
          double quoteTotal = (data['totalPrice'] ?? 0.0).toDouble();
          double quoteLabor = (data['extraLaborCost'] ?? 0.0).toDouble();
          
          revenue += quoteTotal;
          labor += quoteLabor;

          double quoteCost = 0.0;
          
          void processList(List<dynamic> list) {
            for (var item in list) {
              int qty = (item['quantity'] ?? 1) as int;
              double unitCost = (item['costPrice'] ?? item['cost'] ?? 0.0).toDouble();
              quoteCost += (unitCost * qty);

              String name = item['name'] ?? 'Item';
              itemsCounter[name] = (itemsCounter[name] ?? 0) + qty;
            }
          }

          processList(data['blanksList'] ?? []);
          processList(data['cabosList'] ?? []);
          processList(data['reelSeatsList'] ?? []);
          processList(data['passadoresList'] ?? []);
          processList(data['acessoriosList'] ?? []);

          materialCost += quoteCost;

          Timestamp ts = data['createdAt'];
          DateTime date = ts.toDate();
          String monthKey = DateFormat("MM/yyyy").format(date);
          
          if (!monthsMap.containsKey(monthKey)) {
            monthsMap[monthKey] = {"rev": 0.0, "cost": 0.0};
          }
          monthsMap[monthKey]!["rev"] = monthsMap[monthKey]!["rev"]! + quoteTotal;
          monthsMap[monthKey]!["cost"] = monthsMap[monthKey]!["cost"]! + quoteCost;
        }
      }

      var sortedKeys = itemsCounter.keys.toList(growable: false)
        ..sort((k1, k2) => itemsCounter[k2]!.compareTo(itemsCounter[k1]!));
      Map<String, int> top5 = Map.fromIterable(
        sortedKeys.take(5), 
        key: (k) => k, 
        value: (k) => itemsCounter[k]!
      );

      List<Map<String, dynamic>> monthlyStatsList = [];
      monthsMap.forEach((key, value) {
        monthlyStatsList.add({
          'month': key,
          'revenue': value['rev'],
          'cost': value['cost'],
        });
      });

      if (mounted) {
        setState(() {
          _totalRevenue = revenue;
          _totalMaterialCost = materialCost;
          _totalLaborRevenue = labor;
          _salesCount = count;
          _topItems = top5;
          _monthlyStats = monthlyStatsList;
          _isLoading = false;
        });
      }

    } catch (e) {
      print("Erro no dashboard: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- WIDGETS ---

  Widget _buildKPICard(String title, double value, IconData icon, Color color, {bool isCurrency = true, String? subtitle}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isCurrency ? _currencyFormat.format(value) : value.toString(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildProfitCard() {
    double grossProfit = _totalRevenue - _totalMaterialCost;
    double margin = _totalRevenue > 0 ? (grossProfit / _totalRevenue) * 100 : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blueGrey[900]!, Colors.blueGrey[800]!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.blueGrey.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: [
          const Text("LUCRO BRUTO DO PERÍODO", style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(_currencyFormat.format(grossProfit), style: const TextStyle(color: Colors.greenAccent, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Text("Margem: ${margin.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(children: [
                const Text("Materiais", style: TextStyle(color: Colors.white54, fontSize: 11)),
                Text(_currencyFormat.format(_totalMaterialCost), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ]),
              Container(height: 20, width: 1, color: Colors.white24),
              Column(children: [
                const Text("Mão de Obra (Ganho)", style: TextStyle(color: Colors.white54, fontSize: 11)),
                Text(_currencyFormat.format(_totalLaborRevenue), style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
              ]),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTopItemsList() {
    if (_topItems.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Itens Mais Vendidos", style: TextStyle(color: Colors.blueGrey[800], fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._topItems.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 24, height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                    child: Text("${entry.value}", style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(entry.key, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[600]))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart() {
    if (_monthlyStats.isEmpty) return const SizedBox();

    double maxVal = _monthlyStats.map((e) => e['revenue'] as double).reduce((a, b) => a > b ? a : b);
    if(maxVal == 0) maxVal = 1;

    return Container(
      width: double.infinity, 
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.grey.shade200)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Evolução Mensal (Venda vs Custo)", style: TextStyle(color: Colors.blueGrey[800], fontWeight: FontWeight.bold, fontSize: 16)),
                                                         
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _monthlyStats.map((stat) {
                double rev = stat['revenue'];
                double cost = stat['cost'];
                
                double hRev = (rev / maxVal) * 150;
                double hCost = (cost / maxVal) * 150;

                if (rev > 0 && hRev < 4) hRev = 4;
                if (cost > 0 && hCost < 4) hCost = 4;

                return Padding(
                  padding: const EdgeInsets.only(right: 24), 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            children: [
                              if (cost > 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: RotatedBox(
                                    quarterTurns: -1,
                                    child: Text(
                                      _currencyFormat.format(cost).replaceAll('R\$', '').trim(), 
                                      style: TextStyle(fontSize: 9, color: Colors.red[300])
                                    ),
                                  ),
                                ),
                              Container(
                                width: 14, 
                                height: hCost, 
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.7),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4))
                                )
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          Column(
                            children: [
                              if (rev > 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: RotatedBox(
                                    quarterTurns: -1,
                                    child: Text(
                                      _currencyFormat.format(rev).replaceAll('R\$', '').trim(), 
                                      style: TextStyle(fontSize: 9, color: Colors.green[700], fontWeight: FontWeight.bold)
                                    ),
                                  ),
                                ),
                              Container(
                                width: 14, 
                                height: hRev, 
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.7),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4))
                                )
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(stat['month'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double ticketMedio = _salesCount > 0 ? _totalRevenue / _salesCount : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      // SEM APP BAR
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CABEÇALHO DO FILTRO (CUSTOMIZADO)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.filter_list, size: 20, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Text(
                              "${DateFormat('dd/MM/yyyy').format(_dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange.end)}",
                              style: TextStyle(color: Colors.blueGrey[800], fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        // ÍCONE DE CALENDÁRIO AO LADO DA DATA
                        IconButton(
                          icon: const Icon(Icons.edit_calendar, color: Colors.blue),
                          onPressed: _selectDateRange,
                          tooltip: 'Alterar Período',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Card Principal de Lucro
                    _buildProfitCard(),
                    const SizedBox(height: 16),

                    // KPIs Secundários
                    Row(
                      children: [
                        _buildKPICard("Faturamento", _totalRevenue, Icons.attach_money, Colors.blue),
                        const SizedBox(width: 12),
                        _buildKPICard("Custo Total", _totalMaterialCost, Icons.shopping_cart_outlined, Colors.red),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildKPICard("Vendas (Qtd)", _salesCount.toDouble(), Icons.receipt_long, Colors.purple, isCurrency: false),
                        const SizedBox(width: 12),
                        _buildKPICard("Ticket Médio", ticketMedio, Icons.data_thresholding, Colors.orange),
                      ],
                    ),

                    const SizedBox(height: 24),
                    
                    // Gráfico Mensal
                    _buildMonthlyChart(),

                    const SizedBox(height: 24),

                    // Lista Top Itens
                    _buildTopItemsList(),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}