import 'package:flutter/material.dart';
import '../models/component_model.dart';
import '../services/component_service.dart';

class ComponentSelector extends StatefulWidget {
  final String category;
  final bool isAdmin;
  // Callback modificado: Retorna lista de itens selecionados ao confirmar
  final Function(List<Map<String, dynamic>>)? onMultiSelectConfirm; 
  // Callback antigo (para manter compatibilidade se necessário, mas vamos focar no multi)
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
  String _searchQuery = '';

  // Carrinho Temporário: Lista de {comp: Component, var: String?, qty: int}
  final List<Map<String, dynamic>> _tempSelectedItems = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  // Adiciona item ao carrinho temporário
  void _toggleSelection(Component comp, String? variation) {
    setState(() {
      // Verifica se já existe esse item com essa variação
      final existingIndex = _tempSelectedItems.indexWhere(
        (item) => item['comp'].id == comp.id && item['var'] == variation
      );

      if (existingIndex >= 0) {
        // Se já existe, remove (desmarcar)
        _tempSelectedItems.removeAt(existingIndex);
      } else {
        // Se não existe, adiciona
        _tempSelectedItems.add({
          'comp': comp,
          'var': variation,
          'qty': 1 // Padrão 1
        });
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
        // Barra de Busca
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

        // Lista
        Expanded(
          child: StreamBuilder<List<Component>>(
            stream: _componentService.getComponentsByCategoryStream(widget.category),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Nenhum componente encontrado.'));
              }

              final filteredList = snapshot.data!.where((c) {
                return c.name.toLowerCase().contains(_searchQuery.toLowerCase());
              }).toList();

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filteredList.length,
                separatorBuilder: (c, i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final comp = filteredList[index];
                  return _buildComponentTile(comp);
                },
              );
            },
          ),
        ),

        // Botão de Confirmar (Só aparece se tiver itens selecionados)
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
                  child: Text(
                    "ADICIONAR ${_tempSelectedItems.length} ITEM(NS)",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildComponentTile(Component comp) {
    // Se tiver variações, precisa de lógica extra para não selecionar "o pai" direto
    bool hasVariations = comp.variations.isNotEmpty;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: comp.imageUrl.isNotEmpty
            ? Image.network(comp.imageUrl, width: 40, height: 40, fit: BoxFit.cover)
            : Container(width: 40, height: 40, color: Colors.grey[200], child: const Icon(Icons.image_not_supported, size: 20)),
        ),
        title: Text(comp.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Estoque: ${comp.stock}", 
              style: TextStyle(fontSize: 12, color: comp.stock < 3 ? Colors.red : Colors.grey[600])
            ),
            if (widget.isAdmin)
              Text("Custo: R\$ ${comp.costPrice.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        trailing: hasVariations 
            ? null // Seta padrão do ExpansionTile
            : _buildCheckbox(comp, null), // Checkbox direto se não tiver variação
        
        // Se não tiver variações, o clique no corpo seleciona
        onExpansionChanged: hasVariations ? null : (expanded) {
          _toggleSelection(comp, null);
        },
        
        // Filhos (Variações)
        children: comp.variations.entries.map((entry) {
          final varName = entry.key;
          final varStock = entry.value;
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            title: Text(varName),
            subtitle: Text("Estoque: $varStock"),
            trailing: _buildCheckbox(comp, varName),
            onTap: () => _toggleSelection(comp, varName),
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
      onChanged: (val) {
        _toggleSelection(comp, variation);
      },
    );
  }
}