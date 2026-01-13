import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:image_picker/image_picker.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:uuid/uuid.dart'; 
import '../../../models/component_model.dart';
import '../../../services/component_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/config_service.dart';
import '../../../utils/app_constants.dart';

class ComponentFormScreen extends StatefulWidget {
  final Component? component; 

  const ComponentFormScreen({super.key, this.component});

  @override
  State<ComponentFormScreen> createState() => _ComponentFormScreenState();
}

class _ComponentFormScreenState extends State<ComponentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final ComponentService _componentService = ComponentService();
  final StorageService _storageService = StorageService();
  final ConfigService _configService = ConfigService();

  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _supplierPriceController; 
  late TextEditingController _costPriceController;     
  late TextEditingController _priceController;         
  late TextEditingController _stockController;
  late TextEditingController _supplierLinkController;
  
  String? _selectedCategoryKey;

  // LISTA DE VARIAÇÕES (Estrutura interna UI)
  List<Map<String, dynamic>> _variationsUIList = [];

  String? _currentImageUrl; 
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  Uint8List? _newImageBytes; 
  String? _newImageExtension;

  double _defaultMargin = 0.0; 
  double _supplierDiscount = 0.0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.component?.name ?? '');
    _descController = TextEditingController(text: widget.component?.description ?? '');
    
    _supplierPriceController = TextEditingController(text: widget.component?.supplierPrice.toString() ?? '');
    _costPriceController = TextEditingController(text: widget.component?.costPrice.toString() ?? '');
    _priceController = TextEditingController(text: widget.component?.price.toString() ?? '');
    
    _stockController = TextEditingController(text: widget.component?.stock.toString() ?? '');
    _supplierLinkController = TextEditingController(text: widget.component?.supplierLink ?? '');
    
    _selectedCategoryKey = widget.component?.category;
    _currentImageUrl = widget.component?.imageUrl;

    // Carregar variações existentes com os novos campos
    if (widget.component != null) {
      for (var v in widget.component!.variations) {
        _variationsUIList.add({
          'id': v.id,
          'name': v.name,
          'stock': v.stock,
          'supplierPrice': v.supplierPrice, // NOVO
          'costPrice': v.costPrice,         // NOVO
          'price': v.price,
          'imageUrl': v.imageUrl,
          'newImageBytes': null,
          'newImageExt': null
        });
      }
    }

    _loadSettings();
    _supplierPriceController.addListener(_calculateCostPrice);
    _costPriceController.addListener(_calculateSellingPrice);
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _configService.getSettings();
      if (mounted) {
        setState(() {
          _defaultMargin = (settings['defaultMargin'] ?? 0.0).toDouble();
          _supplierDiscount = (settings['supplierDiscount'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      print("Erro config: $e");
    }
  }

  // --- CÁLCULOS TELA PRINCIPAL ---
  void _calculateCostPrice() {
    String supplierText = _supplierPriceController.text;
    if (supplierText.isEmpty) return;
    double supplierVal = double.tryParse(supplierText) ?? 0.0;
    double costVal = supplierVal * (1 - (_supplierDiscount / 100));
    String newText = costVal.toStringAsFixed(2);
    if (_costPriceController.text != newText) _costPriceController.text = newText;
  }

  void _calculateSellingPrice() {
    String costText = _costPriceController.text;
    if (costText.isEmpty) return;
    if (_defaultMargin <= 0) return; 
    double cost = double.tryParse(costText) ?? 0.0;
    double sellingPrice = cost * (1 + (_defaultMargin / 100));
    String newText = sellingPrice.toStringAsFixed(2);
    if (_priceController.text != newText) _priceController.text = newText;
  }

  // --- UPLOAD E LINKS ---
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
      if (image != null) {
        final bytes = await image.readAsBytes();
        final ext = image.name.split('.').last;
        setState(() {
          _newImageBytes = bytes;
          _newImageExtension = ext.isEmpty ? 'jpg' : ext;
          _currentImageUrl = null; 
        });
      }
    } catch (e) { print(e); }
  }

  Future<void> _launchSupplierLink() async {
    final String url = _supplierLinkController.text;
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link.')));
      }
    }
  }

  void _updateTotalStock() {
    int total = 0;
    for (var v in _variationsUIList) {
      total += (v['stock'] as int);
    }
    if (_variationsUIList.isNotEmpty) {
      _stockController.text = total.toString();
    }
  }

  // --- DIALOG DE VARIAÇÕES (COM PRECIFICAÇÃO COMPLETA) ---
  void _openVariationDialog({int? index}) {
    final isEditing = index != null;
    final Map<String, dynamic> currentData = isEditing 
        ? _variationsUIList[index] 
        : {
            'name': '', 
            'stock': 0, 
            'supplierPrice': 0.0, 
            'costPrice': 0.0, 
            'price': 0.0, 
            'imageUrl': null, 
            'newImageBytes': null
          };

    // Controladores
    final nameCtrl = TextEditingController(text: currentData['name']);
    final stockCtrl = TextEditingController(text: currentData['stock'].toString());
    
    // Inicializa preços com 0.0 ou valor existente
    final supplierCtrl = TextEditingController(text: (currentData['supplierPrice'] as double).toStringAsFixed(2));
    final costCtrl = TextEditingController(text: (currentData['costPrice'] as double).toStringAsFixed(2));
    final priceCtrl = TextEditingController(text: (currentData['price'] as double).toStringAsFixed(2));

    // Imagem
    Uint8List? dialogImageBytes = currentData['newImageBytes'];
    String? dialogImageUrl = currentData['imageUrl'];
    String? dialogImageExt = currentData['newImageExt'];

    // --- Lógica de Cálculo Interna do Dialog ---
    void calcVarCost() {
      double supplier = double.tryParse(supplierCtrl.text.replaceAll(',', '.')) ?? 0.0;
      double cost = supplier * (1 - (_supplierDiscount / 100));
      costCtrl.text = cost.toStringAsFixed(2);
    }

    void calcVarSell() {
      double cost = double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0.0;
      if (_defaultMargin > 0) {
        double sell = cost * (1 + (_defaultMargin / 100));
        priceCtrl.text = sell.toStringAsFixed(2);
      }
    }

    // Adiciona Listeners
    supplierCtrl.addListener(() { calcVarCost(); calcVarSell(); });
    costCtrl.addListener(() { calcVarSell(); });

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            Future<void> pickVarImage() async {
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 80);
              if (image != null) {
                final bytes = await image.readAsBytes();
                final ext = image.name.split('.').last;
                setStateDialog(() {
                  dialogImageBytes = bytes;
                  dialogImageExt = ext;
                  dialogImageUrl = null;
                });
              }
            }

            return AlertDialog(
              title: Text(isEditing ? 'Editar Variação' : 'Nova Variação'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Imagem
                    GestureDetector(
                      onTap: pickVarImage,
                      child: Container(
                        height: 80, width: 80,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[400]!)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: dialogImageBytes != null 
                              ? Image.memory(dialogImageBytes!, fit: BoxFit.cover)
                              : (dialogImageUrl != null ? Image.network(dialogImageUrl!, fit: BoxFit.cover) : const Icon(Icons.add_a_photo, color: Colors.grey)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome / Cor', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 12),
                    TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estoque (Qtd)', border: OutlineInputBorder(), isDense: true)),
                    
                    const SizedBox(height: 12),
                    const Divider(),
                    const Text("Precificação Específica (Opcional)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Expanded(child: TextField(controller: supplierCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tabela', border: OutlineInputBorder(), isDense: true))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Custo', border: OutlineInputBorder(), isDense: true))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Venda', border: OutlineInputBorder(), isDense: true)),
                    
                    const SizedBox(height: 4),
                    const Text(
                      "Se deixar os preços zerados, o sistema usará o preço do componente principal.",
                      style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isEmpty) return;
                    
                    final newData = {
                      'id': isEditing ? currentData['id'] : const Uuid().v4(),
                      'name': nameCtrl.text,
                      'stock': int.tryParse(stockCtrl.text) ?? 0,
                      
                      // NOVOS CAMPOS
                      'supplierPrice': double.tryParse(supplierCtrl.text.replaceAll(',', '.')) ?? 0.0,
                      'costPrice': double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0.0,
                      'price': double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0,
                      
                      'imageUrl': dialogImageUrl,
                      'newImageBytes': dialogImageBytes,
                      'newImageExt': dialogImageExt,
                    };

                    setState(() {
                      if (isEditing) {
                        _variationsUIList[index] = newData;
                      } else {
                        _variationsUIList.add(newData);
                      }
                      _updateTotalStock();
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Salvar'),
                )
              ],
            );
          }
        );
      },
    );
  }

  void _removeVariation(int index) {
    setState(() {
      _variationsUIList.removeAt(index);
      _updateTotalStock();
    });
  }

  Future<void> _saveComponent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });

    try {
      // 1. Upload Imagem Principal
      String mainImageUrl = _currentImageUrl ?? '';
      if (_newImageBytes != null && _newImageExtension != null) {
        setState(() => _uploadProgress = 0.1);
        final res = await _storageService.uploadImage(
          fileBytes: _newImageBytes!, 
          fileName: _nameController.text, 
          fileExtension: _newImageExtension!, 
          onProgress: (p) => setState(() => _uploadProgress = p * 0.5)
        );
        if (res != null) mainImageUrl = res.downloadUrl;
      }

      // 2. Processar Variações
      List<ComponentVariation> finalVariations = [];
      
      for (var i = 0; i < _variationsUIList.length; i++) {
        var vData = _variationsUIList[i];
        String? varImgUrl = vData['imageUrl'];
        
        if (vData['newImageBytes'] != null) {
           final res = await _storageService.uploadImage(
             fileBytes: vData['newImageBytes'],
             fileName: "${_nameController.text}_var_$i",
             fileExtension: vData['newImageExt'] ?? 'jpg',
             onProgress: (_) {} 
           );
           if (res != null) varImgUrl = res.downloadUrl;
        }

        finalVariations.add(ComponentVariation(
          id: vData['id'] ?? const Uuid().v4(),
          name: vData['name'],
          stock: vData['stock'],
          
          // SALVA OS PREÇOS INDIVIDUAIS
          supplierPrice: (vData['supplierPrice'] ?? 0.0),
          costPrice: (vData['costPrice'] ?? 0.0),
          price: (vData['price'] ?? 0.0),
          
          imageUrl: varImgUrl,
        ));
      }

      int finalStock = finalVariations.isNotEmpty 
          ? finalVariations.fold(0, (sum, v) => sum + v.stock)
          : (int.tryParse(_stockController.text) ?? 0);

      final component = Component(
        id: widget.component?.id ?? '',
        name: _nameController.text,
        description: _descController.text,
        category: _selectedCategoryKey ?? AppConstants.catBlank,
        supplierPrice: double.tryParse(_supplierPriceController.text) ?? 0.0,
        costPrice: double.tryParse(_costPriceController.text) ?? 0.0,
        price: double.tryParse(_priceController.text) ?? 0.0,
        stock: finalStock,
        imageUrl: mainImageUrl,
        attributes: widget.component?.attributes ?? {},
        supplierLink: _supplierLinkController.text,
        variations: finalVariations,
      );

      if (widget.component == null) {
        await _componentService.addComponent(component);
      } else {
        await _componentService.updateComponent(component);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() { _isLoading = false; _isUploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.component == null ? 'Novo Componente' : 'Editar Componente')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImagePreview(),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.upload_file),
                label: const Text('Imagem Principal'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black87),
              ),
              if (_isUploading) LinearProgressIndicator(value: _uploadProgress),
              
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedCategoryKey,
                hint: const Text('Categoria'),
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Categoria'),
                items: AppConstants.categoryLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setState(() => _selectedCategoryKey = v),
                validator: (v) => v == null ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _descController, decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder()), maxLines: 2),

              const SizedBox(height: 24),
              const Text("Preço Base (Padrão)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _supplierPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tabela (R\$)', border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(controller: _costPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Custo (R\$)', border: OutlineInputBorder(), filled: true))),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(controller: _priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Venda (R\$)', border: OutlineInputBorder(), filled: true))),
                ],
              ),

              const Divider(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Variações (Cor/Tipo)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton.icon(onPressed: () => _openVariationDialog(), icon: const Icon(Icons.add), label: const Text("Adicionar"))
                ],
              ),
              const SizedBox(height: 8),

              if (_variationsUIList.isEmpty)
                TextFormField(
                  controller: _stockController, 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(labelText: 'Estoque Total (Sem Variação)', border: OutlineInputBorder()),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly]
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _variationsUIList.length,
                  separatorBuilder: (_,__) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _variationsUIList[index];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                          child: item['newImageBytes'] != null 
                              ? Image.memory(item['newImageBytes'], fit: BoxFit.cover)
                              : (item['imageUrl'] != null ? Image.network(item['imageUrl'], fit: BoxFit.cover) : const Icon(Icons.image)),
                        ),
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        // Mostra resumo do preço
                        subtitle: Text("Qtd: ${item['stock']} | Venda: R\$ ${item['price'].toStringAsFixed(2)}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blueGrey), onPressed: () => _openVariationDialog(index: index)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeVariation(index)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              
              if (_variationsUIList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("Total Estoque: ${_stockController.text}", textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),

              const SizedBox(height: 24),
              TextFormField(
                controller: _supplierLinkController,
                decoration: const InputDecoration(
                  labelText: 'Link do Fornecedor', 
                  border: OutlineInputBorder(), 
                  suffixIcon: Icon(Icons.link)
                ),
              ),
              if (_supplierLinkController.text.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _launchSupplierLink, 
                    icon: const Icon(Icons.open_in_new, size: 16), 
                    label: const Text('Testar Link')
                  ),
                ),

              const SizedBox(height: 32),
              _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : ElevatedButton(
                    onPressed: _saveComponent, 
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueGrey[800], foregroundColor: Colors.white),
                    child: const Text('SALVAR COMPONENTE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
     return Container(
       height: 180, 
       width: double.infinity,
       decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[400]!)),
       child: ClipRRect(
         borderRadius: BorderRadius.circular(12),
         child: _newImageBytes != null 
          ? Image.memory(_newImageBytes!, fit: BoxFit.cover)
          : (_currentImageUrl != null ? Image.network(_currentImageUrl!, fit: BoxFit.cover) : const Center(child: Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey))),
       ),
     );
  }
}