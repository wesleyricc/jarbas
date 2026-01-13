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
  String? variation; // Nome da variação selecionada
  
  RodItem({
    required this.component, 
    this.quantity = 1, 
    this.variation
  });
}

class RodBuilderProvider extends ChangeNotifier {
  final QuoteService _quoteService = QuoteService(); 

  // Dados do Cliente
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

  // Getters
  List<RodItem> get selectedBlanksList => _selectedBlanks;
  List<RodItem> get selectedCabosList => _selectedCabos;
  List<RodItem> get selectedReelSeatsList => _selectedReelSeats;
  List<RodItem> get selectedPassadoresList => _selectedPassadores;
  List<RodItem> get selectedAcessoriosList => _selectedAcessorios;
  double get extraLaborCost => _extraLaborCost;
  double get totalPrice => _totalPrice;

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

  void updateClientInfo({required String name, required String phone, required String city, required String state}) {
    clientName = name;
    clientPhone = phone;
    clientCity = city;
    clientState = state;
    notifyListeners();
  }

  void setCustomizationText(String text) {
    customizationText = text;
    notifyListeners();
  }

  void setExtraLaborCost(double value) {
    _extraLaborCost = value;
    _calculateTotalPrice();
    notifyListeners();
  }

  Future<void> fetchSettings() async {
    await Future.delayed(Duration.zero); 
  }

  // --- LÓGICA DE PREÇO DINÂMICA (NOVO) ---

  /// Retorna o preço correto:
  /// 1. Se tiver variação selecionada E essa variação tiver preço > 0 -> Preço da Variação.
  /// 2. Caso contrário -> Preço Base do Componente.
  double _getItemPrice(RodItem item) {
    if (item.variation != null && item.variation!.isNotEmpty) {
      try {
        final variant = item.component.variations.firstWhere(
          (v) => v.name == item.variation,
          // Retorna um dummy se não encontrar
          orElse: () => ComponentVariation(id: '', name: '', stock: 0, price: 0.0), 
        );
        
        if (variant.price > 0) return variant.price;
      } catch (e) {
        // Ignora erro
      }
    }
    return item.component.price;
  }

  void _calculateTotalPrice() {
    double total = 0.0;
    
    double sumList(List<RodItem> list) {
      return list.fold(0.0, (sum, item) {
        // Usa o helper de preço dinâmico
        return sum + (_getItemPrice(item) * item.quantity);
      });
    }

    total += sumList(_selectedBlanks);
    total += sumList(_selectedCabos);
    total += sumList(_selectedReelSeats);
    total += sumList(_selectedPassadores);
    total += sumList(_selectedAcessorios);
    
    total += _extraLaborCost; 

    _totalPrice = total;
  }

  void clearBuild() {
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
  
  // --- CARREGAR KIT ---
  Future<bool> loadKit(KitModel kit) async {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      Future<Component?> fetchComp(String id) async {
        if (id.isEmpty) return null;
        try {
          final doc = await firestore.collection(AppConstants.colComponents).doc(id).get();
          if (doc.exists) return Component.fromFirestore(doc);
        } catch (e) {
          print("Erro carregando componente: $e");
        }
        return null;
      }

      Future<void> loadList(List<Map<String, dynamic>> source, List<RodItem> target) async {
        target.clear();
        for (var itemMap in source) {
          final comp = await fetchComp(itemMap['id']);
          if (comp != null) {
            target.add(RodItem(
              component: comp,
              quantity: (itemMap['quantity'] ?? 1).toInt(),
              variation: itemMap['variation'],
            ));
          }
        }
      }

      _selectedBlanks.clear();
      _selectedCabos.clear();
      _selectedReelSeats.clear();
      _selectedPassadores.clear();
      _selectedAcessorios.clear();

      await loadList(kit.blanksIds, _selectedBlanks);
      await loadList(kit.cabosIds, _selectedCabos);
      await loadList(kit.reelSeatsIds, _selectedReelSeats);
      await loadList(kit.passadoresIds, _selectedPassadores);
      await loadList(kit.acessoriosIds, _selectedAcessorios);

      _calculateTotalPrice();
      notifyListeners();
      return true;
  }

  // --- SALVAR ORÇAMENTO ---
  Future<bool> saveQuote(String userId, {required String status}) async {
    List<Map<String, dynamic>> convertList(List<RodItem> list) {
      return list.map((item) => {
        'name': item.component.name,
        'variation': item.variation,
        'quantity': item.quantity,
        'cost': item.component.costPrice, // Custo base (assumimos constante por enquanto)
        'price': _getItemPrice(item), // Salva o preço REAL da variação no momento da compra
      }).toList();
    }

    final quote = Quote(
      userId: userId,
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

  // --- CARREGAR ORÇAMENTO ---
  Future<void> loadFromQuote(Quote quote) async {
    clientName = quote.clientName;
    clientPhone = quote.clientPhone;
    clientCity = quote.clientCity;
    clientState = quote.clientState;
    customizationText = quote.customizationText ?? '';
    _extraLaborCost = quote.extraLaborCost;

    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    Future<Component?> findComponentByName(String name) async {
       final snapshot = await firestore.collection(AppConstants.colComponents)
           .where('name', isEqualTo: name)
           .limit(1)
           .get();
       
       if (snapshot.docs.isNotEmpty) {
         return Component.fromFirestore(snapshot.docs.first);
       }
       return null;
    }

    Future<void> fillList(List<Map<String, dynamic>> source, List<RodItem> target) async {
      target.clear();
      for (var item in source) {
        String name = item['name'];
        Component? comp = await findComponentByName(name);
        
        comp ??= Component(
            id: '', 
            name: name, 
            description: '',
            category: AppConstants.catBlank, 
            price: (item['price'] ?? 0).toDouble(), 
            costPrice: (item['cost'] ?? 0).toDouble(), 
            stock: 0, 
            imageUrl: '', 
            variations: [],
            attributes: {},
          );

        target.add(RodItem(
          component: comp,
          quantity: (item['quantity'] ?? 1).toInt(),
          variation: item['variation'],
        ));
      }
    }

    await fillList(quote.blanksList, _selectedBlanks);
    await fillList(quote.cabosList, _selectedCabos);
    await fillList(quote.reelSeatsList, _selectedReelSeats);
    await fillList(quote.passadoresList, _selectedPassadores);
    await fillList(quote.acessoriosList, _selectedAcessorios);

    _calculateTotalPrice();
    notifyListeners();
  }
}