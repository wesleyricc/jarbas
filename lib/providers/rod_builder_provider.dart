import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/component_model.dart';
import '../models/quote_model.dart';
import '../models/kit_model.dart';
import '../services/quote_service.dart';
import '../utils/app_constants.dart';

class RodItem {
  final Component component;
  int quantity;
  String? variation; 
  
  RodItem({
    required this.component, 
    this.quantity = 1, 
    this.variation
  });
}

class RodBuilderProvider extends ChangeNotifier {
  final QuoteService _quoteService = QuoteService(); 

  // Dados do Cliente
  String? _selectedCustomerId; // NOVO: ID do cliente selecionado
  String clientName = '';
  String clientPhone = '';
  String clientCity = '';
  String clientState = '';

  // Listas
  List<RodItem> _selectedBlanks = [];
  List<RodItem> _selectedCabos = [];
  List<RodItem> _selectedReelSeats = [];
  List<RodItem> _selectedPassadores = [];
  List<RodItem> _selectedAcessorios = [];
  
  // Customização e Totais
  String customizationText = '';
  double _extraLaborCost = 0.0;
  double _totalPrice = 0.0;
  
  // Configurações Globais
  double _globalCustomizationPrice = 0.0; 

  // Getters
  String? get selectedCustomerId => _selectedCustomerId;
  List<RodItem> get selectedBlanksList => _selectedBlanks;
  List<RodItem> get selectedCabosList => _selectedCabos;
  List<RodItem> get selectedReelSeatsList => _selectedReelSeats;
  List<RodItem> get selectedPassadoresList => _selectedPassadores;
  List<RodItem> get selectedAcessoriosList => _selectedAcessorios;
  double get extraLaborCost => _extraLaborCost;
  double get totalPrice => _totalPrice;
  double get customizationPrice => customizationText.isNotEmpty ? _globalCustomizationPrice : 0.0;

  // --- MÉTODOS PÚBLICOS DE IMAGEM E PREÇO ---

  String getItemImage(RodItem item) {
    String baseImage = item.component.imageUrl;
    if (item.variation != null && item.variation!.isNotEmpty) {
      try {
        final variant = item.component.variations.firstWhere(
          (v) => v.name == item.variation,
          orElse: () => ComponentVariation(id: '', name: '', stock: 0, price: 0.0), 
        );
        if (variant.imageUrl != null && variant.imageUrl!.isNotEmpty) {
          return variant.imageUrl!;
        }
      } catch (e) { /* ignore */ }
    }
    return baseImage;
  }

  double getItemPrice(RodItem item) {
    if (item.variation != null && item.variation!.isNotEmpty) {
      try {
        final variant = item.component.variations.firstWhere(
          (v) => v.name == item.variation,
          orElse: () => ComponentVariation(id: '', name: '', stock: 0, price: 0.0), 
        );
        if (variant.price > 0) return variant.price;
      } catch (e) { /* ignore */ }
    }
    return item.component.price;
  }

  double getItemCost(RodItem item) {
    double baseCost = item.component.costPrice;
    if (item.variation != null && item.variation!.isNotEmpty) {
      try {
        final variant = item.component.variations.firstWhere(
          (v) => v.name == item.variation,
          orElse: () => ComponentVariation(id: '', name: '', stock: 0, price: 0.0), 
        );
        if (variant.costPrice > 0) return variant.costPrice;
      } catch (e) { /* ignore */ }
    }
    return baseCost;
  }

  // --- MÉTODOS DE AÇÃO ---

  void addBlank(Component c, int qty, {String? variation}) {
    _selectedBlanks.add(RodItem(component: c, quantity: qty, variation: variation));
    _calculateTotalPrice();
    notifyListeners();
  }
  void removeBlank(int index) {
    _selectedBlanks.removeAt(index);
    _calculateTotalPrice();
    notifyListeners();
  }
  void updateBlankQty(int index, int qty) {
    _selectedBlanks[index].quantity = qty;
    _calculateTotalPrice();
    notifyListeners();
  }

  void addCabo(Component c, int qty, {String? variation}) {
    _selectedCabos.add(RodItem(component: c, quantity: qty, variation: variation));
    _calculateTotalPrice();
    notifyListeners();
  }
  void removeCabo(int index) {
    _selectedCabos.removeAt(index);
    _calculateTotalPrice();
    notifyListeners();
  }
  void updateCaboQty(int index, int qty) {
    _selectedCabos[index].quantity = qty;
    _calculateTotalPrice();
    notifyListeners();
  }

  void addReelSeat(Component c, int qty, {String? variation}) {
    _selectedReelSeats.add(RodItem(component: c, quantity: qty, variation: variation));
    _calculateTotalPrice();
    notifyListeners();
  }
  void removeReelSeat(int index) {
    _selectedReelSeats.removeAt(index);
    _calculateTotalPrice();
    notifyListeners();
  }
  void updateReelSeatQty(int index, int qty) {
    _selectedReelSeats[index].quantity = qty;
    _calculateTotalPrice();
    notifyListeners();
  }

  void addPassador(Component c, int qty, {String? variation}) {
    _selectedPassadores.add(RodItem(component: c, quantity: qty, variation: variation));
    _calculateTotalPrice();
    notifyListeners();
  }
  void removePassador(int index) {
    _selectedPassadores.removeAt(index);
    _calculateTotalPrice();
    notifyListeners();
  }
  void updatePassadorQty(int index, int qty) {
    _selectedPassadores[index].quantity = qty;
    _calculateTotalPrice();
    notifyListeners();
  }

  void addAcessorio(Component c, int qty, {String? variation}) {
    _selectedAcessorios.add(RodItem(component: c, quantity: qty, variation: variation));
    _calculateTotalPrice();
    notifyListeners();
  }
  void removeAcessorio(int index) {
    _selectedAcessorios.removeAt(index);
    _calculateTotalPrice();
    notifyListeners();
  }
  void updateAcessorioQty(int index, int qty) {
    _selectedAcessorios[index].quantity = qty;
    _calculateTotalPrice();
    notifyListeners();
  }

  // Atualizado para aceitar customerId opcional
  void updateClientInfo({
    required String name, 
    required String phone, 
    required String city, 
    required String state,
    String? customerId
  }) {
    clientName = name;
    clientPhone = phone;
    clientCity = city;
    clientState = state;
    if (customerId != null) {
      _selectedCustomerId = customerId;
    }
    notifyListeners();
  }

  void setCustomizationText(String text) {
    customizationText = text;
    _calculateTotalPrice();
    notifyListeners();
  }

  void setExtraLaborCost(double value) {
    _extraLaborCost = value;
    _calculateTotalPrice();
    notifyListeners();
  }

  Future<void> fetchSettings() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('global_config').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _globalCustomizationPrice = (data['customizationPrice'] ?? 0.0).toDouble();
        _calculateTotalPrice(); 
        notifyListeners();
      }
    } catch (e) {
      print("Erro ao buscar configurações: $e");
    }
  }

  void _calculateTotalPrice() {
    double total = 0.0;
    
    double sumList(List<RodItem> list) {
      return list.fold(0.0, (sum, item) {
        return sum + (getItemPrice(item) * item.quantity);
      });
    }

    total += sumList(_selectedBlanks);
    total += sumList(_selectedCabos);
    total += sumList(_selectedReelSeats);
    total += sumList(_selectedPassadores);
    total += sumList(_selectedAcessorios);
    
    total += _extraLaborCost;
    
    if (customizationText.isNotEmpty) {
      total += _globalCustomizationPrice;
    }

    _totalPrice = total;
  }

  void clearBuild() {
    _selectedCustomerId = null;
    clientName = ''; clientPhone = ''; clientCity = ''; clientState = '';
    _selectedBlanks.clear();
    _selectedCabos.clear();
    _selectedReelSeats.clear();
    _selectedPassadores.clear();
    _selectedAcessorios.clear();
    customizationText = '';
    _extraLaborCost = 0.0;
    _totalPrice = 0.0;
    notifyListeners();
  }
  
  Future<bool> loadKit(KitModel kit) async {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      Future<RodItem?> fetchItem(Map<String, dynamic> itemMap) async {
        final id = itemMap['id'];
        if (id == null || id.isEmpty) return null;
        try {
          final doc = await firestore.collection(AppConstants.colComponents).doc(id).get();
          if (doc.exists) {
             return RodItem(
              component: Component.fromFirestore(doc),
              quantity: (itemMap['quantity'] ?? 1).toInt(),
              variation: itemMap['variation'],
            );
          }
        } catch (e) {
          print("Erro carregando componente: $e");
        }
        return null;
      }

      Future<List<RodItem>> processList(List<Map<String, dynamic>> source) async {
        final futures = source.map((item) => fetchItem(item));
        final results = await Future.wait(futures);
        return results.whereType<RodItem>().toList();
      }

      _selectedBlanks.clear();
      _selectedCabos.clear();
      _selectedReelSeats.clear();
      _selectedPassadores.clear();
      _selectedAcessorios.clear();

      try {
        final results = await Future.wait([
          processList(kit.blanksIds),
          processList(kit.cabosIds),
          processList(kit.reelSeatsIds),
          processList(kit.passadoresIds),
          processList(kit.acessoriosIds),
        ]);

        _selectedBlanks.addAll(results[0]);
        _selectedCabos.addAll(results[1]);
        _selectedReelSeats.addAll(results[2]);
        _selectedPassadores.addAll(results[3]);
        _selectedAcessorios.addAll(results[4]);

        _calculateTotalPrice();
        notifyListeners();
        return true;
      } catch (e) {
        print("Erro crítico ao carregar kit: $e");
        return false;
      }
  }

  Future<bool> saveQuote(String userId, {required String status}) async {
    List<Map<String, dynamic>> convertList(List<RodItem> list) {
      return list.map((item) => {
        'id': item.component.id, 
        'name': item.component.name,
        'variation': item.variation,
        'quantity': item.quantity,
        'imageUrl': getItemImage(item), 
        'costPrice': getItemCost(item), 
        'price': getItemPrice(item), 
      }).toList();
    }

    final quote = Quote(
      userId: userId,
      customerId: _selectedCustomerId, // Salva o ID do cliente se houver
      status: status,
      createdAt: Timestamp.now(),
      clientName: clientName,
      clientPhone: clientPhone,
      clientCity: clientCity,
      clientState: clientState,
      blanksList: convertList(_selectedBlanks),
      cabosList: convertList(_selectedCabos),
      reelSeatsList: convertList(_selectedReelSeats),
      passadoresList: convertList(_selectedPassadores),
      acessoriosList: convertList(_selectedAcessorios),
      extraLaborCost: _extraLaborCost,
      totalPrice: _totalPrice,
      customizationText: customizationText,
    );

    try {
      await _quoteService.saveQuote(quote);
      return true;
    } catch (e) {
      print("Erro ao salvar quote: $e");
      return false;
    }
  }

  Future<void> loadFromQuote(Quote quote) async {
    clientName = quote.clientName;
    clientPhone = quote.clientPhone;
    clientCity = quote.clientCity;
    clientState = quote.clientState;
    _selectedCustomerId = quote.customerId; // Restaura o ID do cliente

    customizationText = quote.customizationText ?? '';
    _extraLaborCost = quote.extraLaborCost;

    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    Future<RodItem> fetchQuoteItem(Map<String, dynamic> item) async {
        String name = item['name'];
        Component? comp;
        
        final snapshot = await firestore.collection(AppConstants.colComponents)
           .where('name', isEqualTo: name)
           .limit(1)
           .get();
       
        if (snapshot.docs.isNotEmpty) {
          comp = Component.fromFirestore(snapshot.docs.first);
        } else {
          comp = Component(
            id: '', 
            name: name, 
            description: '',
            category: AppConstants.catBlank, 
            price: (item['price'] ?? 0).toDouble(), 
            costPrice: (item['costPrice'] ?? item['cost'] ?? 0).toDouble(), 
            stock: 0, 
            imageUrl: item['imageUrl'] ?? '', 
            variations: [],
            attributes: {},
          );
        }

        return RodItem(
          component: comp,
          quantity: (item['quantity'] ?? 1).toInt(),
          variation: item['variation'],
        );
    }

    Future<List<RodItem>> processQuoteList(List<Map<String, dynamic>> source) async {
      final futures = source.map((item) => fetchQuoteItem(item));
      return await Future.wait(futures);
    }

    _selectedBlanks.clear();
    _selectedCabos.clear();
    _selectedReelSeats.clear();
    _selectedPassadores.clear();
    _selectedAcessorios.clear();

    try {
      final results = await Future.wait([
        processQuoteList(quote.blanksList),
        processQuoteList(quote.cabosList),
        processQuoteList(quote.reelSeatsList),
        processQuoteList(quote.passadoresList),
        processQuoteList(quote.acessoriosList),
      ]);

      _selectedBlanks.addAll(results[0]);
      _selectedCabos.addAll(results[1]);
      _selectedReelSeats.addAll(results[2]);
      _selectedPassadores.addAll(results[3]);
      _selectedAcessorios.addAll(results[4]);

      _calculateTotalPrice();
      notifyListeners();
    } catch (e) {
      print("Erro ao carregar quote: $e");
    }
  }
}