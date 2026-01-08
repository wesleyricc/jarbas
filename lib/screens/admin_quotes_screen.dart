import 'package:flutter/material.dart';
import '../models/quote_model.dart';
import '../services/quote_service.dart';
import 'admin_quote_detail_screen.dart';
import 'rod_builder_screen.dart'; // <--- Import para criar novo orçamento

class AdminQuotesScreen extends StatefulWidget {
  const AdminQuotesScreen({super.key});

  @override
  State<AdminQuotesScreen> createState() => _AdminQuotesScreenState();
}

class _AdminQuotesScreenState extends State<AdminQuotesScreen> with SingleTickerProviderStateMixin {
  final QuoteService _quoteService = QuoteService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _confirmDelete(String quoteId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Orçamento?"),
        content: const Text(
          "Esta ação é irreversível.\n\n"
          "Se o orçamento estiver Aprovado/Produção/Concluído, "
          "os itens serão estornados ao estoque automaticamente."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _quoteService.deleteQuote(quoteId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Orçamento excluído com sucesso!"), backgroundColor: Colors.green)
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erro ao excluir: $e"), backgroundColor: Colors.red)
                  );
                }
              }
            },
            child: const Text("EXCLUIR", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Padronização
      body: Column(
        children: [
          Container(
            color: Colors.blueGrey[800],
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.amber,
              tabs: const [
                Tab(text: 'Encaminhados'),
                Tab(text: 'Rascunhos'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Quote>>(
              stream: _quoteService.getAllQuotesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("Nenhum orçamento encontrado."));
                }

                final allQuotes = snapshot.data!;
                final submittedQuotes = allQuotes.where((q) => q.status != 'rascunho').toList();
                final draftQuotes = allQuotes.where((q) => q.status == 'rascunho').toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQuoteList(submittedQuotes),
                    _buildQuoteList(draftQuotes),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // --- NOVO: Botão para Criar Orçamento (Admin) ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const RodBuilderScreen()));
        },
        backgroundColor: Colors.blueGrey[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildQuoteList(List<Quote> quotes) {
    if (quotes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text("Lista vazia.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: quotes.length,
      itemBuilder: (context, index) {
        final quote = quotes[index];
        final date = quote.createdAt.toDate();
        final dateStr = "${date.day}/${date.month}/${date.year}";

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => AdminQuoteDetailScreen(quote: quote))
              );
            },
            title: Text(
              quote.clientName.isEmpty ? "Cliente (Sem nome)" : quote.clientName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("Data: $dateStr  •  Total: R\$ ${quote.totalPrice.toStringAsFixed(2)}"),
                const SizedBox(height: 6),
                _buildStatusBadge(quote.status),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Excluir Orçamento',
              onPressed: () {
                if (quote.id != null) {
                  _confirmDelete(quote.id!);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pendente': color = Colors.orange; break;
      case 'aprovado': color = Colors.blue; break;
      case 'producao': color = Colors.purple; break;
      case 'concluido': color = Colors.green; break;
      case 'rascunho': color = Colors.grey; break;
      case 'cancelado': color = Colors.red; break;
      default: color = Colors.blueGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5))
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}