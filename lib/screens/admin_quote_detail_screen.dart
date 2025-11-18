import 'package:flutter/material.dart';
import '../../../models/quote_model.dart';
import '../../../models/component_model.dart'; // Para carregar os componentes
import '../../../services/quote_service.dart';
import '../../../services/component_service.dart'; // Para buscar os componentes
import '../../../services/whatsapp_service.dart';
import '../widgets/component_selector.dart'; // Reutiliza o seletor

class AdminQuoteDetailScreen extends StatefulWidget {
  final Quote quote;

  const AdminQuoteDetailScreen({super.key, required this.quote});

  @override
  State<AdminQuoteDetailScreen> createState() => _AdminQuoteDetailScreenState();
}

class _AdminQuoteDetailScreenState extends State<AdminQuoteDetailScreen> {
  final QuoteService _quoteService = QuoteService();
  final ComponentService _componentService = ComponentService();
  bool _isLoading = false;
  bool _isDeleting = false;
  int _caboQty = 1;
  int _passadoresQty = 1;

  late String _clientName;
  late String _clientPhone;
  late String _clientCity;
  late String _clientState;

  // Componentes Selecionados (podem ser alterados pelo admin)
  late Future<Component?> _blankFuture;
  late Future<Component?> _caboFuture;
  late Future<Component?> _reelSeatFuture;
  late Future<Component?> _passadoresFuture;
  
  // Armazena as *novas* seleções do admin
  Component? _selectedBlank;
  Component? _selectedCabo;
  Component? _selectedReelSeat;
  Component? _selectedPassadores;

  // Personalização (não muda nesta tela)
  late String _corLinha;
  late String _gravacao;

  // Status (pode ser alterado manualmente)
  late String _currentStatus;

  // Lista de status que o admin pode selecionar
  final List<String> _statusOptions = [
    'pendente',
    'enviado',
    'aprovado',
    'producao',
    'concluido',
    'rascunho',
  ];

  @override
  void initState() {
    super.initState();
    _loadQuoteData();
  }

  // Carrega os dados do orçamento original
  void _loadQuoteData() {
    // Carrega dados do cliente e personalização
    _clientName = widget.quote.clientName;
    _clientPhone = widget.quote.clientPhone;
    _clientCity = widget.quote.clientCity;
    _clientState = widget.quote.clientState;
    _corLinha = widget.quote.corLinha ?? '';
    _gravacao = widget.quote.gravacao ?? '';
    _currentStatus = widget.quote.status;
    _caboQty = widget.quote.caboQuantity;
    _passadoresQty = widget.quote.passadoresQuantity;

    // Carrega os componentes originais
    _blankFuture = _componentService.getComponentByName(widget.quote.blankName);
    _caboFuture = _componentService.getComponentByName(widget.quote.caboName);
    _reelSeatFuture = _componentService.getComponentByName(widget.quote.reelSeatName);
    _passadoresFuture = _componentService.getComponentByName(widget.quote.passadoresName);
    
    // Inicializa as seleções com os futuros
    _initSelectedComponents();
  }

  // Inicializa os _selected... com base nos dados carregados
  void _initSelectedComponents() async {
    try {
      _selectedBlank = await _blankFuture;
      _selectedCabo = await _caboFuture;
      _selectedReelSeat = await _reelSeatFuture;
      _selectedPassadores = await _passadoresFuture;
    } catch (e) {
      print("Erro ao inicializar componentes selecionados: $e");
    }
    if (mounted) {
      setState(() {}); // Força a reconstrução após carregar
    }
  }

  // Calcula o NOVO preço total com base nas seleções do admin
  double _calculateNewPrice() {
    double total = 0.0;
    total += _selectedBlank?.price ?? 0.0;
    total += (_selectedCabo?.price ?? 0.0) * _caboQty; // Multiplica
    total += _selectedReelSeat?.price ?? 0.0;
    total += (_selectedPassadores?.price ?? 0.0) * _passadoresQty; // Multiplica
    if (_gravacao.isNotEmpty) {
      total += 25.0;
    }
    return total;
  }

  // --- AÇÕES DO ADMIN ---

  // 1. Atualizar o Status (manualmente)
  Future<void> _updateStatus() async {
    if (widget.quote.id == null) return;
    setState(() { _isLoading = true; });

    try {
      await _quoteService.updateQuote(widget.quote.id!, {
        'status': _currentStatus,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status atualizado!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erro ao atualizar status: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // 2. Enviar a Proposta Final para o Cliente (WhatsApp)
  // --- ATUALIZADO COM WhatsAppService ---
  Future<void> _sendProposalToClient() async {
    if (widget.quote.id == null) return;
    
    // Validação simples do telefone
    if (_clientPhone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente não possui telefone cadastrado.'), backgroundColor: Colors.red),
        );
        return;
    }
    
    setState(() { _isLoading = true; });

    final newTotalPrice = _calculateNewPrice();

    try {
      // 1. Salvar as edições do admin e o novo status "enviado" no Firestore
      await _quoteService.updateQuote(widget.quote.id!, {
        'status': 'enviado',
        'blankName': _selectedBlank?.name ?? '',
        'blankPrice': _selectedBlank?.price ?? 0.0,
        'caboName': _selectedCabo?.name ?? '',
        'caboPrice': _selectedCabo?.price ?? 0.0,
        'reelSeatName': _selectedReelSeat?.name ?? '',
        'reelSeatPrice': _selectedReelSeat?.price ?? 0.0,
        'passadoresName': _selectedPassadores?.name ?? '',
        'passadoresPrice': _selectedPassadores?.price ?? 0.0,
        'caboQuantity': _caboQty,
        'passadoresQuantity': _passadoresQty,
        'totalPrice': newTotalPrice,
      });

      // Atualiza o status local
      setState(() {
        _currentStatus = 'enviado';
      });

      // 2. Enviar a proposta usando o Serviço Centralizado
      await WhatsAppService.sendProposalToClient(
        quote: widget.quote,
        finalPrice: newTotalPrice,
        blankName: _selectedBlank?.name,
        caboName: _selectedCabo?.name,
        caboQty: _caboQty, // Passa novo valor
        reelSeatName: _selectedReelSeat?.name,
        passadoresName: _selectedPassadores?.name,
        passadoresQty: _passadoresQty, // Passa novo valor
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // 3. Excluir o orçamento
  Future<void> _deleteQuote() async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza que deseja excluir este orçamento? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || widget.quote.id == null) {
      return;
    }

    setState(() { _isDeleting = true; });

    try {
      await _quoteService.deleteQuote(widget.quote.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orçamento excluído!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Volta para a lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isDeleting = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcula o preço dinamicamente com base nas seleções
    final newTotalPrice = _calculateNewPrice();
    final bool isBusy = _isLoading || _isDeleting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Orçamento'),
        elevation: 1.0,
        actions: [
          // Logo no AppBar
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/jarbas_logo.png',
              width: 120,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.phishing,
                  color: Colors.blueGrey[800],
                );
              },
            ),
          ),
          // Botão de Excluir
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red[700]),
            tooltip: 'Excluir Orçamento',
            onPressed: isBusy ? null : _deleteQuote,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SEÇÃO 1: DADOS DO CLIENTE (Não editável) ---
            _buildReadOnlyClientData(),
            const Divider(height: 32),

            // --- SEÇÃO 2: GERENCIAR STATUS (Editável) ---
            Text('Gerenciar Status', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currentStatus,
                    items: _statusOptions.map((String status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(status.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: isBusy ? null : (newValue) {
                      if (newValue != null) {
                        setState(() { _currentStatus = newValue; });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: 'Salvar Status',
                  onPressed: isBusy ? null : _updateStatus,
                ),
              ],
            ),
            const Divider(height: 32),

            // --- SEÇÃO 3: EDITOR DE COMPONENTES ---
            Text('Editar Componentes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            
            // Carregador para os seletores
            _buildComponentLoaders(),
            
            const Divider(height: 32),

            // --- SEÇÃO 4: RESUMO DA PROPOSTA ---
            Text('Proposta Final', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildTotalRow(context, newTotalPrice),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: isBusy
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Enviar Proposta ao Cliente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                        foregroundColor: Colors.white
                      ),
                      onPressed: _sendProposalToClient,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Constrói os seletores de componentes
  Widget _buildComponentLoaders() {
    return FutureBuilder<List<Component?>>(
      future: Future.wait([_blankFuture, _caboFuture, _reelSeatFuture, _passadoresFuture]),
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
              onSelect: (component) => setState(() => _selectedBlank = component),
              isAdmin: true, // Admin sempre vê preços
            ),
            const SizedBox(height: 16),
            
            _buildSectionTitle('Cabo'),
            ComponentSelector(
              category: 'cabo',
              selectedComponent: _selectedCabo,
              onSelect: (component) => setState(() => _selectedCabo = component),
              isAdmin: true,
              quantity: _caboQty,
              onQuantityChanged: (val) => setState(() => _caboQty = val),
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('Reel Seat'),
            ComponentSelector(
              category: 'reel_seat',
              selectedComponent: _selectedReelSeat,
              onSelect: (component) => setState(() => _selectedReelSeat = component),
              isAdmin: true,
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('Passadores'),
            ComponentSelector(
              category: 'passadores',
              selectedComponent: _selectedPassadores,
              onSelect: (component) => setState(() => _selectedPassadores = component),
              isAdmin: true,
              quantity: _passadoresQty,
              onQuantityChanged: (val) => setState(() => _passadoresQty = val),
            ),
          ],
        );
      },
    );
  }

  // Constrói os dados do cliente (não editáveis aqui)
  Widget _buildReadOnlyClientData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dados do Cliente', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _buildDetailRow('Nome:', _clientName, null),
        _buildDetailRow('Telefone:', _clientPhone, null),
        _buildDetailRow('Local:', '$_clientCity/$_clientState', null),
      ],
    );
  }

  // Linha de Total no final
  Widget _buildTotalRow(BuildContext context, double price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'NOVO TOTAL:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          'R\$ ${price.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.blueGrey[700]
        ),
      ),
    );
  }

  // Widget auxiliar para mostrar uma linha de detalhe (Nome e Preço)
  Widget _buildDetailRow(String title, String? value, double? price) {
    value = (value == null || value.isEmpty) ? 'Não informado' : value;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          if (price != null && price > 0)
            Text(
              'R\$ ${price.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16),
            ),
        ],
      ),
    );
  }
}