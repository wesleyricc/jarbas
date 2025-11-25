import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/component_model.dart';
import '../../../services/component_service.dart';
import '../../../services/config_service.dart';

class AdminMassUpdateScreen extends StatefulWidget {
  const AdminMassUpdateScreen({super.key});

  @override
  State<AdminMassUpdateScreen> createState() => _AdminMassUpdateScreenState();
}

class _AdminMassUpdateScreenState extends State<AdminMassUpdateScreen> {
  final ComponentService _componentService = ComponentService();
  final ConfigService _configService = ConfigService();
  
  final TextEditingController _percentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategoryKey = 'todos';
  String _searchQuery = '';
  
  final Set<String> _selectedIds = {};
  List<Component> _currentFilteredList = [];

  double _defaultMargin = 0.0;
  double _supplierDiscount = 0.0; // (NOVO)
  
  bool _isLoading = false;

  final Map<String, String> _categoriesMap = {
    'todos': 'Todas as Categorias',
    'blank': 'Blanks',
    'cabo': 'Cabos',
    'passadores': 'Passadores',
    'reel_seat': 'Reel Seats',
    'acessorios': 'Acessórios',
  };

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  Future<void> _loadConfig() async {
    final settings = await _configService.getSettings();
    if (mounted) {
      setState(() {
        _defaultMargin = (settings['defaultMargin'] ?? 0.0).toDouble();
        _supplierDiscount = (settings['supplierDiscount'] ?? 0.0).toDouble(); // (NOVO)
      });
    }
  }

  void _toggleItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _currentFilteredList.length && _currentFilteredList.isNotEmpty) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();
        for (var c in _currentFilteredList) {
          _selectedIds.add(c.id);
        }
      }
    });
  }

  Future<void> _applyUpdate() async {
    double percent = double.tryParse(_percentController.text) ?? 0.0;
    
    if (percent == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um percentual diferente de zero.')));
      return;
    }
    if (percent <= -100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A redução não pode ser de 100% ou mais.')));
      return;
    }
    
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione pelo menos um item.')));
      return;
    }

    String actionText = percent > 0 ? "AUMENTADO" : "REDUZIDO";
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Reajuste'),
        content: SingleChildScrollView(
          child: Text(
            'Você selecionou ${_selectedIds.length} itens.\n\n'
            'O Preço de TABELA será $actionText em $percent%.\n\n'
            'O sistema recalculará:\n'
            '1. Custo (Tabela - $_supplierDiscount%)\n'
            '2. Venda (Custo + $_defaultMargin%)\n\n'
            'Confirma?'
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('CONFIRMAR', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        List<Component> toUpdate = _currentFilteredList.where((c) => _selectedIds.contains(c.id)).toList();
        
        await _componentService.batchUpdateSpecificComponents(
          componentsToUpdate: toUpdate,
          increasePercent: percent,
          currentMargin: _defaultMargin,
          supplierDiscount: _supplierDiscount, // (NOVO) Passa o desconto
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preços atualizados com sucesso!'), backgroundColor: Colors.green));
          Navigator.pop(context);
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
      appBar: AppBar(title: const Text('Reajuste em Massa')),
      body: SafeArea(
        child: Column(
          children: [
            // Cabeçalho de Filtros
            Container(
              color: Colors.white,
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _percentController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,2}'))],
                            decoration: const InputDecoration(
                              labelText: 'Ajuste (%)',
                              hintText: 'Ex: 10 ou -5',
                              suffixText: '%',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save_alt, size: 18),
                            label: Text('APLICAR (${_selectedIds.length})', style: const TextStyle(fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _isLoading ? null : _applyUpdate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategoryKey,
                            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                            isExpanded: true,
                            items: _categoriesMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() {
                              _selectedCategoryKey = v!;
                              _selectedIds.clear();
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Buscar...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: _currentFilteredList.isNotEmpty && _selectedIds.length == _currentFilteredList.length,
                          onChanged: (_) => _toggleSelectAll(),
                        ),
                        const Flexible(
                          child: Text("Selecionar Todos", overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            "${_selectedIds.length} sel.", 
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[800], fontSize: 12)
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // Lista
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<Component>>(
                    stream: _componentService.getComponentsStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      List<Component> all = snapshot.data!;
                      
                      _currentFilteredList = all.where((c) {
                        bool catMatch = _selectedCategoryKey == 'todos' || c.category == _selectedCategoryKey;
                        bool nameMatch = c.name.toLowerCase().contains(_searchQuery.toLowerCase());
                        return catMatch && nameMatch;
                      }).toList();

                      if (_currentFilteredList.isEmpty) {
                        return const Center(child: Text("Nenhum item encontrado."));
                      }

                      return ListView.builder(
                        itemCount: _currentFilteredList.length,
                        itemBuilder: (context, index) {
                          final comp = _currentFilteredList[index];
                          final isSelected = _selectedIds.contains(comp.id);
                          
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => _toggleItem(comp.id),
                            title: Text(comp.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                            // --- CORREÇÃO VISUAL AQUI ---
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _priceTag("Tab.", comp.supplierPrice, Colors.grey[700]!),
                                  _priceTag("Custo", comp.costPrice, Colors.blue[800]!),
                                  _priceTag("Venda", comp.price, Colors.green[800]!),
                                ],
                              ),
                            ),
                            // -----------------------------
                            secondary: comp.imageUrl.isNotEmpty 
                                ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(comp.imageUrl, width: 40, height: 40, fit: BoxFit.cover))
                                : const Icon(Icons.image, color: Colors.grey),
                            activeColor: Colors.orange[800],
                            dense: false, // Aumentei um pouco a altura para caber os preços
                          );
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper para as etiquetas de preço
  Widget _priceTag(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Text(
          "R\$ ${value.toStringAsFixed(2)}", 
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)
        ),
      ],
    );
  }
}