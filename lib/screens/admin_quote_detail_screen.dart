import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/quote_model.dart';
import '../models/customer_model.dart'; 
import '../models/component_model.dart'; // Import para buscar componente completo
import '../services/customer_service.dart'; 
import '../services/storage_service.dart';
import '../services/whatsapp_service.dart';
import '../services/quote_service.dart';
import '../services/component_service.dart'; // Import ComponentService
import '../utils/app_constants.dart';
import '../services/pdf_service.dart';
import 'admin_customers_screen.dart';
import 'component_form_screen.dart'; // Import da tela de edição

class AdminQuoteDetailScreen extends StatefulWidget {
  final Quote quote;
  final String quoteId;

  const AdminQuoteDetailScreen({
    super.key, 
    required this.quote, 
    required this.quoteId
  });

  @override
  State<AdminQuoteDetailScreen> createState() => _AdminQuoteDetailScreenState();
}

class _AdminQuoteDetailScreenState extends State<AdminQuoteDetailScreen> {
  late Quote _localQuote;
  bool _isLoading = false;
  bool _isFetchingCosts = false;
  bool _isUploadingImage = false;
  
  late TextEditingController _customizationController;
  double _globalCustomizationPrice = 0.0;

  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final StorageService _storageService = StorageService();
  final QuoteService _quoteService = QuoteService();
  final CustomerService _customerService = CustomerService();
  final ComponentService _componentService = ComponentService(); // Serviço para buscar componente

  final Map<String, String> _sectionCategoryMap = {
    'Blanks': AppConstants.catBlank,
    'Cabos': AppConstants.catCabo,
    'Reel Seats': AppConstants.catReelSeat,
    'Passadores': AppConstants.catPassadores,
    'Acessórios': AppConstants.catAcessorios,
  };

  final Map<String, Color> _statusColors = {
    AppConstants.statusPendente: Colors.orange,
    AppConstants.statusEnviado: Colors.cyan,
    AppConstants.statusAprovado: Colors.blue,
    AppConstants.statusProducao: Colors.purple,
    AppConstants.statusConcluido: Colors.green,
    AppConstants.statusCancelado: Colors.red,
    AppConstants.statusRascunho: Colors.grey,
  };

  final Set<String> _statusesThatDeductStock = {
    AppConstants.statusAprovado,
    AppConstants.statusProducao,
    AppConstants.statusConcluido,
  };

  @override
  void initState() {
    super.initState();
    _localQuote = widget.quote;
    _customizationController = TextEditingController(text: _localQuote.customizationText);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMissingData();
      _fetchSettings(); 
    });
  }

  @override
  void dispose() {
    _customizationController.dispose();
    super.dispose();
  }

  // --- NAVEGAÇÃO PARA EDIÇÃO DO COMPONENTE ---
  Future<void> _editComponent(String componentId) async {
    if (componentId.isEmpty) return;

    // Busca o componente completo atualizado do banco
    Component? comp = await _componentService.getComponentById(componentId);
    
    if (comp != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ComponentFormScreen(component: comp)),
      );
      // Ao voltar, poderíamos recarregar os custos, mas isso alteraria o orçamento
      // sem consentimento. Então apenas recarregamos dados que "faltam" se houver.
      _fetchMissingData();
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Componente não encontrado (pode ter sido excluído).")));
    }
  }

  Future<void> _fetchSettings() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('global_config').get();
      if (!mounted) return; 

      if (doc.exists && doc.data() != null) {
        setState(() {
          _globalCustomizationPrice = (doc.data()!['customizationPrice'] ?? 0.0).toDouble();
        });
        if (_customizationController.text.isNotEmpty) {
          _recalculateTotal(); 
        }
      }
    } catch (e) {
      print("Erro ao buscar configurações: $e");
    }
  }

  Future<void> _fetchMissingData() async {
    if (_isFetchingCosts) return;
    if (mounted) setState(() => _isFetchingCosts = true);

    bool hasUpdates = false;
    final db = FirebaseFirestore.instance;

    Future<void> processList(List<Map<String, dynamic>> items) async {
      for (var item in items) {
        final currentCost = (item['costPrice'] ?? item['cost'] ?? 0.0) as num;
        
        if (item['originalPrice'] == null) {
           item['originalPrice'] = item['price'];
        }

        final currentImage = item['imageUrl'] as String?;
        final hasVariation = item['variation'] != null && item['variation'].toString().isNotEmpty;
        
        bool needsUpdate = (currentCost == 0) || hasVariation;

        if (needsUpdate) {
          try {
            DocumentSnapshot? doc;
            if (item['id'] != null && item['id'].toString().isNotEmpty) {
               doc = await db.collection(AppConstants.colComponents).doc(item['id']).get();
            } else if (item['name'] != null) {
               final query = await db.collection(AppConstants.colComponents)
                   .where('name', isEqualTo: item['name'])
                   .limit(1)
                   .get();
               if (query.docs.isNotEmpty) doc = query.docs.first;
            }

            if (doc != null && doc.exists && doc.data() != null) {
              final data = doc.data() as Map<String, dynamic>;
              
              double baseCost = (data['costPrice'] is num) ? (data['costPrice'] as num).toDouble() : 0.0;
              double finalCost = baseCost;
              String finalImage = data['imageUrl'] ?? '';
              
              final variationName = item['variation'];

              if (variationName != null && variationName.toString().isNotEmpty) {
                List<dynamic> variations = data['variations'] ?? [];
                final variationMatch = variations.firstWhere(
                  (v) => v['name'] == variationName, 
                  orElse: () => null
                );

                if (variationMatch != null) {
                  double vCost = (variationMatch['costPrice'] is num) ? (variationMatch['costPrice'] as num).toDouble() : 0.0;
                  if (vCost > 0) finalCost = vCost;

                  if (variationMatch['imageUrl'] != null && variationMatch['imageUrl'].toString().isNotEmpty) {
                    finalImage = variationMatch['imageUrl'];
                  }
                }
              }

              if (currentCost == 0 && finalCost > 0) {
                item['costPrice'] = finalCost;
                hasUpdates = true;
              }
              
              if (currentImage == null || (hasVariation && finalImage.isNotEmpty && finalImage != currentImage)) {
                  item['imageUrl'] = finalImage;
                  hasUpdates = true;
              }
            }
          } catch (e) {
            print("Erro ao buscar dados: $e");
          }
        } else {
            if (item['costPrice'] == null && item['cost'] != null) {
                item['costPrice'] = item['cost'];
                hasUpdates = true;
            }
        }
      }
    }

    await processList(_localQuote.blanksList);
    await processList(_localQuote.cabosList);
    await processList(_localQuote.reelSeatsList);
    await processList(_localQuote.passadoresList);
    await processList(_localQuote.acessoriosList);

    if (mounted && hasUpdates) {
      setState(() {});
    }
    
    if (mounted) setState(() => _isFetchingCosts = false);
  }

  // --- GERENCIAMENTO DE ESTOQUE ---
  Future<void> _handleStockChange(String oldStatus, String newStatus) async {
    bool oldDeducts = _statusesThatDeductStock.contains(oldStatus);
    bool newDeducts = _statusesThatDeductStock.contains(newStatus);

    if (!oldDeducts && newDeducts) {
      await _processStockTransaction(isDeducting: true);
    }
    else if (oldDeducts && !newDeducts) {
      await _processStockTransaction(isDeducting: false);
    }
  }

  Future<void> _processStockTransaction({required bool isDeducting}) async {
    await _quoteService.updateStockFromQuote(_localQuote, isDeducting: isDeducting);
  }

  // --- LÓGICA DE DUPLICAR ORÇAMENTO ---
  void _showDuplicateDialog() {
    CustomerModel? selectedCustomer;
    bool updatePrices = false;
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Copiar Orçamento"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Selecione o cliente para o novo orçamento:"),
                    const SizedBox(height: 16),
                    
                    // Seletor de Cliente
                    if (selectedCustomer == null)
                       ElevatedButton.icon(
                        icon: const Icon(Icons.person_search),
                        label: const Text("Selecionar Cliente"),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white
                        ),
                        onPressed: () async {
                          // Abre o seletor e espera o retorno
                          final result = await _pickCustomer(context);
                          if (result != null) {
                            setStateDialog(() => selectedCustomer = result);
                          }
                        },
                       )
                    else 
                       ListTile(
                         contentPadding: EdgeInsets.zero,
                         leading: const CircleAvatar(child: Icon(Icons.person)),
                         title: Text(selectedCustomer!.name),
                         subtitle: Text(selectedCustomer!.phone),
                         trailing: IconButton(
                           icon: const Icon(Icons.close, color: Colors.red),
                           onPressed: () => setStateDialog(() => selectedCustomer = null),
                         ),
                       ),

                    const SizedBox(height: 16),
                    const Divider(),
                    CheckboxListTile(
                      title: const Text("Atualizar preços para o valor atual?", style: TextStyle(fontSize: 14)),
                      subtitle: const Text("Se marcado, busca os preços atuais do catálogo.", style: TextStyle(fontSize: 11)),
                      value: updatePrices,
                      onChanged: (val) {
                        setStateDialog(() {
                          updatePrices = val ?? false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text("Criar Cópia"),
                  onPressed: selectedCustomer == null ? null : () async {
                    Navigator.pop(ctx);
                    await _duplicateQuote(selectedCustomer!, updatePrices);
                  },
                )
              ],
            );
          }
        );
      },
    );
  }

  // --- SELETOR DE CLIENTES (COM BOTÃO DE ADICIONAR NOVO) ---
  Future<CustomerModel?> _pickCustomer(BuildContext context) async {
    CustomerModel? picked;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // Título com botão de adicionar
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Buscar Cliente"),
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.blue),
              tooltip: "Cadastrar Novo",
              onPressed: () async {
                 // Abre o formulário de cadastro
                 await showDialog(
                   context: ctx,
                   builder: (c) => CustomerFormDialog(
                     onSave: (newCust) async {
                        await _customerService.saveCustomer(newCust);
                        // Fecha o form
                        Navigator.pop(c);
                        // Feedback
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Cliente cadastrado! Busque pelo nome na lista."))
                        );
                     }
                   )
                 );
              },
            )
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               StreamBuilder<List<CustomerModel>>(
                stream: _customerService.getCustomers(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final customers = snapshot.data!;
                  
                  return Autocomplete<CustomerModel>(
                    displayStringForOption: (option) => option.name,
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text == '') return const Iterable<CustomerModel>.empty();
                      return customers.where((option) => option.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (selection) {
                      picked = selection;
                      Navigator.pop(ctx);
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                       return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Digite o nome...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
                        ),
                       );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: Container(
                            width: 300,
                            constraints: const BoxConstraints(maxHeight: 200),
                            color: Colors.white,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (ctx, index) {
                                final opt = options.elementAt(index);
                                return ListTile(
                                  title: Text(opt.name),
                                  subtitle: Text(opt.phone),
                                  onTap: () => onSelected(opt),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
               )
            ],
          ),
        ),
      )
    );
    return picked;
  }

  Future<void> _duplicateQuote(CustomerModel customer, bool updatePrices) async {
    final messenger = ScaffoldMessenger.of(context);
    
    if (mounted) setState(() => _isLoading = true);
    
    try {
      List<Map<String, dynamic>> newBlanks = _cloneList(_localQuote.blanksList);
      List<Map<String, dynamic>> newCabos = _cloneList(_localQuote.cabosList);
      List<Map<String, dynamic>> newReelSeats = _cloneList(_localQuote.reelSeatsList);
      List<Map<String, dynamic>> newPassadores = _cloneList(_localQuote.passadoresList);
      List<Map<String, dynamic>> newAcessorios = _cloneList(_localQuote.acessoriosList);

      if (updatePrices) {
        await _updateListPrices(newBlanks);
        await _updateListPrices(newCabos);
        await _updateListPrices(newReelSeats);
        await _updateListPrices(newPassadores);
        await _updateListPrices(newAcessorios);
      }

      double customizationCost = (_localQuote.customizationText != null && _localQuote.customizationText!.isNotEmpty) 
          ? _globalCustomizationPrice 
          : 0.0;

      double newTotal = _calculateTotalFromLists([newBlanks, newCabos, newReelSeats, newPassadores, newAcessorios]) 
          + _localQuote.extraLaborCost 
          + customizationCost;
      
      double discountVal = 0.0;
      if (_localQuote.generalDiscountType == 'percent') {
        discountVal = newTotal * (_localQuote.generalDiscount / 100);
      } else {
        discountVal = _localQuote.generalDiscount;
      }
      newTotal -= discountVal;

      final newQuote = Quote(
        userId: _localQuote.userId,
        status: AppConstants.statusRascunho,
        createdAt: Timestamp.now(),
        customerId: customer.id, // VINCULA AO NOVO CLIENTE
        clientName: customer.name,
        clientPhone: customer.phone,
        clientCity: customer.city,
        clientState: customer.state,
        blanksList: newBlanks,
        cabosList: newCabos,
        reelSeatsList: newReelSeats,
        passadoresList: newPassadores,
        acessoriosList: newAcessorios,
        extraLaborCost: _localQuote.extraLaborCost,
        totalPrice: newTotal,
        generalDiscount: _localQuote.generalDiscount,
        generalDiscountType: _localQuote.generalDiscountType,
        customizationText: _localQuote.customizationText,
        finishedImages: [],
      );

      await _quoteService.saveQuote(newQuote);

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Orçamento copiado com sucesso!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text("Erro ao copiar: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _cloneList(List<Map<String, dynamic>> source) {
    return source.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> _updateListPrices(List<Map<String, dynamic>> items) async {
    final db = FirebaseFirestore.instance;
    for (var item in items) {
      if (item['id'] != null && item['id'].toString().isNotEmpty) {
        try {
          final doc = await db.collection(AppConstants.colComponents).doc(item['id']).get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            
            double basePrice = (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0;
            double baseCost = (data['costPrice'] is num) ? (data['costPrice'] as num).toDouble() : 0.0;
            
            double finalPrice = basePrice;
            double finalCost = baseCost;

            final variationName = item['variation'];
            if (variationName != null && variationName.toString().isNotEmpty) {
              List<dynamic> variations = data['variations'] ?? [];
              final variationMatch = variations.firstWhere((v) => v['name'] == variationName, orElse: () => null);

              if (variationMatch != null) {
                double vPrice = (variationMatch['price'] is num) ? (variationMatch['price'] as num).toDouble() : 0.0;
                double vCost = (variationMatch['costPrice'] is num) ? (variationMatch['costPrice'] as num).toDouble() : 0.0;
                
                if (vPrice > 0) finalPrice = vPrice;
                if (vCost > 0) finalCost = vCost; 
                else finalCost = baseCost;
              }
            }

            item['price'] = finalPrice;
            item['originalPrice'] = finalPrice; 
            item['discountInfo'] = null;
            item['costPrice'] = finalCost;
          }
        } catch (e) {
          print("Erro ao atualizar preço do item ${item['name']}: $e");
        }
      }
    }
  }

  double _calculateTotalFromLists(List<List<Map<String, dynamic>>> allLists) {
    double total = 0.0;
    for (var list in allLists) {
      for (var item in list) {
        final qty = (item['quantity'] ?? 1) as int;
        final price = (item['price'] ?? 0.0) as double;
        total += (price * qty);
      }
    }
    return total;
  }

  // --- LÓGICA DE DESCONTO NO ITEM ---
  void _showDiscountDialog(Map<String, dynamic> item, Function() onUpdate) {
    double originalPrice = (item['originalPrice'] ?? item['price'] ?? 0.0).toDouble();
    if (originalPrice == 0) originalPrice = (item['price'] ?? 0.0).toDouble();

    final valueController = TextEditingController();
    
    int selectedMode = 0; 

    if (item['discountInfo'] != null) {
      if (item['discountInfo']['type'] == 'percent') {
        selectedMode = 1;
      } else {
        selectedMode = 0; 
      }
      valueController.text = item['discountInfo']['value'].toString();
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            String labelText = 'Valor do Desconto (R\$)';
            if (selectedMode == 1) labelText = 'Porcentagem (%)';
            if (selectedMode == 2) labelText = 'Valor Final Desejado (R\$)';

            return AlertDialog(
              title: Text("Desconto: ${item['name']}", style: const TextStyle(fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Preço Original: ${_currencyFormat.format(originalPrice)}"),
                  const SizedBox(height: 16),
                  
                  ToggleButtons(
                    borderRadius: BorderRadius.circular(8),
                    isSelected: [selectedMode == 0, selectedMode == 1, selectedMode == 2],
                    onPressed: (index) {
                      setStateDialog(() {
                        selectedMode = index;
                        valueController.clear();
                      });
                    },
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("(-) R\$")),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("%")),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("(=) R\$")),
                    ],
                  ),
                  
                  const SizedBox(height: 16),

                  TextField(
                    controller: valueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: labelText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    item['price'] = originalPrice;
                    item['originalPrice'] = originalPrice;
                    item['discountInfo'] = null;
                    onUpdate();
                    Navigator.pop(ctx);
                  }, 
                  child: const Text("Remover", style: TextStyle(color: Colors.red))
                ),
                ElevatedButton(
                  onPressed: () {
                    double val = double.tryParse(valueController.text.replaceAll(',', '.')) ?? 0.0;
                    if (val < 0) val = 0;

                    double newPrice = originalPrice;
                    String type = 'fixed';
                    double storedValue = val;

                    if (selectedMode == 0) { 
                      if (val > originalPrice) val = originalPrice;
                      newPrice = originalPrice - val;
                      type = 'fixed';
                      storedValue = val;
                    } 
                    else if (selectedMode == 1) { 
                      if (val > 100) val = 100;
                      newPrice = originalPrice - (originalPrice * (val / 100));
                      type = 'percent';
                      storedValue = val;
                    } 
                    else if (selectedMode == 2) { 
                      if (val > originalPrice) val = originalPrice;
                      newPrice = val;
                      type = 'fixed'; 
                      storedValue = originalPrice - val; 
                    }

                    item['originalPrice'] = originalPrice;
                    item['price'] = newPrice;
                    item['discountInfo'] = {
                      'type': type,
                      'value': storedValue
                    };

                    onUpdate();
                    Navigator.pop(ctx);
                  },
                  child: const Text("Aplicar"),
                )
              ],
            );
          }
        );
      }
    );
  }

  // --- LÓGICA DE DESCONTO GERAL ---
  void _showGeneralDiscountDialog() {
    final valueController = TextEditingController();
    
    int selectedMode = _localQuote.generalDiscountType == 'percent' ? 1 : 0;
    valueController.text = _localQuote.generalDiscount.toString();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            String labelText = selectedMode == 1 ? 'Porcentagem (%)' : 'Valor Fixo (R\$)';

            return AlertDialog(
              title: const Text("Desconto Geral no Orçamento", style: TextStyle(fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Este desconto será aplicado sobre o valor total do orçamento."),
                  const SizedBox(height: 16),
                  
                  ToggleButtons(
                    borderRadius: BorderRadius.circular(8),
                    isSelected: [selectedMode == 0, selectedMode == 1],
                    onPressed: (index) {
                      setStateDialog(() {
                        selectedMode = index;
                      });
                    },
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("R\$ (Fixo)")),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("% (Percentual)")),
                    ],
                  ),
                  
                  const SizedBox(height: 16),

                  TextField(
                    controller: valueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: labelText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _localQuote = Quote(
                        id: widget.quoteId, userId: _localQuote.userId, customerId: _localQuote.customerId, status: _localQuote.status, createdAt: _localQuote.createdAt, clientName: _localQuote.clientName, clientPhone: _localQuote.clientPhone, clientCity: _localQuote.clientCity, clientState: _localQuote.clientState,
                        blanksList: _localQuote.blanksList, cabosList: _localQuote.cabosList, reelSeatsList: _localQuote.reelSeatsList, passadoresList: _localQuote.passadoresList, acessoriosList: _localQuote.acessoriosList,
                        extraLaborCost: _localQuote.extraLaborCost, totalPrice: _localQuote.totalPrice, customizationText: _localQuote.customizationText, finishedImages: _localQuote.finishedImages,
                        generalDiscount: 0.0,
                        generalDiscountType: 'fixed'
                      );
                    });
                    _recalculateTotal();
                    Navigator.pop(ctx);
                  }, 
                  child: const Text("Remover", style: TextStyle(color: Colors.red))
                ),
                ElevatedButton(
                  onPressed: () {
                    double val = double.tryParse(valueController.text.replaceAll(',', '.')) ?? 0.0;
                    if (val < 0) val = 0;
                    if (selectedMode == 1 && val > 100) val = 100;

                    setState(() {
                      _localQuote = Quote(
                        id: widget.quoteId, userId: _localQuote.userId, customerId: _localQuote.customerId, status: _localQuote.status, createdAt: _localQuote.createdAt, clientName: _localQuote.clientName, clientPhone: _localQuote.clientPhone, clientCity: _localQuote.clientCity, clientState: _localQuote.clientState,
                        blanksList: _localQuote.blanksList, cabosList: _localQuote.cabosList, reelSeatsList: _localQuote.reelSeatsList, passadoresList: _localQuote.passadoresList, acessoriosList: _localQuote.acessoriosList,
                        extraLaborCost: _localQuote.extraLaborCost, totalPrice: _localQuote.totalPrice, customizationText: _localQuote.customizationText, finishedImages: _localQuote.finishedImages,
                        generalDiscount: val,
                        generalDiscountType: selectedMode == 1 ? 'percent' : 'fixed'
                      );
                    });
                    _recalculateTotal();
                    Navigator.pop(ctx);
                  },
                  child: const Text("Aplicar"),
                )
              ],
            );
          }
        );
      }
    );
  }

  // --- LÓGICA DE EDITAR CLIENTE (ATUALIZADA) ---
  
  // Opção 1: Selecionar um NOVO cliente para este orçamento
  void _selectNewClient() async {
    final CustomerModel? result = await _pickCustomer(context);
    if (result != null) {
      _updateClientFromModel(result);
    }
  }

  // Opção 2: Editar os DADOS do cliente atual (e salvar no banco)
  void _editCurrentClientData() async {
    CustomerModel? currentCustomer;
    
    // Tenta buscar o cliente atual pelo ID ou pelo nome
    if (_localQuote.customerId != null && _localQuote.customerId!.isNotEmpty) {
      currentCustomer = await _customerService.getCustomerById(_localQuote.customerId!);
    }
    
    // Se não achou pelo ID, cria um objeto temporário com os dados do orçamento
    currentCustomer ??= CustomerModel(
      id: _localQuote.customerId ?? '', // Se for vazio, o form criará um novo
      name: _localQuote.clientName,
      phone: _localQuote.clientPhone,
      city: _localQuote.clientCity,
      state: _localQuote.clientState,
      createdAt: Timestamp.now(),
    );

    if (!mounted) return;

    // Abre o Dialog do AdminCustomersScreen reutilizado
    showDialog(
      context: context,
      builder: (context) => CustomerFormDialog(
        customer: currentCustomer,
        onSave: (updatedModel) async {
          // Salva no banco de clientes
          await _customerService.saveCustomer(updatedModel);
          
          // Atualiza os dados no orçamento local
          setState(() {
             _localQuote = Quote(
              id: widget.quoteId, 
              userId: _localQuote.userId, 
              customerId: updatedModel.id.isNotEmpty ? updatedModel.id : _localQuote.customerId, 
              status: _localQuote.status, 
              createdAt: _localQuote.createdAt,
              clientName: updatedModel.name,
              clientPhone: updatedModel.phone,
              clientCity: updatedModel.city,
              clientState: updatedModel.state,
              blanksList: _localQuote.blanksList, 
              cabosList: _localQuote.cabosList, 
              reelSeatsList: _localQuote.reelSeatsList, 
              passadoresList: _localQuote.passadoresList, 
              acessoriosList: _localQuote.acessoriosList,
              extraLaborCost: _localQuote.extraLaborCost, 
              totalPrice: _localQuote.totalPrice, 
              customizationText: _localQuote.customizationText, 
              finishedImages: _localQuote.finishedImages,
              generalDiscount: _localQuote.generalDiscount, 
              generalDiscountType: _localQuote.generalDiscountType
            );
          });
          
          // Salva o orçamento com os novos dados
          await _saveChanges(silent: true);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Dados do cliente atualizados com sucesso!"))
          );
        },
      ),
    );
  }

  void _updateClientFromModel(CustomerModel customer) {
    setState(() {
      _localQuote = Quote(
        id: widget.quoteId, 
        userId: _localQuote.userId, 
        customerId: customer.id, // Atualiza ID do cliente
        status: _localQuote.status, 
        createdAt: _localQuote.createdAt,
        clientName: customer.name,
        clientPhone: customer.phone,
        clientCity: customer.city,
        clientState: customer.state,
        blanksList: _localQuote.blanksList, 
        cabosList: _localQuote.cabosList, 
        reelSeatsList: _localQuote.reelSeatsList, 
        passadoresList: _localQuote.passadoresList, 
        acessoriosList: _localQuote.acessoriosList,
        extraLaborCost: _localQuote.extraLaborCost, 
        totalPrice: _localQuote.totalPrice, 
        customizationText: _localQuote.customizationText, 
        finishedImages: _localQuote.finishedImages,
        generalDiscount: _localQuote.generalDiscount, 
        generalDiscountType: _localQuote.generalDiscountType
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Cliente alterado para: ${customer.name}"), duration: const Duration(seconds: 2))
    );
  }

  // --- UPLOAD IMAGEM ---
  Future<void> _uploadProductionImage() async {
    final messenger = ScaffoldMessenger.of(context);
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        if (mounted) setState(() => _isUploadingImage = true);
        Uint8List bytes = await image.readAsBytes();
        String ext = image.name.split('.').last;
        String fileName = "production_${DateTime.now().millisecondsSinceEpoch}";
        final result = await _storageService.uploadImage(
          fileBytes: bytes,
          fileName: fileName, 
          fileExtension: ext, 
          onProgress: (_) {}
        );
        if (result != null) {
          if (mounted) setState(() { _localQuote.finishedImages.add(result.downloadUrl); });
          await _saveChanges(silent: true);
        }
      }
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text("Erro ao enviar imagem: $e")));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _deleteProductionImage(int index) async {
    setState(() {
      _localQuote.finishedImages.removeAt(index);
    });
    await _saveChanges(silent: true);
  }

  Future<void> _changeStatus() async {
    final messenger = ScaffoldMessenger.of(context);
    final String? newStatus = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Alterar Status', textAlign: TextAlign.center),
          children: _statusColors.keys.map((String status) {
            return SimpleDialogOption(
              onPressed: () { Navigator.pop(context, status); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(color: _statusColors[status]!.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _statusColors[status]!)),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: _statusColors[status], size: 14),
                    const SizedBox(width: 12),
                    Text(status.toUpperCase(), style: TextStyle(color: _statusColors[status], fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      }
    );

    if (newStatus != null && newStatus != _localQuote.status) {
      if (mounted) setState(() => _isLoading = true);
      try {
        await _handleStockChange(_localQuote.status, newStatus);
        if (mounted) {
          setState(() {
            _localQuote = Quote(
              id: widget.quoteId, userId: _localQuote.userId, customerId: _localQuote.customerId, status: newStatus, createdAt: _localQuote.createdAt, clientName: _localQuote.clientName, clientPhone: _localQuote.clientPhone, clientCity: _localQuote.clientCity, clientState: _localQuote.clientState,
              blanksList: _localQuote.blanksList, cabosList: _localQuote.cabosList, reelSeatsList: _localQuote.reelSeatsList, passadoresList: _localQuote.passadoresList, acessoriosList: _localQuote.acessoriosList,
              extraLaborCost: _localQuote.extraLaborCost, totalPrice: _localQuote.totalPrice, customizationText: _localQuote.customizationText, finishedImages: _localQuote.finishedImages,
              generalDiscount: _localQuote.generalDiscount, generalDiscountType: _localQuote.generalDiscountType
            );
          });
        }
        await _saveChanges(silent: false, customMessage: "Status alterado para $newStatus");
      } catch (e) {
        if(mounted) messenger.showSnackBar(SnackBar(content: Text("Erro ao alterar status: $e")));
      } finally {
        if(mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _recalculateTotal() {
    double total = 0.0;
    
    double sumList(List<Map<String, dynamic>> list) {
      return list.fold(0.0, (sum, item) {
        final qty = (item['quantity'] ?? 1) as int;
        final price = (item['price'] ?? 0.0) as double;
        return sum + (price * qty);
      });
    }

    total += sumList(_localQuote.blanksList);
    total += sumList(_localQuote.cabosList);
    total += sumList(_localQuote.reelSeatsList);
    total += sumList(_localQuote.passadoresList);
    total += sumList(_localQuote.acessoriosList);
    total += _localQuote.extraLaborCost;

    if (_customizationController.text.isNotEmpty) {
      total += _globalCustomizationPrice;
    }

    double discountVal = 0.0;
    if (_localQuote.generalDiscountType == 'percent') {
      discountVal = total * (_localQuote.generalDiscount / 100);
    } else {
      discountVal = _localQuote.generalDiscount;
    }
    
    total -= discountVal;
    if (total < 0) total = 0;

    setState(() {
      _localQuote = Quote(
        id: widget.quoteId, userId: _localQuote.userId, customerId: _localQuote.customerId, status: _localQuote.status, createdAt: _localQuote.createdAt,
        clientName: _localQuote.clientName, clientPhone: _localQuote.clientPhone, clientCity: _localQuote.clientCity, clientState: _localQuote.clientState,
        blanksList: _localQuote.blanksList, cabosList: _localQuote.cabosList, reelSeatsList: _localQuote.reelSeatsList, passadoresList: _localQuote.passadoresList, acessoriosList: _localQuote.acessoriosList,
        extraLaborCost: _localQuote.extraLaborCost, totalPrice: total, 
        customizationText: _customizationController.text, 
        finishedImages: _localQuote.finishedImages,
        generalDiscount: _localQuote.generalDiscount,
        generalDiscountType: _localQuote.generalDiscountType
      );
    });
  }

  void _updateQuantity(List<Map<String, dynamic>> list, int index, int delta) {
    setState(() {
      int currentQty = (list[index]['quantity'] ?? 1) as int;
      int newQty = currentQty + delta;
      if (newQty <= 0) {
        list.removeAt(index);
      } else {
        list[index]['quantity'] = newQty;
      }
    });
    _recalculateTotal();
  }

  Future<void> _generatePdf() async {
    setState(() => _isLoading = true);
    try {
      await _saveChanges(silent: true);
      await PdfService.generateAndPrintQuote(_localQuote);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao gerar PDF: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges({bool silent = false, String? customMessage}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!silent) setState(() => _isLoading = true);
    
    // Garante que o total está sincronizado antes de salvar
    _recalculateTotal();

    try {
      await _quoteService.updateQuote(widget.quoteId, _localQuote.toMap());
      if (!mounted) return;
      if (!silent) messenger.showSnackBar(SnackBar(content: Text(customMessage ?? 'Orçamento salvo com sucesso!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareOnWhatsApp() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await WhatsAppService.sendQuoteToClient(_localQuote);
    } catch (e) {
      if(mounted) messenger.showSnackBar(SnackBar(content: Text("Erro WhatsApp: $e")));
    }
  }

  void _showComponentSelector(String title, String category, Function(Map<String, dynamic>) onSelected) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => ComponentSelectorModal(title: title, category: category, onSelected: onSelected),
    );
  }

  void _addNewItem(String sectionTitle, List<Map<String, dynamic>> list) {
    final category = _sectionCategoryMap[sectionTitle];
    if (category == null) return;
    _showComponentSelector(sectionTitle, category, (newItem) {
        setState(() {
          newItem['originalPrice'] = newItem['price'];
          newItem['discountInfo'] = null;
          list.add(newItem);
        });
        _recalculateTotal();
    });
  }

  // --- WIDGETS ---

  Widget _buildProductionGallery() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("FOTOS DA PRODUÇÃO / ENTREGA", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.blueGrey)),
              if (_isUploadingImage) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else IconButton(icon: const Icon(Icons.add_a_photo, color: Colors.blue), onPressed: _uploadProductionImage, tooltip: "Adicionar Foto")
            ],
          ),
          const Divider(),
          if (_localQuote.finishedImages.isEmpty)
            const Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text("Nenhuma foto registrada.", style: TextStyle(color: Colors.grey))))
          else
            GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _localQuote.finishedImages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemBuilder: (context, index) {
                final imgUrl = _localQuote.finishedImages[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: () { showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: InteractiveViewer(child: Image.network(imgUrl)))); },
                      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(imgUrl, fit: BoxFit.cover)),
                    ),
                    Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => _deleteProductionImage(index), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.delete, color: Colors.white, size: 14))))
                  ],
                );
              },
            )
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryCard() {
    double totalCost = 0.0;
    
    double sumCost(List<Map<String, dynamic>> list) {
      return list.fold(0.0, (sum, item) {
        final qty = (item['quantity'] ?? 1) as int;
        final cost = (item['costPrice'] ?? item['cost'] ?? 0.0) as num;
        return sum + (cost.toDouble() * qty);
      });
    }

    totalCost += sumCost(_localQuote.blanksList);
    totalCost += sumCost(_localQuote.cabosList);
    totalCost += sumCost(_localQuote.reelSeatsList);
    totalCost += sumCost(_localQuote.passadoresList);
    totalCost += sumCost(_localQuote.acessoriosList);

    double labor = _localQuote.extraLaborCost;
    double totalSale = _localQuote.totalPrice; 
    
    double profit = totalSale - totalCost; 
    double margin = totalSale > 0 ? (profit / totalSale) * 100 : 0.0;

    double customCost = (_customizationController.text.isNotEmpty) ? _globalCustomizationPrice : 0.0;

    double totalOriginal = 0.0;
    List<Widget> discountWidgets = [];

    void processOriginalList(List<Map<String, dynamic>> list) {
      for (var item in list) {
        final qty = (item['quantity'] ?? 1) as int;
        final price = (item['price'] ?? 0.0) as double;
        final originalPrice = (item['originalPrice'] ?? price).toDouble();
        totalOriginal += (originalPrice * qty);

        if (item['discountInfo'] != null) {
          double discountVal = item['discountInfo']['value'].toDouble();
          String type = item['discountInfo']['type'];
          String label = type == 'percent' ? "${discountVal.toStringAsFixed(0)}%" : _currencyFormat.format(discountVal);
          discountWidgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text("${item['name']} ($label)", style: TextStyle(color: Colors.orange[200], fontSize: 12))),
                  Text("-${_currencyFormat.format((originalPrice - price) * qty)}", style: TextStyle(color: Colors.orange[200], fontSize: 12)),
                ],
              ),
            )
          );
        }
      }
    }

    processOriginalList(_localQuote.blanksList);
    processOriginalList(_localQuote.cabosList);
    processOriginalList(_localQuote.reelSeatsList);
    processOriginalList(_localQuote.passadoresList);
    processOriginalList(_localQuote.acessoriosList);
    
    totalOriginal += labor;
    totalOriginal += customCost;

    double generalDiscountVal = 0.0;
    if (_localQuote.generalDiscount > 0) {
      if (_localQuote.generalDiscountType == 'percent') {
        double subtotal = totalSale / (1 - (_localQuote.generalDiscount / 100));
        generalDiscountVal = subtotal - totalSale;
      } else {
        generalDiscountVal = _localQuote.generalDiscount;
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("RESUMO FINANCEIRO", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2), textAlign: TextAlign.center),
          const Divider(color: Colors.white24, height: 32),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Custo Produtos:", style: TextStyle(color: Colors.white70)),
              Text(_currencyFormat.format(totalCost), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Mão de Obra:", style: TextStyle(color: Colors.white70)),
              Text(_currencyFormat.format(labor), style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          if (customCost > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Personalização (Gravação):", style: TextStyle(color: Colors.white70)),
                Text(_currencyFormat.format(customCost), style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          
          const Divider(color: Colors.white12, height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Tabela (Bruto):", style: TextStyle(color: Colors.white70)),
              Text(_currencyFormat.format(totalOriginal), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            ],
          ),
          
          if (discountWidgets.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text("Descontos em Itens:", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ...discountWidgets,
          ],

          if (generalDiscountVal > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Desconto Geral:", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                Text("-${_currencyFormat.format(generalDiscountVal)}", style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ],

          const Divider(color: Colors.white12, height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("FATURAMENTO FINAL:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_currencyFormat.format(totalSale), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 22)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("LUCRO LÍQUIDO:", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_currencyFormat.format(profit), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 20)),
                    Text("Margem: ${margin.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.blueGrey[800], letterSpacing: 0.5)),
              InkWell(
                onTap: () => _addNewItem(title, items),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle, size: 16, color: Colors.blue[800]),
                      const SizedBox(width: 4),
                      Text("ADICIONAR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
        
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: items.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(20.0),
                child: Center(child: Text("Nenhum item adicionado.", style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic))),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final qty = (item['quantity'] ?? 1) as int;
                  final price = (item['price'] ?? 0.0) as double;
                  final cost = (item['costPrice'] ?? item['cost'] ?? 0.0) as double;
                  final originalPrice = (item['originalPrice'] ?? price).toDouble();
                  final hasDiscount = item['discountInfo'] != null;
                  
                  final totalItemSale = price * qty;
                  final totalItemCost = cost * qty;
                  
                  final itemProfit = totalItemSale - totalItemCost;
                  final itemMargin = totalItemSale > 0 ? (itemProfit / totalItemSale) * 100 : 0.0;

                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 70, height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            image: (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty)
                              ? DecorationImage(image: NetworkImage(item['imageUrl']), fit: BoxFit.cover)
                              : null, 
                          ),
                          child: (item['imageUrl'] == null || item['imageUrl'].toString().isEmpty) 
                            ? const Icon(Icons.image, color: Colors.grey) 
                            : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // LINHA DO NOME COM BOTÃO DE EDIÇÃO
                              Row(
                                children: [
                                  Expanded(child: Text(item['name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87))),
                                  // BOTÃO DE EDIÇÃO RÁPIDA
                                  IconButton(
                                    icon: const Icon(Icons.edit_note, size: 20, color: Colors.blueGrey),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: "Editar Cadastro do Componente",
                                    onPressed: () => _editComponent(item['id']),
                                  ),
                                ],
                              ),

                              if (item['variation'] != null)
                                Text("${item['variation']}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              const SizedBox(height: 4),
                              
                              Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(6)),
                                child: Column(
                                  children: [
                                    _buildCompactFinanceRow("Custo Unit.", cost, Colors.red[700]!),
                                    _buildCompactFinanceRow("Venda Unit.", price, Colors.black87),
                                    Divider(height: 8, color: Colors.grey[300]),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("Margem:", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                        Text("${itemMargin.toStringAsFixed(0)}%", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[700])),
                                      ],
                                    )
                                  ],
                                ),
                              ),

                              InkWell(
                                onTap: () => _showDiscountDialog(item, () {
                                  setState(() {});
                                  _recalculateTotal();
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: hasDiscount ? Colors.red[50] : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: hasDiscount ? Colors.red : Colors.grey)
                                  ),
                                  child: Text(
                                    hasDiscount ? "Desconto Aplicado" : "Adicionar Desconto",
                                    style: TextStyle(fontSize: 10, color: hasDiscount ? Colors.red : Colors.grey[800], fontWeight: FontWeight.bold)
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (hasDiscount)
                              Text(_currencyFormat.format(originalPrice * qty), style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 12)),
                            
                            Text(_currencyFormat.format(totalItemSale), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black)),
                            Text("Custo: ${_currencyFormat.format(totalItemCost)}", style: TextStyle(fontSize: 10, color: Colors.red[300])),
                            
                            const SizedBox(height: 8),
                            Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300)
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(qty == 1 ? Icons.delete_outline : Icons.remove, size: 18, color: qty == 1 ? Colors.red : Colors.grey[700]),
                                    onPressed: () => _updateQuantity(items, index, -1),
                                  ),
                                  Text("$qty", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(Icons.add, size: 18, color: Colors.green[700]),
                                    onPressed: () => _updateQuantity(items, index, 1),
                                  ),
                                ],
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildCompactFinanceRow(String label, double val, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(_currencyFormat.format(val), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = _statusColors[_localQuote.status] ?? Colors.grey;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text('Detalhes do Orçamento', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.blueGrey),
            onPressed: _showDuplicateDialog,
            tooltip: 'Copiar para novo Cliente',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            onPressed: _generatePdf,
            tooltip: 'Gerar PDF',
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.green),
            onPressed: _shareOnWhatsApp,
            tooltip: 'Enviar para Cliente',
          ),
          TextButton.icon(
            onPressed: () => _saveChanges(),
            icon: const Icon(Icons.check_circle, color: Colors.blue),
            label: const Text("SALVAR", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_localQuote.clientName.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
                            
                            // --- MENU DE AÇÕES DO CLIENTE ---
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey),
                              tooltip: 'Opções do Cliente',
                              onSelected: (String result) {
                                if (result == 'edit_data') {
                                  _editCurrentClientData();
                                } else if (result == 'select_new') {
                                  _selectNewClient();
                                }
                              },
                              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'edit_data',
                                  child: Row(children: [Icon(Icons.edit_note, size: 20), SizedBox(width: 10), Text('Alterar Dados do Cliente')]),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'select_new',
                                  child: Row(children: [Icon(Icons.person_search, size: 20), SizedBox(width: 10), Text('Selecionar Outro Cliente')]),
                                ),
                              ],
                            ),
                            
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _changeStatus,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withOpacity(0.5))),
                                child: Text(_localQuote.status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                              ),
                            )
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(_localQuote.clientPhone, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black45)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text("${_localQuote.clientCity} - ${_localQuote.clientState}", style: const TextStyle(fontSize: 15, color: Colors.black45)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(DateFormat("'Criado em:' dd/MM/yyyy 'às' HH:mm").format(_localQuote.createdAt.toDate()), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  _buildSection("Blanks", _localQuote.blanksList),
                  _buildSection("Cabos", _localQuote.cabosList),
                  _buildSection("Reel Seats", _localQuote.reelSeatsList),
                  _buildSection("Passadores", _localQuote.passadoresList),
                  _buildSection("Acessórios", _localQuote.acessoriosList),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 32, 4, 8),
                    child: Text("SERVIÇOS & NOTAS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.blueGrey[800])),
                  ),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.handyman, color: Colors.orange)),
                            const SizedBox(width: 16),
                            const Expanded(child: Text("Mão de Obra (Montagem)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                            SizedBox(
                              width: 100,
                              child: TextFormField(
                                initialValue: _localQuote.extraLaborCost.toStringAsFixed(2),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                decoration: const InputDecoration(border: InputBorder.none, prefixText: "R\$ "),
                                onChanged: (val) {
                                  setState(() {
                                    _localQuote = Quote(
                                      id: widget.quoteId, userId: _localQuote.userId, customerId: _localQuote.customerId, status: _localQuote.status, createdAt: _localQuote.createdAt, clientName: _localQuote.clientName, clientPhone: _localQuote.clientPhone, clientCity: _localQuote.clientCity, clientState: _localQuote.clientState,
                                      blanksList: _localQuote.blanksList, cabosList: _localQuote.cabosList, reelSeatsList: _localQuote.reelSeatsList, passadoresList: _localQuote.passadoresList, acessoriosList: _localQuote.acessoriosList,
                                      extraLaborCost: double.tryParse(val.replaceAll(',', '.')) ?? 0.0,
                                      totalPrice: _localQuote.totalPrice, customizationText: _localQuote.customizationText, 
                                      finishedImages: _localQuote.finishedImages,
                                      generalDiscount: _localQuote.generalDiscount, generalDiscountType: _localQuote.generalDiscountType
                                    );
                                  });
                                  _recalculateTotal();
                                },
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _showGeneralDiscountDialog,
                          child: Row(
                            children: [
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.discount, color: Colors.red)),
                              const SizedBox(width: 16),
                              const Expanded(child: Text("Desconto Geral", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                              Text(
                                _localQuote.generalDiscount > 0 
                                  ? "- ${_localQuote.generalDiscountType == 'percent' ? '${_localQuote.generalDiscount}%' : _currencyFormat.format(_localQuote.generalDiscount)}"
                                  : "Adicionar",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _localQuote.generalDiscount > 0 ? Colors.red : Colors.grey),
                              )
                            ],
                          ),
                        ),
                        const Divider(height: 30),
                        TextField(
                          controller: _customizationController,
                          maxLines: 5,
                          style: const TextStyle(color: Colors.black87, fontSize: 15),
                          onChanged: (val) {
                             _recalculateTotal();
                          },
                          decoration: InputDecoration(
                            labelText: 'Notas de Customização',
                            labelStyle: TextStyle(color: Colors.grey[600]),
                            alignLabelWithHint: true,
                            border: const OutlineInputBorder(),
                            fillColor: Colors.grey[50],
                            filled: true
                          ),
                        ),
                      ],
                    ),
                  ),

                  _buildFinancialSummaryCard(),
                  _buildProductionGallery(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

class ComponentSelectorModal extends StatefulWidget {
  final String title;
  final String category;
  final Function(Map<String, dynamic>) onSelected;

  const ComponentSelectorModal({super.key, required this.title, required this.category, required this.onSelected});

  @override
  State<ComponentSelectorModal> createState() => _ComponentSelectorModalState();
}

class _ComponentSelectorModalState extends State<ComponentSelectorModal> {
  String _searchQuery = '';
  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    Expanded(child: Text("Adicionar ${widget.title}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center)),
                    const SizedBox(width: 48), 
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Buscar componente...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14)
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(AppConstants.colComponents)
                      .where('category', isEqualTo: widget.category)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("Nenhum componente encontrado."));
                    }

                    final allDocs = snapshot.data!.docs;
                    final filteredDocs = allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      return _searchQuery.isEmpty || name.contains(_searchQuery);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return const Center(child: Text("Nenhum resultado para a busca."));
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredDocs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final data = filteredDocs[index].data() as Map<String, dynamic>;
                        
                        List<dynamic> variations = [];
                        if (data['variations'] != null && data['variations'] is List) {
                          variations = data['variations'] as List<dynamic>;
                        }

                        final hasVariations = variations.isNotEmpty;
                        
                        final basePrice = (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0;
                        final baseCost = (data['costPrice'] is num) ? (data['costPrice'] as num).toDouble() : 0.0;

                        return ExpansionTile(
                          shape: Border.all(color: Colors.transparent),
                          leading: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              image: (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty)
                                ? DecorationImage(image: NetworkImage(data['imageUrl']), fit: BoxFit.cover)
                                : null,
                            ),
                            child: (data['imageUrl'] == null || data['imageUrl'].toString().isEmpty) 
                                ? const Icon(Icons.image_not_supported, color: Colors.grey) : null,
                          ),
                          title: Text(data['name'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                          subtitle: Text("R\$ ${_currencyFormat.format(basePrice).replaceAll('R\$', '')}  •  Est: ${data['stock'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black45)),
                          children: [
                            ListTile(
                              title: const Text("Selecionar Padrão", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                              trailing: const Icon(Icons.add_circle_outline, color: Colors.blue),
                              onTap: () {
                                widget.onSelected({
                                  'id': filteredDocs[index].id,
                                  'name': data['name'],
                                  'variation': null,
                                  'price': basePrice,
                                  'costPrice': baseCost,
                                  'imageUrl': data['imageUrl'],
                                  'quantity': 1,
                                });
                                Navigator.pop(context);
                              },
                            ),
                            if (hasVariations)
                              ...variations.map((v) {
                                final vMap = v as Map<String, dynamic>;
                                final vName = vMap['name'] ?? '';
                                final vPrice = (vMap['price'] is num && (vMap['price'] as num) > 0) 
                                    ? (vMap['price'] as num).toDouble() : basePrice;
                                
                                double vCostRaw = (vMap['costPrice'] is num) ? (vMap['costPrice'] as num).toDouble() : 0.0;
                                final vCost = (vCostRaw > 0) ? vCostRaw : baseCost;

                                final vImg = vMap['imageUrl']; 
                                final hasVarImg = vImg != null && vImg.toString().isNotEmpty;
                                final selectedImg = hasVarImg ? vImg : data['imageUrl'];
                                
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.only(left: 20, right: 16),
                                  leading: hasVarImg 
                                    ? Container(
                                        width: 32, height: 32, 
                                        decoration: BoxDecoration(
                                           borderRadius: BorderRadius.circular(4),
                                           image: DecorationImage(image: NetworkImage(vImg), fit: BoxFit.cover)
                                        )
                                      )
                                    : const Icon(Icons.subdirectory_arrow_right, size: 16),
                                  title: Text(vName, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                                  trailing: Text(_currencyFormat.format(vPrice), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black45)),
                                  onTap: () {
                                    widget.onSelected({
                                      'id': filteredDocs[index].id,
                                      'name': "${data['name']} ($vName)",
                                      'variation': vName,
                                      'price': vPrice,
                                      'costPrice': vCost,
                                      'imageUrl': selectedImg, 
                                      'quantity': 1,
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              }).toList()
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}