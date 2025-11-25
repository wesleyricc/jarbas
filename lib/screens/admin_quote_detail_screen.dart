import 'package:flutter/material.dart';
import '../../../models/quote_model.dart';
import '../../../models/component_model.dart';
import '../../../services/quote_service.dart';
import '../../../services/component_service.dart';
import '../../../services/whatsapp_service.dart';
import '../../../services/config_service.dart';
import '../widgets/component_selector.dart';
import '../widgets/admin_profit_report.dart';

class AdminQuoteDetailScreen extends StatefulWidget {
  final Quote quote;

  const AdminQuoteDetailScreen({super.key, required this.quote});

  @override
  State<AdminQuoteDetailScreen> createState() => _AdminQuoteDetailScreenState();
}

class _AdminQuoteDetailScreenState extends State<AdminQuoteDetailScreen> {
  final QuoteService _quoteService = QuoteService();
  final ComponentService _componentService = ComponentService();
  final ConfigService _configService = ConfigService();

  bool _isLoading = false;
  bool _isDeleting = false;

  // Dados Cliente
  late String _clientName;
  late String _clientPhone;
  late String _clientCity;
  late String _clientState;

  // Futures
  late Future<Component?> _blankFuture;
  late Future<Component?> _caboFuture;
  late Future<Component?> _reelSeatFuture;
  
  // Itens Únicos
  Component? _selectedBlank;
  Component? _selectedCabo;
  Component? _selectedReelSeat;
  
  // Variações de Itens Únicos
  String? _blankVar;
  String? _caboVar;
  String? _reelSeatVar;

  // Listas de Itens Múltiplos (Maps)
  List<Map<String, dynamic>> _selectedPassadoresList = [];
  List<Map<String, dynamic>> _selectedAcessoriosList = []; // (NOVO)

  int _caboQty = 1;

  late String _corLinha;
  late String _gravacao;
  late String _currentStatus;
  
  double _customizationPrice = 25.0;

  final List<String> _statusOptions = [
    'pendente', 'enviado', 'aprovado', 'producao', 'concluido', 'rascunho',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadQuoteData();
  }

  Future<void> _loadSettings() async {
    final settings = await _configService.getSettings();
    if (mounted) {
      setState(() {
        _customizationPrice = (settings['customizationPrice'] ?? 25.0).toDouble();
      });
    }
  }

  void _loadQuoteData() {
    _clientName = widget.quote.clientName;
    _clientPhone = widget.quote.clientPhone;
    _clientCity = widget.quote.clientCity;
    _clientState = widget.quote.clientState;
    
    // _corLinha removido, mantemos gravacao
    _gravacao = widget.quote.gravacao ?? '';
    _currentStatus = widget.quote.status;

    _caboQty = widget.quote.caboQuantity;

    _blankVar = widget.quote.blankVariation;
    _caboVar = widget.quote.caboVariation;
    _reelSeatVar = widget.quote.reelSeatVariation;

    _blankFuture = _componentService.getComponentByName(widget.quote.blankName);
    _caboFuture = _componentService.getComponentByName(widget.quote.caboName);
    _reelSeatFuture = _componentService.getComponentByName(widget.quote.reelSeatName);
    
    // Carrega Passadores
    if (widget.quote.passadoresList.isNotEmpty) {
      _selectedPassadoresList = List.from(widget.quote.passadoresList);
    } else if (widget.quote.passadoresName != null) {
      _selectedPassadoresList.add({
        'name': widget.quote.passadoresName,
        'price': widget.quote.passadoresPrice,
        'cost': widget.quote.passadoresCost,
        'quantity': widget.quote.passadoresQuantity,
        'variation': null,
      });
    }

    // Carrega Acessórios (NOVO)
    if (widget.quote.acessoriosList.isNotEmpty) {
      _selectedAcessoriosList = List.from(widget.quote.acessoriosList);
    }
    
    _initSelectedComponents();
  }

  void _initSelectedComponents() async {
    try {
      _selectedBlank = await _blankFuture;
      _selectedCabo = await _caboFuture;
      _selectedReelSeat = await _reelSeatFuture;
    } catch (e) {
      print("Erro ao inicializar: $e");
    }
    if (mounted) setState(() {});
  }

  // --- CÁLCULO TOTAL ---
  double _calculateNewPrice() {
    double total = 0.0;
    total += _selectedBlank?.price ?? 0.0;
    total += (_selectedCabo?.price ?? 0.0) * _caboQty;
    total += _selectedReelSeat?.price ?? 0.0;
    
    // Soma Passadores
    for (var item in _selectedPassadoresList) {
      double p = (item['price'] ?? 0.0).toDouble();
      int q = (item['quantity'] ?? 1).toInt();
      total += p * q;
    }

    // Soma Acessórios (NOVO)
    for (var item in _selectedAcessoriosList) {
      double p = (item['price'] ?? 0.0).toDouble();
      int q = (item['quantity'] ?? 1).toInt();
      total += p * q;
    }

    if (_gravacao.isNotEmpty) {
      total += _customizationPrice;
    }
    return total;
  }

  // --- GESTÃO DE LISTAS (Passadores e Acessórios) ---

  // Helper genérico para abrir o seletor e adicionar à lista correta
  void _openAddModal(String category, Function(Map<String, dynamic>) onAdd) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(
              children: [
                Padding(padding: const EdgeInsets.all(16), child: Text("Adicionar ${category == 'passadores' ? 'Passador' : 'Acessório'}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: ComponentSelector(
                      category: category,
                      selectedComponent: null,
                      isAdmin: true,
                      onSelect: (comp, variation) {
                        if (comp != null) {
                          onAdd({
                            'name': comp.name,
                            'price': comp.price,
                            'cost': comp.costPrice,
                            'quantity': 1,
                            'variation': variation,
                          });
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Métodos de Passadores
  void _addPassador() => _openAddModal('passadores', (item) => setState(() => _selectedPassadoresList.add(item)));
  void _removePassador(int index) => setState(() => _selectedPassadoresList.removeAt(index));
  void _updatePassadorQty(int index, int newQty) {
    if (newQty < 1) return;
    setState(() => _selectedPassadoresList[index]['quantity'] = newQty);
  }

  // Métodos de Acessórios (NOVO)
  void _addAcessorio() => _openAddModal('acessorios', (item) => setState(() => _selectedAcessoriosList.add(item)));
  void _removeAcessorio(int index) => setState(() => _selectedAcessoriosList.removeAt(index));
  void _updateAcessorioQty(int index, int newQty) {
    if (newQty < 1) return;
    setState(() => _selectedAcessoriosList[index]['quantity'] = newQty);
  }

  // --- ADMIN ACTIONS ---

  Future<void> _updateStatus() async {
    if (widget.quote.id == null) return;
    setState(() { _isLoading = true; });
    try {
      await _quoteService.updateQuote(widget.quote.id!, {'status': _currentStatus});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status atualizado!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _sendProposalToClient() async {
    if (widget.quote.id == null) return;
    if (_clientPhone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente sem telefone.'), backgroundColor: Colors.red));
        return;
    }
    setState(() { _isLoading = true; });
    final newTotalPrice = _calculateNewPrice();

    try {
      await _quoteService.updateQuote(widget.quote.id!, {
        'status': 'enviado',
        'blankName': _selectedBlank?.name ?? '',
        'blankPrice': _selectedBlank?.price ?? 0.0,
        'blankCost': _selectedBlank?.costPrice ?? 0.0,
        'blankVariation': _blankVar,
        
        'caboName': _selectedCabo?.name ?? '',
        'caboPrice': _selectedCabo?.price ?? 0.0,
        'caboCost': _selectedCabo?.costPrice ?? 0.0,
        'caboQuantity': _caboQty,
        'caboVariation': _caboVar,
        
        'reelSeatName': _selectedReelSeat?.name ?? '',
        'reelSeatPrice': _selectedReelSeat?.price ?? 0.0,
        'reelSeatCost': _selectedReelSeat?.costPrice ?? 0.0,
        'reelSeatVariation': _reelSeatVar,
        
        'passadoresList': _selectedPassadoresList,
        'acessoriosList': _selectedAcessoriosList, // (NOVO)
        
        'totalPrice': newTotalPrice,
      });

      setState(() => _currentStatus = 'enviado');

      await WhatsAppService.sendProposalToClient(
        quote: widget.quote,
        finalPrice: newTotalPrice,
        blankName: _selectedBlank?.name,
        blankVar: _blankVar,
        caboName: _selectedCabo?.name,
        caboVar: _caboVar,
        caboQty: _caboQty,
        reelSeatName: _selectedReelSeat?.name,
        reelSeatVar: _reelSeatVar,
        passadoresList: _selectedPassadoresList,
        acessoriosList: _selectedAcessoriosList, // (NOVO)
      );

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _deleteQuote() async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true || widget.quote.id == null) return;

    setState(() { _isDeleting = true; });
    try {
      await _quoteService.deleteQuote(widget.quote.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excluído!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isDeleting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final newTotalPrice = _calculateNewPrice();
    final bool isBusy = _isLoading || _isDeleting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Orçamento'),
        elevation: 1.0,
        actions: [
          IconButton(icon: Icon(Icons.delete_outline, color: Colors.red[700]), onPressed: isBusy ? null : _deleteQuote),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReadOnlyClientData(),
            const Divider(height: 32),

            const Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currentStatus,
                    items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                    onChanged: isBusy ? null : (v) => setState(() => _currentStatus = v!),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(icon: const Icon(Icons.save), tooltip: 'Salvar Status', onPressed: isBusy ? null : _updateStatus),
              ],
            ),
            const Divider(height: 32),

            Text('Editar Componentes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildComponentLoaders(),
            
            const Divider(height: 32),

            // RELATÓRIO
            if (_selectedBlank != null || _selectedCabo != null) ...[
               AdminProfitReport(
                blank: _selectedBlank, blankVar: _blankVar,
                cabo: _selectedCabo, caboVar: _caboVar, caboQty: _caboQty,
                reelSeat: _selectedReelSeat, reelSeatVar: _reelSeatVar,
                passadoresList: _selectedPassadoresList,
                acessoriosList: _selectedAcessoriosList, // (NOVO)
                gravacaoCost: 0.0,
                gravacaoPrice: _gravacao.isNotEmpty ? _customizationPrice : 0.0,
              ),
              const Divider(height: 32),
            ],

            Text('Proposta Final', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildTotalRow(newTotalPrice),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: isBusy
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Enviar Proposta ao Cliente'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: _sendProposalToClient,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentLoaders() {
    return FutureBuilder<List<Component?>>(
      future: Future.wait([_blankFuture, _caboFuture, _reelSeatFuture]),
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Blank'),
            ComponentSelector(
              category: 'blank',
              selectedComponent: _selectedBlank,
              selectedVariation: _blankVar,
              isAdmin: true,
              onSelect: (c, v) => setState(() { _selectedBlank = c; _blankVar = v; }),
            ),
            if (_blankVar != null) Padding(padding: const EdgeInsets.only(left: 8, top: 4), child: Text("Variação: $_blankVar", style: const TextStyle(color: Colors.blueGrey, fontSize: 12))),
            const SizedBox(height: 16),
            
            _buildSectionTitle('Cabo'),
            ComponentSelector(
              category: 'cabo',
              selectedComponent: _selectedCabo,
              selectedVariation: _caboVar,
              isAdmin: true,
              quantity: _caboQty,
              onQuantityChanged: (v) => setState(() => _caboQty = v),
              onSelect: (c, v) => setState(() { _selectedCabo = c; _caboVar = v; }),
            ),
            if (_caboVar != null) Padding(padding: const EdgeInsets.only(left: 8, top: 4), child: Text("Variação: $_caboVar", style: const TextStyle(color: Colors.blueGrey, fontSize: 12))),
            const SizedBox(height: 16),

            _buildSectionTitle('Reel Seat'),
            ComponentSelector(
              category: 'reel_seat',
              selectedComponent: _selectedReelSeat,
              selectedVariation: _reelSeatVar,
              isAdmin: true,
              onSelect: (c, v) => setState(() { _selectedReelSeat = c; _reelSeatVar = v; }),
            ),
            if (_reelSeatVar != null) Padding(padding: const EdgeInsets.only(left: 8, top: 4), child: Text("Variação: $_reelSeatVar", style: const TextStyle(color: Colors.blueGrey, fontSize: 12))),
            const SizedBox(height: 16),

            // LISTA PASSADORES
            _buildListEditor('Passadores', _selectedPassadoresList, _updatePassadorQty, _removePassador, _addPassador),
            
            const SizedBox(height: 16),

            // LISTA ACESSÓRIOS (NOVO)
            _buildListEditor('Acessórios', _selectedAcessoriosList, _updateAcessorioQty, _removeAcessorio, _addAcessorio),
          ],
        );
      },
    );
  }

  // Widget genérico para editar listas (Passadores/Acessórios)
  Widget _buildListEditor(
    String title, 
    List<Map<String, dynamic>> list, 
    Function(int, int) onUpdateQty, 
    Function(int) onRemove,
    VoidCallback onAdd
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('$title (Lista)'),
        Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              if (list.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text("Nenhum item.", style: TextStyle(color: Colors.grey))),
              
              ...list.asMap().entries.map((entry) {
                int idx = entry.key;
                Map<String, dynamic> item = entry.value;
                String name = item['name'];
                if (item['variation'] != null) name += " (${item['variation']})";

                return ListTile(
                  dense: true,
                  title: Text(name),
                  subtitle: Text('R\$ ${(item['price'] ?? 0.0).toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => onUpdateQty(idx, (item['quantity'] ?? 1) - 1)),
                      Text('${item['quantity'] ?? 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => onUpdateQty(idx, (item['quantity'] ?? 1) + 1)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => onRemove(idx)),
                    ],
                  ),
                );
              }),
              
              const Divider(height: 1),
              TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text("Adicionar Item")),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyClientData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dados do Cliente', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _buildDetailRow('Nome:', _clientName),
        _buildDetailRow('Telefone:', _clientPhone),
        _buildDetailRow('Local:', '$_clientCity/$_clientState'),
      ],
    );
  }

  Widget _buildTotalRow(double price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('NOVO TOTAL:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text('R\$ ${price.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blueGrey[700])));
  }

  Widget _buildDetailRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
          Text(value ?? 'N/A', style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}