import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/rod_builder_provider.dart';
import '../../../models/component_model.dart';
import 'component_selector.dart';

class AcessoriosStep extends StatefulWidget {
  final bool isAdmin;
  const AcessoriosStep({super.key, required this.isAdmin});

  @override
  State<AcessoriosStep> createState() => _AcessoriosStepState();
}

class _AcessoriosStepState extends State<AcessoriosStep> {
  
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
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Adicionar Acessório", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: ComponentSelector(
                      category: 'acessorios', // Nova Categoria
                      selectedComponent: null,
                      isAdmin: widget.isAdmin,
                      onQuantityChanged: null,
                      onSelect: (component, variation) {
                        if (component != null) {
                          context.read<RodBuilderProvider>().addAcessorio(component, 1, variation: variation);
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
    final provider = context.watch<RodBuilderProvider>();
    final list = provider.selectedAcessoriosList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (list.isEmpty)
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
                Icon(Icons.extension_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text("Nenhum acessório selecionado.", style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = list[index];
              return _buildTile(provider, index, item);
            },
          ),

        const SizedBox(height: 16),

        OutlinedButton.icon(
          onPressed: () => _openAddModal(context),
          icon: const Icon(Icons.add),
          label: const Text("ADICIONAR ACESSÓRIO"),
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

  Widget _buildTile(RodBuilderProvider provider, int index, RodItem item) {
    String displayName = item.component.name;
    if (item.variation != null && item.variation!.isNotEmpty) {
      displayName += " (${item.variation})";
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: item.component.imageUrl.isNotEmpty
                ? Image.network(item.component.imageUrl, width: 40, height: 40, fit: BoxFit.cover)
                : Container(width: 40, height: 40, color: Colors.grey[200], child: const Icon(Icons.image, size: 20, color: Colors.grey)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                if (widget.isAdmin)
                  Text('R\$ ${item.component.price.toStringAsFixed(2)} un', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.grey),
                onPressed: () {
                  if (item.quantity > 1) provider.updateAcessorioQty(index, item.quantity - 1);
                  else provider.removeAcessorio(index);
                },
              ),
              Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
              IconButton(
                icon: Icon(Icons.add_circle_outline, size: 20, color: Colors.blueGrey[700]),
                onPressed: () => provider.updateAcessorioQty(index, item.quantity + 1),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red[700], size: 20),
            onPressed: () => provider.removeAcessorio(index),
          ),
        ],
      ),
    );
  }
}