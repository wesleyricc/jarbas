import 'package:flutter/material.dart';
import '../models/component_model.dart';
import '../providers/rod_builder_provider.dart'; // Para acessar RodItem
import 'component_selector.dart';

class MultiComponentStep extends StatefulWidget {
  final bool isAdmin;
  final String categoryKey;
  final String title;
  final String emptyMessage;
  final IconData emptyIcon;
  final List<RodItem> items; // Lista atual do Provider
  
  // Callbacks
  final Function(Component, String?) onAdd; // Mantido para compatibilidade simples
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
                // Header do Modal
                const SizedBox(height: 12),
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Selecionar ${widget.title}(s)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                
                // O Seletor
                Expanded(
                  child: ComponentSelector(
                    category: widget.categoryKey,
                    isAdmin: widget.isAdmin,
                    // Aqui está a mágica da múltipla seleção
                    onMultiSelectConfirm: (selectedList) {
                      for (var item in selectedList) {
                        // Chama o onAdd para cada item selecionado
                        widget.onAdd(item['comp'], item['var']);
                      }
                      Navigator.pop(context); // Fecha o modal só no final
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Botão de Adicionar
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

        // Lista de Itens Selecionados
        if (widget.items.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!)
            ),
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
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[200]!)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      // Imagem
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: rodItem.component.imageUrl.isNotEmpty
                            ? Image.network(rodItem.component.imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                            : Container(width: 50, height: 50, color: Colors.grey[100], child: const Icon(Icons.image, size: 20, color: Colors.grey)),
                      ),
                      const SizedBox(width: 12),
                      
                      // Infos
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rodItem.component.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            if (rodItem.variation != null)
                              Text("Var: ${rodItem.variation}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            
                            // Preço Unitário
                            const SizedBox(height: 4),
                            Text(
                              "R\$ ${rodItem.component.price.toStringAsFixed(2)}", 
                              style: TextStyle(fontSize: 12, color: Colors.blueGrey[700], fontWeight: FontWeight.bold)
                            ),
                          ],
                        ),
                      ),

                      // Controle de Quantidade
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