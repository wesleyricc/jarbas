import 'package:flutter/material.dart';
import '../models/component_model.dart';
import '../providers/rod_builder_provider.dart'; 
import 'component_selector.dart';

class MultiComponentStep extends StatefulWidget {
  final bool isAdmin;
  final String categoryKey;
  final String title;
  final String emptyMessage;
  final IconData emptyIcon;
  final List<RodItem> items; 
  
  final Function(Component, String?) onAdd;
  final Function(int) onRemove;
  final Function(int, int) onUpdateQty;

  const MultiComponentStep({
    super.key,
    required this.isAdmin,
    required this.categoryKey,
    required this.title,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.items,
    required this.onAdd,
    required this.onRemove,
    required this.onUpdateQty,
  });

  @override
  State<MultiComponentStep> createState() => _MultiComponentStepState();
}

class _MultiComponentStepState extends State<MultiComponentStep> {
  
  void _openMultiSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Selecionar ${widget.title}(s)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ComponentSelector(
                    category: widget.categoryKey,
                    isAdmin: widget.isAdmin,
                    onMultiSelectConfirm: (selectedList) {
                      for (var item in selectedList) {
                        widget.onAdd(item['comp'], item['var']);
                      }
                      Navigator.pop(context); 
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- LÓGICA DE RESOLUÇÃO DE IMAGEM ---
  String _resolveItemImage(RodItem item) {
    // 1. Verifica se tem variação selecionada
    if (item.variation != null && item.variation!.isNotEmpty) {
      try {
        // 2. Procura a variação dentro da lista do componente
        final variant = item.component.variations.firstWhere(
          (v) => v.name == item.variation,
        );
        // 3. Se a variação tiver imagem, retorna ela
        if (variant.imageUrl != null && variant.imageUrl!.isNotEmpty) {
          return variant.imageUrl!;
        }
      } catch (_) {
        // Se não encontrar ou der erro, segue para o fallback
      }
    }
    // 4. Fallback: Retorna imagem principal do componente
    return item.component.imageUrl;
  }

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _openMultiSelector,
          icon: const Icon(Icons.add),
          label: Text('Adicionar ${widget.title}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[50],
            foregroundColor: Colors.blueGrey[900],
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.blueGrey[200]!),
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (widget.items.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
            child: Column(
              children: [
                Icon(widget.emptyIcon, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text(widget.emptyMessage, style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.items.length,
            separatorBuilder: (c, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final rodItem = widget.items[index];
              // Resolve a imagem correta para este item
              final displayImage = _resolveItemImage(rodItem);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[200]!)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // IMAGEM CLICÁVEL (Usando displayImage resolvida)
                      GestureDetector(
                        onTap: () => _showImageDialog(displayImage),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: displayImage.isNotEmpty
                              ? Image.network(displayImage, width: 50, height: 50, fit: BoxFit.cover)
                              : Container(width: 50, height: 50, color: Colors.grey[100], child: const Icon(Icons.image, size: 20, color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rodItem.component.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            
                            if (rodItem.component.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                                child: Text(
                                  rodItem.component.description, 
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  softWrap: true,
                                ),
                              ),

                            if (rodItem.variation != null)
                              Text("Var: ${rodItem.variation}", style: TextStyle(color: Colors.blueGrey[700], fontSize: 12, fontWeight: FontWeight.w500)),
                            
                            if (widget.isAdmin) ...[
                              const SizedBox(height: 4),
                              // Nota: Aqui o preço é o base do componente. 
                              // Se quiser mostrar preço da variação, precisaria de lógica similar à da imagem.
                              Text("R\$ ${rodItem.component.price.toStringAsFixed(2)}", style: TextStyle(fontSize: 12, color: Colors.blueGrey[700], fontWeight: FontWeight.bold)),
                            ]
                          ],
                        ),
                      ),

                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                            onPressed: () {
                              if (rodItem.quantity > 1) {
                                widget.onUpdateQty(index, rodItem.quantity - 1);
                              } else {
                                widget.onRemove(index);
                              }
                            },
                          ),
                          Text('${rodItem.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.blueGrey),
                            onPressed: () {
                              widget.onUpdateQty(index, rodItem.quantity + 1);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}