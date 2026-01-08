import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rod_builder_provider.dart';
import '../models/component_model.dart';

class SummaryStep extends StatelessWidget {
  final bool isAdmin;
  const SummaryStep({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RodBuilderProvider>();

    // --- CÁLCULOS GERAIS PARA O ADMIN ---
    double totalCostPrice = 0.0;
    if (isAdmin) {
      double sumCost(List<RodItem> list) {
        return list.fold(0.0, (sum, item) => sum + (item.component.costPrice * item.quantity));
      }
      totalCostPrice += sumCost(provider.selectedBlanksList);
      totalCostPrice += sumCost(provider.selectedCabosList);
      totalCostPrice += sumCost(provider.selectedReelSeatsList);
      totalCostPrice += sumCost(provider.selectedPassadoresList);
      totalCostPrice += sumCost(provider.selectedAcessoriosList);
    }

    double estimatedProfit = provider.totalPrice - totalCostPrice;
    double marginPercent = provider.totalPrice > 0 
        ? (estimatedProfit / provider.totalPrice) * 100 
        : 0.0;
    // ------------------------------------

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Resumo da Montagem', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 24),

        // --- DADOS CLIENTE ---
        _buildSectionTitle('Dados do Cliente'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(8), 
            border: Border.all(color: Colors.grey[300]!)
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${provider.clientName} - ${provider.clientPhone}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              Text('${provider.clientCity}/${provider.clientState}', style: TextStyle(color: Colors.grey[800])),
            ],
          ),
        ),
        const Divider(height: 32),

        // --- LISTAGEM DE ITENS ---
        _buildSectionTitle(isAdmin ? 'Análise Detalhada (Custos e Vendas)' : 'Lista de Componentes'),
        
        if (isAdmin) ...[
          // ADMIN: TABELA SUPER DETALHADA
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildDetailedFinancialGroup('Blanks', provider.selectedBlanksList),
                _buildDetailedFinancialGroup('Cabos', provider.selectedCabosList),
                _buildDetailedFinancialGroup('Reel Seats', provider.selectedReelSeatsList),
                _buildDetailedFinancialGroup('Passadores', provider.selectedPassadoresList),
                _buildDetailedFinancialGroup('Acessórios', provider.selectedAcessoriosList),
              ],
            ),
          )
        ] else ...[
          // CLIENTE: LISTA SIMPLES
          _buildListSummary('Blanks', provider.selectedBlanksList),
          _buildListSummary('Cabos', provider.selectedCabosList),
          _buildListSummary('Reel Seats', provider.selectedReelSeatsList),
          _buildListSummary('Passadores', provider.selectedPassadoresList),
          _buildListSummary('Acessórios', provider.selectedAcessoriosList),
        ],

        const Divider(height: 32),
        
        // --- PERSONALIZAÇÃO ---
        _buildSectionTitle('Personalização'),
        Text(
          provider.customizationText.isEmpty ? 'Nenhuma observação.' : provider.customizationText,
          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
        ),

        const Divider(height: 32),

        // ============================================================
        //              RESUMO FINANCEIRO TOTAL (ADMIN)
        // ============================================================
        if (isAdmin) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, // Fundo Branco limpo
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueGrey[200]!),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assessment_outlined, size: 20, color: Colors.blueGrey[800]),
                    const SizedBox(width: 8),
                    Text("BALANÇO FINANCEIRO (ADMIN)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[800], fontSize: 14)),
                  ],
                ),
                const Divider(height: 24),
                
                // Linhas de totais
                _buildSummaryRow("Receita Bruta:", provider.totalPrice, isBold: false),
                _buildSummaryRow("Custo Total Peças:", totalCostPrice, isNegative: true),
                if(provider.extraLaborCost > 0)
                  _buildSummaryRow("Mão de Obra (Extra):", provider.extraLaborCost, isBold: true),
                
                const SizedBox(height: 16),
                
                // Card de Lucro Destacado
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50], 
                    borderRadius: BorderRadius.circular(8), 
                    border: Border.all(color: Colors.green[300]!)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("LUCRO LÍQUIDO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("R\$ ${estimatedProfit.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green[900])),
                          Text("Margem: ${marginPercent.toStringAsFixed(1)}%", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[800])),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
        // ============================================================

        // --- RODAPÉ VISUAL PADRÃO (CLIENTE/ADMIN) ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Peças:', style: TextStyle(color: Colors.grey)),
            Text('R\$ ${(provider.totalPrice - provider.extraLaborCost).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        if (provider.extraLaborCost > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mão de Obra / Extras:', style: TextStyle(color: Colors.grey)),
                Text('R\$ ${provider.extraLaborCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueGrey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL DO PEDIDO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('R\$ ${provider.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(), 
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey[700], letterSpacing: 0.5)
      ),
    );
  }

  // --- LISTA SIMPLES (CLIENTE) ---
  Widget _buildListSummary(String title, List<RodItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text("${item.quantity}x ${item.component.name}${item.variation != null ? ' (${item.variation})' : ''}", style: const TextStyle(fontSize: 13))),
                Text("R\$ ${(item.component.price * item.quantity).toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // --- TABELA DETALHADA FINANCEIRA (ADMIN) ---
  Widget _buildDetailedFinancialGroup(String categoryName, List<RodItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        // Cabeçalho da Categoria
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.grey[200],
          child: Text(categoryName.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        ),
        
        // Itens
        ...items.map((item) {
          // Cálculos
          double unitCost = item.component.costPrice;
          double totalCost = unitCost * item.quantity;
          
          double unitSale = item.component.price;
          double totalSale = unitSale * item.quantity;
          
          double profit = totalSale - totalCost;
          double margin = totalSale > 0 ? (profit / totalSale) * 100 : 0.0;
          
          String variation = item.variation != null ? " [${item.variation}]" : "";

          return Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nome e Quantidade
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "${item.quantity}x ${item.component.name}$variation",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // LINHA DE DADOS (3 COLUNAS)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- COLUNA 1: CUSTOS (Vermelho/Cinza) ---
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("CUSTO", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text("Un: R\$ ${unitCost.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          Text("Tot: R\$ ${totalCost.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[800])),
                        ],
                      ),
                    ),
                    
                    // Separador Vertical Sutil
                    Container(width: 1, height: 24, color: Colors.grey[300]),
                    const SizedBox(width: 8),

                    // --- COLUNA 2: VENDAS (Azul/Preto) ---
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("VENDA", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text("Un: R\$ ${unitSale.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          Text("Tot: R\$ ${totalSale.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
                        ],
                      ),
                    ),

                    // --- COLUNA 3: RESULTADO (Verde) ---
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(6)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("Mg: ${margin.toStringAsFixed(1)}%", style: TextStyle(fontSize: 10, color: Colors.green[800])),
                            Text("R\$ ${profit.toStringAsFixed(2)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green[900])),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          );
        }),
        const Divider(height: 1, color: Colors.grey),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isNegative = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[800], fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            "${isNegative ? '-' : ''}R\$ ${value.toStringAsFixed(2)}", 
            style: TextStyle(
              fontSize: 14, 
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isNegative ? Colors.red[800] : Colors.black87
            )
          ),
        ],
      ),
    );
  }
}