import 'package:flutter/material.dart';
import '../../../models/quote_model.dart';
import '../../../services/quote_service.dart';
import 'admin_quote_detail_screen.dart';

class AdminQuotesScreen extends StatefulWidget {
  const AdminQuotesScreen({super.key});

  @override
  State<AdminQuotesScreen> createState() => _AdminQuotesScreenState();
}

class _AdminQuotesScreenState extends State<AdminQuotesScreen> with SingleTickerProviderStateMixin {
  final QuoteService _quoteService = QuoteService();
  late Stream<List<Quote>> _allQuotesStream;
  
  // Controlador das Abas
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _allQuotesStream = _quoteService.getAllQuotesStream();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Orçamentos'),
        // Configuração das Abas
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueGrey[800],
          labelColor: Colors.blueGrey[800],
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'ENCAMINHADOS', icon: Icon(Icons.inbox)),
            Tab(text: 'RASCUNHOS', icon: Icon(Icons.edit_note)),
          ],
        ),
      ),
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

          List<Quote> allQuotes = snapshot.data!;
          
          // Ordena por data (mais novos primeiro)
          allQuotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          // Separa as listas
          final receivedQuotes = allQuotes.where((q) => q.status != 'rascunho').toList();
          final draftQuotes = allQuotes.where((q) => q.status == 'rascunho').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              // ABA 1: Recebidos
              _buildQuoteList(receivedQuotes, isDraft: false),
              
              // ABA 2: Rascunhos
              _buildQuoteList(draftQuotes, isDraft: true),
            ],
          );
        },
      ),
    );
  }

  // Construtor da Lista Reutilizável
  Widget _buildQuoteList(List<Quote> quotes, {required bool isDraft}) {
    if (quotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isDraft ? Icons.note_alt_outlined : Icons.inbox_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isDraft ? 'Nenhum rascunho.' : 'Nenhum orçamento recebido.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: quotes.length,
      itemBuilder: (context, index) {
        return _buildQuoteCard(quotes[index]);
      },
    );
  }

  Widget _buildQuoteCard(Quote quote) {
    String formattedDate = '${quote.createdAt.toDate().day}/${quote.createdAt.toDate().month}/${quote.createdAt.toDate().year}';
    
    String clientDisplay = quote.clientName.isNotEmpty ? quote.clientName : 'Cliente Desconhecido';
    String locationDisplay = '';
    if (quote.clientCity.isNotEmpty) {
      locationDisplay = ' - ${quote.clientCity}/${quote.clientState}';
    }

    String titleText = '$clientDisplay$locationDisplay - $formattedDate';

    return Card(
      color: const Color(0xFF2C2C2C),
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        
        title: Text(
          titleText, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)
        ),
        
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(quote.status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _getStatusColor(quote.status), width: 1),
                ),
                child: Text(
                  quote.status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(quote.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'R\$ ${quote.totalPrice.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey[100]),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
        
        onTap: () {
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pendente': return Colors.yellowAccent;
      case 'rascunho': return Colors.grey;
      case 'enviado': return Colors.lightBlueAccent;
      case 'aprovado': return Colors.greenAccent;
      case 'producao': return Colors.orangeAccent;
      case 'concluido': return Colors.purpleAccent;
      default: return Colors.white;
    }
  }
}