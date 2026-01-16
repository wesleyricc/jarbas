import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // Necessário para abrir o WhatsApp
import '../models/quote_model.dart';
import '../utils/app_constants.dart';
import 'admin_quote_detail_screen.dart';
import 'rod_builder_screen.dart';



class AdminQuotesScreen extends StatefulWidget {
  const AdminQuotesScreen({super.key});

  @override
  State<AdminQuotesScreen> createState() => _AdminQuotesScreenState();
}

class _AdminQuotesScreenState extends State<AdminQuotesScreen> {
  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _statusFilter = 'todos';

  // O status 'enviado' NÃO desconta estoque (igual pendente/rascunho)
  final Set<String> _statusesThatDeductStock = {
    AppConstants.statusAprovado,
    AppConstants.statusProducao,
    AppConstants.statusConcluido,
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openQuoteDetail(Quote quote, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (c) => AdminQuoteDetailScreen(quote: quote, quoteId: id)),
    );
  }

  void _createNewQuote() {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => RodBuilderScreen()));
  }

  // --- ABRIR WHATSAPP DO CLIENTE ---
  Future<void> _openClientWhatsApp(String phone) async {
    if (phone.isEmpty) return;

    // Limpa o número
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]+'), '');
    if (cleanPhone.length >= 10 && !cleanPhone.startsWith('55')) {
      cleanPhone = '55$cleanPhone';
    }

    final Uri appUrl = Uri.parse("whatsapp://send?phone=$cleanPhone");
    final Uri webUrl = Uri.parse("https://wa.me/$cleanPhone");

    try {
      if (kIsWeb) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        if (await canLaunchUrl(appUrl)) {
          await launchUrl(appUrl, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Não foi possível abrir o WhatsApp.")));
    }
  }

  Future<void> _deleteQuoteWithStockReturn(String quoteId, Map<String, dynamic> quoteData) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Orçamento"),
        content: const Text("Tem certeza? Se este orçamento estiver aprovado ou em produção, o estoque será devolvido automaticamente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Excluir", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (!confirm) return;

    try {
      final db = FirebaseFirestore.instance;
      String status = quoteData['status'] ?? '';

      if (_statusesThatDeductStock.contains(status)) {
        await _processStockReturn(db, quoteData);
      }

      await db.collection(AppConstants.colQuotes).doc(quoteId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Orçamento excluído.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao excluir: $e")));
      }
    }
  }

  Future<void> _processStockReturn(FirebaseFirestore db, Map<String, dynamic> data) async {
    List<dynamic> allItems = [];
    allItems.addAll(data['blanksList'] ?? []);
    allItems.addAll(data['cabosList'] ?? []);
    allItems.addAll(data['reelSeatsList'] ?? []);
    allItems.addAll(data['passadoresList'] ?? []);
    allItems.addAll(data['acessoriosList'] ?? []);

    for (var item in allItems) {
      String? componentId = item['id'];
      int qty = (item['quantity'] ?? 1) as int;
      String? variationName = item['variation'];

      if (componentId == null || componentId.isEmpty) continue;

      try {
        await db.runTransaction((transaction) async {
          DocumentReference docRef = db.collection(AppConstants.colComponents).doc(componentId);
          DocumentSnapshot snapshot = await transaction.get(docRef);

          if (!snapshot.exists) return;

          Map<String, dynamic> compData = snapshot.data() as Map<String, dynamic>;

          if (variationName != null && variationName.isNotEmpty) {
            List<dynamic> variations = List.from(compData['variations'] ?? []);
            int index = variations.indexWhere((v) => v['name'] == variationName);

            if (index != -1) {
              int currentStock = (variations[index]['stock'] ?? 0) as int;
              variations[index]['stock'] = currentStock + qty;
              transaction.update(docRef, {'variations': variations});
            }
          } else {
            int currentStock = (compData['stock'] ?? 0) as int;
            transaction.update(docRef, {'stock': currentStock + qty});
          }
        });
      } catch (e) {
        print("Erro ao devolver estoque: $e");
      }
    }
  }

  Widget _buildQuoteSummary(Quote quote) {
    List<Widget> sections = [];

    void addSection(String label, List<Map<String, dynamic>> items) {
      final names = items
          .map((e) => e['name'] as String?)
          .where((name) => name != null && name.isNotEmpty)
          .toList();

      if (names.isNotEmpty) {
        sections.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                children: [
                  TextSpan(
                    text: "• $label: ",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
                  ),
                  TextSpan(
                    text: names.join(", "),
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    }

    addSection("Blank", quote.blanksList);
    addSection("Cabo", quote.cabosList);
    addSection("Reel Seat", quote.reelSeatsList);
    addSection("Passadores", quote.passadoresList);
    addSection("Acessórios", quote.acessoriosList);

    if (sections.isEmpty) {
      return const Text("Nenhum componente selecionado.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  bool _quoteContainsComponent(Quote quote, String query) {
    List<List<Map<String, dynamic>>> allLists = [
      quote.blanksList,
      quote.cabosList,
      quote.reelSeatsList,
      quote.passadoresList,
      quote.acessoriosList
    ];

    for (var list in allLists) {
      for (var item in list) {
        String name = (item['name'] ?? '').toString().toLowerCase();
        String variation = (item['variation'] ?? '').toString().toLowerCase();
        if (name.contains(query) || variation.contains(query)) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Column(
          children: [
            Container(
              color: Colors.blueGrey[800],
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar Cliente ou Componente...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip('todos', 'Todos', Colors.white),
                        const SizedBox(width: 8),
                        _buildFilterChip(AppConstants.statusRascunho, 'Rascunhos', Colors.grey),
                        const SizedBox(width: 8),
                        _buildFilterChip(AppConstants.statusPendente, 'Pendentes', Colors.orange),
                        const SizedBox(width: 8),
                        // NOVO FILTRO ENVIADO
                        _buildFilterChip(AppConstants.statusEnviado, 'Enviados', Colors.cyan),
                        const SizedBox(width: 8),
                        _buildFilterChip(AppConstants.statusAprovado, 'Aprovados', Colors.blue),
                        const SizedBox(width: 8),
                        _buildFilterChip(AppConstants.statusProducao, 'Produção', Colors.purple),
                        const SizedBox(width: 8),
                        _buildFilterChip(AppConstants.statusConcluido, 'Concluídos', Colors.green),
                        const SizedBox(width: 8),
                        _buildFilterChip(AppConstants.statusCancelado, 'Cancelados', Colors.red),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(AppConstants.colQuotes)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("Nenhum orçamento encontrado."));
                  }

                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final quote = Quote.fromFirestore(doc);
                    
                    if (_statusFilter != 'todos' && quote.status != _statusFilter) {
                      return false;
                    }

                    if (_searchQuery.isNotEmpty) {
                      bool matchName = quote.clientName.toLowerCase().contains(_searchQuery);
                      bool matchComponent = _quoteContainsComponent(quote, _searchQuery);
                      return matchName || matchComponent;
                    }

                    return true;
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(child: Text("Nenhum resultado para a busca."));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final quote = Quote.fromFirestore(doc);
                      
                      Color statusColor = Colors.grey;
                      if (quote.status == AppConstants.statusPendente) statusColor = Colors.orange;
                      if (quote.status == AppConstants.statusEnviado) statusColor = Colors.cyan; // COR DO STATUS NOVO
                      if (quote.status == AppConstants.statusAprovado) statusColor = Colors.blue;
                      if (quote.status == AppConstants.statusProducao) statusColor = Colors.purple;
                      if (quote.status == AppConstants.statusConcluido) statusColor = Colors.green;
                      if (quote.status == AppConstants.statusCancelado) statusColor = Colors.red;

                      String summary = _buildQuoteSummary(quote).toString(); 

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () => _openQuoteDetail(quote, doc.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: statusColor.withOpacity(0.5))
                                      ),
                                      child: Text(
                                        quote.status.toUpperCase(),
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                      ),
                                    ),
                                    Text(
                                      DateFormat("dd/MM/yyyy").format(quote.createdAt.toDate()),
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(quote.clientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(quote.clientPhone, style: TextStyle(fontSize: 13, color: Colors.grey[800])),
                                    const SizedBox(width: 16),
                                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text("${quote.clientCity} - ${quote.clientState}", style: TextStyle(fontSize: 13, color: Colors.grey[800])),
                                  ],
                                ),
                                const Divider(height: 12),
                                
                                const Text("Resumo do Pedido:", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 4),
                                _buildQuoteSummary(quote),
                                
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _currencyFormat.format(quote.totalPrice),
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blueGrey),
                                      ),
                                    ),
                                    
                                    // BOTÃO WHATSAPP
                                    IconButton(
                                      icon: const Icon(Icons.chat, color: Colors.green),
                                      onPressed: () => _openClientWhatsApp(quote.clientPhone),
                                      tooltip: "Conversar no WhatsApp",
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    
                                    // BOTÃO EXCLUIR
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _deleteQuoteWithStockReturn(doc.id, data),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _createNewQuote,
          backgroundColor: Colors.blueGrey[800],
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, Color baseColor) {
    bool isSelected = _statusFilter == key;
    Color chipColor = isSelected ? baseColor : Colors.white.withOpacity(0.15);
    Color textColor = isSelected 
        ? (baseColor == Colors.white ? Colors.black : Colors.white) 
        : Colors.white;

    return GestureDetector(
      onTap: () => setState(() => _statusFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.white30),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      ),
    );
  }
}