import 'package:flutter/material.dart';
import '../models/component_model.dart';
import '../services/component_service.dart';
import 'component_form_screen.dart'; // Importa a tela de edição reutilizável

class AdminLowStockScreen extends StatefulWidget {
  const AdminLowStockScreen({super.key});

  @override
  State<AdminLowStockScreen> createState() => _AdminLowStockScreenState();
}

class _AdminLowStockScreenState extends State<AdminLowStockScreen> {
  final ComponentService _componentService = ComponentService();
  int _threshold = 3; // Limite padrão

  // Redireciona para a tela de formulário padrão
  void _editComponent(Component component) {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (c) => ComponentFormScreen(component: component))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Alerta de Estoque (Baixa Rápida)"),
        backgroundColor: Colors.amber[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filtro de Limite
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.filter_alt, color: Colors.blueGrey[700]),
                const SizedBox(width: 8),
                const Text("Exibir itens com estoque abaixo de: ", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _threshold,
                  underline: Container(height: 2, color: Colors.amber),
                  style: TextStyle(color: Colors.blueGrey[900], fontWeight: FontWeight.bold),
                  items: [1, 3, 5, 10, 20].map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _threshold = val);
                  },
                )
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<Component>>(
              stream: _componentService.getLowStockComponentsStream(threshold: _threshold),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
                        const SizedBox(height: 16),
                        Text("Tudo certo!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
                        Text("Nenhum item abaixo de $_threshold unidades.", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                // Ordena por estoque (menor para maior) para priorizar os críticos
                items.sort((a, b) => a.stock.compareTo(b.stock));

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final comp = items[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          width: 50, height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.warning_amber_rounded, color: Colors.red[800], size: 28),
                        ),
                        title: Text(comp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Estoque Total: ${comp.stock}", style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold, fontSize: 14)),
                              if (comp.variations.isNotEmpty)
                                Text(
                                  "Variações críticas: ${_getLowVariations(comp)}",
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                )
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
                          tooltip: "Editar Estoque",
                          onPressed: () => _editComponent(comp),
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
    );
  }

  // Helper para mostrar quais variações estão baixas
  String _getLowVariations(Component c) {
    final low = c.variations.entries.where((e) => e.value <= _threshold).map((e) => "${e.key}: ${e.value}").join(", ");
    return low.isEmpty ? "Variações OK" : low;
  }
}