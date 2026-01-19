import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rod_builder_provider.dart';
import '../models/customer_model.dart';
import '../services/customer_service.dart';
import '../screens/admin_customers_screen.dart'; // Para reutilizar o CustomerFormDialog

class ClientInfoStep extends StatefulWidget {
  const ClientInfoStep({super.key});

  @override
  State<ClientInfoStep> createState() => _ClientInfoStepState();
}

class _ClientInfoStepState extends State<ClientInfoStep> {
  final CustomerService _customerService = CustomerService();
  CustomerModel? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    // Tenta carregar se já houver algo no provider (ex: edição)
    // Note: Isso é básico. Para produção ideal, buscaria pelo ID no provider.
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RodBuilderProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecione o Cliente',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Autocomplete para buscar clientes
          StreamBuilder<List<CustomerModel>>(
            stream: _customerService.getCustomers(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              final customers = snapshot.data!;

              return Column(
                children: [
                  Autocomplete<CustomerModel>(
                    displayStringForOption: (CustomerModel option) => option.name,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        return const Iterable<CustomerModel>.empty();
                      }
                      return customers.where((CustomerModel option) {
                        return option.name
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (CustomerModel selection) {
                      setState(() {
                        _selectedCustomer = selection;
                      });
                      // Atualiza o Provider
                      provider.updateClientInfo(
                        name: selection.name,
                        phone: selection.phone,
                        city: selection.city,
                        state: selection.state,
                        customerId: selection.id,
                      );
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      // Se o provider já tiver nome e o controller estiver vazio, preenche
                      if (textEditingController.text.isEmpty && provider.clientName.isNotEmpty) {
                         textEditingController.text = provider.clientName;
                      }
                      
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Buscar Cliente por Nome',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.person_add),
                            onPressed: () => _showNewCustomerDialog(context, provider, textEditingController),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
          
          // Exibição dos dados do cliente selecionado (Read-only aqui, pois edita no menu de clientes)
          if (provider.clientName.isNotEmpty) ...[
            Card(
              color: Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Cliente Selecionado:", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(provider.clientName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(provider.clientPhone),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('${provider.clientCity} - ${provider.clientState}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
             const Padding(
               padding: EdgeInsets.symmetric(vertical: 20),
               child: Center(child: Text("Nenhum cliente selecionado. Busque acima ou adicione um novo.")),
             ),
          ]
        ],
      ),
    );
  }

  void _showNewCustomerDialog(BuildContext context, RodBuilderProvider provider, TextEditingController autocompleteController) {
    showDialog(
      context: context,
      builder: (context) => CustomerFormDialog(
        onSave: (newCustomer) async {
          // Salva no Firestore
          await _customerService.saveCustomer(newCustomer);
          
          // Precisamos pegar o ID recém criado ou recarregar a lista.
          // Como o saveCustomer gera ID se for vazio, mas a função retorna void, 
          // a melhor UX aqui é fechar e pedir pra buscar, ou refatorar o saveCustomer pra retornar o ID.
          // Pela simplicidade, vamos apenas setar os dados no provider para visualização imediata, 
          // mas o ideal é que o usuário busque o nome recém criado para vincular o ID corretamente se o saveCustomer não retornar ID.
          
          // ATENÇÃO: Para garantir o ID, vou forçar a busca ou assumir que o usuário vai digitar o nome.
          // Vou facilitar preenchendo o campo de busca.
          autocompleteController.text = newCustomer.name;
          
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cliente cadastrado! Selecione-o na lista.')),
          );
        },
      ),
    );
  }
}