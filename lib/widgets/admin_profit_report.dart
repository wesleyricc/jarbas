import 'package:flutter/material.dart';
import '../models/component_model.dart';

class AdminProfitReport extends StatelessWidget {
  final Component? blank;
  final String? blankVar;
  
  final Component? cabo;
  final int caboQty;
  final String? caboVar;
  
  final Component? reelSeat;
  final String? reelSeatVar;
  
  final List<Map<String, dynamic>> passadoresList;
  final List<Map<String, dynamic>> acessoriosList; // (NOVO)
  
  final double gravacaoCost;
  final double gravacaoPrice;

  const AdminProfitReport({
    super.key,
    required this.blank,
    this.blankVar,
    required this.cabo,
    required this.caboQty,
    this.caboVar,
    required this.reelSeat,
    this.reelSeatVar,
    required this.passadoresList,
    required this.acessoriosList, // (NOVO)
    required this.gravacaoCost,
    required this.gravacaoPrice,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> rows = [];
    
    if (blank != null) _addRow(rows, 'Blank', blank!.name, blankVar, blank!.costPrice, blank!.price, 1);
    if (cabo != null) _addRow(rows, 'Cabo', cabo!.name, caboVar, cabo!.costPrice, cabo!.price, caboQty);
    if (reelSeat != null) _addRow(rows, 'Reel Seat', reelSeat!.name, reelSeatVar, reelSeat!.costPrice, reelSeat!.price, 1);
    
    // Passadores
    for (var p in passadoresList) {
      _addRowFromMap(rows, 'Passador', p);
    }

    // Acessórios (NOVO)
    for (var a in acessoriosList) {
      _addRowFromMap(rows, 'Acessório', a);
    }
    
    if (gravacaoPrice > 0) {
      double profit = gravacaoPrice - gravacaoCost;
      rows.add({
        'item': 'Gravação',
        'name': 'Personalização',
        'qty': 1,
        'costUnit': gravacaoCost,
        'sellUnit': gravacaoPrice,
        'totalCost': gravacaoCost,
        'totalSell': gravacaoPrice,
        'profit': profit,
      });
    }

    // Cálculos Gerais
    double totalCost = 0;
    double totalSell = 0;
    double totalProfit = 0;

    for (var row in rows) {
      totalCost += row['totalCost'];
      totalSell += row['totalSell'];
      totalProfit += row['profit'];
    }

    double totalMargin = totalSell > 0 ? (totalProfit / totalSell) * 100 : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey[200]!),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Cabeçalho
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey[800],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: const Text(
              'ANÁLISE DE LUCRATIVIDADE (ADMIN)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),

          // Lista Expansível
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = rows[index];
              return _buildExpandableRow(row);
            },
          ),
          
          const Divider(height: 1, thickness: 2),

          // Rodapé
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildTotalRow('Custo Total:', totalCost, Colors.blueGrey[600]!),
                const SizedBox(height: 8),
                _buildTotalRow('Venda Total:', totalSell, Colors.red[700]!),
                const Divider(height: 16),
                _buildTotalRow('LUCRO LÍQUIDO:', totalProfit, Colors.green[700]!),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('MARGEM GERAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                    Text('${totalMargin.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- Helpers ---

  void _addRow(List<Map<String, dynamic>> rows, String type, String name, String? variation, double cost, double price, int qty) {
    double totalCost = cost * qty;
    double totalSell = price * qty;
    
    String displayName = name;
    if (variation != null && variation.isNotEmpty) {
      displayName += " ($variation)";
    }
    
    // Prefixo apenas para diferenciar
    if (type == 'Passador') displayName = "Passador: $displayName";
    if (type == 'Acessório') displayName = "Acess.: $displayName";

    rows.add({
      'item': displayName,
      'qty': qty,
      'costUnit': cost,
      'sellUnit': price,
      'totalCost': totalCost,
      'totalSell': totalSell,
      'profit': totalSell - totalCost,
    });
  }

  // Helper para adicionar vindo de Maps (Lista de Passadores/Acessórios)
  void _addRowFromMap(List<Map<String, dynamic>> rows, String type, Map<String, dynamic> map) {
    String name = map['name'] ?? 'Desc.';
    String? variation = map['variation'];
    double cost = (map['cost'] ?? 0.0).toDouble();
    double price = (map['price'] ?? 0.0).toDouble();
    int qty = (map['quantity'] ?? 1).toInt();

    _addRow(rows, type, name, variation, cost, price, qty);
  }

  String _fmt(double val) => 'R\$ ${val.toStringAsFixed(2)}';

  Widget _buildExpandableRow(Map<String, dynamic> row) {
    double margin = row['totalSell'] > 0 ? (row['profit'] / row['totalSell']) * 100 : 0;
    
    return ExpansionTile(
      backgroundColor: Colors.blueGrey[50],
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      
      title: Text(row['item'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15)),
      subtitle: Text('Qtd: ${row['qty']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('Lucro', style: TextStyle(fontSize: 10, color: Colors.grey)),
          Text(_fmt(row['profit']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15)),
        ],
      ),
      
      children: [
        const Divider(),
        _buildDetailLine(
          label1: 'Custo Unit.:', val1: _fmt(row['costUnit']), color1: Colors.black54,
          label2: 'Custo Total:', val2: _fmt(row['totalCost']), color2: Colors.black87,
        ),
        const SizedBox(height: 8),
        _buildDetailLine(
          label1: 'Venda Unit.:', val1: _fmt(row['sellUnit']), color1: Colors.black54,
          label2: 'Venda Total:', val2: _fmt(row['totalSell']), color2: Colors.red[700]!,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
             const Text('Margem: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
             Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getMarginColor(margin),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${margin.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
             )
          ],
        )
      ],
    );
  }

  Widget _buildDetailLine({required String label1, required String val1, required Color color1, required String label2, required String val2, required Color color2}) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(label1, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 4),
              Text(val1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color1)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(label2, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 4),
              Text(val2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, double val, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        Text(_fmt(val), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
      ],
    );
  }

  Color _getMarginColor(double margin) {
    if (margin >= 50) return Colors.green;
    if (margin >= 30) return Colors.orange;
    return Colors.red;
  }
}