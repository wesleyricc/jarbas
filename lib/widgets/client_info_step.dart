import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // (NOVO) Import para o InputFormatter
import '../../../providers/rod_builder_provider.dart';

class ClientInfoStep extends StatefulWidget {
  const ClientInfoStep({super.key});

  @override
  State<ClientInfoStep> createState() => _ClientInfoStepState();
}

class _ClientInfoStepState extends State<ClientInfoStep> {
  // Controladores de cliente
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<RodBuilderProvider>();
    
    // Inicializa os controladores com os valores do provider
    _nameController = TextEditingController(text: provider.clientName);
    _phoneController = TextEditingController(text: provider.clientPhone);
    _cityController = TextEditingController(text: provider.clientCity);
    _stateController = TextEditingController(text: provider.clientState);

    // Adiciona listeners para atualizar o provider
    _nameController.addListener(() {
      provider.setClientName(_nameController.text);
    });
    _phoneController.addListener(() {
      provider.setClientPhone(_phoneController.text);
    });
    _cityController.addListener(() {
      provider.setClientCity(_cityController.text);
    });
    _stateController.addListener(() {
      provider.setClientState(_stateController.text);
    });
  }

  @override
  void dispose() {
    // Limpa os controladores
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usamos um Consumer para garantir que o widget seja reconstruído
    // se o provider for limpo (clearBuild)
    return Consumer<RodBuilderProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informações de Contato',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome Completo'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Telefone (com DDD)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Row(
              // Usa CrossAxisAlignment.start para alinhar pelo topo
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'Cidade'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'UF',
                      counterText: "", // Remove o contador de espaço
                    ),
                    // --- CORREÇÃO AQUI ---
                    maxLength: 2, // Mantém o maxLength para feedback visual
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(2), // Limita a 2 caracteres
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')), // Permite apenas letras
                      TextInputFormatter.withFunction((oldValue, newValue) => // Força maiúsculas
                         TextEditingValue(
                            text: newValue.text.toUpperCase(),
                            selection: newValue.selection,
                          ),
                      ),
                    ],
                    // --- FIM DA CORREÇÃO ---
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}