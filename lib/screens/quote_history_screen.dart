import 'package:flutter/material.dart';
import '../../models/quote_model.dart';
import '../../services/quote_service.dart';
import '../../services/auth_service.dart';
import 'quote_detail_screen.dart'; 

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
      _quotesStream = _quoteService.getQuotesStream(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Rascunhos'),
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
                  return const Center(child: Text('Nenhum rascunho encontrado.'));
                }

                List<Quote> allQuotes = snapshot.data!;

                // --- FILTRO: APENAS RASCUNHOS ---
                final quotes = allQuotes.where((q) => q.status == 'rascunho').toList();

                if (quotes.isEmpty) {
                   return const Center(child: Text('Nenhum rascunho pendente.'));
                }

                // Ordena por data
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
        title: Text('Rascunho - $formattedDate',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(
          'Status: ${quote.status.toUpperCase()}',
          style: TextStyle(
            color: Colors.grey[400], // Cor neutra para rascunho
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Icon(
          Icons.edit, // Ícone de edição para indicar que é um rascunho
          color: Colors.grey[500],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              // Nota: Se for admin, pode querer redirecionar para o AdminQuoteDetailScreen 
              // para ter poder de edição total, ou manter o QuoteDetailScreen se for apenas visualização.
              // Como é "Meus Rascunhos", geralmente queremos editar.
              builder: (context) => QuoteDetailScreen(quote: quote),
            ),
          );
        },
      ),
    );
  }
}