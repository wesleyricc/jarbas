import 'package:flutter/material.dart';
import '../models/quote_model.dart';
import '../services/quote_service.dart';
import '../utils/app_constants.dart';
import 'admin_quote_detail_screen.dart';
import 'rod_builder_screen.dart'; 

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
    // Agora são 5 abas
    _tabController = TabController(length: 5, vsync: this);
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
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Container(
            color: Colors.blueGrey[800],
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.amber,
              isScrollable: true, // Adicionado scroll para caber 5 abas em telas menores
              tabs: const [
                Tab(text: 'Orçados'),      // Pendente, Enviado
                Tab(text: 'Rascunhos'),    // Rascunho
                Tab(text: 'Em Andamento'), // Aprovado, Produção
                Tab(text: 'Concluídos'),   // Concluído
                Tab(text: 'Cancelados'),   // Cancelado
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

                // --- LOGICA DE FILTRO DAS 5 ABAS ---
                
                // 1. ORÇADOS: Pendente ou Enviado
                final listOrcados = allQuotes.where((q) => 
                  q.status == AppConstants.statusPendente || 
                  q.status == AppConstants.statusEnviado
                ).toList();

                // 2. RASCUNHOS
                final listRascunhos = allQuotes.where((q) => 
                  q.status == AppConstants.statusRascunho
                ).toList();

                // 3. CANCELADOS
                final listCancelados = allQuotes.where((q) => 
                  q.status == AppConstants.statusCancelado
                ).toList();

                // 4. EM ANDAMENTO: Aprovado ou Produção
                final listAndamento = allQuotes.where((q) => 
                  q.status == AppConstants.statusAprovado || 
                  q.status == AppConstants.statusProducao
                ).toList();

                // 5. CONCLUÍDOS
                final listConcluidos = allQuotes.where((q) => 
                  q.status == AppConstants.statusConcluido
                ).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQuoteList(listOrcados, "Nenhum orçamento pendente."),
                    _buildQuoteList(listRascunhos, "Nenhum rascunho."),
                    _buildQuoteList(listAndamento, "Nenhuma produção em andamento."),
                    _buildQuoteList(listConcluidos, "Nenhuma entrega concluída."),
                    _buildQuoteList(listCancelados, "Nenhum cancelado."),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const RodBuilderScreen()));
        },
        backgroundColor: Colors.blueGrey[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildQuoteList(List<Quote> quotes, String emptyMsg) {
    if (quotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(emptyMsg, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Ordenar por data (mais recente primeiro)
    quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
    Color color = AppConstants.statusColors[status] ?? Colors.blueGrey;

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