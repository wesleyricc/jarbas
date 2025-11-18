import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rod_builder_provider.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/whatsapp_service.dart';
import '../widgets/client_info_step.dart';
import '../widgets/component_selector.dart';
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
  final int _totalSteps = 7; // Cliente + 4 Componentes + Personalização + Resumo

  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  late Future<bool> _isAdminFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RodBuilderProvider>().clearBuild();
    });
    _isAdminFuture = _getAdminStatus();
  }

  Future<bool> _getAdminStatus() async {
    final user = _authService.currentUser;
    if (user == null) return false;
    return await _userService.isAdmin(user);
  }

  // --- AÇÕES DE FINALIZAÇÃO ---

  Future<void> _saveQuoteAsDraft(RodBuilderProvider provider) async {
    final user = _authService.currentUser;
    if (user == null) return;

    if (provider.clientName.isEmpty || provider.clientPhone.isEmpty) {
      _showError('Preencha os dados do cliente no Passo 1.');
      setState(() => _currentStep = 0);
      return;
    }

    setState(() => _isLoading = true);
    bool success = await provider.saveQuote(user.uid, status: 'rascunho');
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rascunho salvo!'), backgroundColor: Colors.green),
        );
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
    bool success = await provider.saveQuote(user.uid, status: 'pendente');

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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // --- NAVEGAÇÃO ---

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
      // AppBar Limpa
      appBar: AppBar(
        title: const Text('Montar Vara'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<bool>(
        future: _isAdminFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final bool isAdmin = snapshot.data!;
          final provider = context.watch<RodBuilderProvider>();

          return Column(
            children: [
              // 1. BARRA DE PROGRESSO SUPERIOR
              _buildProgressBar(),

              // 2. CONTEÚDO DA ETAPA (EXPANDIDO)
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStepContent(_currentStep, isAdmin, provider),
                ),
              ),

              // 3. BARRA DE PREÇO (SE ADMIN)
              if (isAdmin)
                PriceSummaryBar(totalPrice: provider.totalPrice),

              // 4. BARRA DE NAVEGAÇÃO INFERIOR
              _buildBottomNavigation(isAdmin, provider),
            ],
          );
        },
      ),
    );
  }

  // Widget da Barra de Progresso
  Widget _buildProgressBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Passo ${_currentStep + 1} de $_totalSteps',
            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueGrey[700]!),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // Conteúdo de cada passo
  Widget _buildStepContent(int step, bool isAdmin, RodBuilderProvider provider) {
    // Envolvemos em um Container com Key para o AnimatedSwitcher funcionar
    return Container(
      key: ValueKey<int>(step),
      color: const Color(0xFFF5F7FA),
      padding: const EdgeInsets.all(24.0),
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título Grande da Etapa
            Text(
              _getStepTitle(step),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              _getStepSubtitle(step),
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            
            // O Conteúdo Específico
            _getStepWidget(step, isAdmin, provider),
          ],
        ),
      ),
    );
  }

  // Barra inferior com botões grandes
  Widget _buildBottomNavigation(bool isAdmin, RodBuilderProvider provider) {
    bool isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          // Botão Voltar (Visível se não for o primeiro passo)
          if (_currentStep > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[400]!),
                ),
                child: const Text('Voltar', style: TextStyle(color: Colors.black87)),
              ),
            ),
          
          if (_currentStep > 0) const SizedBox(width: 16),

          // Botão Próximo / Finalizar
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading 
                ? null 
                : (isLastStep 
                    ? () => isAdmin ? _saveQuoteAsDraft(provider) : _submitClientQuote(provider)
                    : _nextStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastStep ? (isAdmin ? Colors.blue[700] : const Color(0xFF25D366)) : Colors.blueGrey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    isLastStep 
                      ? (isAdmin ? 'Salvar Rascunho' : 'Solicitar via WhatsApp') 
                      : 'Próximo Passo',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER METHODS PARA TÍTULOS E WIDGETS ---

  String _getStepTitle(int step) {
    switch (step) {
      case 0: return 'Vamos começar!';
      case 1: return 'Escolha o Blank';
      case 2: return 'Escolha o Cabo';
      case 3: return 'Escolha o Reel Seat';
      case 4: return 'Escolha os Passadores';
      case 5: return 'Personalize';
      case 6: return 'Resumo Final';
      default: return '';
    }
  }

  String _getStepSubtitle(int step) {
    switch (step) {
      case 0: return 'Precisamos de alguns dados para entrar em contato.';
      case 1: return 'O corpo da vara. Selecione a base ideal.';
      case 2: return 'O conforto da pegada. Defina o material e a quantidade.';
      case 3: return 'Onde sua carretilha ou molinete será fixado.';
      case 4: return 'Guias para a linha. Defina o modelo e a quantidade.';
      case 5: return 'Dê o seu toque final com cores e textos.';
      case 6: return 'Confira tudo antes de enviar.';
      default: return '';
    }
  }

  Widget _getStepWidget(int step, bool isAdmin, RodBuilderProvider provider) {
    switch (step) {
      case 0:
        return const ClientInfoStep();
      case 1:
        return ComponentSelector(
          category: 'blank',
          selectedComponent: provider.selectedBlank,
          onSelect: (c) => provider.selectBlank(c),
          isAdmin: isAdmin,
        );
      case 2:
        return ComponentSelector(
          category: 'cabo',
          selectedComponent: provider.selectedCabo,
          onSelect: (c) => provider.selectCabo(c),
          isAdmin: isAdmin,
          quantity: provider.caboQuantity,
          onQuantityChanged: (val) => provider.setCaboQuantity(val),
        );
      case 3:
        return ComponentSelector(
          category: 'reel_seat',
          selectedComponent: provider.selectedReelSeat,
          onSelect: (c) => provider.selectReelSeat(c),
          isAdmin: isAdmin,
        );
      case 4:
        return ComponentSelector(
          category: 'passadores',
          selectedComponent: provider.selectedPassadores,
          onSelect: (c) => provider.selectPassadores(c),
          isAdmin: isAdmin,
          quantity: provider.passadoresQuantity,
          onQuantityChanged: (val) => provider.setPassadoresQuantity(val),
        );
      case 5:
        return const CustomizationStep();
      case 6:
        return SummaryStep(isAdmin: isAdmin);
      default:
        return const SizedBox.shrink();
    }
  }
}