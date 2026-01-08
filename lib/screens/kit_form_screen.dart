import 'package:flutter/material.dart';
import '../models/kit_model.dart';
import '../models/component_model.dart';
import '../services/kit_service.dart';
import '../services/storage_service.dart'; // Se não tiver upload de imagem, pode remover
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
  
  // Se você não tiver o StorageService implementado, pode comentar as partes de imagem
  final StorageService _storageService = StorageService(); 

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // Listas de componentes selecionados
  final List<Map<String, dynamic>> _selBlanks = [];
  final List<Map<String, dynamic>> _selCabos = [];
  final List<Map<String, dynamic>> _selReelSeats = [];
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

    Future<void> loadList(List<Map<String, dynamic>> source, List<Map<String, dynamic>> dest) async {
      for(var item in source) {
        final c = await _kitService.getComponentById(item['id']);
        if(c != null) dest.add({'comp': c, 'var': item['variation'], 'qty': item['quantity']});
      }
    }

    await loadList(k.blanksIds, _selBlanks);
    await loadList(k.cabosIds, _selCabos);
    await loadList(k.reelSeatsIds, _selReelSeats);
    await loadList(k.passadoresIds, _selPassadores);
    await loadList(k.acessoriosIds, _selAcessorios);

    setState(() => _isLoading = false);
  }

  // --- CORREÇÃO AQUI ---
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Selecionar $category", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const Divider(height: 1),
              
              Expanded(
                child: ComponentSelector(
                  category: category,
                  isAdmin: true,
                  // REMOVIDO: selectedComponent: null
                  
                  // ADICIONADO: Lógica de Multi Seleção
                  onMultiSelectConfirm: (selectedList) {
                    for (var item in selectedList) {
                      // Chama a função onSelect para cada item retornado
                      onSelect(item['comp'], item['var']);
                    }
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    // Se não tiver StorageService, remova este bloco ou adapte
    try {
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
    } catch (e) {
      print("Erro upload: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validação mínima: Kit precisa ter ao menos o básico
    if (_selBlanks.isEmpty || _selCabos.isEmpty || _selReelSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione pelo menos 1 Blank, 1 Cabo e 1 Reel Seat.')));
      return;
    }

    setState(() => _isLoading = true);

    List<Map<String, dynamic>> convert(List<Map<String, dynamic>> uiList) {
      return uiList.map((e) => {
        'id': (e['comp'] as Component).id,
        'variation': e['var'],
        'quantity': e['qty']
      }).toList();
    }

    final kit = KitModel(
      id: widget.kit?.id ?? '',
      name: _nameController.text,
      description: _descController.text,
      imageUrls: _imageUrls,
      blanksIds: convert(_selBlanks),
      cabosIds: convert(_selCabos),
      reelSeatsIds: convert(_selReelSeats),
      passadoresIds: convert(_selPassadores),
      acessoriosIds: convert(_selAcessorios),
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
              const Text("Componentes do Kit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey)),
              const SizedBox(height: 16),

              // SEÇÕES DE LISTA
              _buildListSection('Blanks', 'blank', _selBlanks),
              const SizedBox(height: 24),
              _buildListSection('Cabos', 'cabo', _selCabos),
              const SizedBox(height: 24),
              _buildListSection('Reel Seats', 'reel_seat', _selReelSeats),
              const SizedBox(height: 24),
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

  Widget _buildListSection(String title, String cat, List<Map<String, dynamic>> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
            TextButton.icon(
              icon: const Icon(Icons.add, color: Colors.blueGrey),
              label: const Text("Adicionar", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              // Passa a função que adiciona UM item na lista local
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
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: comp.imageUrl.isNotEmpty
              ? Image.network(comp.imageUrl, width: 40, height: 40, fit: BoxFit.cover)
              : Container(width: 40, height: 40, color: Colors.grey[200], child: const Icon(Icons.image, size: 20, color: Colors.grey)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                if (variation != null) Text(variation, style: TextStyle(color: Colors.blueGrey[600], fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
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