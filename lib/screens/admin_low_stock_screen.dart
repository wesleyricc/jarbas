import 'package:flutter/material.dart';
import '../models/component_model.dart';
import '../services/component_service.dart';
import '../services/storage_service.dart'; // Necessário para imagem, se for editar

class AdminLowStockScreen extends StatefulWidget {
  const AdminLowStockScreen({super.key});

  @override
  State<AdminLowStockScreen> createState() => _AdminLowStockScreenState();
}

class _AdminLowStockScreenState extends State<AdminLowStockScreen> {
  final ComponentService _componentService = ComponentService();
  final StorageService _storageService = StorageService(); // Para o formulário
  int _threshold = 3; // Limite padrão

  // --- LÓGICA DE EDIÇÃO (Formulário Completo) ---
  
  void _showComponentForm(Component component) {
    // Controladores preenchidos com os dados atuais
    final nameController = TextEditingController(text: component.name);
    final descController = TextEditingController(text: component.description);
    final categoryController = TextEditingController(text: component.category);
    final priceController = TextEditingController(text: component.price.toString());
    final costController = TextEditingController(text: component.costPrice.toString());
    final stockController = TextEditingController(text: component.stock.toString());
    final imageController = TextEditingController(text: component.imageUrl);

    Map<String, int> tempVariations = Map<String, int>.from(component.variations);

    // Helper de imagem
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
                      'Editar: ${component.name}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Imagem
                    GestureDetector(
                      onTap: () => pickImage(setStateModal),
                      child: Container(
                        height: 100,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                        child: imageController.text.isNotEmpty
                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(imageController.text, fit: BoxFit.cover, width: double.infinity))
                            : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: Colors.grey), SizedBox(height: 4), Text("Foto", style: TextStyle(color: Colors.grey))]),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Campos principais
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder())),
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
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: TextField(controller: costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Custo (R\$)', border: OutlineInputBorder()))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Venda (R\$)', border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Gestão de Estoque (Foco Principal desta tela)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        border: Border.all(color: Colors.amber), 
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Column(
                        children: [
                          Row(children: [Icon(Icons.inventory, color: Colors.amber[900], size: 20), const SizedBox(width: 8), Text("Ajuste de Estoque", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[900]))]),
                          const SizedBox(height: 12),
                          if (tempVariations.isEmpty)
                            TextField(controller: stockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estoque Total', border: OutlineInputBorder(), filled: true, fillColor: Colors.white))
                          else
                            Column(
                              children: [
                                ...tempVariations.entries.map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Row(
                                        children: [
                                          IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: (){ setStateModal(() { if(e.value > 0) tempVariations[e.key] = e.value - 1; }); }),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey[300]!)),
                                            child: Text("${e.value}", style: const TextStyle(fontWeight: FontWeight.bold))
                                          ),
                                          IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: (){ setStateModal(() { tempVariations[e.key] = e.value + 1; }); }),
                                        ],
                                      )
                                    ],
                                  ),
                                )).toList(),
                                TextButton.icon(
                                  onPressed: () {
                                    _showAddVariationDialog(context, (name, qty) { setStateModal(() => tempVariations[name] = qty); });
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text("Nova Variação")
                                )
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () async {
                        final String name = nameController.text;
                        final String desc = descController.text;
                        final double price = double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0;
                        final double cost = double.tryParse(costController.text.replaceAll(',', '.')) ?? 0;
                        final String cat = categoryController.text;
                        final String img = imageController.text;
                        // Recalcula estoque total
                        int stock = tempVariations.isNotEmpty ? tempVariations.values.fold(0, (sum, val) => sum + val) : (int.tryParse(stockController.text) ?? 0);

                        if (name.isEmpty) return;

                        final newComp = Component(
                          id: component.id, // Mantém ID
                          name: name, description: desc, category: cat, price: price, costPrice: cost, stock: stock, imageUrl: img, variations: tempVariations, attributes: component.attributes,
                        );

                        await _componentService.updateComponent(newComp);

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Estoque atualizado!"), backgroundColor: Colors.green));
                        }
                      },
                      child: const Text('SALVAR ALTERAÇÕES', style: TextStyle(fontWeight: FontWeight.bold)),
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
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nome (ex: #5, 12mm)")), TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Quantidade Inicial"))]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
        TextButton(onPressed: (){ if(nameCtrl.text.isNotEmpty) { onAdd(nameCtrl.text, int.tryParse(qtyCtrl.text) ?? 0); Navigator.pop(ctx); }}, child: const Text("Adicionar")),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Alerta de Estoque"),
        backgroundColor: Colors.amber[800], // Cor de alerta
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filtro de Limite
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.filter_alt, color: Colors.blueGrey[700]),
                const SizedBox(width: 8),
                const Text("Exibir itens com estoque abaixo de: ", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _threshold,
                  underline: Container(height: 2, color: Colors.amber),
                  style: TextStyle(color: Colors.blueGrey[900], fontWeight: FontWeight.bold),
                  items: [1, 3, 5, 10, 20].map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _threshold = val);
                  },
                )
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<Component>>(
              stream: _componentService.getLowStockComponentsStream(threshold: _threshold),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
                        const SizedBox(height: 16),
                        Text("Tudo certo!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
                        Text("Nenhum item abaixo de $_threshold unidades.", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final comp = items[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          width: 50, height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.warning_amber_rounded, color: Colors.red[800], size: 28),
                        ),
                        title: Text(comp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text("Estoque Atual: ${comp.stock}", style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
                          tooltip: "Editar Estoque",
                          onPressed: () => _showComponentForm(comp), // <--- CHAMADA CORRIGIDA
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
    );
  }
}