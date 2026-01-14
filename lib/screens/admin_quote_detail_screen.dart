import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../models/quote_model.dart';
import '../services/storage_service.dart';
import '../services/whatsapp_service.dart';
import '../services/quote_service.dart';
import '../utils/app_constants.dart';

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
  
  // CONTROLADOR DE TEXTO
  late TextEditingController _customizationController;

  // PREÇO CONFIGURADO
  double _globalCustomizationPrice = 0.0;

  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final StorageService _storageService = StorageService();
  final QuoteService _quoteService = QuoteService();

  final Map<String, String> _sectionCategoryMap = {
    'Blanks': AppConstants.catBlank,
    'Cabos': AppConstants.catCabo,
    'Reel Seats': AppConstants.catReelSeat,
    'Passadores': AppConstants.catPassadores,
    'Acessórios': AppConstants.catAcessorios,
  };

  final Map<String, Color> _statusColors = {
    AppConstants.statusPendente: Colors.orange,
    AppConstants.statusAprovado: Colors.blue,
    AppConstants.statusProducao: Colors.purple,
    AppConstants.statusConcluido: Colors.green,
    AppConstants.statusCancelado: Colors.red,
    AppConstants.statusRascunho: Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _localQuote = widget.quote;
    
    // INICIALIZA O CONTROLADOR
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

  Future<void> _fetchSettings() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('global_config').get();
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
    setState(() => _isFetchingCosts = true);

    bool hasUpdates = false;
    final db = FirebaseFirestore.instance;

    Future<void> processList(List<Map<String, dynamic>> items) async {
      for (var item in items) {
        final currentCost = (item['costPrice'] ?? item['cost'] ?? 0.0) as num;
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

    if (hasUpdates && mounted) {
      setState(() {});
    }
    
    if (mounted) setState(() => _isFetchingCosts = false);
  }

  // --- LÓGICA DE DUPLICAR ORÇAMENTO ---

  void _showDuplicateDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    
    bool updatePrices = false;

    var phoneMask = MaskTextInputFormatter(
      mask: '(##) #####-####', 
      filter: { "#": RegExp(r'[0-9]') },
      type: MaskAutoCompletionType.lazy
    );
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Copiar Orçamento"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Informe os dados do novo cliente para criar uma cópia deste orçamento."),
                    const SizedBox(height: 16),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nome do Cliente", border: OutlineInputBorder())),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneCtrl, 
                      keyboardType: TextInputType.phone, 
                      inputFormatters: [phoneMask], 
                      decoration: const InputDecoration(labelText: "Telefone", border: OutlineInputBorder())
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: "Cidade", border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        SizedBox(width: 80, child: TextField(controller: stateCtrl, decoration: const InputDecoration(labelText: "UF", border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text("Atualizar preços para o valor atual?", style: TextStyle(fontSize: 14)),
                      subtitle: const Text("Se marcado, busca os preços atuais do catálogo. Se desmarcado, mantém os preços originais.", style: TextStyle(fontSize: 11)),
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
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Informe o nome do cliente.")));
                      return;
                    }
                    Navigator.pop(ctx);
                    await _duplicateQuote(
                      nameCtrl.text, 
                      phoneCtrl.text, 
                      cityCtrl.text, 
                      stateCtrl.text, 
                      updatePrices
                    );
                  },
                )
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _duplicateQuote(String name, String phone, String city, String state, bool updatePrices) async {
    setState(() => _isLoading = true);
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

      final newQuote = Quote(
        userId: _localQuote.userId,
        status: AppConstants.statusRascunho,
        createdAt: Timestamp.now(),
        clientName: name,
        clientPhone: phone,
        clientCity: city,
        clientState: state,
        blanksList: newBlanks,
        cabosList: newCabos,
        reelSeatsList: newReelSeats,
        passadoresList: newPassadores,
        acessoriosList: newAcessorios,
        extraLaborCost: _localQuote.extraLaborCost,
        totalPrice: newTotal,
        customizationText: _localQuote.customizationText,
        finishedImages: [],
      );

      await _quoteService.saveQuote(newQuote);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Orçamento copiado com sucesso!"), backgroundColor: Colors.green)
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao copiar: $e"), backgroundColor: Colors.red));
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
              final variationMatch = variations.firstWhere(
                (v) => v['name'] == variationName, 
                orElse: () => null
              );

              if (variationMatch != null) {
                double vPrice = (variationMatch['price'] is num) ? (variationMatch['price'] as num).toDouble() : 0.0;
                double vCost = (variationMatch['costPrice'] is num) ? (variationMatch['costPrice'] as num).toDouble() : 0.0;
                
                if (vPrice > 0) finalPrice = vPrice;
                if (vCost > 0) finalCost = vCost; 
                else finalCost = baseCost;
              }
            }

            item['price'] = finalPrice;
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

  // --- LÓGICA DE EDITAR CLIENTE ---

  void _showEditClientDialog() {
    final nameCtrl = TextEditingController(text: _localQuote.clientName);
    final phoneCtrl = TextEditingController(text: _localQuote.clientPhone);
    final cityCtrl = TextEditingController(text: _localQuote.clientCity);
    final stateCtrl = TextEditingController(text: _localQuote.clientState);

    var phoneMask = MaskTextInputFormatter(
      mask: '(##) #####-####', 
      filter: { "#": RegExp(r'[0-9]') },
      type: MaskAutoCompletionType.lazy
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Editar Dados do Cliente"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Nome do Cliente", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [phoneMask],
                decoration: const InputDecoration(labelText: "Telefone", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(labelText: "Cidade", border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: stateCtrl,
                      decoration: const InputDecoration(labelText: "UF", border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("O nome é obrigatório.")));
                return;
              }
              _updateClientData(
                name: nameCtrl.text,
                phone: phoneCtrl.text,
                city: cityCtrl.text,
                state: stateCtrl.text,
              );
              Navigator.pop(ctx);
            },
            child: const Text("Atualizar"),
          )
        ],
      ),
    );
  }

  // --- UPLOAD IMAGEM ---
  Future<void> _uploadProductionImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() => _isUploadingImage = true);
        
        Uint8List bytes = await image.readAsBytes();
        String ext = image.name.split('.').last;
        String fileName = "production_${DateTime.now().millisecondsSinceEpoch}";

        final result = await _storageService.uploadImage(
          fileBytes: bytes, 
          fileName: fileName, 
          fileExtension: ext,
          //folder: 'quotes/${widget.quoteId}/finished',
          onProgress: (_) {}
        );

        if (result != null) {
          setState(() {
            _localQuote.finishedImages.add(result.downloadUrl);
          });
          await _saveChanges(silent: true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao enviar imagem: $e")));
      }
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

  // --- STATUS ---
  Future<void> _changeStatus() async {
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
                decoration: BoxDecoration(
                  color: _statusColors[status]!.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _statusColors[status]!),
                ),
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
      setState(() {
        _localQuote = Quote(
          id: widget.quoteId, userId: _localQuote.userId, status: newStatus, createdAt: _localQuote.createdAt,
          clientName: _localQuote.clientName, clientPhone: _localQuote.clientPhone, clientCity: _localQuote.clientCity, clientState: _localQuote.clientState,
          blanksList: _localQuote.blanksList, cabosList: _localQuote.cabosList, reelSeatsList: _localQuote.reelSeatsList, passadoresList: _localQuote.passadoresList, acessoriosList: _localQuote.acessoriosList,
          extraLaborCost: _localQuote.extraLaborCost, totalPrice: _localQuote.totalPrice, customizationText: _localQuote.customizationText, 
          finishedImages: _localQuote.finishedImages,
        );
      });
      await _saveChanges(silent: false, customMessage: "Status alterado para $newStatus");
    }
  }

  void _updateClientData({String? name, String? phone, String? city, String? state}) {
    setState(() {
      _localQuote = Quote(
        id: widget.quoteId, userId: _localQuote.userId, status: _localQuote.status, createdAt: _localQuote.createdAt,
        clientName: name ?? _localQuote.clientName,
        clientPhone: phone ?? _localQuote.clientPhone,
        clientCity: city ?? _localQuote.clientCity,
        clientState: state ?? _localQuote.clientState,
        blanksList: _localQuote.blanksList, cabosList: _localQuote.cabosList, reelSeatsList: _localQuote.reelSeatsList, passadoresList: _localQuote.passadoresList, acessoriosList: _localQuote.acessoriosList,
        extraLaborCost: _localQuote.extraLaborCost, totalPrice: _localQuote.totalPrice, customizationText: _localQuote.customizationText, finishedImages: _localQuote.finishedImages,
      );
    });
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

    setState(() {
      _localQuote = Quote(
        id: widget.quoteId, userId: _localQuote.userId, status: _localQuote.status, createdAt: _localQuote.createdAt,
        clientName: _localQuote.clientName, clientPhone: _localQuote.clientPhone, clientCity: _localQuote.clientCity, clientState: _localQuote.clientState,
        blanksList: _localQuote.blanksList, cabosList: _localQuote.cabosList, reelSeatsList: _localQuote.reelSeatsList, passadoresList: _localQuote.passadoresList, acessoriosList: _localQuote.acessoriosList,
        extraLaborCost: _localQuote.extraLaborCost, totalPrice: total, 
        customizationText: _customizationController.text, 
        finishedImages: _localQuote.finishedImages,
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

  Future<void> _saveChanges({bool silent = false, String? customMessage}) async {
    if (!silent) setState(() => _isLoading = true);
    
    _localQuote = Quote(
      id: widget.quoteId, userId: _localQuote.userId, status: _localQuote.status, createdAt: _localQuote.createdAt,
      clientName: _localQuote.clientName, clientPhone: _localQuote.clientPhone, clientCity: _localQuote.clientCity, clientState: _localQuote.clientState,
      blanksList: _localQuote.blanksList, cabosList: _localQuote.cabosList, reelSeatsList: _localQuote.reelSeatsList, passadoresList: _localQuote.passadoresList, acessoriosList: _localQuote.acessoriosList,
      extraLaborCost: _localQuote.extraLaborCost, totalPrice: _localQuote.totalPrice, 
      customizationText: _customizationController.text, // Garante que salva o que está no campo
      finishedImages: _localQuote.finishedImages,
    );

    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.colQuotes) 
          .doc(widget.quoteId)
          .update(_localQuote.toMap());

      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(customMessage ?? 'Orçamento salvo com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareOnWhatsApp() async {
    try {
      await WhatsAppService.sendQuoteToClient(_localQuote);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro WhatsApp: $e")));
    }
  }

  void _showComponentSelector(String title, String category, Function(Map<String, dynamic>) onSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ComponentSelectorModal(
        title: title, 
        category: category, 
        onSelected: onSelected
      ),
    );
  }

  void _addNewItem(String sectionTitle, List<Map<String, dynamic>> list) {
    final category = _sectionCategoryMap[sectionTitle];
    if (category == null) return;

    _showComponentSelector(sectionTitle, category, (newItem) {
        setState(() {
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("FOTOS DA PRODUÇÃO / ENTREGA", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.blueGrey)),
              if (_isUploadingImage)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: const Icon(Icons.add_a_photo, color: Colors.blue),
                  onPressed: _uploadProductionImage,
                  tooltip: "Adicionar Foto",
                )
            ],
          ),
          const Divider(),
          if (_localQuote.finishedImages.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text("Nenhuma foto registrada.", style: TextStyle(color: Colors.grey))),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _localQuote.finishedImages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, 
                crossAxisSpacing: 8, 
                mainAxisSpacing: 8
              ),
              itemBuilder: (context, index) {
                final imgUrl = _localQuote.finishedImages[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: () {
                        showDialog(context: context, builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: InteractiveViewer(child: Image.network(imgUrl)),
                        ));
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(imgUrl, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => _deleteProductionImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.delete, color: Colors.white, size: 14),
                        ),
                      ),
                    )
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

    double customCost = (_customizationController.text.isNotEmpty) 
        ? _globalCustomizationPrice 
        : 0.0;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               const Icon(Icons.analytics_outlined, color: Colors.white70, size: 20),
               const SizedBox(width: 8),
               const Text("RESUMO FINANCEIRO FINAL", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
               if (_isFetchingCosts) ...[
                 const SizedBox(width: 12),
                 const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
               ]
            ],
          ),
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
              const Text("FATURAMENTO TOTAL:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(_currencyFormat.format(totalSale), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18)),
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
                              Text(item['name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                              if (item['variation'] != null)
                                Text("${item['variation']}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
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
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
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
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_localQuote.clientName.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
                            IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey), onPressed: _showEditClientDialog, tooltip: 'Editar Dados do Cliente'),
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
                                      id: widget.quoteId, userId: _localQuote.userId, status: _localQuote.status, createdAt: _localQuote.createdAt, clientName: _localQuote.clientName, clientPhone: _localQuote.clientPhone, clientCity: _localQuote.clientCity, clientState: _localQuote.clientState,
                                      blanksList: _localQuote.blanksList, cabosList: _localQuote.cabosList, reelSeatsList: _localQuote.reelSeatsList, passadoresList: _localQuote.passadoresList, acessoriosList: _localQuote.acessoriosList,
                                      extraLaborCost: double.tryParse(val.replaceAll(',', '.')) ?? 0.0,
                                      totalPrice: _localQuote.totalPrice, customizationText: _localQuote.customizationText, 
                                      finishedImages: _localQuote.finishedImages,
                                    );
                                  });
                                  _recalculateTotal();
                                },
                              ),
                            )
                          ],
                        ),
                        const Divider(height: 30),
                        TextField(
                          controller: _customizationController,
                          maxLines: 3,
                          // CORREÇÃO: COR DO TEXTO DEFINIDA COMO PRETO
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

// --- MODAL SELECTOR ---

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
                    Expanded(child: Text("Adicionar ${widget.title}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
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
                          title: Text(data['name'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text("R\$ ${_currencyFormat.format(basePrice).replaceAll('R\$', '')}  •  Est: ${data['stock'] ?? 0}"),
                          children: [
                            ListTile(
                              title: const Text("Selecionar Padrão"),
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

                                // LÓGICA DE IMAGEM DA VARIAÇÃO
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
                                  title: Text(vName),
                                  trailing: Text(_currencyFormat.format(vPrice)),
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