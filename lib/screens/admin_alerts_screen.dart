import 'package:flutter/material.dart';
import '../models/component_model.dart';
import '../services/component_service.dart';
import 'component_form_screen.dart';

class AdminAlertsScreen extends StatefulWidget {
  const AdminAlertsScreen({super.key});

  @override
  State<AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends State<AdminAlertsScreen> {
  final ComponentService _compService = ComponentService();
  
  // Estado do Filtro (null = Todos)
  String? _selectedCategory;

  // Mapa de categorias para os Chips
  final Map<String, String> _categoriesMap = {
    'blank': 'Blank',
    'cabo': 'Cabo',
    'reel_seat': 'Reel Seat',
    'passadores': 'Passadores',
    'acessorios': 'Acessórios',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas de Estoque'),
        backgroundColor: Colors.amber[700], // Cor de alerta
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- 1. BARRA DE FILTROS ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _buildCategoryFilter(),
          ),
          const Divider(height: 1),

          // --- 2. LISTA DE ALERTAS ---
          Expanded(
            child: StreamBuilder<List<Component>>(
              stream: _compService.getLowStockComponentsStream(threshold: 3),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                // Dados brutos do Firebase (Todos com estoque baixo)
                List<Component> allLowStock = snapshot.data ?? [];

                // --- LÓGICA DE FILTRAGEM LOCAL ---
                // Filtra a lista baseada na categoria selecionada
                final filteredList = allLowStock.where((comp) {
                  if (_selectedCategory == null) return true; // Mostra tudo
                  return comp.category == _selectedCategory;
                }).toList();

                // Verifica se a lista (filtrada ou total) está vazia
                if (filteredList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedCategory == null ? Icons.check_circle_outline : Icons.filter_alt_off, 
                          size: 80, 
                          color: Colors.grey[300]
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedCategory == null 
                              ? 'Estoque saudável!' 
                              : 'Nenhum alerta em "${_categoriesMap[_selectedCategory]}"',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                // Ordena alfabeticamente
                filteredList.sort((a, b) => a.name.compareTo(b.name));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final comp = filteredList[index];
                    return _buildAlertCard(comp);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // Botão "Todos"
          _buildChoiceChip(label: 'Todos', key: null),
          
          // Categorias do Mapa
          ..._categoriesMap.entries.map((entry) {
            return _buildChoiceChip(label: entry.value, key: entry.key);
          }),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({required String label, required String? key}) {
    final isSelected = _selectedCategory == key;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: Colors.amber[100], // Fundo selecionado (tom de alerta suave)
        backgroundColor: Colors.grey[100],
        labelStyle: TextStyle(
          color: isSelected ? Colors.brown[900] : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: isSelected ? BorderSide(color: Colors.amber[700]!) : BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (selected) {
          setState(() {
            _selectedCategory = key;
          });
        },
      ),
    );
  }

  Widget _buildAlertCard(Component comp) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red[50],
          child: Text(
            '${comp.stock}',
            style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(comp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          _getVariationStockText(comp), 
          style: const TextStyle(fontSize: 12),
          maxLines: 2, overflow: TextOverflow.ellipsis,
        ),
        trailing: TextButton(
          onPressed: () {
            // Vai para a tela de edição para repor estoque
            Navigator.push(context, MaterialPageRoute(builder: (c) => ComponentFormScreen(component: comp)));
          },
          style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
          child: const Text('REPOR'),
        ),
      ),
    );
  }

  String _getVariationStockText(Component c) {
    if (c.variations.isEmpty) return 'Item único';
    
    // Filtra variações com estoque baixo (< 3)
    final lowVars = c.variations.entries
        .where((e) => e.value < 3)
        .map((e) => "${e.key}: ${e.value}")
        .join(", ");
    
    if (lowVars.isEmpty) return 'Estoque total baixo, mas variações ok.';
    return "Críticos: $lowVars";
  }
}