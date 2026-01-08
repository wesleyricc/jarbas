import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quote_model.dart';
import '../models/component_model.dart';
import '../providers/rod_builder_provider.dart';
import '../services/quote_service.dart';
import '../services/whatsapp_service.dart';
import '../utils/app_constants.dart'; // Import Constants
import '../widgets/multi_component_step.dart';

class AdminQuoteDetailScreen extends StatefulWidget {
  final Quote quote;
  const AdminQuoteDetailScreen({super.key, required this.quote});

  @override
  State<AdminQuoteDetailScreen> createState() => _AdminQuoteDetailScreenState();
}

class _AdminQuoteDetailScreenState extends State<AdminQuoteDetailScreen> {
  final QuoteService _quoteService = QuoteService();
  bool _isLoading = false;
  late String _currentStatus;

  // Usa as constantes para as opções
  final List<String> _statusOptions = [
    AppConstants.statusPendente,
    AppConstants.statusAprovado,
    AppConstants.statusProducao,
    AppConstants.statusConcluido,
    AppConstants.statusEnviado,
    AppConstants.statusRascunho,
    AppConstants.statusCancelado
  ];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.quote.status;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQuoteIntoProvider();
    });
  }

  Future<void> _loadQuoteIntoProvider() async {
    setState(() => _isLoading = true);
    await context.read<RodBuilderProvider>().loadFromQuote(widget.quote);
    setState(() => _isLoading = false);
  }

  Future<void> _saveChanges() async {
    if (widget.quote.id == null) return;
    setState(() => _isLoading = true);

    final provider = context.read<RodBuilderProvider>();
    
    List<Map<String, dynamic>> convertList(List<RodItem> list) {
      return list.map((item) => {
        'name': item.component.name,
        'variation': item.variation,
        'quantity': item.quantity,
        'cost': item.component.costPrice,
        'price': item.component.price,
      }).toList();
    }

    final updatedData = {
      'status': _currentStatus,
      'clientName': provider.clientName,
      'clientPhone': provider.clientPhone,
      'clientCity': provider.clientCity,
      'clientState': provider.clientState,
      'extraLaborCost': provider.extraLaborCost,
      'totalPrice': provider.totalPrice,
      'customizationText': provider.customizationText,
      'blanksList': convertList(provider.selectedBlanksList),
      'cabosList': convertList(provider.selectedCabosList),
      'reelSeatsList': convertList(provider.selectedReelSeatsList),
      'passadoresList': convertList(provider.selectedPassadoresList),
      'acessoriosList': convertList(provider.selectedAcessoriosList),
    };

    try {
      await _quoteService.updateQuote(widget.quote.id!, updatedData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orçamento atualizado com sucesso!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendWhatsApp() async {
    final provider = context.read<RodBuilderProvider>();
    try {
      await WhatsAppService.sendNewQuoteRequest(provider: provider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao abrir WhatsApp')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RodBuilderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text("Editando: ${provider.clientName}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveChanges,
            tooltip: 'Salvar Alterações',
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(provider),
                const SizedBox(height: 24),

                const Text("Editar Componentes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 16),

                _buildEditSection(provider),
                
                const SizedBox(height: 32),

                _buildCustomizationCard(provider),
                
                const SizedBox(height: 32),

                _buildFinancialAnalysis(provider),

                const SizedBox(height: 40),
              ],
            ),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sendWhatsApp,
        backgroundColor: const Color(0xFF25D366),
        icon: const Icon(Icons.send, color: Colors.white),
        label: const Text("Enviar WhatsApp", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- SEÇÕES DA TELA ---

  Widget _buildHeaderCard(RodBuilderProvider provider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blueGrey),
                const SizedBox(width: 8),
                const Text("Status Atual:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: _currentStatus,
                    isExpanded: true,
                    isDense: true,
                    underline: Container(height: 1, color: Colors.blueGrey),
                    items: _statusOptions.map((s) {
                      // Pega a cor do mapa de constantes
                      Color color = AppConstants.statusColors[s] ?? Colors.black;
                      return DropdownMenuItem(
                        value: s, 
                        child: Text(s.toUpperCase(), style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color
                        ))
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _currentStatus = val);
                    },
                  ),
                ),
              ],
            ),
            const Divider(),
            TextFormField(
              initialValue: provider.clientName,
              decoration: const InputDecoration(labelText: 'Nome do Cliente', border: InputBorder.none, isDense: true),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              onChanged: (v) => provider.updateClientInfo(name: v, phone: provider.clientPhone, city: provider.clientCity, state: provider.clientState),
            ),
            TextFormField(
              initialValue: provider.clientPhone,
              decoration: const InputDecoration(labelText: 'Telefone / WhatsApp', border: InputBorder.none, isDense: true),
              onChanged: (v) => provider.updateClientInfo(name: provider.clientName, phone: v, city: provider.clientCity, state: provider.clientState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditSection(RodBuilderProvider provider) {
    Widget buildStep(String title, String key, IconData icon, List<RodItem> items, 
        Function(Component, String?) add, Function(int) remove, Function(int, int) upd) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: MultiComponentStep(
          isAdmin: true,
          categoryKey: key,
          title: title,
          emptyMessage: 'Sem itens.',
          emptyIcon: icon,
          items: items,
          onAdd: add,
          onRemove: remove,
          onUpdateQty: upd,
        ),
      );
    }

    return Column(
      children: [
        buildStep('Blank', AppConstants.catBlank, Icons.crop_square, provider.selectedBlanksList, 
            (c,v)=>provider.addBlank(c,1,variation:v), (i)=>provider.removeBlank(i), (i,q)=>provider.updateBlankQty(i,q)),
        
        buildStep('Cabo', AppConstants.catCabo, Icons.grid_goldenratio, provider.selectedCabosList, 
            (c,v)=>provider.addCabo(c,1,variation:v), (i)=>provider.removeCabo(i), (i,q)=>provider.updateCaboQty(i,q)),
        
        buildStep('Reel Seat', AppConstants.catReelSeat, Icons.chair, provider.selectedReelSeatsList, 
            (c,v)=>provider.addReelSeat(c,1,variation:v), (i)=>provider.removeReelSeat(i), (i,q)=>provider.updateReelSeatQty(i,q)),
        
        buildStep('Passador', AppConstants.catPassadores, Icons.format_list_bulleted, provider.selectedPassadoresList, 
            (c,v)=>provider.addPassador(c,1,variation:v), (i)=>provider.removePassador(i), (i,q)=>provider.updatePassadorQty(i,q)),
        
        buildStep('Acessório', AppConstants.catAcessorios, Icons.extension, provider.selectedAcessoriosList, 
            (c,v)=>provider.addAcessorio(c,1,variation:v), (i)=>provider.removeAcessorio(i), (i,q)=>provider.updateAcessorioQty(i,q)),
      ],
    );
  }

  Widget _buildCustomizationCard(RodBuilderProvider provider) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[300]!)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Detalhes Extras", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: provider.customizationText,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Personalização', border: OutlineInputBorder()),
              onChanged: (v) => provider.setCustomizationText(v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: provider.extraLaborCost.toStringAsFixed(2),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Mão de Obra / Custo Extra (R\$)', border: OutlineInputBorder(), prefixText: 'R\$ '),
              onChanged: (v) {
                final val = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                provider.setExtraLaborCost(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialAnalysis(RodBuilderProvider provider) {
    double sumCost(List<RodItem> list) => list.fold(0.0, (sum, item) => sum + (item.component.costPrice * item.quantity));
    
    double totalCostPrice = 0.0;
    totalCostPrice += sumCost(provider.selectedBlanksList);
    totalCostPrice += sumCost(provider.selectedCabosList);
    totalCostPrice += sumCost(provider.selectedReelSeatsList);
    totalCostPrice += sumCost(provider.selectedPassadoresList);
    totalCostPrice += sumCost(provider.selectedAcessoriosList);

    double estimatedProfit = provider.totalPrice - totalCostPrice;
    double marginPercent = provider.totalPrice > 0 ? (estimatedProfit / provider.totalPrice) * 100 : 0.0;

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
              Icon(Icons.analytics, size: 24, color: Colors.blueGrey[800]),
              const SizedBox(width: 8),
              Text("ANÁLISE FINANCEIRA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[800], fontSize: 16)),
            ],
          ),
          const Divider(height: 24),
          
          _buildDetailedFinancialGroup('Blanks', provider.selectedBlanksList),
          _buildDetailedFinancialGroup('Cabos', provider.selectedCabosList),
          _buildDetailedFinancialGroup('Reel Seats', provider.selectedReelSeatsList),
          _buildDetailedFinancialGroup('Passadores', provider.selectedPassadoresList),
          _buildDetailedFinancialGroup('Acessórios', provider.selectedAcessoriosList),

          const SizedBox(height: 16),
          const Divider(thickness: 2),
          const SizedBox(height: 16),

           _buildSummaryRow("Receita Bruta:", provider.totalPrice, isBold: false),
           _buildSummaryRow("Custo Total Peças:", totalCostPrice, isNegative: true),
           if(provider.extraLaborCost > 0)
             _buildSummaryRow("Mão de Obra (Extra):", provider.extraLaborCost, isBold: true),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green[300]!)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("LUCRO LÍQUIDO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("R\$ ${estimatedProfit.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green[900])),
                    Text("Margem: ${marginPercent.toStringAsFixed(1)}%", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[800])),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDetailedFinancialGroup(String categoryName, List<RodItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.grey[200],
          child: Text(categoryName.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        ),
        ...items.map((item) {
          double totalCost = item.component.costPrice * item.quantity;
          double totalSale = item.component.price * item.quantity;
          double profit = totalSale - totalCost;
          double margin = totalSale > 0 ? (profit / totalSale) * 100 : 0.0;
          String variation = item.variation != null ? " [${item.variation}]" : "";

          return Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text("${item.quantity}x ${item.component.name}$variation", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("CUSTO", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text("Un: R\$ ${item.component.costPrice.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          Text("Tot: R\$ ${totalCost.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[800])),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 24, color: Colors.grey[300]),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("VENDA", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text("Un: R\$ ${item.component.price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          Text("Tot: R\$ ${totalSale.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
                        ],
                      ),
                    ),
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
          Text("${isNegative ? '-' : ''}R\$ ${value.toStringAsFixed(2)}", style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: isNegative ? Colors.red[800] : Colors.black87)),
        ],
      ),
    );
  }
}