import 'package:flutter/material.dart';
import '../models/quote_model.dart';

class QuoteDetailScreen extends StatelessWidget {
  final Quote quote;

  const QuoteDetailScreen({super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    String formattedDate = "${quote.createdAt.toDate().day}/${quote.createdAt.toDate().month}/${quote.createdAt.toDate().year}";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Pedido'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey[200]!)
              ),
              child: Column(
                children: [
                  Text("Pedido realizado em: $formattedDate", style: TextStyle(color: Colors.blueGrey[800])),
                  const SizedBox(height: 8),
                  Text(
                    quote.status.toUpperCase(),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Itens
            const Text("Itens Selecionados", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            
            _buildSection("Blanks", quote.blanksList),
            _buildSection("Cabos", quote.cabosList),
            _buildSection("Reel Seats", quote.reelSeatsList),
            _buildSection("Passadores", quote.passadoresList),
            _buildSection("Acessórios", quote.acessoriosList),

            if (quote.customizationText != null && quote.customizationText!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text("Personalização", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(quote.customizationText!, style: const TextStyle(fontStyle: FontStyle.italic)),
            ],

            const SizedBox(height: 24),
            const Divider(thickness: 2),
            
            // Totais
            if (quote.extraLaborCost > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Mão de Obra / Extras:"),
                    Text("R\$ ${quote.extraLaborCost.toStringAsFixed(2)}"),
                  ],
                ),
              ),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TOTAL", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text("R\$ ${quote.totalPrice.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[700])),
          ...items.map((item) {
            String name = item['name'] ?? 'Item';
            String variation = item['variation'] != null ? " (${item['variation']})" : "";
            int qty = (item['quantity'] ?? 1).toInt();
            double price = (item['price'] ?? 0.0).toDouble();
            
            return Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text("${qty}x $name$variation", style: const TextStyle(fontSize: 14))),
                  Text("R\$ ${(price * qty).toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}