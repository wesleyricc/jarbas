import 'package:flutter/material.dart';
import '../../models/quote_model.dart';
import '../../services/quote_service.dart';
import '../../services/auth_service.dart';
import 'quote_detail_screen.dart'; // Para navegar para os detalhes

class QuoteHistoryScreen extends StatefulWidget {
  const QuoteHistoryScreen({super.key});

  @override
  State<QuoteHistoryScreen> createState() => _QuoteHistoryScreenState();
}

class _QuoteHistoryScreenState extends State<QuoteHistoryScreen> {
  final QuoteService _quoteService = QuoteService();
  final AuthService _authService = AuthService();
  Stream<List<Quote>>? _quotesStream;

  @override
  void initState() {
    super.initState();
    final user = _authService.currentUser;
    if (user != null) {
      // Busca apenas os orçamentos deste usuário
      _quotesStream = _quoteService.getQuotesStream(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Orçamentos'),
      ),
      body: _quotesStream == null
          ? const Center(child: Text('Erro ao carregar usuário.'))
          : StreamBuilder<List<Quote>>(
              stream: _quotesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('Você ainda não criou nenhum orçamento.'));
                }

                List<Quote> quotes = snapshot.data!;
                // Ordena no cliente para exibir os mais novos primeiro
                quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: quotes.length,
                  itemBuilder: (context, index) {
                    Quote quote = quotes[index];
                    return _buildQuoteCard(quote);
                  },
                );
              },
            ),
    );
  }

  Widget _buildQuoteCard(Quote quote) {
    String formattedDate =
        '${quote.createdAt.toDate().day}/${quote.createdAt.toDate().month}/${quote.createdAt.toDate().year}';

    return Card(
      color: const Color(0xFF2C2C2C),
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        title: Text('Orçamento - $formattedDate',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'Status: ${quote.status.toUpperCase()}',
          style: TextStyle(
            color: _getStatusColor(quote.status),
            fontWeight: FontWeight.bold,
          ),
        ),
        
        // --- CORREÇÃO AQUI (Removendo o Preço) ---
        // Em vez de mostrar o preço, mostramos um ícone para indicar
        // que o usuário pode clicar para ver os detalhes.
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey[600],
        ),
        // --- FIM DA CORREÇÃO ---

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuoteDetailScreen(quote: quote),
            ),
          );
        },
      ),
    );
  }

  // Funções de cor (incluindo o novo status 'pendente')
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pendente': return Colors.yellow[300]!;
      case 'rascunho': return Colors.grey[400]!;
      case 'enviado': return Colors.blue[300]!;
      case 'aprovado': return Colors.green[300]!;
      case 'producao': return Colors.orange[300]!;
      case 'concluido': return Colors.purple[200]!;
      default: return Colors.white;
    }
  }
}