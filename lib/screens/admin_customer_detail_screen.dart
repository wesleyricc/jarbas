import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/quote_model.dart';
import '../services/customer_service.dart';
import '../services/whatsapp_service.dart';
import '../utils/financial_helper.dart'; 
import '../utils/app_constants.dart';
import 'admin_quote_detail_screen.dart';

class AdminCustomerDetailScreen extends StatefulWidget {
  final CustomerModel customer;

  const AdminCustomerDetailScreen({super.key, required this.customer});

  @override
  State<AdminCustomerDetailScreen> createState() => _AdminCustomerDetailScreenState();
}

class _AdminCustomerDetailScreenState extends State<AdminCustomerDetailScreen> {
  final CustomerService _customerService = CustomerService();
  final WhatsAppService _whatsappService = WhatsAppService();
  late TextEditingController _notesController;
  bool _isSavingNotes = false;

  final Map<String, Color> _statusColors = {
    AppConstants.statusPendente: Colors.orange,
    AppConstants.statusEnviado: Colors.cyan,
    AppConstants.statusAprovado: Colors.blue,
    AppConstants.statusProducao: Colors.purple,
    AppConstants.statusConcluido: Colors.green,
    AppConstants.statusCancelado: Colors.red,
    AppConstants.statusRascunho: Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.customer.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    setState(() => _isSavingNotes = true);
    try {
      CustomerModel updatedCustomer = CustomerModel(
        id: widget.customer.id,
        name: widget.customer.name,
        phone: widget.customer.phone,
        city: widget.customer.city,
        state: widget.customer.state,
        createdAt: widget.customer.createdAt,
        notes: _notesController.text,
      );

      await _customerService.saveCustomer(updatedCustomer);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Observações salvas com sucesso!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingNotes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: Text(widget.customer.name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<List<Quote>>(
        stream: _customerService.getCustomerQuotes(widget.customer.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final quotes = snapshot.data ?? [];
          final metrics = _calculateMetrics(quotes);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCustomerHeader(),

                const SizedBox(height: 16),

                _buildMetricsCard(metrics),

                const SizedBox(height: 16),

                _buildNotesCard(),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "HISTÓRICO DE ORÇAMENTOS",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.blueGrey[800], letterSpacing: 0.5),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(12)),
                      child: Text("${quotes.length}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[800], fontSize: 12)),
                    )
                  ],
                ),
                
                const SizedBox(height: 8),

                if (quotes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(child: Text("Nenhum orçamento encontrado.", style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic))),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: quotes.length,
                    itemBuilder: (context, index) {
                      return _buildQuoteCard(context, quotes[index]);
                    },
                  ),
                  
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- HEADER DO CLIENTE ---
  Widget _buildCustomerHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blueGrey[100],
                child: Text(
                  widget.customer.name.isNotEmpty ? widget.customer.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.customer.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('${widget.customer.city} - ${widget.customer.state}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.green.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.chat, color: Colors.green),
                  label: Text('WhatsApp (${widget.customer.phone})', style: TextStyle(color: Colors.green.shade700)),
                  onPressed: () {
                    _whatsappService.openWhatsApp(
                      phone: widget.customer.phone,
                      message: "Olá ${widget.customer.name}, aqui é da Jarbas Custom Rods...",
                    );
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // --- CARD DO ORÇAMENTO (COM RESUMO DETALHADO) ---
  Widget _buildQuoteCard(BuildContext context, Quote quote) {
    Color statusColor = _statusColors[quote.status] ?? Colors.grey;
    final dateStr = DateFormat('dd/MM/yyyy').format(quote.createdAt.toDate());
    final totalStr = FinancialHelper.formatCurrency(quote.totalPrice);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: Colors.black.withOpacity(0.05),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminQuoteDetailScreen(
                quote: quote,
                quoteId: quote.id ?? '',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha Superior: Ícone, ID, Data e Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.receipt_long, color: Colors.blueGrey[700], size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "#${quote.id?.substring(0, 4).toUpperCase() ?? '----'}",
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(dateStr, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3))
                    ),
                    child: Text(
                      quote.status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, thickness: 0.5)),
              
              // Resumo Detalhado dos Itens (IGUAL ADMIN_QUOTES_SCREEN)
              const Text("Resumo do Pedido:", style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 4),
              _buildQuoteSummary(quote),
              
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, thickness: 0.5)),
              
              // Valor Total
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    totalStr,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET AUXILIAR: RESUMO DOS ITENS ---
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

  // --- DASHBOARD DE MÉTRICAS ---
  Widget _buildMetricsCard(_CustomerMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey[900], 
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: [
          const Text("RESUMO GERAL", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Total Fechado", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(FinancialHelper.formatCurrency(metrics.totalClosed), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Total Orçado", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(FinancialHelper.formatCurrency(metrics.totalQuoted), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCompactMetric("Orçamentos", "${metrics.countQuoted}"),
              _buildCompactMetric("Aprovados", "${metrics.countClosed}"),
              _buildCompactMetric("Último", metrics.lastDate, isDate: true),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCompactMetric(String label, String value, {bool isDate = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: Colors.white, fontSize: isDate ? 13 : 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildNotesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.edit_note, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text("Observações Internas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              if (_isSavingNotes)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                InkWell(
                  onTap: _saveNotes,
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text("SALVAR", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                )
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: "Preferências, medidas, detalhes...",
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  _CustomerMetrics _calculateMetrics(List<Quote> quotes) {
    double totalQuoted = 0.0;
    double totalClosed = 0.0;
    int countClosed = 0;
    DateTime? lastDate;

    const closedStatuses = [
      AppConstants.statusAprovado, 
      AppConstants.statusProducao, 
      AppConstants.statusConcluido,
      AppConstants.statusEnviado
    ];

    for (var quote in quotes) {
      totalQuoted += quote.totalPrice;
      if (closedStatuses.contains(quote.status)) {
        totalClosed += quote.totalPrice;
        countClosed++;
      }
      final qDate = quote.createdAt.toDate();
      if (lastDate == null || qDate.isAfter(lastDate)) {
        lastDate = qDate;
      }
    }

    String lastDateStr = lastDate != null ? DateFormat('dd/MM/yyyy').format(lastDate) : '-';

    return _CustomerMetrics(
      totalQuoted: totalQuoted,
      totalClosed: totalClosed,
      countQuoted: quotes.length,
      countClosed: countClosed,
      lastDate: lastDateStr,
    );
  }
}

class _CustomerMetrics {
  final double totalQuoted;
  final double totalClosed;
  final int countQuoted;
  final int countClosed;
  final String lastDate;

  _CustomerMetrics({
    required this.totalQuoted, 
    required this.totalClosed, 
    required this.countQuoted, 
    required this.countClosed, 
    required this.lastDate
  });
}