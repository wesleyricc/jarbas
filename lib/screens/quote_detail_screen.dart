import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/quote_model.dart';
import '../../../models/component_model.dart'; 
import '../../../services/quote_service.dart';
import '../../../services/whatsapp_service.dart';
import '../../../services/auth_service.dart'; 
import '../../../services/user_service.dart'; 
import '../widgets/admin_profit_report.dart'; 

class QuoteDetailScreen extends StatefulWidget {
  final Quote quote;

  const QuoteDetailScreen({super.key, required this.quote});

  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  final QuoteService _quoteService = QuoteService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  bool _isLoading = false;
  late Quote _currentQuote;
  bool _isAdmin = false; 

  @override
  void initState() {
    super.initState();
    _currentQuote = widget.quote;
    _checkAdmin(); 
  }

  Future<void> _checkAdmin() async {
    final user = _authService.currentUser;
    if (user != null) {
      final isAdmin = await _userService.isAdmin(user);
      if (mounted) setState(() => _isAdmin = isAdmin);
    }
  }

  Future<void> _sendQuote() async {
    if (_currentQuote.id == null) return;
    setState(() { _isLoading = true; });

    try {
      await _quoteService.updateQuote(_currentQuote.id!, {'status': 'enviado'});
      final DocumentSnapshot updatedDoc = await _quoteService.getQuoteSnapshot(_currentQuote.id!);
      setState(() {
        _currentQuote = Quote.fromFirestore(updatedDoc);
      });
      await _launchWhatsAppToSupplier();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _launchWhatsAppToSupplier() async {
    try {
      await WhatsAppService.resendQuoteRequest(_currentQuote);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

  // Helper para recriar componente a partir do histórico do orçamento
  // Usado para alimentar o Relatório de Lucratividade
  Component? _createTempComponent(String? name, double? price, double? cost) {
    if (name == null || name.isEmpty) return null;
    return Component(
      id: 'temp', 
      name: name, 
      description: '', 
      category: '', 
      price: price ?? 0.0, 
      costPrice: cost ?? 0.0, 
      stock: 0, 
      imageUrl: '', 
      attributes: {}
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do Orçamento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const Divider(height: 32),

            Text('Seus Dados', style: Theme.of(context).textTheme.titleLarge),
            _buildDetailRow('Nome:', _currentQuote.clientName),
            _buildDetailRow('Telefone:', _currentQuote.clientPhone),
            _buildDetailRow('Local:', '${_currentQuote.clientCity}/${_currentQuote.clientState}'),
            const Divider(height: 32),

            Text('Componentes Selecionados', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            
            // Itens Únicos com Variação
            _buildDetailRow('Blank:', _currentQuote.blankName, variation: _currentQuote.blankVariation),
            _buildDetailRow('Cabo:', _currentQuote.caboName, qty: _currentQuote.caboQuantity, variation: _currentQuote.caboVariation),
            _buildDetailRow('Reel Seat:', _currentQuote.reelSeatName, variation: _currentQuote.reelSeatVariation),
            
            // Lista de Passadores
            const Padding(padding: EdgeInsets.only(top: 12, bottom: 4), child: Text("Passadores:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            if (_currentQuote.passadoresList.isEmpty)
               const Text("Nenhum", style: TextStyle(fontStyle: FontStyle.italic))
            else
               ..._currentQuote.passadoresList.map((p) => _buildDetailRow(
                 '-', 
                 p['name'], 
                 qty: (p['quantity']??1).toInt(),
                 variation: p['variation']
               )),

            // Lista de Acessórios (NOVO)
            const Padding(padding: EdgeInsets.only(top: 12, bottom: 4), child: Text("Acessórios:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            if (_currentQuote.acessoriosList.isEmpty)
               const Text("Nenhum", style: TextStyle(fontStyle: FontStyle.italic))
            else
               ..._currentQuote.acessoriosList.map((p) => _buildDetailRow(
                 '-', 
                 p['name'], 
                 qty: (p['quantity']??1).toInt(),
                 variation: p['variation']
               )),

            const Divider(height: 32),

            Text('Personalização', style: Theme.of(context).textTheme.titleLarge),
            // Campo Cor da Linha (removido do fluxo novo, mas mantido aqui se quiser ver histórico)
            if (_currentQuote.corLinha != null && _currentQuote.corLinha!.isNotEmpty)
               _buildDetailRow('Cor da Linha:', _currentQuote.corLinha),
               
            _buildDetailRow('Gravação:', _currentQuote.gravacao),

            const Divider(height: 32),

            // --- RELATÓRIO (SÓ ADMIN) ---
            if (_isAdmin) ...[
              AdminProfitReport(
                // Recria componentes com dados históricos (Custo e Preço da época da compra)
                blank: _createTempComponent(_currentQuote.blankName, _currentQuote.blankPrice, _currentQuote.blankCost),
                blankVar: _currentQuote.blankVariation,
                
                cabo: _createTempComponent(_currentQuote.caboName, _currentQuote.caboPrice, _currentQuote.caboCost),
                caboVar: _currentQuote.caboVariation,
                caboQty: _currentQuote.caboQuantity,
                
                reelSeat: _createTempComponent(_currentQuote.reelSeatName, _currentQuote.reelSeatPrice, _currentQuote.reelSeatCost),
                reelSeatVar: _currentQuote.reelSeatVariation,
                
                passadoresList: _currentQuote.passadoresList,
                acessoriosList: _currentQuote.acessoriosList, // (NOVO)
                
                gravacaoCost: 0.0,
                gravacaoPrice: (_currentQuote.gravacao?.isNotEmpty ?? false) ? 25.0 : 0.0, 
              ),
              const SizedBox(height: 24),
            ],

            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    String formattedDate = '${_currentQuote.createdAt.toDate().day}/${_currentQuote.createdAt.toDate().month}/${_currentQuote.createdAt.toDate().year}';
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Criado em: $formattedDate', style: TextStyle(color: Colors.grey[400])),
          const SizedBox(height: 8),
          Text('Status: ${_currentQuote.status.toUpperCase()}', 
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: _getStatusColor(_currentQuote.status))),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_currentQuote.status == 'rascunho') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Enviar Orçamento via WhatsApp'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: _sendQuote,
        ),
      );
    }
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.chat_outlined),
        label: const Text('Reenviar via WhatsApp'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
        onPressed: _launchWhatsAppToSupplier,
      ),
    );
  }

  Widget _buildDetailRow(String title, String? value, {int qty = 1, String? variation}) {
    value = (value == null || value.isEmpty) ? 'Não selecionado' : value;
    
    // Adiciona Variação
    if (variation != null && variation.isNotEmpty) {
      value += " ($variation)";
    }
    
    // Adiciona Quantidade
    if (qty > 1) value = "$value ($qty un)";
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
          Expanded(
            child: Text(
              value, 
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'rascunho': return Colors.grey[400]!;
      case 'enviado': return Colors.blue[300]!;
      case 'aprovado': return Colors.green[300]!;
      case 'producao': return Colors.orange[300]!;
      case 'concluido': return Colors.purple[200]!;
      default: return Colors.white;
    }
  }
}