import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rod_builder_provider.dart';
import '../../models/kit_model.dart';
import '../../services/kit_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/whatsapp_service.dart';
import '../../utils/app_constants.dart'; // Importação das Constantes
import '../widgets/client_info_step.dart';
import '../widgets/multi_component_step.dart';
import '../widgets/customization_step.dart';
import '../widgets/price_summary_bar.dart';
import '../widgets/summary_step.dart';

class RodBuilderScreen extends StatefulWidget {
  const RodBuilderScreen({super.key});

  @override
  State<RodBuilderScreen> createState() => _RodBuilderScreenState();
}

class _RodBuilderScreenState extends State<RodBuilderScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  final int _totalSteps = 9;

  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final KitService _kitService = KitService();
  late Future<bool> _isAdminFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RodBuilderProvider>();
      provider.clearBuild();
      provider.fetchSettings();
    });
    _isAdminFuture = _getAdminStatus();
  }

  Future<bool> _getAdminStatus() async {
    final user = _authService.currentUser;
    if (user == null) return false;
    return await _userService.isAdmin(user);
  }

  // --- AÇÕES DO BUILDER ---

  Future<void> _saveQuoteAsDraft(RodBuilderProvider provider) async {
    final user = _authService.currentUser;
    if (user == null) return;

    if (provider.clientName.isEmpty || provider.clientPhone.isEmpty) {
      _showError('Preencha os dados do cliente no Passo 1.');
      setState(() => _currentStep = 0);
      return;
    }

    setState(() => _isLoading = true);
    // Usa a constante para Rascunho
    bool success = await provider.saveQuote(user.uid, status: AppConstants.statusRascunho);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rascunho salvo!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        _showError('Erro ao salvar rascunho.');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitClientQuote(RodBuilderProvider provider) async {
    final user = _authService.currentUser;
    if (user == null) return;

    if (provider.clientName.isEmpty || provider.clientPhone.isEmpty) {
      _showError('Preencha seus dados de contato no primeiro passo.');
      setState(() => _currentStep = 0);
      return;
    }

    setState(() => _isLoading = true);
    // Usa a constante para Pendente
    bool success = await provider.saveQuote(user.uid, status: AppConstants.statusPendente);

    if (mounted) {
      if (success) {
        try {
          await WhatsAppService.sendNewQuoteRequest(provider: provider);
          provider.clearBuild();
          Navigator.pop(context);
        } catch (e) {
          _showError('Salvo, mas erro ao abrir WhatsApp: $e');
        }
      } else {
        _showError('Erro ao salvar orçamento.');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectKitAndProceed(KitModel kit, RodBuilderProvider provider) async {
    setState(() => _isLoading = true);
    final success = await provider.loadKit(kit);
    setState(() => _isLoading = false);

    if (success) {
      setState(() => _currentStep = 2);
    } else {
      _showError('Erro ao carregar kit.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Montar Vara'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: FutureBuilder<bool>(
        future: _isAdminFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final bool isAdmin = snapshot.data!;
          final provider = context.watch<RodBuilderProvider>();

          return Column(
            children: [
              _buildProgressBar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStepContent(_currentStep, isAdmin, provider),
                ),
              ),
              if (isAdmin) PriceSummaryBar(totalPrice: provider.totalPrice),
              _buildBottomNavigation(isAdmin, provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Passo ${_currentStep + 1} de $_totalSteps', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (_currentStep + 1) / _totalSteps, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(Colors.blueGrey[700]!), minHeight: 6),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(int step, bool isAdmin, RodBuilderProvider provider) {
    return Container(
      key: ValueKey<int>(step),
      color: const Color(0xFFF5F7FA),
      padding: const EdgeInsets.all(24.0),
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getStepTitle(step), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Text(_getStepSubtitle(step), style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 32),
            _getStepWidget(step, isAdmin, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(bool isAdmin, RodBuilderProvider provider) {
    bool isLastStep = _currentStep == _totalSteps - 1;
    bool isModeSelection = _currentStep == 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(child: OutlinedButton(onPressed: _isLoading ? null : _prevStep, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: Colors.grey[400]!)), child: const Text('Voltar', style: TextStyle(color: Colors.black87)))),

          if (_currentStep > 0) const SizedBox(width: 16),

          if (!isModeSelection)
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : (isLastStep ? () => isAdmin ? _saveQuoteAsDraft(provider) : _submitClientQuote(provider) : _nextStep),
                style: ElevatedButton.styleFrom(backgroundColor: isLastStep ? (isAdmin ? Colors.blue[700] : const Color(0xFF25D366)) : Colors.blueGrey[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0),
                child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isLastStep ? (isAdmin ? 'Salvar Rascunho' : 'Solicitar via WhatsApp') : 'Próximo Passo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getStepWidget(int step, bool isAdmin, RodBuilderProvider provider) {
    switch (step) {
      case 0: return const ClientInfoStep();
      case 1: return _buildModeSelectionStep(provider, isAdmin);

      case 2: return MultiComponentStep(
          isAdmin: isAdmin,
          // Usa constante
          categoryKey: AppConstants.catBlank,
          title: 'Blank',
          emptyMessage: 'Nenhum blank selecionado.',
          emptyIcon: Icons.crop_square,
          items: provider.selectedBlanksList,
          onAdd: (c, v) => provider.addBlank(c, 1, variation: v),
          onRemove: (i) => provider.removeBlank(i),
          onUpdateQty: (i, q) => provider.updateBlankQty(i, q),
      );

      case 3: return MultiComponentStep(
          isAdmin: isAdmin,
          // Usa constante
          categoryKey: AppConstants.catCabo,
          title: 'Cabo',
          emptyMessage: 'Nenhum cabo selecionado.',
          emptyIcon: Icons.grid_goldenratio,
          items: provider.selectedCabosList,
          onAdd: (c, v) => provider.addCabo(c, 1, variation: v),
          onRemove: (i) => provider.removeCabo(i),
          onUpdateQty: (i, q) => provider.updateCaboQty(i, q),
      );

      case 4: return MultiComponentStep(
          isAdmin: isAdmin,
          // Usa constante
          categoryKey: AppConstants.catReelSeat,
          title: 'Reel Seat',
          emptyMessage: 'Nenhum reel seat selecionado.',
          emptyIcon: Icons.chair,
          items: provider.selectedReelSeatsList,
          onAdd: (c, v) => provider.addReelSeat(c, 1, variation: v),
          onRemove: (i) => provider.removeReelSeat(i),
          onUpdateQty: (i, q) => provider.updateReelSeatQty(i, q),
      );

      case 5: return MultiComponentStep(
          isAdmin: isAdmin, 
          // Usa constante
          categoryKey: AppConstants.catPassadores, 
          title: 'Passador', emptyMessage: 'Nenhum passador selecionado.', emptyIcon: Icons.playlist_add,
          items: provider.selectedPassadoresList, onAdd: (c, v) => provider.addPassador(c, 1, variation: v),
          onRemove: (i) => provider.removePassador(i), onUpdateQty: (i, q) => provider.updatePassadorQty(i, q));

      case 6: return MultiComponentStep(
          isAdmin: isAdmin, 
          // Usa constante
          categoryKey: AppConstants.catAcessorios, 
          title: 'Acessório', emptyMessage: 'Nenhum acessório selecionado.', emptyIcon: Icons.extension_outlined,
          items: provider.selectedAcessoriosList, onAdd: (c, v) => provider.addAcessorio(c, 1, variation: v),
          onRemove: (i) => provider.removeAcessorio(i), onUpdateQty: (i, q) => provider.updateAcessorioQty(i, q));
      
      case 7: return CustomizationStep(isAdmin: isAdmin);
      case 8: return SummaryStep(isAdmin: isAdmin);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildModeSelectionStep(RodBuilderProvider provider, bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildModeCard(
          title: 'Montar do Zero',
          description: 'Escolha peça por peça e crie algo totalmente único.',
          icon: Icons.build,
          color: Colors.blueGrey,
          onTap: () {
            provider.clearBuild();
            _nextStep();
          },
        ),
        const SizedBox(height: 24),
        const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("OU")), Expanded(child: Divider())]),
        const SizedBox(height: 24),

        Text(
          "Usar Configuração Pronta (Template):",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey[800]
          )
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 280,
          child: StreamBuilder<List<KitModel>>(
            stream: _kitService.getKitsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Nenhum kit disponível."));

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final kit = snapshot.data![index];
                  return _buildKitCard(kit, provider, isAdmin); 
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModeCard({required String title, required String description, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color.withOpacity(0.1), radius: 30, child: Icon(icon, color: color, size: 30)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKitCard(KitModel kit, RodBuilderProvider provider, bool isAdmin) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showKitDetails(context, kit, provider, isAdmin),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _kitService.getKitSummary(kit),
            builder: (context, snapshot) {
              String priceText = '';
              if (isAdmin && snapshot.hasData) {
                priceText = 'R\$ ${(snapshot.data!['totalPrice'] as double).toStringAsFixed(2)}';
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: kit.imageUrls.isNotEmpty
                              ? Image.network(kit.imageUrls.first, fit: BoxFit.cover)
                              : Container(color: Colors.grey[200], child: const Icon(Icons.image_not_supported)),
                        ),
                        if (isAdmin && priceText.isNotEmpty)
                          Positioned(
                            top: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                              child: Text(priceText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kit.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(kit.description, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const Spacer(),
                          Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(8)),
                            child: Text("USAR ESTE MODELO", style: TextStyle(color: Colors.blueGrey[800], fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<Map<String, List<String>>> _fetchKitComponentsData(KitModel kit) async {
    Future<List<String>> resolveList(List<Map<String, dynamic>> items) async {
      List<String> names = [];
      for (var item in items) {
        final c = await _kitService.getComponentById(item['id']);
        if (c != null) {
          String suffix = "";
          if (item['variation'] != null) suffix += " - ${item['variation']}";
          names.add("${c.name}$suffix (${item['quantity']}x)");
        }
      }
      return names;
    }

    return {
      'blanks': await resolveList(kit.blanksIds),
      'cabos': await resolveList(kit.cabosIds),
      'reelSeats': await resolveList(kit.reelSeatsIds),
      'passadores': await resolveList(kit.passadoresIds),
      'acessorios': await resolveList(kit.acessoriosIds),
    };
  }

  void _showKitDetails(BuildContext context, KitModel kit, RodBuilderProvider provider, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      if (kit.imageUrls.isNotEmpty)
                        SizedBox(
                          height: 250,
                          child: PageView.builder(
                            itemCount: kit.imageUrls.length,
                            itemBuilder: (ctx, index) {
                              return Image.network(kit.imageUrls[index], fit: BoxFit.cover);
                            },
                          ),
                        )
                      else
                        Container(height: 200, color: Colors.grey[200], child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),

                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kit.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 8),
                            Text(kit.description, style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.4)),

                            const Divider(height: 40),
                            Text("Configuração do Template", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[900])),
                            const SizedBox(height: 16),

                            FutureBuilder<Map<String, List<String>>>(
                              future: _fetchKitComponentsData(kit),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
                                }
                                if (snapshot.hasError) return const Text("Erro ao carregar detalhes.");

                                final data = snapshot.data!;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailList(Icons.crop_square, "Blanks", data['blanks']!),
                                    _buildDetailList(Icons.grid_goldenratio, "Cabos", data['cabos']!),
                                    _buildDetailList(Icons.chair, "Reel Seats", data['reelSeats']!),
                                    _buildDetailList(Icons.format_list_bulleted, "Passadores", data['passadores']!),
                                    _buildDetailList(Icons.extension, "Acessórios", data['acessorios']!),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _selectKitAndProceed(kit, provider);
                        },
                        child: const Text("CARREGAR ESTA CONFIGURAÇÃO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailList(IconData icon, String label, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey[700])),
                const SizedBox(height: 2),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: Text("• $item", style: const TextStyle(fontSize: 15, color: Colors.black87)),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0: return 'Vamos começar!';
      case 1: return 'Como deseja montar?';
      case 2: return 'Escolha os Blanks';
      case 3: return 'Escolha os Cabos';
      case 4: return 'Escolha os Reel Seats';
      case 5: return 'Escolha os Passadores';
      case 6: return 'Acessórios';
      case 7: return 'Personalize';
      case 8: return 'Resumo Final';
      default: return '';
    }
  }

  String _getStepSubtitle(int step) {
    switch (step) {
      case 0: return 'Precisamos de alguns dados para entrar em contato.';
      case 1: return 'Você pode começar do zero ou usar um modelo pronto.';
      case 2: return 'Selecione a base da vara (pode ser mais de uma).';
      case 3: return 'Defina os cabos e materiais.';
      case 4: return 'Fixadores para a carretilha/molinete.';
      case 5: return 'Adicione quantos passadores forem necessários.';
      case 6: return 'Escolha itens extras para sua vara.';
      case 7: return 'Dê o seu toque final com a gravação.';
      case 8: return 'Confira tudo antes de enviar.';
      default: return '';
    }
  }
}