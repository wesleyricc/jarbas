import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/rod_builder_provider.dart';

class CustomizationStep extends StatefulWidget {
  final bool isAdmin; // (NOVO) Recebe o status

  const CustomizationStep({super.key, required this.isAdmin});

  @override
  State<CustomizationStep> createState() => _CustomizationStepState();
}

class _CustomizationStepState extends State<CustomizationStep> {
  late TextEditingController _corLinhaController;
  late TextEditingController _gravacaoController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<RodBuilderProvider>();
    
    _corLinhaController = TextEditingController(text: provider.corLinha);
    _gravacaoController = TextEditingController(text: provider.gravacao);

    _corLinhaController.addListener(() => provider.setCorLinha(_corLinhaController.text));
    _gravacaoController.addListener(() => provider.setGravacao(_gravacaoController.text));
  }

  @override
  void dispose() {
    _corLinhaController.dispose();
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.brush, color: Colors.blueGrey[800]),
              const SizedBox(width: 8),
              Text(
                'Detalhes Finais',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[800],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          
          // Campo de Cor da Linha
          TextFormField(
            controller: _corLinhaController,
            decoration: const InputDecoration(
              labelText: 'Cor da Linha',
              hintText: 'Ex: Preto com detalhes Dourados',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.palette_outlined),
            ),
          ),
          const SizedBox(height: 24),
          
          // Campo de Gravação
          TextFormField(
            controller: _gravacaoController,
            decoration: InputDecoration(
              labelText: 'Gravação (Nome ou Frase)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.text_fields),
              
              // --- LÓGICA DE EXIBIÇÃO CONDICIONAL ---
              // Só mostra o preço se for ADMIN. Se for cliente, não mostra nada (null).
              helperText: (widget.isAdmin && price > 0) 
                  ? 'Adicional de R\$ ${price.toStringAsFixed(2)}' 
                  : null,
                  
              helperStyle: TextStyle(
                color: (widget.isAdmin && price > 0) ? Colors.orange[800] : Colors.grey,
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ],
      ),
    );
  }
}