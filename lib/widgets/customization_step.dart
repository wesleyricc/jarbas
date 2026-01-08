import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rod_builder_provider.dart';

class CustomizationStep extends StatefulWidget {
  final bool isAdmin;
  const CustomizationStep({super.key, required this.isAdmin});

  @override
  State<CustomizationStep> createState() => _CustomizationStepState();
}

class _CustomizationStepState extends State<CustomizationStep> {
  late TextEditingController _textController;
  late TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<RodBuilderProvider>();
    _textController = TextEditingController(text: provider.customizationText);
    _costController = TextEditingController(text: provider.extraLaborCost > 0 ? provider.extraLaborCost.toStringAsFixed(2) : '');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RodBuilderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Detalhes da Personalização',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Descreva cores, trançados, nome para gravação ou qualquer detalhe específico.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _textController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Ex: Gravar nome "João Silva", linha azul metálica...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => provider.setCustomizationText(value),
        ),
        
        // --- CAMPO DE CUSTO EXTRA (SÓ ADMIN) ---
        if (widget.isAdmin) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Custos Adicionais (Admin)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Mão de Obra Extra / Personalização Especial (R\$)',
              prefixText: 'R\$ ',
              border: OutlineInputBorder(),
              helperText: 'Este valor será somado ao total do orçamento.',
            ),
            onChanged: (value) {
              // Converte vírgula para ponto se necessário
              String safeValue = value.replaceAll(',', '.');
              double? cost = double.tryParse(safeValue);
              provider.setExtraLaborCost(cost ?? 0.0);
            },
          ),
        ]
      ],
    );
  }
}