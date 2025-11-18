import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Para o link do fornecedor
import '../../../models/component_model.dart';
import '../../../services/component_service.dart';
import '../screens/component_form_screen.dart';

class ComponentSelector extends StatefulWidget {
  final String category;
  final Component? selectedComponent;
  final Function(Component?) onSelect;
  final bool isAdmin;
  
  // --- Campos para Controle de Quantidade ---
  final int quantity;
  final Function(int)? onQuantityChanged; // Se nulo, esconde o contador

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

  // --- Paleta de Cores de Alto Contraste ---
  final Color _selectedBackgroundColor = const Color(0xFF263238); // BlueGrey 900 (Fundo Escuro)
  final Color _unselectedBackgroundColor = Colors.white; // Fundo Claro
  final Color _selectedTextColor = Colors.white; // Texto Claro
  final Color _unselectedTextColor = Colors.black87; // Texto Escuro
  final Color _accentColor = Colors.greenAccent[400]!; // Verde Neon para destaque (Check)

  @override
  void initState() {
    super.initState();
    // Busca componentes da categoria em tempo real
    _componentsStream = _componentService.getComponentsByCategoryStream(widget.category);
  }

  // Método para abrir o link do fornecedor
  Future<void> _launchSupplierLink(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum link cadastrado.'), backgroundColor: Colors.orange),
      );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir link: $url'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Método para mostrar a imagem ampliada (Zoom)
  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Component>>(
      stream: _componentsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Center(
              child: Text(
                'Nenhum componente encontrado nesta categoria.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        List<Component> components = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 1. CONTADOR DE QUANTIDADE (Destacado) ---
            if (widget.onQuantityChanged != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end, // Alinha à direita
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white, // Sempre Branco para destaque
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: _selectedBackgroundColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Quantidade:", 
                            style: TextStyle(fontWeight: FontWeight.bold, color: _selectedBackgroundColor)
                          ),
                          const SizedBox(width: 12),
                          _buildQtyButton(Icons.remove, () {
                            if (widget.quantity > 1) widget.onQuantityChanged!(widget.quantity - 1);
                          }),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              '${widget.quantity}',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _selectedBackgroundColor),
                            ),
                          ),
                          _buildQtyButton(Icons.add, () {
                            widget.onQuantityChanged!(widget.quantity + 1);
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // --- 2. LISTA DE COMPONENTES ---
            Container(
              // Limita altura para scroll interno se a lista for muito grande
              constraints: const BoxConstraints(maxHeight: 500), 
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                   BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: ListView.separated(
                  shrinkWrap: true, // Importante para não expandir infinitamente
                  padding: EdgeInsets.zero,
                  itemCount: components.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1),
                  itemBuilder: (context, index) {
                    Component component = components[index];
                    final bool isSelected = widget.selectedComponent?.id == component.id;
                    return _buildComponentTile(component, isSelected);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Botão circular para + e -
  Widget _buildQtyButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }

  // O Card de cada componente
  Widget _buildComponentTile(Component component, bool isSelected) {
    // Define cores dinâmicas baseadas na seleção
    final backgroundColor = isSelected ? _selectedBackgroundColor : _unselectedBackgroundColor;
    final mainTextColor = isSelected ? _selectedTextColor : _unselectedTextColor;
    final subTextColor = isSelected ? Colors.grey[400] : Colors.grey[600];
    
    return Material(
      color: backgroundColor, // A cor de fundo muda aqui
      child: InkWell(
        onTap: () {
          // Lógica de Toggle (clicar no selecionado remove a seleção)
          if (isSelected) {
            widget.onSelect(null);
          } else {
            widget.onSelect(component);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Espaçamento generoso
          child: Row(
            children: [
              // --- IMAGEM ---
              GestureDetector(
                onTap: () {
                  if (component.imageUrl.isNotEmpty) _showImageDialog(context, component.imageUrl);
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white, // Fundo da imagem sempre branco para não "sumir" no escuro
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: component.imageUrl.isNotEmpty
                        ? Image.network(
                            component.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey[400]),
                          )
                        : Icon(Icons.image_not_supported, color: Colors.grey[400]),
                  ),
                ),
              ),

              const SizedBox(width: 16),
              
              // --- TEXTOS ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      component.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: mainTextColor, // Branco ou Preto
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      component.description,
                      style: TextStyle(
                        fontSize: 13, 
                        color: subTextColor, // Cinza claro ou Cinza escuro
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),

              // --- PREÇO E CHECK ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Ícone de Seleção (Check ou Radio Vazio)
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? _accentColor : Colors.grey[400],
                    size: 30,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Preço (Apenas Admin)
                  if (widget.isAdmin)
                    Text(
                      'R\$ ${component.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.blueGrey[800],
                      ),
                    ),

                  // Botão de Edição (Apenas Admin e se não estiver selecionado, para não poluir)
                  if (widget.isAdmin && !isSelected) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botão Link (CORREÇÃO AQUI)
                        if (component.supplierLink != null && component.supplierLink!.isNotEmpty)
                          InkWell(
                            onTap: () => _launchSupplierLink(component.supplierLink), // Chama a função privada
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.link, size: 20, color: Colors.blue),
                            ),
                          ),
                          
                        const SizedBox(width: 8),

                        // Botão Editar
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ComponentFormScreen(component: component),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.edit_note, size: 22, color: Colors.grey),
                      ),
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