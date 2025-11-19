import 'dart:typed_data'; // Para Uint8List (essencial para Web)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para InputFormatters
import 'package:url_launcher/url_launcher.dart'; // Para abrir links
import '../../../models/component_model.dart';
import '../../../services/component_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/config_service.dart'; // (NOVO) Serviço de Configuração
import 'package:image_picker/image_picker.dart';

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
  final ConfigService _configService = ConfigService(); // Instância do ConfigService

  bool _isLoading = false;

  // Controladores de Texto
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;     // Preço de Venda
  late TextEditingController _costPriceController; // Preço de Custo (NOVO)
  late TextEditingController _stockController;
  late TextEditingController _supplierLinkController;
  
  String? _selectedCategoryKey;

  // Estado da Imagem
  String? _currentImageUrl; // URL da imagem existente (se houver)
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  Uint8List? _newImageBytes; // Bytes da nova imagem selecionada
  String? _newImageExtension; // Extensão do arquivo (png, jpg)

  // Configuração Global
  double _defaultMargin = 0.0; // Armazena a margem carregada do banco

  // Mapa de categorias para o Dropdown
  final Map<String, String> _categoriesMap = {
    'blank': 'Blank',
    'cabo': 'Cabo',
    'passadores': 'Passadores',
    'reel_seat': 'Reel Seat'
  };

  @override
  void initState() {
    super.initState();
    // Inicializa os controladores (com dados existentes ou vazios)
    _nameController = TextEditingController(text: widget.component?.name ?? '');
    _descController = TextEditingController(text: widget.component?.description ?? '');
    _priceController = TextEditingController(text: widget.component?.price.toString() ?? '');
    _costPriceController = TextEditingController(text: widget.component?.costPrice.toString() ?? '');
    _stockController = TextEditingController(text: widget.component?.stock.toString() ?? '');
    _supplierLinkController = TextEditingController(text: widget.component?.supplierLink ?? '');
    
    _selectedCategoryKey = widget.component?.category;
    _currentImageUrl = widget.component?.imageUrl;

    // 1. Carrega as configurações globais (Margem de Lucro)
    _loadSettings();

    // 2. Adiciona o listener para calcular o preço de venda automaticamente
    _costPriceController.addListener(_calculateSellingPrice);
  }

  // Carrega a margem do ConfigService
  Future<void> _loadSettings() async {
    try {
      final settings = await _configService.getSettings();
      if (mounted) {
        setState(() {
          _defaultMargin = (settings['defaultMargin'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      print("Erro ao carregar margem: $e");
    }
  }

  // Lógica de Cálculo Automático: Custo + Margem%
  void _calculateSellingPrice() {
    String costText = _costPriceController.text;
    if (costText.isEmpty) return;

    // Se a margem for 0, não calculamos nada (permite edição manual livre)
    if (_defaultMargin <= 0) return;

    double cost = double.tryParse(costText) ?? 0.0;
    
    // Fórmula: Custo * (1 + Margem / 100)
    // Ex: 50 * (1 + 1) = 100
    double sellingPrice = cost * (1 + (_defaultMargin / 100));

    // Atualiza o campo de venda
    _priceController.text = sellingPrice.toStringAsFixed(2);
  }

  @override
  void dispose() {
    // Remove listener e descarta controladores
    _costPriceController.removeListener(_calculateSellingPrice);
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _supplierLinkController.dispose();
    super.dispose();
  }

  // --- IMAGEM ---

  Future<void> _pickImage() async {
    // NENHUM código de UI aqui (sem unfocus, sem print, nada).
    
    try {
      // Instancia DIRETO aqui para ser instantâneo
      final ImagePicker picker = ImagePicker();
      
      // Chama a galeria DIRETAMENTE. Sem passar por service.
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // Opcional: Reduz tamanho para ajudar a memória do celular
        imageQuality: 80, // Opcional
      );

      if (image != null) {
        // Só agora processamos os dados
        final bytes = await image.readAsBytes();
        final ext = image.name.split('.').last;

        setState(() {
          _newImageBytes = bytes;
          _newImageExtension = ext.isEmpty ? 'jpg' : ext;
          _currentImageUrl = null;
        });
      }
    } catch (e) {
      print("Erro ao pegar imagem: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na galeria: $e')),
      );
    }
  }

  // --- LINK DO FORNECEDOR ---

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
        throw 'Could not launch';
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
      // 1. Upload Imagem (se houver nova)
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
          // Deleta imagem antiga para não acumular lixo
          if (oldImageUrl != null && oldImageUrl.isNotEmpty && oldImageUrl != imageUrlToSave) {
            await _storageService.deleteImage(oldImageUrl);
          }
        }
        setState(() { _isUploading = false; });
      }

      // 2. Cria o Objeto
      final component = Component(
        id: widget.component?.id ?? '', // ID vazio se novo
        name: _nameController.text,
        description: _descController.text,
        category: _selectedCategoryKey!,
        
        // Salva Preço de Venda e de Custo
        price: double.tryParse(_priceController.text) ?? 0.0,
        costPrice: double.tryParse(_costPriceController.text) ?? 0.0,
        
        stock: int.tryParse(_stockController.text) ?? 0,
        imageUrl: imageUrlToSave,
        attributes: widget.component?.attributes ?? {},
        supplierLink: _supplierLinkController.text,
      );

      // 3. Salva no Firestore
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

  // --- EXCLUIR ---

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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
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
              
              // 3. NOME
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome do Componente', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              ),
              
              const SizedBox(height: 16),
              
              // 4. DESCRIÇÃO
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder()),
                maxLines: 2,
              ),

              const SizedBox(height: 16),
              
              // 5. PREÇOS (Lado a Lado)
              Row(
                children: [
                  // CUSTO
                  Expanded(
                    child: TextFormField(
                      controller: _costPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Custo (R\$)', 
                        border: const OutlineInputBorder(),
                        //fillColor: Color(0xFFFFFDE7), // Amarelo claro para indicar input manual importante
                        filled: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // VENDA (Calculado)
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'Venda (R\$)',
                        border: const OutlineInputBorder(),
                        // Mostra a margem usada como dica
                        //helperText: _defaultMargin > 0 ? 'Margem: ${_defaultMargin.toStringAsFixed(0)}%' : null,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              
              // 6. ESTOQUE
              TextFormField(
                controller: _stockController, 
                decoration: const InputDecoration(labelText: 'Estoque', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),

              const SizedBox(height: 16),
              
              // 7. LINK
              TextFormField(
                controller: _supplierLinkController,
                decoration: const InputDecoration(
                  labelText: 'Link do Fornecedor', 
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.link),
                ),
              ),
              if (_supplierLinkController.text.isNotEmpty)
                 TextButton.icon(
                   onPressed: _launchSupplierLink,
                   icon: const Icon(Icons.open_in_new, size: 16),
                   label: const Text('Testar Link'),
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
                    child: const Text('SALVAR COMPONENTE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para preview da imagem
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