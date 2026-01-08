import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rod_builder_provider.dart';
import 'multi_component_step.dart'; // Certifique-se de importar o widget genérico

class PassadoresStep extends StatelessWidget {
  final bool isAdmin;

  const PassadoresStep({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    // Escuta o provider para pegar a lista atualizada
    final provider = context.watch<RodBuilderProvider>();

    return MultiComponentStep(
      isAdmin: isAdmin,
      categoryKey: 'passadores', // Chave para buscar no Firebase
      title: 'Passador',
      emptyMessage: 'Nenhum passador selecionado.',
      emptyIcon: Icons.playlist_add,
      
      // Passa a lista do Provider
      items: provider.selectedPassadoresList,
      
      // Mapeia as ações para os métodos do Provider
      onAdd: (component, variation) => provider.addPassador(component, 1, variation: variation),
      onRemove: (index) => provider.removePassador(index),
      onUpdateQty: (index, qty) => provider.updatePassadorQty(index, qty),
    );
  }
}