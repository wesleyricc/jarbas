import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/rod_builder_provider.dart';
import 'admin_profit_report.dart';

class SummaryStep extends StatelessWidget {
  final bool isAdmin;

  const SummaryStep({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RodBuilderProvider>();

    // 1. Prepara lista de PASSADORES para o Relatório
    final List<Map<String, dynamic>> passadoresForReport = provider.selectedPassadoresList.map((item) {
      return {
        'name': item.component.name,
        'variation': item.variation,
        'cost': item.component.costPrice,
        'price': item.component.price,
        'quantity': item.quantity,
      };
    }).toList();

    // 2. Prepara lista de ACESSÓRIOS para o Relatório (NOVO)
    final List<Map<String, dynamic>> acessoriosForReport = provider.selectedAcessoriosList.map((item) {
      return {
        'name': item.component.name,
        'variation': item.variation,
        'cost': item.component.costPrice,
        'price': item.component.price,
        'quantity': item.quantity,
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- SEÇÃO 1: DADOS DO CLIENTE ---
        _buildSectionCard(
          title: 'Dados do Cliente',
          icon: Icons.person_outline,
          children: [
            _buildSummaryRow(
              'Nome:',
              provider.clientName.isEmpty ? 'Não informado' : provider.clientName,
            ),
            _buildSummaryRow(
              'Telefone:',
              provider.clientPhone.isEmpty ? 'Não informado' : provider.clientPhone,
            ),
            _buildSummaryRow(
              'Local:',
              (provider.clientCity.isEmpty || provider.clientState.isEmpty)
                  ? 'Não informado'
                  : '${provider.clientCity}/${provider.clientState}',
            ),
          ],
        ),
        
        const SizedBox(height: 16),

        // --- SEÇÃO 2: COMPONENTES ---
        _buildSectionCard(
          title: 'Componentes Selecionados',
          icon: Icons.inventory_2_outlined,
          children: [
            _buildItemRow(
              'Blank:',
              provider.selectedBlank?.name,
              provider.selectedBlank?.price,
              variation: provider.selectedBlankVariation,
            ),
            _buildItemRow(
              'Cabo:',
              provider.selectedCabo?.name,
              provider.selectedCabo?.price,
              quantity: provider.caboQuantity,
              variation: provider.selectedCaboVariation,
            ),
            _buildItemRow(
              'Reel Seat:',
              provider.selectedReelSeat?.name,
              provider.selectedReelSeat?.price,
              variation: provider.selectedReelSeatVariation,
            ),
            
            // --- Lista de Passadores ---
            const Padding(
              padding: EdgeInsets.only(top: 12.0, bottom: 4.0),
              child: Text("Passadores:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            if (provider.selectedPassadoresList.isEmpty)
              const Text("Nenhum selecionado", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
            else
              ...provider.selectedPassadoresList.map((item) => _buildItemRow(
                '-', 
                item.component.name,
                item.component.price,
                quantity: item.quantity,
                variation: item.variation,
              )),

            // --- Lista de Acessórios (NOVO) ---
            const Padding(
              padding: EdgeInsets.only(top: 12.0, bottom: 4.0),
              child: Text("Acessórios:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            if (provider.selectedAcessoriosList.isEmpty)
              const Text("Nenhum selecionado", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
            else
              ...provider.selectedAcessoriosList.map((item) => _buildItemRow(
                '-',
                item.component.name,
                item.component.price,
                quantity: item.quantity,
                variation: item.variation,
              )),
          ],
        ),

        const SizedBox(height: 16),

        // --- SEÇÃO 3: PERSONALIZAÇÃO ---
        _buildSectionCard(
          title: 'Personalização',
          icon: Icons.brush_outlined,
          children: [
            // Campo Cor da Linha REMOVIDO conforme solicitado
            
            _buildItemRow(
              'Gravação:',
              provider.gravacao,
              // Preço dinâmico vindo do provider
              provider.gravacao.isNotEmpty ? provider.customizationPrice : null,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // --- SEÇÃO 4: TOTAL (ADMIN) ou MENSAGEM (CLIENTE) ---
        if (isAdmin)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF263238), // Fundo Escuro
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'R\$ ${provider.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        
        if (!isAdmin)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueGrey[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blueGrey[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Clique em "Solicitar via WhatsApp". Os valores finais e frete serão confirmados pelo fornecedor.',
                    style: TextStyle(
                      color: Colors.blueGrey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // --- SEÇÃO 5: RELATÓRIO DE LUCRATIVIDADE (SÓ ADMIN) ---
        if (isAdmin) ...[
          const SizedBox(height: 32),
          AdminProfitReport(
            blank: provider.selectedBlank,
            blankVar: provider.selectedBlankVariation,
            
            cabo: provider.selectedCabo,
            caboQty: provider.caboQuantity,
            caboVar: provider.selectedCaboVariation,
            
            reelSeat: provider.selectedReelSeat,
            reelSeatVar: provider.selectedReelSeatVariation,
            
            passadoresList: passadoresForReport,
            acessoriosList: acessoriosForReport, // (NOVO)
            
            gravacaoCost: 0.0,
            gravacaoPrice: provider.gravacao.isNotEmpty ? provider.customizationPrice : 0.0,
          ),
        ],
          
        const SizedBox(height: 80),
      ],
    );
  }

  // --- HELPERS ---

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.blueGrey[700]),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.0, color: Colors.blueGrey[700]),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildItemRow(String title, String? value, double? price, {int quantity = 1, String? variation}) {
    value = (value == null || value.isEmpty) ? 'Não selecionado' : value;
    
    if (variation != null && variation.isNotEmpty) {
      value += " ($variation)";
    }

    if (quantity > 1) {
      value += " ($quantity un)";
    }
    
    double? finalPrice = price;
    if (price != null) {
      finalPrice = price * quantity;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != '-')
                  Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (isAdmin && finalPrice != null && finalPrice > 0)
            Expanded(
              flex: 1,
              child: Text(
                'R\$ ${finalPrice.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 15, color: Colors.blueGrey[800], fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }
}