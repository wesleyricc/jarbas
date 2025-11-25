import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../../models/component_model.dart';
import '../../../services/component_service.dart';
import '../screens/component_form_screen.dart';

class ComponentSelector extends StatefulWidget {
  final String category;
  final Component? selectedComponent;
  
  final String? selectedVariation; 
  final void Function(Component? component, String? variation) onSelect;
  
  final bool isAdmin;
  final int quantity;
  final Function(int)? onQuantityChanged; 

  const ComponentSelector({
    super.key,
    required this.category,
    required this.selectedComponent,
    this.selectedVariation,
    required this.onSelect,
    required this.isAdmin,
    this.quantity = 1,
    this.onQuantityChanged,
  });

  @override
  State<ComponentSelector> createState() => _ComponentSelectorState();
}

class _ComponentSelectorState extends State<ComponentSelector> {
  final ComponentService _componentService = ComponentService();
  late Stream<List<Component>> _componentsStream;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final Color _selectedBackgroundColor = const Color(0xFF263238); 
  final Color _unselectedBackgroundColor = Colors.white; 
  final Color _selectedTextColor = Colors.white; 
  final Color _unselectedTextColor = Colors.black87; 
  final Color _accentColor = Colors.greenAccent[400]!; 

  @override
  void initState() {
    super.initState();
    _componentsStream = _componentService.getComponentsByCategoryStream(widget.category);
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchSupplierLink(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum link cadastrado.'), backgroundColor: Colors.orange));
      return;
    }
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $url')));
    }
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: Image.network(imageUrl, fit: BoxFit.contain)),
            IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx))
          ],
        ),
      ),
    );
  }

  void _showDetailsBottomSheet(BuildContext context, Component component) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 24),
                    if (component.imageUrl.isNotEmpty)
                      Center(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(component.imageUrl, height: 200, fit: BoxFit.cover))),
                    const SizedBox(height: 24),
                    Text(component.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    if (widget.isAdmin)
                      Text('Preço: R\$ ${component.price.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
                    const Divider(height: 32),
                    const Text("Descrição Detalhada:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(component.description.isNotEmpty ? component.description : 'Sem descrição.', style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87)),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showVariationPicker(BuildContext context, Component component) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Selecione a variação para ${component.name}", 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: component.variations.length,
                separatorBuilder: (c, i) => const Divider(),
                itemBuilder: (context, index) {
                  String key = component.variations.keys.elementAt(index);
                  int stock = component.variations[key]!;
                  
                  return ListTile(
                    title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                    subtitle: Text(stock > 0 ? 'Estoque: $stock' : 'Indisponível', style: TextStyle(color: stock > 0 ? Colors.grey[700] : Colors.red[300])),
                    enabled: stock > 0, 
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => Navigator.pop(context, key), 
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ).then((selectedVar) {
      if (selectedVar != null && selectedVar is String) {
        widget.onSelect(component, selectedVar);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Component>>(
      stream: _componentsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData) return const Center(child: Text('Erro ao carregar.'));

        List<Component> allComponents = snapshot.data!;

        List<Component> filteredComponents = allComponents;
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          filteredComponents = allComponents.where((comp) {
            final nameMatch = comp.name.toLowerCase().contains(query);
            final descMatch = comp.description.toLowerCase().contains(query);
            return nameMatch || descMatch;
          }).toList();
        }

        if (allComponents.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
            child: const Center(child: Text('Nenhum componente encontrado nesta categoria.')),
          );
        }

        return Column(
          children: [
            // Barra de Busca
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar ${widget.category}...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); FocusScope.of(context).unfocus(); }) 
                    : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),

            // Contador
            if (widget.onQuantityChanged != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: _selectedBackgroundColor, width: 1.5)),
                      child: Row(
                        children: [
                          Text("Quantidade:", style: TextStyle(fontWeight: FontWeight.bold, color: _selectedBackgroundColor)),
                          const SizedBox(width: 12),
                          _buildQtyButton(Icons.remove, () { if (widget.quantity > 1) widget.onQuantityChanged!(widget.quantity - 1); }),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Text('${widget.quantity}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _selectedBackgroundColor))),
                          _buildQtyButton(Icons.add, () { widget.onQuantityChanged!(widget.quantity + 1); }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Lista de Itens
            if (filteredComponents.isEmpty)
               Container(
                height: 100, alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                child: const Text("Nenhum item encontrado para esta busca.", style: TextStyle(color: Colors.grey)),
               )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 500),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ListView.separated(
                    shrinkWrap: true,
                    // --- CORREÇÃO AQUI: Padding no final da lista ---
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 90),
                    // -----------------------------------------------
                    itemCount: filteredComponents.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (c, i) => _buildComponentTile(filteredComponents[i], widget.selectedComponent?.id == filteredComponents[i].id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed, borderRadius: BorderRadius.circular(20),
      child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle), child: Icon(icon, size: 20, color: Colors.black87)),
    );
  }

  Widget _buildComponentTile(Component component, bool isSelected) {
    final backgroundColor = isSelected ? _selectedBackgroundColor : _unselectedBackgroundColor;
    final mainTextColor = isSelected ? _selectedTextColor : _unselectedTextColor;
    final subTextColor = isSelected ? Colors.grey[400] : Colors.grey[600];
    final actionIconColor = isSelected ? Colors.white70 : Colors.grey[600];

    String displayName = component.name;
    if (isSelected && widget.selectedVariation != null) {
      displayName += " (${widget.selectedVariation})";
    }

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: () {
          if (isSelected) {
            widget.onSelect(null, null); 
          } else {
            if (component.variations.isNotEmpty) {
              _showVariationPicker(context, component); 
            } else {
              widget.onSelect(component, null); 
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // COLUNA 1: IMAGEM
              GestureDetector(
                onTap: () { if (component.imageUrl.isNotEmpty) _showImageDialog(context, component.imageUrl); },
                child: Container(
                  width: 70, height: 70, // Um pouco maior
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: component.imageUrl.isNotEmpty
                        ? Image.network(component.imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey[400]))
                        : Icon(Icons.image_not_supported, color: Colors.grey[400]),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // COLUNA 2: CONTEÚDO EXPANDIDO
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: mainTextColor),
                            softWrap: true, 
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isSelected ? _accentColor : Colors.grey[300], 
                          size: 28
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 6),
                    
                    Text(
                      component.description,
                      style: TextStyle(fontSize: 13, color: subTextColor),
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (widget.isAdmin)
                          Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: Text(
                              'R\$ ${component.price.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.blueGrey[800]),
                            ),
                          ),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _showDetailsBottomSheet(context, component),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.info_outline, size: 22, color: isSelected ? Colors.lightBlueAccent : Colors.blue)),
                            ),
                            
                            if (widget.isAdmin) ...[
                              if (component.supplierLink != null && component.supplierLink!.isNotEmpty)
                                InkWell(
                                  onTap: () => _launchSupplierLink(component.supplierLink),
                                  child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.link, size: 22, color: actionIconColor)),
                                ),
                              InkWell(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ComponentFormScreen(component: component))),
                                child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.edit_note, size: 24, color: actionIconColor)),
                              ),
                            ]
                          ],
                        )
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}