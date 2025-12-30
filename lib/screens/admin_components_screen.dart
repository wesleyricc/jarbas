import 'package:flutter/material.dart';
import '../../../models/component_model.dart';
import '../../../services/component_service.dart';
import 'component_form_screen.dart';
// Removido: import 'admin_settings_screen.dart'; // Não é mais necessário aqui, pois está na Home

class AdminComponentsScreen extends StatefulWidget {
  const AdminComponentsScreen({super.key});

  @override
  State<AdminComponentsScreen> createState() => _AdminComponentsScreenState();
}

class _AdminComponentsScreenState extends State<AdminComponentsScreen> {
  final ComponentService _componentService = ComponentService();
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  String? _selectedCategoryKey; 

  final Map<String, String> _categoriesMap = {
    'blank': 'Blank',
    'cabo': 'Cabo',
    'reel_seat': 'Reel Seat',
    'passadores': 'Passadores',
    'acessorios': 'Acessórios', 
  };

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    // CORREÇÃO: Removemos o AppBar daqui. Quem manda é o AdminHomeScreen.
    return Scaffold(
      // Mantemos o Scaffold apenas para o FloatingActionButton funcionar corretamente
      backgroundColor: Colors.transparent, // Fundo transparente para mesclar com a Home
      body: Column(
        children: [
          // 1. BARRA DE BUSCA
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar componente...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // 2. FILTRO DE CATEGORIAS
          _buildCategoryFilter(),
          
          const Divider(height: 1),

          // 3. LISTA DE ITENS
          Expanded(
            child: StreamBuilder<List<Component>>(
              stream: _componentService.getComponentsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Nenhum componente cadastrado.'));
                }

                List<Component> allComponents = snapshot.data!;

                final filteredComponents = allComponents.where((component) {
                  final matchesSearch = component.name.toLowerCase().contains(_searchQuery.toLowerCase());
                  final matchesCategory = _selectedCategoryKey == null || component.category == _selectedCategoryKey;
                  return matchesSearch && matchesCategory;
                }).toList();

                if (filteredComponents.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('Nenhum item encontrado com este filtro.', style: TextStyle(color: Colors.grey)),
                    ],
                  );
                }

                filteredComponents.sort((a, b) => a.name.compareTo(b.name));

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filteredComponents.length,
                  itemBuilder: (context, index) {
                    final component = filteredComponents[index];
                    return _buildAdminComponentCard(component);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComponentFormScreen()),
          );
        },
        label: const Text('Novo Item'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          _buildCategoryChip(label: 'Todos', key: null),
          ..._categoriesMap.entries.map((entry) {
            return _buildCategoryChip(label: entry.value, key: entry.key);
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({required String label, required String? key}) {
    final isSelected = _selectedCategoryKey == key;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: Colors.blueGrey[800],
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        onSelected: (selected) {
          setState(() {
            _selectedCategoryKey = key; 
          });
        },
      ),
    );
  }

  Widget _buildAdminComponentCard(Component component) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ComponentFormScreen(component: component)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: component.imageUrl.isNotEmpty
                      ? Image.network(
                          component.imageUrl, 
                          fit: BoxFit.cover,
                          errorBuilder: (c,e,s) => const Icon(Icons.broken_image, color: Colors.grey),
                        )
                      : const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      component.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildTag(Icons.inventory_2, '${component.stock} un', 
                          component.stock < 5 ? Colors.red[100]! : Colors.grey[100]!,
                          component.stock < 5 ? Colors.red[800]! : Colors.grey[800]!
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Custo: R\$ ${component.costPrice.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R\$ ${component.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.blueGrey[800]
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(Icons.edit_note, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label, 
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text)
          ),
        ],
      ),
    );
  }
}