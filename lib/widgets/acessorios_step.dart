import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rod_builder_provider.dart';
import 'multi_component_step.dart';

class AcessoriosStep extends StatelessWidget {
  final bool isAdmin;

  const AcessoriosStep({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RodBuilderProvider>();

    return MultiComponentStep(
      isAdmin: isAdmin,
      categoryKey: 'acessorios',
      title: 'Acessório',
      emptyMessage: 'Nenhum acessório selecionado.',
      emptyIcon: Icons.extension_outlined,
      
      items: provider.selectedAcessoriosList,
      
      onAdd: (component, variation) => provider.addAcessorio(component, 1, variation: variation),
      onRemove: (index) => provider.removeAcessorio(index),
      onUpdateQty: (index, qty) => provider.updateAcessorioQty(index, qty),
    );
  }
}