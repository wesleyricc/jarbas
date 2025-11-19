import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/config_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final ConfigService _configService = ConfigService();
  
  final TextEditingController _marginController = TextEditingController();
  final TextEditingController _customizationPriceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = true;

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
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
                
                // 1. Margem de Lucro
                TextField(
                  controller: _marginController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  decoration: const InputDecoration(
                    labelText: 'Margem de Lucro Padrão (%)',
                    hintText: 'Ex: 100',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    helperText: 'Aplicado automaticamente no cadastro de componentes.',
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Preço da Customização
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
                _buildSectionTitle('Contato / WhatsApp'),

                // 3. Telefone do Fornecedor
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone do Fornecedor (WhatsApp)',
                    hintText: '5511999999999',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                    helperText: 'Use DDD + Número (ex: 5548999999999).',
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
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
      ),
    );
  }
}