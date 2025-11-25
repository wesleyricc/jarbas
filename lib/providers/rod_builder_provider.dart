import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/component_model.dart';
import '../models/quote_model.dart';
import '../services/quote_service.dart';
import '../services/config_service.dart';

// Classe auxiliar para itens da lista
class RodItem {
  final Component component;
  int quantity;
  String? variation;

  RodItem({required this.component, this.quantity = 1, this.variation});
  
  double get totalPrice => component.price * quantity;
}

class RodBuilderProvider with ChangeNotifier {
  final QuoteService _quoteService = QuoteService();
  final ConfigService _configService = ConfigService();

  // Componentes
  Component? _selectedBlank;
  Component? _selectedCabo;
  Component? _selectedReelSeat;
  
  // Variações
  String? _selectedBlankVariation;
  String? _selectedCaboVariation;
  String? _selectedReelSeatVariation;

  // Listas
  final List<RodItem> _selectedPassadoresList = [];
  final List<RodItem> _selectedAcessoriosList = [];

  // Quantidades
  int _caboQuantity = 1;

  // Personalização e Configuração
  // Alterado padrão para 0.0 para evitar o "25.0" fantasma se falhar o carregamento
  double _customizationPrice = 0.0; 
  
  String _corLinha = '';
  String _gravacao = '';
  String _clientName = '';
  String _clientPhone = '';
  String _clientCity = '';
  String _clientState = '';
  
  double _totalPrice = 0.0;

  // --- GETTERS ---
  Component? get selectedBlank => _selectedBlank;
  String? get selectedBlankVariation => _selectedBlankVariation;
  
  Component? get selectedCabo => _selectedCabo;
  String? get selectedCaboVariation => _selectedCaboVariation;
  int get caboQuantity => _caboQuantity;
  
  Component? get selectedReelSeat => _selectedReelSeat;
  String? get selectedReelSeatVariation => _selectedReelSeatVariation;
  
  List<RodItem> get selectedPassadoresList => _selectedPassadoresList;
  List<RodItem> get selectedAcessoriosList => _selectedAcessoriosList;

  double get totalPrice => _totalPrice;
  double get customizationPrice => _customizationPrice;
  String get corLinha => _corLinha;
  String get gravacao => _gravacao;
  String get clientName => _clientName;
  String get clientPhone => _clientPhone;
  String get clientCity => _clientCity;
  String get clientState => _clientState;

  // --- CARREGAR CONFIGURAÇÕES ---
  Future<void> fetchSettings() async {
    try {
      final settings = await _configService.getSettings();
      
      // Garante que converte para double mesmo se vier int ou string do banco
      var priceData = settings['customizationPrice'];
      if (priceData is int) {
        _customizationPrice = priceData.toDouble();
      } else if (priceData is double) {
        _customizationPrice = priceData;
      } else {
        _customizationPrice = 25.0; // Fallback apenas se vier nulo ou inválido
      }

      print("DEBUG: Preço Customização Carregado: $_customizationPrice");
      
      _calculateTotalPrice();
      notifyListeners();
    } catch (e) {
      print("Erro ao carregar settings no provider: $e");
    }
  }

  // --- SELEÇÃO DE COMPONENTES ---

  void selectBlank(Component? c, {String? variation}) {
    _selectedBlank = c;
    _selectedBlankVariation = variation;
    _calculateTotalPrice();
    notifyListeners();
  }

  void selectCabo(Component? c, {String? variation}) {
    _selectedCabo = c;
    _selectedCaboVariation = variation;
    _calculateTotalPrice();
    notifyListeners();
  }
  
  void setCaboQuantity(int q) {
    if (q < 1) return;
    _caboQuantity = q;
    _calculateTotalPrice();
    notifyListeners();
  }

  void selectReelSeat(Component? c, {String? variation}) {
    _selectedReelSeat = c;
    _selectedReelSeatVariation = variation;
    _calculateTotalPrice();
    notifyListeners();
  }

  // --- PASSADORES ---
  void addPassador(Component component, int qty, {String? variation}) {
    final index = _selectedPassadoresList.indexWhere((item) => item.component.id == component.id && item.variation == variation);
    if (index >= 0) {
      _selectedPassadoresList[index].quantity += qty;
    } else {
      _selectedPassadoresList.add(RodItem(component: component, quantity: qty, variation: variation));
    }
    _calculateTotalPrice();
    notifyListeners();
  }

  void removePassador(int index) {
    _selectedPassadoresList.removeAt(index);
    _calculateTotalPrice();
    notifyListeners();
  }
  
  void updatePassadorQty(int index, int newQty) {
    if (newQty < 1) return;
    _selectedPassadoresList[index].quantity = newQty;
    _calculateTotalPrice();
    notifyListeners();
  }

  // --- ACESSÓRIOS ---
  void addAcessorio(Component component, int qty, {String? variation}) {
    final index = _selectedAcessoriosList.indexWhere((item) => item.component.id == component.id && item.variation == variation);
    if (index >= 0) {
      _selectedAcessoriosList[index].quantity += qty;
    } else {
      _selectedAcessoriosList.add(RodItem(component: component, quantity: qty, variation: variation));
    }
    _calculateTotalPrice();
    notifyListeners();
  }

  void removeAcessorio(int index) {
    _selectedAcessoriosList.removeAt(index);
    _calculateTotalPrice();
    notifyListeners();
  }
  
  void updateAcessorioQty(int index, int newQty) {
    if (newQty < 1) return;
    _selectedAcessoriosList[index].quantity = newQty;
    _calculateTotalPrice();
    notifyListeners();
  }

  // --- PERSONALIZAÇÃO ---
  void setCorLinha(String v) { _corLinha = v; notifyListeners(); }
  
  void setGravacao(String v) {
    _gravacao = v;
    _calculateTotalPrice();
    notifyListeners();
  }

  void setClientName(String v) { _clientName = v; notifyListeners(); }
  void setClientPhone(String v) { _clientPhone = v; notifyListeners(); }
  void setClientCity(String v) { _clientCity = v; notifyListeners(); }
  void setClientState(String v) { _clientState = v; notifyListeners(); }

  // --- CÁLCULO TOTAL ---
  void _calculateTotalPrice() {
    double total = 0.0;
    total += _selectedBlank?.price ?? 0.0;
    total += (_selectedCabo?.price ?? 0.0) * _caboQuantity;
    total += _selectedReelSeat?.price ?? 0.0;
    
    for (var item in _selectedPassadoresList) total += item.totalPrice;
    for (var item in _selectedAcessoriosList) total += item.totalPrice;

    // Só cobra se tiver texto
    if (_gravacao.isNotEmpty) {
      total += _customizationPrice;
    }
    
    _totalPrice = total;
  }

  void clearBuild() {
    _selectedBlank = null; _selectedBlankVariation = null;
    _selectedCabo = null; _selectedCaboVariation = null; _caboQuantity = 1;
    _selectedReelSeat = null; _selectedReelSeatVariation = null;
    
    _selectedPassadoresList.clear();
    _selectedAcessoriosList.clear();

    _corLinha = '';
    _gravacao = '';
    _clientName = '';
    _clientPhone = '';
    _clientCity = '';
    _clientState = '';
    _totalPrice = 0.0;
    
    notifyListeners();
  }

  Future<bool> saveQuote(String userId, {String status = 'rascunho'}) async {
    _calculateTotalPrice();

    // Helpers de conversão
    List<Map<String, dynamic>> toMapList(List<RodItem> list) {
      return list.map((item) => {
        'name': item.component.name,
        'price': item.component.price,
        'cost': item.component.costPrice,
        'quantity': item.quantity,
        'variation': item.variation,
      }).toList();
    }

    final quote = Quote(
      userId: userId,
      status: status,
      createdAt: Timestamp.now(),
      totalPrice: _totalPrice,
      
      clientName: _clientName, clientPhone: _clientPhone, clientCity: _clientCity, clientState: _clientState,
      
      blankName: _selectedBlank?.name, blankPrice: _selectedBlank?.price, blankCost: _selectedBlank?.costPrice, blankVariation: _selectedBlankVariation,
      caboName: _selectedCabo?.name, caboPrice: _selectedCabo?.price, caboCost: _selectedCabo?.costPrice, caboQuantity: _caboQuantity, caboVariation: _selectedCaboVariation,
      reelSeatName: _selectedReelSeat?.name, reelSeatPrice: _selectedReelSeat?.price, reelSeatCost: _selectedReelSeat?.costPrice, reelSeatVariation: _selectedReelSeatVariation,
      
      passadoresList: toMapList(_selectedPassadoresList),
      acessoriosList: toMapList(_selectedAcessoriosList),
      
      corLinha: _corLinha,
      gravacao: _gravacao,
    );

    try {
      await _quoteService.saveQuote(quote);
      return true;
    } catch (e) {
      print("Erro ao salvar: $e");
      return false;
    }
  }
}