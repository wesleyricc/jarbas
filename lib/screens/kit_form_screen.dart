import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/kit_model.dart';
import '../models/component_model.dart';
import '../services/kit_service.dart';
import '../services/storage_service.dart';
import '../widgets/component_selector.dart';

class KitFormScreen extends StatefulWidget {
  final KitModel? kit;
  const KitFormScreen({super.key, this.kit});

  @override
  State<KitFormScreen> createState() => _KitFormScreenState();
}

class _KitFormScreenState extends State<KitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final KitService _kitService = KitService();
  final StorageService _storageService = StorageService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // Seleções Únicas
  Component? _selBlank; String? _varBlank;
  Component? _selCabo; String? _varCabo; int _qtyCabo = 1; // Quantidade do Cabo
  Component? _selReel; String? _varReel;
  
  // Listas (Guardam {component, variation, quantity})
  final List<Map<String, dynamic>> _selPassadores = []; 
  final List<Map<String, dynamic>> _selAcessorios = [];

  List<String> _imageUrls = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.kit != null) {
      _loadExistingKit();
    }
  }

  Future<void> _loadExistingKit() async {
    setState(() => _isLoading = true);
    final k = widget.kit!;
    _nameController.text = k.name;
    _descController.text = k.description;
    _imageUrls = List.from(k.imageUrls);

    _selBlank = await _kitService.getComponentById(k.blankId);
    _varBlank = k.blankVariation;
    
    _selCabo = await _kitService.getComponentById(k.caboId);
    _varCabo = k.caboVariation;
    _qtyCabo = k.caboQuantity;
    
    _selReel = await _kitService.getComponentById(k.reelSeatId);
    _varReel = k.reelSeatVariation;

    // Carregar Listas
    for(var item in k.passadoresIds) {
      final c = await _kitService.getComponentById(item['id']);
      if(c!=null) _selPassadores.add({'comp': c, 'var': item['variation'], 'qty': item['quantity']});
    }
    for(var item in k.acessoriosIds) {
      final c = await _kitService.getComponentById(item['id']);
      if(c!=null) _selAcessorios.add({'comp': c, 'var': item['variation'], 'qty': item['quantity']});
    }

    setState(() => _isLoading = false);
  }

  // Helpers de UI
  void _openSelector(String category, Function(Component, String?) onSelect) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  child: ComponentSelector(
                    category: category,
                    selectedComponent: null,
                    isAdmin: true,
                    onSelect: (c, v) {
                      if (c != null) onSelect(c, v);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final res = await _storageService.pickImageForPreview();
    if (res != null) {
      setState(() => _isLoading = true);
      final upload = await _storageService.uploadImage(
        fileBytes: res.bytes, 
        fileName: 'kit_${DateTime.now().millisecondsSinceEpoch}', 
        fileExtension: res.extension, 
        onProgress: (_){}
      );
      if (upload != null) {
        setState(() => _imageUrls.add(upload.downloadUrl));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selBlank == null || _selCabo == null || _selReel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione Blank, Cabo e Reel Seat.')));
      return;
    }

    setState(() => _isLoading = true);

    // Converte listas de objetos para listas de IDs/Maps
    List<Map<String, dynamic>> passList = _selPassadores.map((e) => {
      'id': (e['comp'] as Component).id,
      'variation': e['var'],
      'quantity': e['qty']
    }).toList();

    List<Map<String, dynamic>> acessList = _selAcessorios.map((e) => {
      'id': (e['comp'] as Component).id,
      'variation': e['var'],
      'quantity': e['qty']
    }).toList();

    final kit = KitModel(
      id: widget.kit?.id ?? '',
      name: _nameController.text,
      description: _descController.text,
      imageUrls: _imageUrls,
      blankId: _selBlank!.id,
      blankVariation: _varBlank,
      caboId: _selCabo!.id,
      caboVariation: _varCabo,
      caboQuantity: _qtyCabo,
      reelSeatId: _selReel!.id,
      reelSeatVariation: _varReel,
      passadoresIds: passList,
      acessoriosIds: acessList,
    );

    await _kitService.saveKit(kit);
    if(mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.kit == null ? 'Novo Kit' : 'Editar Kit')),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Fotos
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 80, 
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.add_a_photo, color: Colors.grey),
                      ),
                    ),
                    ..._imageUrls.map((url) => Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Stack(
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, width: 80, height: 100, fit: BoxFit.cover)),
                          Positioned(right: 0, child: InkWell(
                            onTap: () => setState(() => _imageUrls.remove(url)),
                            child: const CircleAvatar(backgroundColor: Colors.white, radius: 10, child: Icon(Icons.close, color: Colors.red, size: 16)),
                          ))
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // 2. Dados Básicos
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome do Kit', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _descController, decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder()), maxLines: 2),
              
              const Divider(height: 32),
              const Text("Componentes Principais", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey)),
              const SizedBox(height: 16),
              
              // BLANK
              _buildSelectorTile(
                title: 'Blank', 
                comp: _selBlank, 
                variation: _varBlank, 
                onTap: () => _openSelector('blank', (c, v) => setState((){ _selBlank=c; _varBlank=v; }))
              ),
              
              const SizedBox(height: 12),

              // CABO (Com quantidade)
              _buildSelectorTile(
                title: 'Cabo', 
                comp: _selCabo, 
                variation: _varCabo, 
                qty: _qtyCabo,
                onQtyChanged: (val) => setState(() => _qtyCabo = val),
                onTap: () => _openSelector('cabo', (c, v) => setState((){ _selCabo=c; _varCabo=v; }))
              ),

              const SizedBox(height: 12),

              // REEL SEAT
              _buildSelectorTile(
                title: 'Reel Seat', 
                comp: _selReel, 
                variation: _varReel, 
                onTap: () => _openSelector('reel_seat', (c, v) => setState((){ _selReel=c; _varReel=v; }))
              ),

              const Divider(height: 32),
              
              // 3. Listas (Passadores e Acessórios)
              _buildListSection('Passadores', 'passadores', _selPassadores),
              const SizedBox(height: 24),
              _buildListSection('Acessórios', 'acessorios', _selAcessorios),

              const SizedBox(height: 48),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[800], foregroundColor: Colors.white),
                  onPressed: _save, 
                  child: const Text('SALVAR KIT', style: TextStyle(fontWeight: FontWeight.bold))
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildSelectorTile({
    required String title, 
    Component? comp, 
    String? variation, 
    int? qty,
    Function(int)? onQtyChanged,
    required VoidCallback onTap
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey[200]!), // Borda com mais contraste
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            // TÍTULO: Cor Azul Escuro (Padrão)
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
            // SUBTÍTULO: Preto Forte
            subtitle: Text(
              comp == null ? 'Toque para selecionar' : '${comp.name}${variation!=null?" ($variation)":""}',
              style: TextStyle(
                fontSize: 16, 
                color: comp == null ? Colors.grey[500] : Colors.black87, 
                fontWeight: comp != null ? FontWeight.w600 : FontWeight.normal
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.blueGrey),
            onTap: onTap,
          ),
          if (comp != null && qty != null && onQtyChanged != null) ...[
            const Divider(height: 1, color: Colors.grey),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Quantidade:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.blueGrey), 
                        onPressed: () { if(qty > 1) onQtyChanged(qty - 1); },
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87))),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.blueGrey), 
                        onPressed: () => onQtyChanged(qty + 1),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  )
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildListSection(String title, String cat, List<Map<String, dynamic>> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey)),
            TextButton.icon(
              icon: const Icon(Icons.add, color: Colors.blueGrey), 
              label: const Text("Adicionar", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              onPressed: () => _openSelector(cat, (c, v) => setState(() => list.add({'comp': c, 'var': v, 'qty': 1})))
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (list.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, 
              border: Border.all(color: Colors.blueGrey[100]!),
              borderRadius: BorderRadius.circular(8)
            ),
            child: Text("Nenhum item adicionado.", style: TextStyle(color: Colors.blueGrey[300]), textAlign: TextAlign.center),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (c, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = list[index];
              return _buildEditableListTile(item, () => setState(() => list.removeAt(index)));
            },
          ),
      ],
    );
  }

  Widget _buildEditableListTile(Map<String, dynamic> item, VoidCallback onRemove) {
    final comp = item['comp'] as Component;
    final qty = item['qty'] as int;
    final variation = item['var'] as String?;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(8), 
        border: Border.all(color: Colors.blueGrey[200]!)
      ),
      child: Row(
        children: [
          // Imagem
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: comp.imageUrl.isNotEmpty 
              ? Image.network(comp.imageUrl, width: 40, height: 40, fit: BoxFit.cover) 
              : Container(width: 40, height: 40, color: Colors.grey[200], child: const Icon(Icons.image, size: 20, color: Colors.grey)),
          ),
          const SizedBox(width: 12),
          // Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                if (variation != null) Text(variation, style: TextStyle(color: Colors.blueGrey[600], fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Quantidade
          Row(
            children: [
              InkWell(
                onTap: () => setState(() { if(qty > 1) item['qty'] = qty - 1; }),
                child: const Icon(Icons.remove, size: 20, color: Colors.grey),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
              ),
              InkWell(
                onTap: () => setState(() { item['qty'] = qty + 1; }),
                child: const Icon(Icons.add, size: 20, color: Colors.blueGrey),
              ),
            ],
          ),
          const SizedBox(width: 12),
          InkWell(onTap: onRemove, child: const Icon(Icons.delete_outline, color: Colors.red)),
        ],
      ),
    );
  }
}