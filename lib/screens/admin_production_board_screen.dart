import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/quote_model.dart';
import '../services/quote_service.dart';
import '../utils/app_constants.dart';
import 'admin_quote_detail_screen.dart';

class AdminProductionBoardScreen extends StatefulWidget {
  const AdminProductionBoardScreen({super.key});

  @override
  State<AdminProductionBoardScreen> createState() => _AdminProductionBoardScreenState();
}

class _AdminProductionBoardScreenState extends State<AdminProductionBoardScreen> {
  final QuoteService _quoteService = QuoteService();

  int _getPriorityWeight(String p) {
    if (p == AppConstants.priorityUrgente) return 3;
    if (p == AppConstants.priorityAlta) return 2;
    return 1;
  }

  void _sortQuotes(List<Quote> quotes) {
    quotes.sort((a, b) {
      int pA = _getPriorityWeight(a.priority);
      int pB = _getPriorityWeight(b.priority);
      if (pA != pB) return pB.compareTo(pA);

      if (a.deliveryDate != null && b.deliveryDate != null) {
        return a.deliveryDate!.compareTo(b.deliveryDate!);
      } else if (a.deliveryDate != null) {
        return -1;
      } else if (b.deliveryDate != null) {
        return 1;
      }

      return a.createdAt.compareTo(b.createdAt);
    });
  }

  Future<void> _updateQuoteStatus(Quote quote, String newStatus) async {
    if (quote.status == newStatus) return; 

    try {
      await _quoteService.updateQuote(quote.id!, {
        'status': newStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Movido para ${newStatus.toUpperCase()}!'), backgroundColor: Colors.green, duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(AppConstants.colQuotes)
            .where('status', whereIn: [
              AppConstants.statusAprovado, 
              AppConstants.statusProducao, 
              AppConstants.statusAguardandoEnvio,
              AppConstants.statusEnviado,
              AppConstants.statusConcluido
            ])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
             return const Center(child: Text("Nenhuma vara na fila de produção."));
          }

          final allQuotes = snapshot.data!.docs.map((d) => Quote.fromFirestore(d)).toList();

          final fila = allQuotes.where((q) => q.status == AppConstants.statusAprovado).toList();
          final producao = allQuotes.where((q) => q.status == AppConstants.statusProducao).toList();
          final aguardando = allQuotes.where((q) => q.status == AppConstants.statusAguardandoEnvio).toList();
          final enviados = allQuotes.where((q) => q.status == AppConstants.statusEnviado).toList();
          final concluidos = allQuotes.where((q) => q.status == AppConstants.statusConcluido).toList();

          _sortQuotes(fila);
          _sortQuotes(producao);
          _sortQuotes(aguardando);
          _sortQuotes(enviados);
          _sortQuotes(concluidos);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              scrollDirection: Axis.horizontal, 
              children: [
                _buildKanbanColumn('FILA DE ESPERA', AppConstants.statusAprovado, fila, Colors.blue),
                const SizedBox(width: 16),
                _buildKanbanColumn('EM PRODUÇÃO', AppConstants.statusProducao, producao, Colors.purple),
                const SizedBox(width: 16),
                _buildKanbanColumn('AGUARD. ENVIO', AppConstants.statusAguardandoEnvio, aguardando, Colors.indigo),
                const SizedBox(width: 16),
                _buildKanbanColumn('ENVIADOS', AppConstants.statusEnviado, enviados, Colors.teal),
                const SizedBox(width: 16),
                _buildKanbanColumn('CONCLUÍDOS', AppConstants.statusConcluido, concluidos, Colors.green),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKanbanColumn(String title, String statusKey, List<Quote> quotes, MaterialColor color) {
    return Container(
      width: 320, 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: color[200]!))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: color[800], fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color[200], borderRadius: BorderRadius.circular(10)),
                  child: Text('${quotes.length}', style: TextStyle(fontWeight: FontWeight.bold, color: color[900], fontSize: 12)),
                )
              ],
            ),
          ),
          
          Expanded(
            child: DragTarget<Quote>(
              onWillAcceptWithDetails: (data) => data.data.status != statusKey, 
              onAcceptWithDetails: (data) {
                _updateQuoteStatus(data.data, statusKey);
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  color: candidateData.isNotEmpty ? color[50]?.withOpacity(0.5) : Colors.transparent,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: quotes.length,
                    itemBuilder: (context, index) {
                      final quote = quotes[index];
                      return LongPressDraggable<Quote>(
                        data: quote,
                        feedback: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 300,
                            child: _buildQuoteCard(quote, isDragging: true),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _buildQuoteCard(quote),
                        ),
                        child: _buildQuoteCard(quote),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCard(Quote quote, {bool isDragging = false}) {
    Color priorityColor = Colors.grey;
    String priorityText = "NORMAL";
    
    if (quote.priority == AppConstants.priorityAlta) {
      priorityColor = Colors.orange;
      priorityText = "ALTA";
    } else if (quote.priority == AppConstants.priorityUrgente) {
      priorityColor = Colors.red;
      priorityText = "URGENTE";
    }

    String blankName = "Sem Blank";
    if (quote.blanksList.isNotEmpty) {
      blankName = quote.blanksList.first['name'] ?? 'Blank';
      if (quote.blanksList.first['variation'] != null) {
        blankName += " (${quote.blanksList.first['variation']})";
      }
    }

    // --- LÓGICA DE ATRASO NO KANBAN ---
    String deliveryDateStr = "Sem Prazo";
    Color deliveryColor = Colors.black87;
    IconData deliveryIcon = Icons.calendar_month;

    if (quote.deliveryDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final delDate = quote.deliveryDate!.toDate();
      final delDateOnly = DateTime(delDate.year, delDate.month, delDate.day);
      final diff = delDateOnly.difference(today).inDays;

      if (quote.status == AppConstants.statusConcluido || quote.status == AppConstants.statusEnviado) {
          deliveryDateStr = DateFormat('dd/MM/yyyy').format(delDate);
          deliveryColor = Colors.grey[700]!;
      } else {
        if (diff < 0) {
          deliveryDateStr = "Atrasado (${diff.abs()} dias)";
          deliveryColor = Colors.red;
          deliveryIcon = Icons.warning_rounded;
        } else if (diff == 0) {
          deliveryDateStr = "Hoje";
          deliveryColor = Colors.orange[800]!;
          deliveryIcon = Icons.notification_important;
        } else if (diff == 1) {
          deliveryDateStr = "Amanhã";
          deliveryColor = Colors.orange[800]!;
        } else {
          deliveryDateStr = DateFormat('dd/MM/yyyy').format(delDate);
          deliveryColor = Colors.black87;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDragging ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          // Se for urgente ou atrasado, a borda do card fica vermelha
          color: (quote.priority == AppConstants.priorityUrgente || deliveryColor == Colors.red) 
              ? Colors.red.withOpacity(0.5) 
              : Colors.transparent,
          width: (quote.priority == AppConstants.priorityUrgente || deliveryColor == Colors.red) ? 2 : 0
        )
      ),
      child: InkWell(
        onTap: isDragging ? null : () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AdminQuoteDetailScreen(quote: quote, quoteId: quote.id!)));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("#${quote.id?.substring(0, 4).toUpperCase() ?? ''}", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: priorityColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: priorityColor.withOpacity(0.3))),
                    child: Text(priorityText, style: TextStyle(color: priorityColor, fontSize: 9, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Text(quote.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.build, size: 12, color: Colors.blueGrey[400]),
                  const SizedBox(width: 4),
                  Expanded(child: Text(blankName, style: TextStyle(fontSize: 12, color: Colors.blueGrey[700]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(deliveryIcon, size: 14, color: deliveryColor),
                      const SizedBox(width: 4),
                      Text(
                        deliveryDateStr,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: deliveryColor)
                      )
                    ],
                  ),
                  const Icon(Icons.drag_indicator, size: 16, color: Colors.grey),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}