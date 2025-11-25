import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/config_service.dart';
import '../../services/component_service.dart'; // (NOVO)
import 'admin_mass_update_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final ConfigService _configService = ConfigService();
  final ComponentService _componentService = ComponentService(); // (NOVO)
  
  final TextEditingController _marginController = TextEditingController();
  final TextEditingController _customizationPriceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = true;

  // Opções de Categoria para o filtro de aumento
  final Map<String, String> _categoriesMap = {
    'todos': 'Todos os Itens',
    'blank': 'Blanks',
    'cabo': 'Cabos',
    'passadores': 'Passadores',
    'reel_seat': 'Reel Seats',
    'acessorios': 'Acessórios',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _configService.getSettings();
    setState(() {
      _marginController.text = (settings['defaultMargin'] ?? 0.0).toString();
      _customizationPriceController.text = (settings['customizationPrice'] ?? 25.0).toString();
      _phoneController.text = (settings['supplierPhone'] ?? '').toString();
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    double margin = double.tryParse(_marginController.text) ?? 0.0;
    double customPrice = double.tryParse(_customizationPriceController.text) ?? 0.0;
    String phone = _phoneController.text.trim();
    
    try {
      await _configService.saveSettings(
        defaultMargin: margin,
        customizationPrice: customPrice,
        supplierPhone: phone,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- AÇÃO 1: RECALCULAR VENDA (Baseado na margem atual) ---
  Future<void> _recalculateAllSellingPrices() async {
    double margin = double.tryParse(_marginController.text) ?? 0.0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atenção: Reprocessamento'),
        content: Text('Isso irá atualizar o PREÇO DE VENDA de TODOS os componentes do catálogo baseando-se no custo atual de cada um e na margem de $margin%.\n\nDeseja continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, Reprocessar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // Primeiro salva a configuração para garantir
        await _configService.saveSettings(
          defaultMargin: margin,
          customizationPrice: double.tryParse(_customizationPriceController.text) ?? 0,
          supplierPhone: _phoneController.text,
        );
        
        // Chama o serviço
        await _componentService.batchRecalculateSellingPrices(margin);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Preços de venda atualizados com sucesso!'), backgroundColor: Colors.green)
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- AÇÃO 2: AUMENTAR CUSTO EM MASSA ---
  void _showCostIncreaseDialog() {
    final percentController = TextEditingController();
    String selectedCategory = 'todos';
    double currentMargin = double.tryParse(_marginController.text) ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder( // Necessário para o Dropdown dentro do Dialog atualizar
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Reajuste de Custo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Informe o percentual de aumento no custo. O preço de venda será recalculado automaticamente mantendo a margem atual.'),
                const SizedBox(height: 16),
                
                // Percentual
                TextField(
                  controller: percentController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  decoration: const InputDecoration(
                    labelText: 'Aumento (%)',
                    hintText: 'Ex: 10 para +10%',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Filtro de Categoria
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Aplicar em:', border: OutlineInputBorder()),
                  items: _categoriesMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[800]),
                onPressed: () async {
                  double percent = double.tryParse(percentController.text) ?? 0.0;
                  if (percent <= 0) return;

                  Navigator.pop(context); // Fecha diálogo
                  _executeCostIncrease(percent, selectedCategory, currentMargin);
                },
                child: const Text('Aplicar Reajuste', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _executeCostIncrease(double percent, String category, double currentMargin) async {
    setState(() => _isLoading = true);
    try {
      await _componentService.batchIncreaseCostPrices(
        increasePercent: percent,
        currentMargin: currentMargin,
        categoryFilter: category,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Custos reajustados em $percent% com sucesso!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações Globais')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Margens e Preços'),
                
                TextField(
                  controller: _marginController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  decoration: const InputDecoration(
                    labelText: 'Margem de Lucro Padrão (%)',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                // BOTÃO REPROCESSAR MARGEM
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reprocessar Preços de Venda (Tudo)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[800],
                      side: BorderSide(color: Colors.blue[800]!),
                      padding: const EdgeInsets.symmetric(vertical: 12)
                    ),
                    onPressed: _recalculateAllSellingPrices,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 24),
                  child: Text(
                    'Nota: Isso atualizará o preço de venda de todos os itens do catálogo baseado no custo atual e na margem acima.',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),

                TextField(
                  controller: _customizationPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  decoration: const InputDecoration(
                    labelText: 'Preço da Customização (Gravação)',
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                
                const Divider(height: 48),
                
                // --- SEÇÃO MANUTENÇÃO DE CUSTOS ---
                _buildSectionTitle('Reajuste de Fornecedor'),
                const Text(
                  'Use esta opção quando o fornecedor aumentar os preços. Isso aumentará o Custo e o Preço de Venda proporcionalmente.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.trending_up),
                    label: const Text('Reajuste de Preços (Seleção Avançada)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    // AQUI MUDOU: Navega para a nova tela
                    onPressed: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const AdminMassUpdateScreen())
                      );
                    },
                  ),
                ),
          

                const Divider(height: 48),
                _buildSectionTitle('Contato / WhatsApp'),

                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone do Fornecedor',
                    hintText: '5511999999999',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Salvar Configurações'),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
    );
  }
}