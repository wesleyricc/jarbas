import 'package:flutter/material.dart';
import '../models/component_model.dart'; // Import para Component
import '../providers/rod_builder_provider.dart'; // Import para RodItem
import 'component_selector.dart';

class MultiComponentStep extends StatefulWidget {
  final bool isAdmin;
  final String categoryKey; // 'passadores' ou 'acessorios'
  final String title;
  final String emptyMessage;
  final IconData emptyIcon;
  
  // Callbacks para ações do Provider
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
  
  void _openAddModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Adicionar ${widget.title}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: ComponentSelector(
                      category: widget.categoryKey,
                      selectedComponent: null,
                      isAdmin: widget.isAdmin,
                      onQuantityChanged: null,
                      onSelect: (component, variation) {
                        if (component != null) {
                          widget.onAdd(component, variation);
                          Navigator.pop(context);
                        }
                      },
                    ),
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
        if (widget.items.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Icon(widget.emptyIcon, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(widget.emptyMessage, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.items.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return _buildTile(index, item);
            },
          ),

        const SizedBox(height: 16),

        OutlinedButton.icon(
          onPressed: () => _openAddModal(context),
          icon: const Icon(Icons.add),
          label: Text("ADICIONAR ${widget.title.toUpperCase()}"),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            side: BorderSide(color: Colors.blueGrey[800]!, width: 1.5),
            foregroundColor: Colors.blueGrey[800],
            backgroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTile(int index, RodItem item) {
    String displayName = item.component.name;
    if (item.variation != null && item.variation!.isNotEmpty) {
      displayName += " (${item.variation})";
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        dense: true,
        
        // --- CORREÇÃO AQUI: SizedBox força o tamanho exato ---
        leading: SizedBox(
          width: 48, 
          height: 48,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: item.component.imageUrl.isNotEmpty
                ? Image.network(
                    item.component.imageUrl, 
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                      Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 20, color: Colors.grey)),
                  )
                : Container(
                    color: Colors.grey[200], 
                    child: const Icon(Icons.image, size: 20, color: Colors.grey)
                  ),
          ),
        ),
        // ----------------------------------------------------

        title: Text(
          displayName, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        subtitle: widget.isAdmin 
          ? Text('R\$ ${item.component.price.toStringAsFixed(2)} un', style: TextStyle(fontSize: 12, color: Colors.grey[600]))
          : null,
          
        trailing: Row(
          mainAxisSize: MainAxisSize.min, 
          children: [
            // Botão Menos
            SizedBox(
              width: 32,
              child: IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 22, color: Colors.grey),
                padding: EdgeInsets.zero,
                onPressed: () {
                  if (item.quantity > 1) widget.onUpdateQty(index, item.quantity - 1);
                  else widget.onRemove(index);
                },
              ),
            ),
            
            // Texto Quantidade
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                '${item.quantity}', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),

            // Botão Mais
            SizedBox(
              width: 32,
              child: IconButton(
                icon: Icon(Icons.add_circle_outline, size: 22, color: Colors.blueGrey[700]),
                padding: EdgeInsets.zero,
                onPressed: () => widget.onUpdateQty(index, item.quantity + 1),
              ),
            ),

            const SizedBox(width: 4),

            // Botão Excluir
            SizedBox(
              width: 32,
              child: IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red[700], size: 22),
                padding: EdgeInsets.zero,
                onPressed: () => widget.onRemove(index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}