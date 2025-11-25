import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/rod_builder_provider.dart';

class CustomizationStep extends StatefulWidget {
  final bool isAdmin;
  const CustomizationStep({super.key, required this.isAdmin});

  @override
  State<CustomizationStep> createState() => _CustomizationStepState();
}

class _CustomizationStepState extends State<CustomizationStep> {
  // Removed: _corLinhaController
  late TextEditingController _gravacaoController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<RodBuilderProvider>();
    _gravacaoController = TextEditingController(text: provider.gravacao);
    _gravacaoController.addListener(() => provider.setGravacao(_gravacaoController.text));
  }

  @override
  void dispose() {
    _gravacaoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RodBuilderProvider>();
    final price = provider.customizationPrice;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.brush, color: Colors.blueGrey[800]),
              const SizedBox(width: 8),
              Text('Detalhes Finais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
            ],
          ),
          const Divider(height: 32),
          
          // REMOVIDO: Campo Cor da Linha
          
          TextFormField(
            controller: _gravacaoController,
            decoration: InputDecoration(
              labelText: 'Gravação (Nome ou Frase)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.text_fields),
              helperText: (widget.isAdmin && price > 0) ? 'Adicional de R\$ ${price.toStringAsFixed(2)}' : null,
              helperStyle: TextStyle(color: (widget.isAdmin && price > 0) ? Colors.orange[800] : Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}