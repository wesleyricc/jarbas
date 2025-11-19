import 'package:flutter/material.dart';
import '../models/component_model.dart';

class AdminProfitReport extends StatelessWidget {
  final Component? blank;
  final Component? cabo;
  final int caboQty;
  final Component? reelSeat;
  final Component? passadores;
  final int passadoresQty;
  final double gravacaoCost;
  final double gravacaoPrice;

  const AdminProfitReport({
    super.key,
    required this.blank,
    required this.cabo,
    required this.caboQty,
    required this.reelSeat,
    required this.passadores,
    required this.passadoresQty,
    required this.gravacaoCost,
    required this.gravacaoPrice,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Preparar os dados (Lógica Mantida)
    final List<Map<String, dynamic>> rows = [];
    
    if (blank != null) _addRow(rows, 'Blank', blank!, 1);
    if (cabo != null) _addRow(rows, 'Cabo', cabo!, caboQty);
    if (reelSeat != null) _addRow(rows, 'Reel Seat', reelSeat!, 1);
    if (passadores != null) _addRow(rows, 'Passadores', passadores!, passadoresQty);
    
    if (gravacaoPrice > 0) {
      rows.add({
        'item': 'Gravação',
        'qty': 1,
        'costUnit': gravacaoCost,
        'sellUnit': gravacaoPrice,
        'totalCost': gravacaoCost,
        'totalSell': gravacaoPrice,
        'profit': gravacaoPrice - gravacaoCost,
      });
    }

    // 2. Calcular Totais Gerais
    double totalCost = 0;
    double totalSell = 0;
    double totalProfit = 0;

    for (var row in rows) {
      totalCost += row['totalCost'];
      totalSell += row['totalSell'];
      totalProfit += row['profit'];
    }

    double totalMargin = totalSell > 0 ? (totalProfit / totalSell) * 100 : 0;

    // 3. Construir a UI (Nova Estrutura em Lista Expansível)
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

          // Lista de Itens Expansíveis
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // Rola com a página principal
            itemCount: rows.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = rows[index];
              return _buildExpandableRow(row);
            },
          ),
          
          const Divider(height: 1, thickness: 2),

          // Rodapé com Totais (Mantido o estilo visual que você gostou)
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
                
                // Margem Geral
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

  // --- LÓGICA DE DADOS ---
  void _addRow(List<Map<String, dynamic>> rows, String name, Component comp, int qty) {
    double totalCost = comp.costPrice * qty;
    double totalSell = comp.price * qty;
    rows.add({
      'item': comp.name,
      'qty': qty,
      'costUnit': comp.costPrice,
      'sellUnit': comp.price,
      'totalCost': totalCost,
      'totalSell': totalSell,
      'profit': totalSell - totalCost,
    });
  }

  String _fmt(double val) => 'R\$ ${val.toStringAsFixed(2)}';

  // --- NOVOS WIDGETS ---

  // Constrói a linha expansível
  Widget _buildExpandableRow(Map<String, dynamic> row) {
    double margin = row['totalSell'] > 0 ? (row['profit'] / row['totalSell']) * 100 : 0;
    
    return ExpansionTile(
      backgroundColor: Colors.blueGrey[50], // Cor de fundo leve ao expandir
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      
      // 1. Cabeçalho (Sempre visível)
      title: Text(
        row['item'],
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15),
      ),
      subtitle: Text(
        'Qtd: ${row['qty']}', 
        style: TextStyle(color: Colors.grey[600], fontSize: 13)
      ),
      // O Lucro fica sempre visível à direita
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('Lucro', style: TextStyle(fontSize: 10, color: Colors.grey)),
          Text(
            _fmt(row['profit']),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15),
          ),
        ],
      ),
      
      // 2. Detalhes (Visíveis ao clicar)
      children: [
        const Divider(),
        // Linha 1: Custos
        _buildDetailLine(
          label1: 'Custo Unit.:', val1: _fmt(row['costUnit']), color1: Colors.black54,
          label2: 'Custo Total:', val2: _fmt(row['totalCost']), color2: Colors.black87,
        ),
        const SizedBox(height: 8),
        
        // Linha 2: Vendas
        _buildDetailLine(
          label1: 'Venda Unit.:', val1: _fmt(row['sellUnit']), color1: Colors.black54,
          label2: 'Venda Total:', val2: _fmt(row['totalSell']), color2: Colors.red[700]!, // Destaque Vermelho
        ),
        const SizedBox(height: 8),

        // Linha 3: Margem
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
                child: Text(
                  '${margin.toStringAsFixed(0)}%', 
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                ),
             )
          ],
        )
      ],
    );
  }

  // Helper para as linhas internas de detalhe
  Widget _buildDetailLine({
    required String label1, required String val1, required Color color1,
    required String label2, required String val2, required Color color2,
  }) {
    return Row(
      children: [
        // Coluna Esquerda (Unitário)
        Expanded(
          child: Row(
            children: [
              Text(label1, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 4),
              Text(val1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color1)),
            ],
          ),
        ),
        // Coluna Direita (Total)
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

  // Widget de Rodapé (Igual ao anterior, com fontes grandes)
  Widget _buildTotalRow(String label, double val, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label, 
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)
        ),
        Text(
          _fmt(val), 
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)
        ),
      ],
    );
  }

  Color _getMarginColor(double margin) {
    if (margin >= 50) return Colors.green;
    if (margin >= 30) return Colors.orange;
    return Colors.red;
  }
}