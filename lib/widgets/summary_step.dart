import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/rod_builder_provider.dart';
import 'admin_profit_report.dart';

class SummaryStep extends StatelessWidget {
  final bool isAdmin; // Recebe o status de admin

  const SummaryStep({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RodBuilderProvider>();

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
            ),
            _buildItemRow(
              'Cabo:',
              provider.selectedCabo?.name,
              provider.selectedCabo?.price,
              quantity: provider.caboQuantity,
            ),
            _buildItemRow(
              'Reel Seat:',
              provider.selectedReelSeat?.name,
              provider.selectedReelSeat?.price,
            ),
            _buildItemRow(
              'Passadores:',
              provider.selectedPassadores?.name,
              provider.selectedPassadores?.price,
              quantity: provider.passadoresQuantity,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // --- SEÇÃO 3: PERSONALIZAÇÃO ---
        _buildSectionCard(
          title: 'Personalização',
          icon: Icons.brush_outlined,
          children: [
            _buildItemRow(
              'Cor da Linha:',
              provider.corLinha,
              null,
            ),
            _buildItemRow(
              'Gravação:',
              provider.gravacao,
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
              color: const Color(0xFF263238), // Fundo Escuro para destaque
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

          if (isAdmin) ...[
          const SizedBox(height: 32),
          AdminProfitReport(
            blank: provider.selectedBlank,
            cabo: provider.selectedCabo,
            caboQty: provider.caboQuantity,
            reelSeat: provider.selectedReelSeat,
            passadores: provider.selectedPassadores,
            passadoresQty: provider.passadoresQuantity,
            // Se a gravação tem custo para você (ex: R$ 5,00 de material), coloque aqui.
            // Caso contrário, deixe 0.0. O preço de venda é 25.0 se houver texto.
            gravacaoCost: 0.0, 
            gravacaoPrice: provider.gravacao.isNotEmpty ? provider.customizationPrice : 0.0,
          ),
        ],
        
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
                    'Clique em "Solicitar Orçamento". Os valores finais serão confirmados via WhatsApp.',
                    style: TextStyle(
                      color: Colors.blueGrey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
        // Espaço extra no final para não ficar colado no botão inferior
        const SizedBox(height: 80),
      ],
    );
  }

  // Helper para criar os Cartões Brancos
  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, // Fundo Branco
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.0,
                  color: Colors.blueGrey[700],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  // Linha simples
  Widget _buildSummaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              title, 
              style: TextStyle(
                color: Colors.grey[600], // Cinza médio (legível no branco)
                fontWeight: FontWeight.w500
              )
            ),
          ),
          Expanded(
            child: Text(
              value, 
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87, // Preto suave (alto contraste)
                fontWeight: FontWeight.w600
              )
            ),
          ),
        ],
      ),
    );
  }

  // Linha de item com preço
  Widget _buildItemRow(String title, String? value, double? price, {int quantity = 1}) {
    value = (value == null || value.isEmpty) ? 'Não selecionado' : value;
    
    if (quantity > 1) {
      value = "$value ($quantity un)";
    }
    
    double? finalPrice = price;
    if (price != null) {
      finalPrice = price * quantity;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Mais espaço
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)
                ),
                const SizedBox(height: 2),
                Text(
                  value, 
                  style: const TextStyle(
                    fontSize: 16, 
                    color: Colors.black87,
                    fontWeight: FontWeight.w600
                  )
                ),
              ],
            ),
          ),
          
          if (isAdmin && finalPrice != null && finalPrice > 0)
            Expanded(
              flex: 1,
              child: Text(
                'R\$ ${finalPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.blueGrey[800],
                  fontWeight: FontWeight.bold
                ),
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }
}