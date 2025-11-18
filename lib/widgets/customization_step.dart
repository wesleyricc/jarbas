import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/rod_builder_provider.dart';

class CustomizationStep extends StatefulWidget {
  const CustomizationStep({super.key});

  @override
  State<CustomizationStep> createState() => _CustomizationStepState();
}

class _CustomizationStepState extends State<CustomizationStep> {
  // Controladores para os campos de texto
  late TextEditingController _corLinhaController;
  late TextEditingController _gravacaoController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<RodBuilderProvider>();
    
    // Inicializa os controladores com os valores do provider
    _corLinhaController = TextEditingController(text: provider.corLinha);
    _gravacaoController = TextEditingController(text: provider.gravacao);

    // Adiciona listeners para atualizar o provider
    _corLinhaController.addListener(() {
      provider.setCorLinha(_corLinhaController.text);
    });
    _gravacaoController.addListener(() {
      provider.setGravacao(_gravacaoController.text);
    });
  }

  @override
  void dispose() {
    _corLinhaController.dispose();
    _gravacaoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usamos Consumer para garantir que os campos sejam limpos se o provider mudar
    return Consumer<RodBuilderProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalhes Finais da Vara',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Campo de Cor da Linha
            TextFormField(
              controller: _corLinhaController,
              decoration: const InputDecoration(labelText: 'Cor da Linha (ex: Vermelho e Preto)'),
            ),
            const SizedBox(height: 16),
            
            // Campo de Gravação
            TextFormField(
              controller: _gravacaoController,
              decoration: const InputDecoration(
                labelText: 'Gravação (Nome ou Frase)',
                //helperText: 'Custo adicional de R\$ 25,00',
              ),
            ),
          ],
        );
      },
    );
  }
}