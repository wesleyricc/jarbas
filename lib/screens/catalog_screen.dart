import 'package:flutter/material.dart';
import '../models/component_model.dart';
import '../services/component_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../utils/app_constants.dart'; // Import Constantes
import 'component_form_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final ComponentService _componentService = ComponentService();
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  String? _selectedCategoryKey;

  late Future<bool> _isAdminFuture;

  @override
  void initState() {
    super.initState();
    _isAdminFuture = _getAdminStatus();
  }

  Future<bool> _getAdminStatus() async {
    final user = _authService.currentUser;
    if (user == null) return false;
    return await _userService.isAdmin(user);
  }

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
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image, color: Colors.white, size: 50),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.5)
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
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
    return FutureBuilder<bool>(
      future: _isAdminFuture,
      builder: (context, adminSnapshot) {
        if (adminSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final bool isAdmin = adminSnapshot.data ?? false;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Catálogo de Componentes'),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Adicionar Componente',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ComponentFormScreen(),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              _buildCategoryFilter(),
              
              Expanded(
                child: StreamBuilder<List<Component>>(
                  stream: _selectedCategoryKey == null
                      ? _componentService.getComponentsStream()
                      : _componentService.getComponentsByCategoryStream(_selectedCategoryKey!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Erro: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Nenhum componente encontrado.'));
                    }

                    List<Component> components = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: components.length,
                      itemBuilder: (context, index) {
                        Component component = components[index];
                        return _buildComponentCard(component, isAdmin);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Botão Todos (Não vem do AppConstants)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: const Text('Todos'),
              selected: _selectedCategoryKey == null,
              selectedColor: Colors.blueGrey[800],
              labelStyle: TextStyle(
                color: _selectedCategoryKey == null ? Colors.white : Colors.black, // Correção visual
                fontWeight: _selectedCategoryKey == null ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (selected) {
                setState(() { _selectedCategoryKey = null; });
              },
            ),
          ),
          // Botões de Categoria via AppConstants
          ...AppConstants.categoryLabels.entries.map((entry) {
            final categoryKey = entry.key;
            final categoryName = entry.value;
            final isSelected = _selectedCategoryKey == categoryKey;
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ChoiceChip(
                label: Text(categoryName),
                selected: isSelected,
                selectedColor: Colors.blueGrey[800],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black, // Correção visual
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  setState(() { _selectedCategoryKey = selected ? categoryKey : null; });
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildComponentCard(Component component, bool isAdmin) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: isAdmin
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ComponentFormScreen(component: component),
                  ),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (component.imageUrl.isNotEmpty) {
                    _showImageDialog(context, component.imageUrl);
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: component.imageUrl.isNotEmpty
                      ? Image.network(
                          component.imageUrl, 
                          fit: BoxFit.cover, 
                          errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey[400])
                        )
                      : Icon(Icons.image_not_supported, color: Colors.grey[400]),
                  ),
                ),
              ),

              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      component.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      component.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    if (isAdmin)
                      Text(
                        'R\$ ${component.price.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
                      ),
                  ],
                ),
              ),
              if (isAdmin)
                Icon(Icons.edit_note_outlined, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }
}