import 'dart:typed_data'; // Para o preview da imagem na web
// import 'package:flutter/foundation.dart' show kIsWeb; // Não é mais necessário
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart'; // Para o botão de link
import '../../../models/component_model.dart';
import '../../../services/component_service.dart';
import '../../../services/storage_service.dart'; // (NOVO) Serviço de Upload

class ComponentFormScreen extends StatefulWidget {
  final Component? component; // Se for nulo, é "Adicionar". Se não, é "Editar".

  const ComponentFormScreen({super.key, this.component});

  @override
  State<ComponentFormScreen> createState() => _ComponentFormScreenState();
}

class _ComponentFormScreenState extends State<ComponentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ComponentService _componentService = ComponentService();
  final StorageService _storageService = StorageService(); // (NOVO)
  bool _isLoading = false;

  // Controladores
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _supplierLinkController;
  String? _selectedCategoryKey;

  // --- (ATUALIZADO) Estado para Upload da Imagem ---
  String? _currentImageUrl; // URL da imagem existente (para preview)
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  // Armazena os bytes da nova imagem selecionada (essencial para web)
  Uint8List? _newImageBytes; 
  String? _newImageExtension; // (NOVO) Armazena a extensão (ex: 'png')
  // --- FIM DO ESTADO DE UPLOAD ---

  // Mapa de categorias (para exibir nomes amigáveis)
  final Map<String, String> _categoriesMap = {
    'blank': 'Blank',
    'cabo': 'Cabo',
    'passadores': 'Passadores',
    'reel_seat': 'Reel Seat'
  };

  @override
  void initState() {
    super.initState();
    // Preenche os controladores se estiver editando
    _nameController = TextEditingController(text: widget.component?.name ?? '');
    _descController = TextEditingController(text: widget.component?.description ?? '');
    _priceController = TextEditingController(text: widget.component?.price.toString() ?? '');
    _stockController = TextEditingController(text: widget.component?.stock.toString() ?? '');
    _supplierLinkController = TextEditingController(text: widget.component?.supplierLink ?? '');
    _selectedCategoryKey = widget.component?.category;
    _currentImageUrl = widget.component?.imageUrl; // (NOVO)
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _supplierLinkController.dispose();
    super.dispose();
  }

  // (ATUALIZADO) Método para selecionar a imagem
  Future<void> _pickImage() async {
    FocusScope.of(context).unfocus();
    final PickedImage? result = await _storageService.pickImageForPreview();
    if (result != null) {
      setState(() {
        _newImageBytes = result.bytes;
        _newImageExtension = result.extension;
        _currentImageUrl = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Imagem selecionada! Clique em SALVAR para enviar.'), duration: Duration(seconds: 1)),
      );

    }
  }

  // Método para abrir o link
  Future<void> _launchSupplierLink() async {
    // ... (código existente, sem alterações) ...
    final String url = _supplierLinkController.text;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum link cadastrado.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o link: $url'), backgroundColor: Colors.red),
      );
    }
  }

  // --- (MODIFICADO) Método para Salvar o Componente ---
  Future<void> _saveComponent() async {
    if (!_formKey.currentState!.validate()) {
      return; // Formulário inválido
    }

    setState(() { _isLoading = true; });

    String imageUrlToSave = _currentImageUrl ?? ''; // Começa com a URL existente
    String? oldImageUrl = widget.component?.imageUrl;

    try {
      // 1. Fazer upload da nova imagem (se houver)
      if (_newImageBytes != null && _newImageExtension != null) {
        setState(() { _isUploading = true; _uploadProgress = 0.0; });

        final UploadResult? result = await _storageService.uploadImage(
          fileBytes: _newImageBytes!,
          fileName: _nameController.text.isNotEmpty ? _nameController.text : 'component',
          fileExtension: _newImageExtension!, // Passa a extensão
          onProgress: (progress) {
            setState(() { _uploadProgress = progress; });
          },
        );

        if (result != null) {
          imageUrlToSave = result.downloadUrl; // Salva a nova URL
          
          // 2. Deletar a imagem antiga (se estiver editando e a URL antiga existir)
          if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
            // Compara para não deletar a mesma imagem se for um re-upload
            if (oldImageUrl != imageUrlToSave) {
              await _storageService.deleteImage(oldImageUrl);
            }
          }
        } else {
          throw Exception("Falha no upload da imagem.");
        }
      }

      setState(() { _isUploading = false; });

      // 3. Criar o objeto Componente
      final component = Component(
        id: widget.component?.id ?? '', // ID é ignorado ao adicionar
        name: _nameController.text,
        description: _descController.text,
        category: _selectedCategoryKey!,
        price: double.tryParse(_priceController.text) ?? 0.0,
        stock: int.tryParse(_stockController.text) ?? 0,
        imageUrl: imageUrlToSave, // Salva a URL (nova ou antiga)
        attributes: widget.component?.attributes ?? {},
        supplierLink: _supplierLinkController.text,
      );

      // 4. Salvar no Firestore
      if (widget.component == null) {
        // Criar novo
        await _componentService.addComponent(component);
      } else {
        // Atualizar existente
        await _componentService.updateComponent(widget.component!.id, component);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Componente salvo!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Volta para a lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; _isUploading = false; });
      }
    }
  }

  // Método para deletar (agora também deleta a imagem do storage)
  Future<void> _deleteComponent() async {
    // Confirmação de exclusão
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza que deseja excluir este componente? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || widget.component == null) {
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // 1. Deletar o documento do Firestore
      await _componentService.deleteComponent(widget.component!.id);
      
      // 2. Deletar a imagem associada do Storage
      if (widget.component!.imageUrl.isNotEmpty) {
        await _storageService.deleteImage(widget.component!.imageUrl);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Componente excluído!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.component == null ? 'Adicionar Componente' : 'Editar Componente'),
        actions: [
          if (widget.component != null) // Só mostra se estiver editando
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Excluir Componente',
              onPressed: _isLoading ? null : _deleteComponent,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- (NOVO) Widget de Preview e Upload de Imagem ---
              _buildImagePreview(),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: Text(_currentImageUrl != null && _currentImageUrl!.isNotEmpty ? 'Trocar Imagem' : 'Selecionar Imagem'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black87
                ),
                onPressed: _pickImage,
              ),
              if (_isUploading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 8),
                Text('${(_uploadProgress * 100).toStringAsFixed(0)}% concluído', textAlign: TextAlign.center),
              ],
              // --- FIM DO WIDGET DE UPLOAD ---

              const Divider(height: 32),
              
              // Categoria
              DropdownButtonFormField<String>(
                value: _selectedCategoryKey,
                hint: const Text('Categoria'),
                items: _categoriesMap.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() { _selectedCategoryKey = newValue; });
                },
                validator: (value) => value == null ? 'Selecione uma categoria' : null,
              ),
              const SizedBox(height: 16),
              
              // Nome
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) => (value == null || value.isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              
              // Descrição
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descrição'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              
              // Preço
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Preço (ex: 150.99)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                validator: (value) => (value == null || value.isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              
              // Estoque
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(labelText: 'Estoque'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => (value == null || value.isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              
              // Link do Fornecedor (Mantido)
              TextFormField(
                controller: _supplierLinkController,
                decoration: const InputDecoration(labelText: 'Link do Fornecedor (Preço)'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 32),
              
              // Botões
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Botão Salvar
                        ElevatedButton(
                          onPressed: _saveComponent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey[700],
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Salvar'),
                        ),
                        const SizedBox(height: 12),

                        // Botão Consultar Valor (Link do Fornecedor)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Consultar Valor (Link)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFFFFF),
                            foregroundColor: Colors.blueGrey[800],
                            side: BorderSide(color: Colors.grey[400]!),
                          ),
                          onPressed: _launchSupplierLink,
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // (NOVO) Widget de preview da imagem
  Widget _buildImagePreview() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: () {
          // 1. Se uma nova imagem foi selecionada (bytes)
          if (_newImageBytes != null) {
            return Image.memory(_newImageBytes!, fit: BoxFit.cover);
          }
          // 2. Se uma imagem existente está carregada (URL)
          if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
            return Image.network(
              _currentImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey, size: 40),
            );
          }
          // 3. Placeholder padrão
          return const Center(
            child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
          );
        }(),
      ),
    );
  }
}