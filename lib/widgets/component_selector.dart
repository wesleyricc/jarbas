import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../../models/component_model.dart';
import '../../../services/component_service.dart';
import '../screens/component_form_screen.dart';

class ComponentSelector extends StatefulWidget {
  final String category;
  final Component? selectedComponent;
  final Function(Component?) onSelect;
  final bool isAdmin;
  
  final int quantity;
  final Function(int)? onQuantityChanged; 

  const ComponentSelector({
    super.key,
    required this.category,
    required this.selectedComponent,
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

  final Color _selectedBackgroundColor = const Color(0xFF263238); 
  final Color _unselectedBackgroundColor = Colors.white; 
  final Color _selectedTextColor = Colors.white; 
  final Color _unselectedTextColor = Colors.black87; 
  final Color _accentColor = Colors.greenAccent[400]!; 

  @override
  void initState() {
    super.initState();
    _componentsStream = _componentService.getComponentsByCategoryStream(widget.category);
  }

  // --- (MÉTODOS AUXILIARES EXISTENTES) ---
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
            InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            )
          ],
        ),
      ),
    );
  }

  // --- NOVO MÉTODO: DETALHES COMPLETOS ---
  void _showDetailsBottomSheet(BuildContext context, Component component) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite altura maior
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5, // Começa na metade da tela
          minChildSize: 0.3,
          maxChildSize: 0.9, // Pode subir até 90%
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white, // <--- AQUI: Força o fundo branco para leitura
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle (tracinho cinza para puxar)
                  Center(
                    child: Container(
                      width: 40, height: 5,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Imagem Grande
                  if (component.imageUrl.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(component.imageUrl, height: 200, fit: BoxFit.cover),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Nome
                  Text(
                    component.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  
                  // Preço (se Admin)
                  if (widget.isAdmin)
                    Text(
                      'Preço: R\$ ${component.price.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
                    ),
                  
                  const Divider(height: 32),
                  
                  // Descrição Completa
                  const Text(
                    "Descrição Detalhada:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    component.description.isNotEmpty ? component.description : 'Sem descrição.',
                    style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                  ),
                  
                  const SizedBox(height: 40), // Espaço final
                ],
              ),
              ),
            );
          },
        );
      },
    );
  }
  // ---------------------------------------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Component>>(
      stream: _componentsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)
            ),
            child: const Center(child: Text('Nenhum componente encontrado.')),
          );
        }

        List<Component> components = snapshot.data!;

        return Column(
          children: [
            // Contador (Mantido igual)
            if (widget.onQuantityChanged != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: _selectedBackgroundColor, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Text("Quantidade:", style: TextStyle(fontWeight: FontWeight.bold, color: _selectedBackgroundColor)),
                          const SizedBox(width: 12),
                          _buildQtyButton(Icons.remove, () { if (widget.quantity > 1) widget.onQuantityChanged!(widget.quantity - 1); }),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('${widget.quantity}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _selectedBackgroundColor)),
                          ),
                          _buildQtyButton(Icons.add, () { widget.onQuantityChanged!(widget.quantity + 1); }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Lista
            Container(
              constraints: const BoxConstraints(maxHeight: 500),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  shrinkWrap: true, padding: EdgeInsets.zero, itemCount: components.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (c, i) => _buildComponentTile(components[i], widget.selectedComponent?.id == components[i].id),
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
      child: Container(
        padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }

  Widget _buildComponentTile(Component component, bool isSelected) {
    final backgroundColor = isSelected ? _selectedBackgroundColor : _unselectedBackgroundColor;
    final mainTextColor = isSelected ? _selectedTextColor : _unselectedTextColor;
    final subTextColor = isSelected ? Colors.grey[400] : Colors.grey[600];

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: () => isSelected ? widget.onSelect(null) : widget.onSelect(component),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Imagem
              GestureDetector(
                onTap: () { if (component.imageUrl.isNotEmpty) _showImageDialog(context, component.imageUrl); },
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: component.imageUrl.isNotEmpty
                        ? Image.network(component.imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey[400]))
                        : Icon(Icons.image_not_supported, color: Colors.grey[400]),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Textos + Ícone Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LINHA DO TÍTULO COM BOTÃO DE INFO
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            component.name,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: mainTextColor),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // --- ÍCONE INFO ---
                        InkWell(
                          onTap: () => _showDetailsBottomSheet(context, component), // Abre o detalhe
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(Icons.info_outline, size: 20, color: isSelected ? Colors.lightBlueAccent : Colors.blue),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    Text(
                      component.description,
                      style: TextStyle(fontSize: 13, color: subTextColor),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Preço e Ações
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? _accentColor : Colors.grey[400], size: 30,
                  ),
                  const SizedBox(height: 8),
                  if (widget.isAdmin)
                    Text('R\$ ${component.price.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.blueGrey[800])),
                  
                  // Admin Actions
                  if (widget.isAdmin && !isSelected) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (component.supplierLink != null && component.supplierLink!.isNotEmpty)
                           InkWell(
                            onTap: () => _launchSupplierLink(component.supplierLink),
                            child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.link, size: 20, color: Colors.blue)),
                          ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ComponentFormScreen(component: component))),
                          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.edit_note, size: 22, color: Colors.grey)),
                        ),
                      ],
                    )
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}