import 'package:flutter/material.dart';
import '../../../models/component_model.dart';
import '../../../services/component_service.dart';
import 'component_form_screen.dart';

class AdminComponentsScreen extends StatefulWidget {
  const AdminComponentsScreen({super.key});

  @override
  State<AdminComponentsScreen> createState() => _AdminComponentsScreenState();
}

class _AdminComponentsScreenState extends State<AdminComponentsScreen> {
  final ComponentService _componentService = ComponentService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // --- ATUALIZAÇÃO AQUI ---
  // Adicionamos o mapa de categorias aqui também
  final Map<String, String> _categoriesMap = {
    'blank': 'Blank',
    'cabo': 'Cabo',
    'passadores': 'Passadores',
    'reel_seat': 'Reel Seat'
  };
  // --- FIM DA ATUALIZAÇÃO ---

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

  // Helper para buscar o nome amigável (ou retornar a chave se não encontrar)
  String _getCategoryDisplayName(String key) {
    return _categoriesMap[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Campo de Busca
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Filtrar por nome...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          // Lista de Componentes
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

                // 1. APLICAR FILTRO DE BUSCA
                final filteredComponents = allComponents.where((component) {
                  final nameMatches = component.name
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                  return nameMatches;
                }).toList();

                if (filteredComponents.isEmpty) {
                  return const Center(child: Text('Nenhum componente encontrado para esta busca.'));
                }

                // 2. AGRUPAR POR CATEGORIA
                final Map<String, List<Component>> groupedComponents = {};
                for (var component in filteredComponents) {
                  (groupedComponents[component.category] ??= []).add(component);
                }
                
                final sortedCategories = groupedComponents.keys.toList()..sort();

                // 3. CONSTRUIR A LISTA AGRUPADA
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 80.0),
                  itemCount: sortedCategories.length,
                  itemBuilder: (context, index) {
                    final categoryKey = sortedCategories[index];
                    final componentsInCategory = groupedComponents[categoryKey]!;
                    
                    // --- ATUALIZAÇÃO AQUI ---
                    // Busca o nome amigável
                    final categoryDisplayName = _getCategoryDisplayName(categoryKey);
                    // --- FIM DA ATUALIZAÇÃO ---

                    return Card(
                      color: const Color(0xFF2C2C2C),
                      margin: const EdgeInsets.only(bottom: 12.0),
                      child: ExpansionTile(
                        initiallyExpanded: _searchQuery.isNotEmpty, 
                        title: Text(
                          // --- ATUALIZAÇÃO AQUI ---
                          // Usa o nome amigável
                          '${categoryDisplayName.toUpperCase()} (${componentsInCategory.length})',
                          // --- FIM DA ATUALIZAÇÃO ---
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[200]),
                        ),
                        children: componentsInCategory.map((component) {
                          return _buildComponentListTile(component);
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ComponentFormScreen(),
            ),
          );
        },
        tooltip: 'Adicionar Componente',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildComponentListTile(Component component) {
    return Container(
      color: Colors.grey.withOpacity(0.1),
      child: ListTile(
        title: Text(component.name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          'Estoque: ${component.stock}',
          style: TextStyle(color: Colors.grey[400]),
        ),
        trailing: Text(
          'R\$ ${component.price.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ComponentFormScreen(component: component),
            ),
          );
        },
      ),
    );
  }
}