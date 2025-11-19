import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/quote_model.dart';
import '../../../models/component_model.dart';
import '../../../services/quote_service.dart';
import '../../../services/whatsapp_service.dart'; 
import '../../../services/auth_service.dart'; // (NOVO)
import '../../../services/user_service.dart'; // (NOVO)
import '../widgets/admin_profit_report.dart'; // (NOVO)

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

  // Usamos um objeto Quote local para refletir a mudança de status
  late Quote _currentQuote;
  bool _isAdmin = false; // (NOVO)

  @override
  void initState() {
    super.initState();
    _currentQuote = widget.quote;
    _checkAdmin(); // (NOVO)
  }

  // Verifica se é admin para mostrar o relatório
  Future<void> _checkAdmin() async {
    final user = _authService.currentUser;
    if (user != null) {
      final isAdmin = await _userService.isAdmin(user);
      if (mounted) setState(() => _isAdmin = isAdmin);
    }
  }

  // Ação de enviar o orçamento
  Future<void> _sendQuote() async {
    if (_currentQuote.id == null) return;

    setState(() { _isLoading = true; });

    try {
      // 1. Atualiza o status no Firestore
      await _quoteService.updateQuote(_currentQuote.id!, {
        'status': 'enviado',
      });

      // --- CORREÇÃO DO 'await' ---
      // 2. Busca o documento atualizado do Firestore
      final DocumentSnapshot updatedDoc = await _quoteService.getQuoteSnapshot(_currentQuote.id!);
      
      // 3. Atualiza o estado local (dentro do setState)
      setState(() {
        _currentQuote = Quote.fromFirestore(updatedDoc);
      });
      // --- FIM DA CORREÇÃO ---

      // 4. Prepara e abre o WhatsApp
      await _launchWhatsAppToSupplier();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _launchWhatsAppToSupplier() async {
    try {
      // --- NOVA CHAMADA CENTRALIZADA ---
      await WhatsAppService.resendQuoteRequest(_currentQuote);
      // ---------------------------------
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir WhatsApp: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- HELPER: Cria Componente Temporário a partir do Quote ---
  Component? _createTempComponent(String? name, double? price, double? cost) {
    if (name == null || name.isEmpty) return null;
    return Component(
      id: 'temp', 
      name: name, 
      description: '', 
      category: '', 
      price: price ?? 0.0, 
      costPrice: cost ?? 0.0, // Usa o custo histórico salvo no quote
      stock: 0, 
      imageUrl: '', 
      attributes: {}
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Orçamento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header com Status
            _buildHeader(context),
            const Divider(height: 32),

            // Dados do Cliente
            Text('Seus Dados', style: Theme.of(context).textTheme.titleLarge),
            _buildDetailRow('Nome:', _currentQuote.clientName),
            _buildDetailRow('Telefone:', _currentQuote.clientPhone),
            _buildDetailRow('Local:', '${_currentQuote.clientCity}/${_currentQuote.clientState}'),
            const Divider(height: 32),

            // Seção de Componentes
            Text('Componentes Selecionados', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildDetailRow('Blank:', _currentQuote.blankName),
            _buildDetailRow('Cabo:', _currentQuote.caboName, qty: _currentQuote.caboQuantity),
            _buildDetailRow('Reel Seat:', _currentQuote.reelSeatName),
            _buildDetailRow('Passadores:', _currentQuote.passadoresName, qty: _currentQuote.passadoresQuantity),
            
            const Divider(height: 32),

            // Personalização
            Text('Personalização', style: Theme.of(context).textTheme.titleLarge),
            _buildDetailRow('Cor da Linha:', _currentQuote.corLinha),
            _buildDetailRow('Gravação:', _currentQuote.gravacao),
          
            const Divider(height: 32),

            // --- NOVO: RELATÓRIO DE LUCRATIVIDADE (SÓ ADMIN) ---
            if (_isAdmin) ...[
              AdminProfitReport(
                blank: _createTempComponent(_currentQuote.blankName, _currentQuote.blankPrice, _currentQuote.blankCost),
                cabo: _createTempComponent(_currentQuote.caboName, _currentQuote.caboPrice, _currentQuote.caboCost),
                caboQty: _currentQuote.caboQuantity,
                reelSeat: _createTempComponent(_currentQuote.reelSeatName, _currentQuote.reelSeatPrice, _currentQuote.reelSeatCost),
                passadores: _createTempComponent(_currentQuote.passadoresName, _currentQuote.passadoresPrice, _currentQuote.passadoresCost),
                passadoresQty: _currentQuote.passadoresQuantity,
                gravacaoCost: 0.0,
                // Assumindo custo 0 e preço 25 (ou calculado na diferença do total se quiser ser exato)
                gravacaoPrice: (_currentQuote.gravacao?.isNotEmpty ?? false) ? 25.0 : 0.0, 
              ),
              const SizedBox(height: 24),
            ],
            // ----------------------------------------------------

            // --- Botões de Ação ---
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // Header com Status
  Widget _buildHeader(BuildContext context) {
    String formattedDate = '${_currentQuote.createdAt.toDate().day}/${_currentQuote.createdAt.toDate().month}/${_currentQuote.createdAt.toDate().year}';
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Criado em: $formattedDate', style: TextStyle(color: Colors.grey[400])),
          const SizedBox(height: 8),
          Text('Status: ${_currentQuote.status.toUpperCase()}', 
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold, 
              color: _getStatusColor(_currentQuote.status)
            )
          ),
        ],
      ),
    );
  }

  // Constrói os botões de ação (Enviar / Reenviar)
  Widget _buildActionButtons() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Se o orçamento for um Rascunho
    if (_currentQuote.status == 'rascunho') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Enviar Orçamento via WhatsApp'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366), // Cor do WhatsApp
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _sendQuote,
        ),
      );
    }
    
    // Se já foi enviado ou está em outro status
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.chat_outlined),
        label: const Text('Reenviar via WhatsApp'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueGrey[600], // Um pouco diferente
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: _launchWhatsAppToSupplier, // Apenas abre o WhatsApp
      ),
    );
  }

  // Widget auxiliar para mostrar uma linha de detalhe (sem preço)
  Widget _buildDetailRow(String title, String? value, {int qty = 1}) {
    value = (value == null || value.isEmpty) ? 'Não selecionado' : value;
    if (qty > 1) value = "$value ($qty un)"; // Mostra quantidade
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                        fontWeight: FontWeight.bold, color: Colors.grey[400])),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          // Ocultamos o preço
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