import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart'; // <--- Importante importar
import '../providers/rod_builder_provider.dart';

class ClientInfoStep extends StatefulWidget {
  const ClientInfoStep({super.key});

  @override
  State<ClientInfoStep> createState() => _ClientInfoStepState();
}

class _ClientInfoStepState extends State<ClientInfoStep> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;

  // --- CONFIGURAÇÃO DA MÁSCARA ---
  final maskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####', 
    filter: { "#": RegExp(r'[0-9]') },
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void initState() {
    super.initState();
    final provider = context.read<RodBuilderProvider>();
    _nameController = TextEditingController(text: provider.clientName);
    _phoneController = TextEditingController(text: provider.clientPhone);
    _cityController = TextEditingController(text: provider.clientCity);
    _stateController = TextEditingController(text: provider.clientState);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  void _updateProvider() {
    context.read<RodBuilderProvider>().updateClientInfo(
      name: _nameController.text,
      phone: _phoneController.text, // Salva já formatado ex: (11) 99999-9999
      city: _cityController.text,
      state: _stateController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Seus Dados',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Preencha para podermos entrar em contato.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        
        // Nome
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nome Completo', 
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _updateProvider(),
        ),
        const SizedBox(height: 16),
        
        // Telefone com Máscara
        TextField(
          controller: _phoneController,
          // Mudei para number para abrir o teclado numérico
          keyboardType: TextInputType.number, 
          // AQUI ENTRA A MÁSCARA
          inputFormatters: [maskFormatter], 
          decoration: const InputDecoration(
            labelText: 'Telefone / WhatsApp', 
            hintText: '(DDD) 99999-9999',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone_android),
          ),
          onChanged: (_) => _updateProvider(),
        ),
        const SizedBox(height: 16),
        
        // Cidade e Estado
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Cidade', 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                onChanged: (_) => _updateProvider(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _stateController,
                textCapitalization: TextCapitalization.characters, // Caixa alta automático
                maxLength: 2, // Limita a 2 letras
                decoration: const InputDecoration(
                  labelText: 'UF', 
                  border: OutlineInputBorder(),
                  counterText: '', // Esconde o contador 0/2
                ),
                onChanged: (_) => _updateProvider(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}