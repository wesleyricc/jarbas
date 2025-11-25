import 'dart:typed_data'; // Para Uint8List (essencial para Web)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para InputFormatters
import 'package:image_picker/image_picker.dart'; // Importe o ImagePicker
import 'package:url_launcher/url_launcher.dart'; // Para abrir links
import '../../../models/component_model.dart';
import '../../../services/component_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/config_service.dart';

class ComponentFormScreen extends StatefulWidget {
  final Component? component; // Se nulo = Adicionar, Se existe = Editar

  const ComponentFormScreen({super.key, this.component});

  @override
  State<ComponentFormScreen> createState() => _ComponentFormScreenState();
}

class _ComponentFormScreenState extends State<ComponentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Serviços
  final ComponentService _componentService = ComponentService();
  final StorageService _storageService = StorageService();
  final ConfigService _configService = ConfigService();

  bool _isLoading = false;

  // Controladores de Texto
  late TextEditingController _nameController;
  late TextEditingController _descController;
  
  // Controladores de Preço
  late TextEditingController _supplierPriceController; 
  late TextEditingController _costPriceController;     
  late TextEditingController _priceController;         
  
  late TextEditingController _stockController;
  late TextEditingController _supplierLinkController;
  
  String? _selectedCategoryKey;

  // Variações (Lista Local)
  List<Map<String, TextEditingController>> _variationsControllers = [];

  // Estado da Imagem
  String? _currentImageUrl; 
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  Uint8List? _newImageBytes; 
  String? _newImageExtension;

  // Configurações Globais
  double _defaultMargin = 0.0; 
  double _supplierDiscount = 0.0;

  // Mapa de categorias
  final Map<String, String> _categoriesMap = {
    'blank': 'Blank',
    'cabo': 'Cabo',
    'passadores': 'Passadores',
    'reel_seat': 'Reel Seat',
    'acessorios': 'Acessórios'
  };

  @override
  void initState() {
    super.initState();
    // Inicializa os controladores
    _nameController = TextEditingController(text: widget.component?.name ?? '');
    _descController = TextEditingController(text: widget.component?.description ?? '');
    
    _supplierPriceController = TextEditingController(text: widget.component?.supplierPrice.toString() ?? '');
    _costPriceController = TextEditingController(text: widget.component?.costPrice.toString() ?? '');
    _priceController = TextEditingController(text: widget.component?.price.toString() ?? '');
    
    _stockController = TextEditingController(text: widget.component?.stock.toString() ?? '');
    _supplierLinkController = TextEditingController(text: widget.component?.supplierLink ?? '');
    
    _selectedCategoryKey = widget.component?.category;
    _currentImageUrl = widget.component?.imageUrl;

    // 1. Carrega as Variações Existentes
    if (widget.component != null && widget.component!.variations.isNotEmpty) {
      widget.component!.variations.forEach((key, value) {
        _variationsControllers.add({
          'name': TextEditingController(text: key),
          'stock': TextEditingController(text: value.toString()),
        });
      });
    }

    // 2. Carrega Configurações e Adiciona Listeners
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
      print("Erro ao carregar config: $e");
    }
  }

  // --- LÓGICA DE PREÇO ---

  void _calculateCostPrice() {
    String supplierText = _supplierPriceController.text;
    if (supplierText.isEmpty) return;

    double supplierVal = double.tryParse(supplierText) ?? 0.0;
    double costVal = supplierVal * (1 - (_supplierDiscount / 100));

    String newText = costVal.toStringAsFixed(2);
    if (_costPriceController.text != newText) {
      _costPriceController.text = newText;
    }
  }

  void _calculateSellingPrice() {
    String costText = _costPriceController.text;
    if (costText.isEmpty) return;
    if (_defaultMargin <= 0) return; 

    double cost = double.tryParse(costText) ?? 0.0;
    double sellingPrice = cost * (1 + (_defaultMargin / 100));

    String newText = sellingPrice.toStringAsFixed(2);
    if (_priceController.text != newText) {
      _priceController.text = newText;
    }
  }

  // --- LÓGICA DE VARIAÇÕES ---
  
  void _updateTotalStock() {
    if (_variationsControllers.isEmpty) return;
    
    int total = 0;
    for (var v in _variationsControllers) {
      int qtd = int.tryParse(v['stock']!.text) ?? 0;
      total += qtd;
    }
    _stockController.text = total.toString();
  }

  void _addVariationRow() {
    setState(() {
      final stockCtrl = TextEditingController(text: '0');
      stockCtrl.addListener(() => _updateTotalStock());

      _variationsControllers.add({
        'name': TextEditingController(),
        'stock': stockCtrl,
      });
    });
  }

  void _removeVariationRow(int index) {
    setState(() {
      _variationsControllers[index]['name']?.dispose();
      _variationsControllers[index]['stock']?.dispose();
      _variationsControllers.removeAt(index);
      _updateTotalStock(); 
    });
  }

  @override
  void dispose() {
    _supplierPriceController.removeListener(_calculateCostPrice);
    _costPriceController.removeListener(_calculateSellingPrice);
    
    _nameController.dispose();
    _descController.dispose();
    _supplierPriceController.dispose();
    _costPriceController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _supplierLinkController.dispose();
    
    for (var v in _variationsControllers) {
      v['name']?.dispose();
      v['stock']?.dispose();
    }
    
    super.dispose();
  }

  // --- IMAGEM ---

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, 
        imageQuality: 85, 
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final ext = image.name.split('.').last;

        setState(() {
          _newImageBytes = bytes;
          _newImageExtension = ext.isEmpty ? 'jpg' : ext;
          _currentImageUrl = null; 
        });
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro na imagem: $e')));
    }
  }

  Future<void> _launchSupplierLink() async {
    final String url = _supplierLinkController.text;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha o link primeiro.')));
      return;
    }
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir link: $url')));
    }
  }

  // --- SALVAR ---

  Future<void> _saveComponent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; });

    String imageUrlToSave = _currentImageUrl ?? '';
    String? oldImageUrl = widget.component?.imageUrl;

    try {
      if (_newImageBytes != null && _newImageExtension != null) {
        setState(() { _isUploading = true; _uploadProgress = 0.0; });
        
        final UploadResult? result = await _storageService.uploadImage(
          fileBytes: _newImageBytes!,
          fileName: _nameController.text.isNotEmpty ? _nameController.text : 'component',
          fileExtension: _newImageExtension!,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );

        if (result != null) {
          imageUrlToSave = result.downloadUrl;
          if (oldImageUrl != null && oldImageUrl.isNotEmpty && oldImageUrl != imageUrlToSave) {
            await _storageService.deleteImage(oldImageUrl);
          }
        }
        setState(() { _isUploading = false; });
      }

      Map<String, int> variationsMap = {};
      for (var v in _variationsControllers) {
        String name = v['name']!.text.trim();
        int qty = int.tryParse(v['stock']!.text) ?? 0;
        if (name.isNotEmpty) {
          variationsMap[name] = qty;
        }
      }

      int finalStock = variationsMap.isNotEmpty 
          ? variationsMap.values.fold(0, (sum, item) => sum + item)
          : (int.tryParse(_stockController.text) ?? 0);

      final component = Component(
        id: widget.component?.id ?? '',
        name: _nameController.text,
        description: _descController.text,
        category: _selectedCategoryKey!,
        
        supplierPrice: double.tryParse(_supplierPriceController.text) ?? 0.0,
        costPrice: double.tryParse(_costPriceController.text) ?? 0.0,
        price: double.tryParse(_priceController.text) ?? 0.0,
        
        stock: finalStock,
        variations: variationsMap,
        imageUrl: imageUrlToSave,
        attributes: widget.component?.attributes ?? {},
        supplierLink: _supplierLinkController.text,
      );

      if (widget.component == null) {
        await _componentService.addComponent(component);
      } else {
        await _componentService.updateComponent(widget.component!.id, component);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Componente salvo!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isLoading = false; _isUploading = false; });
    }
  }

  Future<void> _deleteComponent() async {
    if (widget.component == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza? Esta ação é irreversível.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _componentService.deleteComponent(widget.component!.id);
        if (widget.component!.imageUrl.isNotEmpty) {
          await _storageService.deleteImage(widget.component!.imageUrl);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excluído!'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.component == null ? 'Adicionar Componente' : 'Editar Componente'),
        actions: [
           if (widget.component != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Excluir',
              onPressed: _isLoading ? null : _deleteComponent,
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. IMAGEM
              _buildImagePreview(),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Selecionar Imagem'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black87),
                onPressed: _pickImage,
              ),
              if (_isUploading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _uploadProgress),
                Text('${(_uploadProgress * 100).toStringAsFixed(0)}%', textAlign: TextAlign.center),
              ],
              
              const Divider(height: 32),
              
              // 2. CATEGORIA
              DropdownButtonFormField<String>(
                value: _selectedCategoryKey,
                hint: const Text('Categoria'),
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Categoria'),
                items: _categoriesMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setState(() => _selectedCategoryKey = v),
                validator: (v) => v == null ? 'Selecione uma categoria' : null,
              ),
              
              const SizedBox(height: 16),
              
              // 3. NOME E DESCRIÇÃO
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder()),
                maxLines: 2,
              ),

              const SizedBox(height: 24),
              const Text("Precificação", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),

              // 4. FORNECEDOR
              TextFormField(
                controller: _supplierPriceController,
                decoration: const InputDecoration(
                  labelText: 'Preço Tabela Fornecedor',
                  prefixText: 'R\$ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              ),
              
              const SizedBox(height: 16),
              
              // 5. CUSTO E VENDA (Lado a Lado)
              Row(
                children: [
                  // CUSTO (Agora com Helper do Desconto)
                  Expanded(
                    child: TextFormField(
                      controller: _costPriceController,
                      decoration: InputDecoration(
                        labelText: 'Custo (R\$)', 
                        border: const OutlineInputBorder(),
                        //fillColor: const Color(0xFFFFFDE7), 
                        filled: true,
                        // --- AQUI: Helper de Desconto ---
                        helperText: _supplierDiscount > 0 ? 'Desconto: ${_supplierDiscount.toStringAsFixed(0)}%' : null,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // VENDA (Com Helper de Margem)
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'Venda (R\$)',
                        border: const OutlineInputBorder(),
                        // --- Helper de Margem ---
                        helperText: _defaultMargin > 0 ? 'Margem: ${_defaultMargin.toStringAsFixed(0)}%' : null,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                ],
              ),

              const Divider(height: 32),
              
              // 6. ESTOQUE E VARIAÇÕES
              const Text("Estoque e Variações", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),

              if (_variationsControllers.isEmpty) ...[
                // Modo Simples
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockController, 
                        decoration: const InputDecoration(labelText: 'Estoque Total', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _addVariationRow,
                      icon: const Icon(Icons.list),
                      label: const Text("Criar Variações"),
                    ),
                  ],
                ),
              ] else ...[
                // Modo Variações
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[50],
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Expanded(flex: 2, child: Text("Variação (ex: Tam 10)", style: TextStyle(color: Colors.grey))),
                          SizedBox(width: 8),
                          Expanded(flex: 1, child: Text("Qtd", style: TextStyle(color: Colors.grey))),
                          SizedBox(width: 40),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      ..._variationsControllers.asMap().entries.map((entry) {
                        int idx = entry.key;
                        var ctrl = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: ctrl['name'],
                                  decoration: const InputDecoration(hintText: 'Nome', isDense: true, border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: ctrl['stock'],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(hintText: '0', isDense: true, border: OutlineInputBorder()),
                                  onChanged: (_) => _updateTotalStock(), 
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeVariationRow(idx),
                              ),
                            ],
                          ),
                        );
                      }),
                      
                      TextButton.icon(
                        onPressed: _addVariationRow, 
                        icon: const Icon(Icons.add), 
                        label: const Text("Adicionar Variação")
                      ),
                      
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Estoque Total Calculado:", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(_stockController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      )
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              
              // 7. LINK
              TextFormField(
                controller: _supplierLinkController, 
                decoration: const InputDecoration(labelText: 'Link do Fornecedor', border: OutlineInputBorder(), suffixIcon: Icon(Icons.link))
              ),
              if (_supplierLinkController.text.isNotEmpty)
                 Align(
                   alignment: Alignment.centerLeft,
                   child: TextButton.icon(onPressed: _launchSupplierLink, icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Testar Link')),
                 ),

              const SizedBox(height: 32),
              
              // 8. BOTÃO SALVAR
              _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _saveComponent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[800], 
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('SALVAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
     return Container(
       height: 200, 
       width: double.infinity,
       decoration: BoxDecoration(
         color: Colors.grey[200],
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: Colors.grey[400]!),
       ),
       child: ClipRRect(
         borderRadius: BorderRadius.circular(12),
         child: _newImageBytes != null 
          ? Image.memory(_newImageBytes!, fit: BoxFit.cover)
          : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty
              ? Image.network(
                  _currentImageUrl!, 
                  fit: BoxFit.cover,
                  errorBuilder: (c,e,s) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ) 
              : const Center(child: Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey))
            ),
       ),
     );
  }
}