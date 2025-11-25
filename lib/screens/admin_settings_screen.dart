import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/config_service.dart';
import '../../services/component_service.dart';
import 'admin_mass_update_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  // Serviços
  final ConfigService _configService = ConfigService();
  final ComponentService _componentService = ComponentService();
  
  // Controladores de Texto
  final TextEditingController _marginController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _customizationPriceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _marginController.dispose();
    _discountController.dispose();
    _customizationPriceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Carrega configurações do Firestore
  Future<void> _loadSettings() async {
    final settings = await _configService.getSettings();
    
    setState(() {
      _marginController.text = (settings['defaultMargin'] ?? 0.0).toString();
      _discountController.text = (settings['supplierDiscount'] ?? 0.0).toString();
      _customizationPriceController.text = (settings['customizationPrice'] ?? 25.0).toString();
      _phoneController.text = (settings['supplierPhone'] ?? '').toString();
      _isLoading = false;
    });
  }

  // Salva configurações no Firestore
  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    
    try {
      await _configService.saveSettings(
        defaultMargin: double.tryParse(_marginController.text) ?? 0.0,
        supplierDiscount: double.tryParse(_discountController.text) ?? 0.0,
        customizationPrice: double.tryParse(_customizationPriceController.text) ?? 0.0,
        supplierPhone: _phoneController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Ação: Recalcular Preço de Venda de TODOS os itens
  Future<void> _recalculateAllSellingPrices() async {
    double margin = double.tryParse(_marginController.text) ?? 0.0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atenção: Reprocessamento'),
        content: Text(
          'Isso irá atualizar o PREÇO DE VENDA de TODOS os componentes do catálogo baseando-se no custo atual de cada um e na margem de $margin%.\n\n'
          'Esta ação não pode ser desfeita.\n\nDeseja continuar?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
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
        // 1. Salva a configuração primeiro para garantir consistência
        await _configService.saveSettings(
          defaultMargin: margin,
          supplierDiscount: double.tryParse(_discountController.text) ?? 0.0,
          customizationPrice: double.tryParse(_customizationPriceController.text) ?? 0.0,
          supplierPhone: _phoneController.text,
        );
        
        // 2. Chama o serviço de atualização em lote
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações Globais'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SEÇÃO 1: PRECIFICAÇÃO ---
                _buildSectionTitle('Formação de Preços'),
                
                // Desconto Fornecedor
                TextField(
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  decoration: const InputDecoration(
                    labelText: 'Desconto Padrão do Fornecedor (%)',
                    hintText: 'Ex: 30',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    helperText: 'Aplicado sobre o Preço do Fornecedor para calcular o Custo.',
                  ),
                ),
                const SizedBox(height: 24),

                // Margem de Lucro
                TextField(
                  controller: _marginController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  decoration: const InputDecoration(
                    labelText: 'Margem de Lucro Padrão (%)',
                    hintText: 'Ex: 100',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    helperText: 'Aplicado sobre o Custo para calcular a Venda.',
                  ),
                ),
                const SizedBox(height: 16),
                
                // Botão Reprocessar Venda
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
                    'Nota: Aplica a margem acima sobre o custo atual de TODOS os itens.',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),

                // Preço Customização
                TextField(
                  controller: _customizationPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  decoration: const InputDecoration(
                    labelText: 'Preço da Customização (Gravação)',
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(),
                    helperText: 'Valor cobrado pela gravação do nome na vara.',
                  ),
                ),
                
                const Divider(height: 48),
                
                // --- SEÇÃO 2: MANUTENÇÃO DE CUSTOS ---
                _buildSectionTitle('Manutenção de Custo'),
                const Text(
                  'Use esta opção quando houver reajuste de preços por parte do fornecedor. Você poderá selecionar itens específicos ou categorias inteiras.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                
                // Botão Reajuste em Massa
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
                    onPressed: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const AdminMassUpdateScreen())
                      );
                    },
                  ),
                ),

                const Divider(height: 48),
                
                // --- SEÇÃO 3: CONTATO ---
                _buildSectionTitle('Contato / WhatsApp'),

                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone do Fornecedor',
                    hintText: '5511999999999',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                    helperText: 'Use DDD + Número (ex: 5548999999999).',
                  ),
                ),

                const SizedBox(height: 48),
                
                // --- BOTÃO SALVAR ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('SALVAR CONFIGURAÇÕES'),
                  ),
                ),
                
                const SizedBox(height: 40), // Espaço final
              ],
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
      ),
    );
  }
}