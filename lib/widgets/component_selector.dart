import 'package:flutter/material.dart';
import '../models/component_model.dart';
import '../services/component_service.dart';

class ComponentSelector extends StatefulWidget {
  final String category;
  final bool isAdmin;
  final Function(List<Map<String, dynamic>>)? onMultiSelectConfirm; 
  final Function(Component, String?)? onSelect; 

  const ComponentSelector({
    super.key, 
    required this.category, 
    required this.isAdmin,
    this.onSelect,
    this.onMultiSelectConfirm,
  });

  @override
  State<ComponentSelector> createState() => _ComponentSelectorState();
}

class _ComponentSelectorState extends State<ComponentSelector> {
  final ComponentService _componentService = ComponentService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late Stream<List<Component>> _componentsStream; 
  String _searchQuery = '';

  final List<Map<String, dynamic>> _tempSelectedItems = [];

  @override
  void initState() {
    super.initState();
    _componentsStream = _componentService.getComponentsByCategoryStream(widget.category);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- NOVO MÉTODO: Exibir Imagem Ampliada ---
  void _showImageDialog(String imageUrl) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ------------------------------------------

  void _toggleSelection(Component comp, String? variation) {
    setState(() {
      final existingIndex = _tempSelectedItems.indexWhere(
        (item) => item['comp'].id == comp.id && item['var'] == variation
      );

      if (existingIndex >= 0) {
        _tempSelectedItems.removeAt(existingIndex);
      } else {
        _tempSelectedItems.add({'comp': comp, 'var': variation, 'qty': 1});
      }
    });
  }

  bool _isSelected(Component comp, String? variation) {
    return _tempSelectedItems.any(
      (item) => item['comp'].id == comp.id && item['var'] == variation
    );
  }

  void _confirmSelection() {
    if (widget.onMultiSelectConfirm != null) {
      widget.onMultiSelectConfirm!(_tempSelectedItems);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar ${widget.category}...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<List<Component>>(
            stream: _componentsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Nenhum componente encontrado.'));

              final filteredList = snapshot.data!.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

              return ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filteredList.length,
                separatorBuilder: (c, i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _buildComponentTile(filteredList[index]);
                },
              );
            },
          ),
        ),

        if (_tempSelectedItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _confirmSelection,
                  child: Text("ADICIONAR ${_tempSelectedItems.length} ITEM(NS)", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildComponentTile(Component comp) {
    bool hasVariations = comp.variations.isNotEmpty;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        leading: GestureDetector( // CLICÁVEL AQUI
          onTap: () => _showImageDialog(comp.imageUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: comp.imageUrl.isNotEmpty
              ? Image.network(comp.imageUrl, width: 40, height: 40, fit: BoxFit.cover)
              : Container(width: 40, height: 40, color: Colors.grey[200], child: const Icon(Icons.image_not_supported, size: 20)),
          ),
        ),
        title: Text(comp.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (comp.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2.0, bottom: 4.0),
                child: Text(comp.description, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            if (widget.isAdmin) ...[
              Text("Estoque Total: ${comp.stock}", style: TextStyle(fontSize: 12, color: comp.stock < 3 ? Colors.red : Colors.blueGrey[800], fontWeight: FontWeight.bold)),
              Text("Custo Base: R\$ ${comp.costPrice.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]
          ],
        ),
        trailing: hasVariations ? null : _buildCheckbox(comp, null),
        onExpansionChanged: hasVariations ? null : (expanded) => _toggleSelection(comp, null),
        children: comp.variations.map((variant) {
          String priceInfo = (widget.isAdmin && variant.price > 0) ? " | R\$ ${variant.price.toStringAsFixed(2)}" : "";
          
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            leading: GestureDetector( // CLICÁVEL AQUI TAMBÉM (Variação)
              onTap: () => _showImageDialog(variant.imageUrl ?? ''),
              child: variant.imageUrl != null && variant.imageUrl!.isNotEmpty
                  ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(variant.imageUrl!, width: 30, height: 30, fit: BoxFit.cover))
                  : const Icon(Icons.circle, size: 10, color: Colors.grey),
            ),
            title: Text(variant.name),
            subtitle: widget.isAdmin ? Text("Estoque: ${variant.stock}$priceInfo") : null,
            trailing: _buildCheckbox(comp, variant.name),
            onTap: () => _toggleSelection(comp, variant.name),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCheckbox(Component comp, String? variation) {
    final isSelected = _isSelected(comp, variation);
    return Checkbox(
      value: isSelected,
      activeColor: Colors.blueGrey[800],
      onChanged: (val) => _toggleSelection(comp, variation),
    );
  }
}