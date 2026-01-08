import 'package:flutter/material.dart';
import '../models/component_model.dart';
import '../services/component_service.dart';
import '../services/storage_service.dart';
import '../services/config_service.dart';

class AdminComponentsScreen extends StatefulWidget {
  const AdminComponentsScreen({super.key});

  @override
  State<AdminComponentsScreen> createState() => _AdminComponentsScreenState();
}

class _AdminComponentsScreenState extends State<AdminComponentsScreen> {
  final ComponentService _componentService = ComponentService();
  final StorageService _storageService = StorageService();
  final ConfigService _configService = ConfigService();
  
  // UX: Controladores
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedFilter = 'todos'; 

  // Variáveis Globais de Configuração
  double _globalSupplierDiscount = 0.0;
  double _globalMargin = 0.0;

  final Map<String, String> _categories = {
    'todos': 'Todos',
    'blank': 'Blanks',
    'cabo': 'Cabos',
    'reel_seat': 'Reel Seats',
    'passadores': 'Passadores',
    'acessorios': 'Acessórios',
  };

  @override
  void initState() {
    super.initState();
    _loadGlobalSettings();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  Future<void> _loadGlobalSettings() async {
    final settings = await _configService.getSettings();
    if (mounted) {
      setState(() {
        _globalSupplierDiscount = (settings['supplierDiscount'] ?? 0.0).toDouble();
        _globalMargin = (settings['defaultMargin'] ?? 0.0).toDouble();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- FORMULÁRIO COMPLETO ---
  void _showComponentForm({Component? component}) {
    // Controladores Básicos
    final nameController = TextEditingController(text: component?.name ?? '');
    final descController = TextEditingController(text: component?.description ?? '');
    final linkController = TextEditingController(text: component?.supplierLink ?? '');
    final categoryController = TextEditingController(text: component?.category ?? 'blank');
    final imageController = TextEditingController(text: component?.imageUrl ?? '');

    // Controladores de Preço
    final tablePriceController = TextEditingController(); 
    final costController = TextEditingController(text: component?.costPrice.toStringAsFixed(2) ?? '');
    final priceController = TextEditingController(text: component?.price.toStringAsFixed(2) ?? '');
    
    // Tenta estimar o preço de tabela reverso para exibição
    if (component != null && _globalSupplierDiscount > 0 && component.costPrice > 0) {
      double reverseTable = component.costPrice / (1 - (_globalSupplierDiscount / 100));
      tablePriceController.text = reverseTable.toStringAsFixed(2);
    }

    // Estoque
    final stockController = TextEditingController(text: component?.stock.toString() ?? '0');
    Map<String, int> tempVariations = component?.variations != null 
        ? Map<String, int>.from(component!.variations) 
        : {};

    // --- LÓGICA DE CÁLCULO AUTOMÁTICO ---
    
    // 1. Calcula Venda baseado no Custo e Margem Global
    void calculateSalePrice() {
      double cost = double.tryParse(costController.text.replaceAll(',', '.')) ?? 0.0;
      if (cost > 0) {
        double salePrice = cost * (1 + (_globalMargin / 100));
        priceController.text = salePrice.toStringAsFixed(2);
      }
    }

    // 2. Calcula Custo baseado na Tabela e Desconto Global -> Depois chama Venda
    void calculateCostFromTable() {
      double tablePrice = double.tryParse(tablePriceController.text.replaceAll(',', '.')) ?? 0.0;
      if (tablePrice > 0) {
        double discountMultiplier = 1 - (_globalSupplierDiscount / 100);
        double finalCost = tablePrice * discountMultiplier;
        
        costController.text = finalCost.toStringAsFixed(2);
        calculateSalePrice(); // Cascata: Atualiza venda também
      }
    }

    // --- HELPER DE IMAGEM ---
    Future<void> pickImage(StateSetter setStateModal) async {
      try {
        final res = await _storageService.pickImageForPreview();
        if (res != null) {
          final upload = await _storageService.uploadImage(
             fileBytes: res.bytes, 
             fileName: 'comp_${DateTime.now().millisecondsSinceEpoch}', 
             fileExtension: res.extension,
             onProgress: (_){}
          );
          if (upload != null) {
            setStateModal(() => imageController.text = upload.downloadUrl);
          }
        }
      } catch (e) { print("Erro imagem: $e"); }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            int currentTotalStock = tempVariations.isNotEmpty 
                ? tempVariations.values.fold(0, (sum, val) => sum + val) 
                : (int.tryParse(stockController.text) ?? 0);

            return Padding(
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      component == null ? 'Novo Componente' : 'Editar Componente',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // FOTO
                    GestureDetector(
                      onTap: () => pickImage(setStateModal),
                      child: Container(
                        height: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                        child: imageController.text.isNotEmpty
                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(imageController.text, fit: BoxFit.cover, width: double.infinity))
                            : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: Colors.grey), SizedBox(height: 4), Text("Toque para adicionar foto", style: TextStyle(color: Colors.grey))]),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- DADOS GERAIS ---
                    _buildSectionTitle("Informações Básicas"),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome do Produto', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: descController, decoration: const InputDecoration(labelText: 'Descrição (Opcional)', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(
                      controller: linkController, 
                      decoration: const InputDecoration(
                        labelText: 'Link do Fornecedor (URL)', 
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                        hintText: 'http://...'
                      )
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: ['blank', 'cabo', 'reel_seat', 'passadores', 'acessorios'].contains(categoryController.text) ? categoryController.text : 'blank',
                      decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'blank', child: Text('Blank')),
                        DropdownMenuItem(value: 'cabo', child: Text('Cabo')),
                        DropdownMenuItem(value: 'reel_seat', child: Text('Reel Seat')),
                        DropdownMenuItem(value: 'passadores', child: Text('Passadores')),
                        DropdownMenuItem(value: 'acessorios', child: Text('Acessórios')),
                      ],
                      onChanged: (v) => categoryController.text = v!,
                    ),
                    const SizedBox(height: 24),

                    // --- PRECIFICAÇÃO (CORRIGIDO VISIBILIDADE) ---
                    _buildSectionTitle("Precificação Automática"),
                    Card(
                      elevation: 0,
                      color: Colors.grey[100], // Fundo levemente cinza para destacar o branco dos inputs
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[300]!)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // 1. INPUT FORNECEDOR (CORRIGIDO: STYLE BLACK)
                            TextField(
                              controller: tablePriceController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              // AQUI ESTÁ A CORREÇÃO: Forçando cor preta e negrito
                              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Preço Tabela Fornecedor',
                                prefixText: 'R\$ ',
                                suffixText: '(-${_globalSupplierDiscount.toStringAsFixed(0)}% desc.)',
                                border: const OutlineInputBorder(),
                                filled: true, fillColor: Colors.white,
                                labelStyle: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                              ),
                              onChanged: (val) => calculateCostFromTable(),
                            ),
                            
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Icon(Icons.arrow_downward, color: Colors.grey[500]),
                            ),

                            // 2. CUSTO REAL (Calculado)
                            TextField(
                              controller: costController,
                              keyboardType: TextInputType.number,
                              onChanged: (val) => calculateSalePrice(), 
                              // CORREÇÃO: Forçando cor preta
                              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(
                                labelText: 'Custo Real (Base)', 
                                prefixText: 'R\$ ',
                                border: OutlineInputBorder(),
                                filled: true, fillColor: Colors.white,
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, size: 16, color: Colors.green[700]),
                                  Text(" Margem Global (${_globalMargin.toStringAsFixed(0)}%) ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
                                  Icon(Icons.arrow_downward, size: 16, color: Colors.green[700]),
                                ],
                              ),
                            ),

                            // 3. VENDA FINAL (Destaque)
                            TextField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: Colors.green[900], fontWeight: FontWeight.w900, fontSize: 18),
                              decoration: InputDecoration(
                                labelText: 'Preço de Venda Final', 
                                prefixText: 'R\$ ',
                                border: OutlineInputBorder(borderSide: BorderSide(color: Colors.green[300]!, width: 2)),
                                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green[600]!, width: 2)),
                                filled: true, fillColor: Colors.green[50],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // --- ESTOQUE E VARIAÇÕES ---
                    _buildSectionTitle("Gestão de Estoque"),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!), 
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Column(
                        children: [
                          if (tempVariations.isEmpty)
                            // Modo Simples
                            Column(
                              children: [
                                TextField(
                                  controller: stockController, 
                                  keyboardType: TextInputType.number, 
                                  decoration: const InputDecoration(labelText: 'Quantidade Total', border: OutlineInputBorder())
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    _showAddVariationDialog(context, (name, qty) { setStateModal(() => tempVariations[name] = qty); });
                                  },
                                  icon: const Icon(Icons.list_alt),
                                  label: const Text("Converter para Variações (Tamanho/Cor)")
                                )
                              ],
                            )
                          else
                            // Modo Variações
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Variações Ativas", style: TextStyle(fontWeight: FontWeight.bold)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.blueGrey[100], borderRadius: BorderRadius.circular(4)),
                                      child: Text("Total: $currentTotalStock", style: TextStyle(color: Colors.blueGrey[900], fontWeight: FontWeight.bold))
                                    ),
                                  ],
                                ),
                                const Divider(),
                                ...tempVariations.entries.map((e) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(e.key, style: const TextStyle(fontSize: 15)),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle, size: 24, color: Colors.red), 
                                            onPressed: (){ setStateModal(() { if(e.value > 0) tempVariations[e.key] = e.value - 1; }); }
                                          ),
                                          Container(
                                            constraints: const BoxConstraints(minWidth: 35),
                                            alignment: Alignment.center,
                                            child: Text("${e.value}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle, size: 24, color: Colors.green), 
                                            onPressed: (){ setStateModal(() { tempVariations[e.key] = e.value + 1; }); }
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey), 
                                            onPressed: (){ setStateModal(() { tempVariations.remove(e.key); }); }
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                )).toList(),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _showAddVariationDialog(context, (name, qty) { setStateModal(() => tempVariations[name] = qty); });
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text("Adicionar Nova Variação")
                                )
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    
                    // BOTÃO SALVAR
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey[800], 
                        foregroundColor: Colors.white, 
                        padding: const EdgeInsets.symmetric(vertical: 16), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                      onPressed: () async {
                        final String name = nameController.text;
                        final String desc = descController.text;
                        final String link = linkController.text;
                        final double price = double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0;
                        final double cost = double.tryParse(costController.text.replaceAll(',', '.')) ?? 0;
                        final String cat = categoryController.text;
                        final String img = imageController.text;
                        
                        int stock = tempVariations.isNotEmpty ? tempVariations.values.fold(0, (sum, val) => sum + val) : (int.tryParse(stockController.text) ?? 0);

                        if (name.isEmpty) return;

                        final newComp = Component(
                          id: component?.id ?? '', 
                          name: name, 
                          description: desc, 
                          category: cat, 
                          price: price, 
                          costPrice: cost, 
                          stock: stock, 
                          imageUrl: img, 
                          supplierLink: link, 
                          variations: tempVariations, 
                          attributes: component?.attributes ?? {},
                        );

                        if (component == null) await _componentService.addComponent(newComp);
                        else await _componentService.updateComponent(newComp);

                        if (mounted) Navigator.pop(context);
                      },
                      child: Text(component == null ? 'CADASTRAR PRODUTO' : 'ATUALIZAR DADOS', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddVariationDialog(BuildContext context, Function(String, int) onAdd) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '0');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Nova Variação"),
      content: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nome (ex: Tam 16, Vermelho)")), 
          const SizedBox(height: 12),
          TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Quantidade Inicial"))
        ]
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: (){ 
            if(nameCtrl.text.isNotEmpty) { 
              onAdd(nameCtrl.text, int.tryParse(qtyCtrl.text) ?? 0); 
              Navigator.pop(ctx); 
            }
          }, 
          child: const Text("Adicionar")
        ),
      ],
    ));
  }

  void _deleteComponent(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Item?"),
        content: const Text("Esta ação é irreversível."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async { await _componentService.deleteComponent(id); if (mounted) Navigator.pop(ctx); },
            child: const Text("Excluir", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey[600], letterSpacing: 0.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // BARRA SUPERIOR
            Container(
              color: Colors.blueGrey[800],
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome...',
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
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        String key = _categories.keys.elementAt(index);
                        String label = _categories.values.elementAt(index);
                        bool isSelected = _selectedFilter == key;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedFilter = key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.amber[700] : Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: isSelected ? null : Border.all(color: Colors.white30),
                            ),
                            alignment: Alignment.center,
                            child: Text(label, style: TextStyle(color: isSelected ? Colors.blueGrey[900] : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // LISTA
            Expanded(
              child: StreamBuilder<List<Component>>(
                stream: _componentService.getComponentsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Catálogo vazio."));

                  final filteredList = snapshot.data!.where((c) {
                    bool matchesSearch = c.name.toLowerCase().contains(_searchQuery);
                    bool matchesCategory = _selectedFilter == 'todos' || c.category == _selectedFilter;
                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (filteredList.isEmpty) return const Center(child: Text("Nenhum item encontrado."));

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final comp = filteredList[index];
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                            child: comp.imageUrl.isNotEmpty 
                              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(comp.imageUrl, fit: BoxFit.cover))
                              : const Icon(Icons.image, color: Colors.grey),
                          ),
                          title: Text(comp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Estoque: ${comp.stock}", style: TextStyle(color: comp.stock < 5 ? Colors.red : Colors.grey[600], fontWeight: comp.stock < 5 ? FontWeight.bold : FontWeight.normal)),
                              Text("Venda: R\$ ${comp.price.toStringAsFixed(2)}"),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey), onPressed: () => _showComponentForm(component: comp)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteComponent(comp.id)),
                            ],
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showComponentForm(),
        backgroundColor: Colors.blueGrey[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}