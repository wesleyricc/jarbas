import 'package:flutter/material.dart';
import '../models/component_model.dart';
import '../services/component_service.dart';
import '../utils/app_constants.dart';
import 'component_form_screen.dart';

class AdminComponentsScreen extends StatefulWidget {
  const AdminComponentsScreen({super.key});

  @override
  State<AdminComponentsScreen> createState() => _AdminComponentsScreenState();
}

class _AdminComponentsScreenState extends State<AdminComponentsScreen> {
  final ComponentService _componentService = ComponentService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedFilter = 'todos'; 

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showComponentForm({Component? component}) {
    Navigator.push(context, MaterialPageRoute(builder: (c) => ComponentFormScreen(component: component)));
  }

  void _deleteComponent(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Item?"),
        content: const Text("Esta ação é irreversível."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async { await _componentService.deleteComponent(id); if (mounted) Navigator.pop(ctx); },
            child: const Text("Excluir", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        // CORREÇÃO PARA WEB/PWA: Impede o redimensionamento brusco com o teclado
        resizeToAvoidBottomInset: false, 
        backgroundColor: Colors.grey[50],
        body: Column(
          children: [
            // BARRA SUPERIOR
            Container(
              color: Colors.blueGrey[800],
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip('todos', 'Todos'),
                        const SizedBox(width: 8),
                        ...AppConstants.categoryLabels.entries.map((e) => 
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _buildFilterChip(e.key, e.value),
                          )
                        ).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // LISTA
            Expanded(
              child: StreamBuilder<List<Component>>(
                stream: _componentService.getComponentsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Catálogo vazio."));

                  final filteredList = snapshot.data!.where((c) {
                    bool matchesSearch = c.name.toLowerCase().contains(_searchQuery);
                    bool matchesCategory = _selectedFilter == 'todos' || c.category == _selectedFilter;
                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (filteredList.isEmpty) return const Center(child: Text("Nenhum item encontrado."));

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final comp = filteredList[index];
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                            child: comp.imageUrl.isNotEmpty 
                              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(comp.imageUrl, fit: BoxFit.cover))
                              : const Icon(Icons.image, color: Colors.grey),
                          ),
                          title: Text(comp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Estoque: ${comp.stock}", style: TextStyle(color: comp.stock < 5 ? Colors.red : Colors.grey[600], fontWeight: comp.stock < 5 ? FontWeight.bold : FontWeight.normal)),
                              Text("Venda: R\$ ${comp.price.toStringAsFixed(2)}"),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey), onPressed: () => _showComponentForm(component: comp)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteComponent(comp.id)),
                            ],
                          ),
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
          onPressed: () => _showComponentForm(),
          backgroundColor: Colors.blueGrey[800],
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    bool isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber[700] : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.white30),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: isSelected ? Colors.blueGrey[900] : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      ),
    );
  }
}