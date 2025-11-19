import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../providers/rod_builder_provider.dart';

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

  @override
  void initState() {
    super.initState();
    final provider = context.read<RodBuilderProvider>();
    
    _nameController = TextEditingController(text: provider.clientName);
    _phoneController = TextEditingController(text: provider.clientPhone);
    _cityController = TextEditingController(text: provider.clientCity);
    _stateController = TextEditingController(text: provider.clientState);

    _nameController.addListener(() => provider.setClientName(_nameController.text));
    _phoneController.addListener(() => provider.setClientPhone(_phoneController.text));
    _cityController.addListener(() => provider.setClientCity(_cityController.text));
    _stateController.addListener(() => provider.setClientState(_stateController.text));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Encapsulamos em um Container Branco (Card) para contraste
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white, // Fundo Branco
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!), // Borda sutil
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
              Icon(Icons.person_outline, color: Colors.blueGrey[800]),
              const SizedBox(width: 8),
              Text(
                'Informações de Contato',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[800], // Cor Escura para Contraste
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome Completo',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Telefone (com DDD)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'Cidade',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'UF',
                    counterText: "",
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 2,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(2),
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                    TextInputFormatter.withFunction((oldValue, newValue) => 
                       TextEditingValue(
                          text: newValue.text.toUpperCase(),
                          selection: newValue.selection,
                        ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}