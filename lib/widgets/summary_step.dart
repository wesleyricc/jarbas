import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rod_builder_provider.dart';
import '../utils/financial_helper.dart'; 

class SummaryStep extends StatelessWidget {
  final bool isAdmin;
  const SummaryStep({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RodBuilderProvider>();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildClientInfoCard(provider),
        const SizedBox(height: 24),

        const Text(
          "Itens do Projeto",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
        const SizedBox(height: 12),

        if (isAdmin) ...[
          _buildAdminComponentList(provider),
          const SizedBox(height: 24),
          _buildAdminFinancialTotals(provider),
        ] else ...[
          _buildClientComponentList(provider),
        ],
      ],
    );
  }

  Widget _buildClientInfoCard(RodBuilderProvider provider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blueGrey[700]),
                const SizedBox(width: 8),
                const Text("DADOS DO CLIENTE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const Divider(),
            _buildInfoRow("Nome:", provider.clientName),
            _buildInfoRow("Telefone:", provider.clientPhone),
            _buildInfoRow("Local:", "${provider.clientCity} - ${provider.clientState}"),
            if (provider.customizationText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(4)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("PERSONALIZAÇÃO (GRAVAÇÃO)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber[900])),
                      Text(provider.customizationText, style: const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildClientComponentList(RodBuilderProvider provider) {
    return Column(
      children: [
        _buildSimpleGroup("Blanks", provider.selectedBlanksList),
        _buildSimpleGroup("Cabos", provider.selectedCabosList),
        _buildSimpleGroup("Reel Seats", provider.selectedReelSeatsList),
        _buildSimpleGroup("Passadores", provider.selectedPassadoresList),
        _buildSimpleGroup("Acessórios", provider.selectedAcessoriosList),
      ],
    );
  }

  // --- CORREÇÃO DE VISIBILIDADE AQUI ---
  Widget _buildSimpleGroup(String title, List<RodItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
          child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
        ),
        ...items.map((item) {
          String variation = item.variation != null ? " - ${item.variation}" : "";
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              children: [
                // Quantidade em destaque
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blueGrey[200]!)
                  ),
                  child: Text("${item.quantity}x", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                ),
                const SizedBox(width: 12),
                
                // Texto Principal com cor mais forte (Correção de Contraste)
                Expanded(
                  child: Text(
                    "${item.component.name}$variation", 
                    style: const TextStyle(
                      color: Colors.black87, // Cor escura para contraste no fundo branco
                      fontWeight: FontWeight.w500,
                      fontSize: 14
                    )
                  )
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAdminComponentList(RodBuilderProvider provider) {
    return Column(
      children: [
        _buildDetailedGroup("Blanks", provider.selectedBlanksList),
        _buildDetailedGroup("Cabos", provider.selectedCabosList),
        _buildDetailedGroup("Reel Seats", provider.selectedReelSeatsList),
        _buildDetailedGroup("Passadores", provider.selectedPassadoresList),
        _buildDetailedGroup("Acessórios", provider.selectedAcessoriosList),
      ],
    );
  }

  Widget _buildDetailedGroup(String categoryName, List<RodItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.blueGrey[100],
          child: Text(categoryName.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey[900])),
        ),
        ...items.map((item) {
          final metrics = FinancialHelper.calculateItemMetrics(
            costPrice: item.component.costPrice,
            sellPrice: item.component.price,
            quantity: item.quantity,
          );
          
          String variation = item.variation != null ? " [${item.variation}]" : "";

          return Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            margin: const EdgeInsets.only(bottom: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                       decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(4)),
                       child: Text("${item.quantity}x", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text("${item.component.name}$variation", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("CUSTO", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text("Un: R\$ ${item.component.costPrice.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          Text("Tot: R\$ ${metrics.totalCost.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[800])),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 24, color: Colors.grey[300]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("VENDA", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text("Un: R\$ ${item.component.price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          Text("Tot: R\$ ${metrics.totalRevenue.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(6)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("Mg: ${metrics.marginPercent.toStringAsFixed(0)}%", style: TextStyle(fontSize: 9, color: Colors.green[800])),
                          Text("R\$ ${metrics.grossProfit.toStringAsFixed(2)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green[900])),
                        ],
                      ),
                    ),
                  ],
                )
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAdminFinancialTotals(RodBuilderProvider provider) {
    double sumCost(List<RodItem> list) => list.fold(0.0, (sum, item) => sum + (item.component.costPrice * item.quantity));
    
    double totalPartsCost = 0.0;
    totalPartsCost += sumCost(provider.selectedBlanksList);
    totalPartsCost += sumCost(provider.selectedCabosList);
    totalPartsCost += sumCost(provider.selectedReelSeatsList);
    totalPartsCost += sumCost(provider.selectedPassadoresList);
    totalPartsCost += sumCost(provider.selectedAcessoriosList);

    double totalRevenue = provider.totalPrice; 
    double totalProfit = totalRevenue - totalPartsCost;
    double marginPercent = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monetization_on, size: 24, color: Colors.blueGrey[800]),
              const SizedBox(width: 8),
              Text("RESUMO FINANCEIRO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[800], fontSize: 16)),
            ],
          ),
          const Divider(height: 24),
          
          _buildSummaryRow("Receita Bruta (Venda):", totalRevenue, isBold: false),
          _buildSummaryRow("Custo Peças:", totalPartsCost, isNegative: true),
          if(provider.extraLaborCost > 0)
            _buildSummaryRow("Mão de Obra (Adicional):", provider.extraLaborCost, isBold: true),
          
          const SizedBox(height: 16),
          const Divider(thickness: 1, height: 1),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("LUCRO LÍQUIDO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("R\$ ${totalProfit.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.green[800])),
                  Text("Margem Total: ${marginPercent.toStringAsFixed(1)}%", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[700])),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isNegative = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            "${isNegative ? '-' : ''}R\$ ${value.toStringAsFixed(2)}", 
            style: TextStyle(
              fontSize: 15, 
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500, 
              color: isNegative ? Colors.red[800] : Colors.black87
            )
          ),
        ],
      ),
    );
  }
}