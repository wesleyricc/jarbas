import 'package:flutter/material.dart';
import '../../../models/quote_model.dart';
import '../../../services/quote_service.dart';
// Importa a nova tela de detalhes/editor do admin
import 'admin_quote_detail_screen.dart'; 

class AdminQuotesScreen extends StatefulWidget {
  const AdminQuotesScreen({super.key});

  @override
  State<AdminQuotesScreen> createState() => _AdminQuotesScreenState();
}

class _AdminQuotesScreenState extends State<AdminQuotesScreen> {
  final QuoteService _quoteService = QuoteService();
  late Stream<List<Quote>> _allQuotesStream;

  @override
  void initState() {
    super.initState();
    // Buscamos todos os orçamentos
    _allQuotesStream = _quoteService.getAllQuotesStream(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- ADIÇÃO DO APPBAR ---
      appBar: AppBar(
        title: const Text('Gerenciar Orçamentos'),
      ),
      // --- FIM DA ADIÇÃO ---
      body: StreamBuilder<List<Quote>>(
        stream: _allQuotesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum orçamento encontrado.'));
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
    // --- ATUALIZAÇÃO DO TÍTULO (CONFORME SOLICITADO) ---
    String formattedDate = '${quote.createdAt.toDate().day}/${quote.createdAt.toDate().month}/${quote.createdAt.toDate().year}';
    String clientName = quote.clientName.isNotEmpty ? quote.clientName : 'Cliente';
    String location = (quote.clientCity.isNotEmpty && quote.clientState.isNotEmpty) 
        ? '${quote.clientCity}/${quote.clientState}' 
        : 'Local não inf.';
    
    String title = '$clientName - $location - $formattedDate';
    // --- FIM DA ATUALIZAÇÃO DO TÍTULO ---

    return Card(
      color: const Color(0xFF2C2C2C),
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          'Status: ${quote.status.toUpperCase()}',
          style: TextStyle(color: _getStatusColor(quote.status), fontWeight: FontWeight.bold),
        ),
        trailing: Text(
          'R\$ ${quote.totalPrice.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 15, color: Colors.blueGrey[200]),
        ),
        onTap: () {
          // Navega para a tela de admin que permite edição
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminQuoteDetailScreen(quote: quote),
            ),
          );
        },
      ),
    );
  }

  // Funções de cor
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pendente': return Colors.yellow[300]!; // (NOVO STATUS)
      case 'rascunho': return Colors.grey[400]!;
      case 'enviado': return Colors.blue[300]!;
      case 'aprovado': return Colors.green[300]!;
      case 'producao': return Colors.orange[300]!;
      case 'concluido': return Colors.purple[200]!;
      default: return Colors.white;
    }
  }
}