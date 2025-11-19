import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/component_model.dart';
import '../models/quote_model.dart';
import '../services/quote_service.dart';
import '../services/config_service.dart';

class RodBuilderProvider with ChangeNotifier {
  final QuoteService _quoteService = QuoteService();
  final ConfigService _configService = ConfigService();

  // Componentes
  Component? _selectedBlank;
  Component? _selectedCabo;
  Component? _selectedReelSeat;
  Component? _selectedPassadores;

  // --- NOVOS CAMPOS DE QUANTIDADE ---
  int _caboQuantity = 1;
  int _passadoresQuantity = 1;

  // Personalização
  String _corLinha = '';
  String _gravacao = '';

  // Cliente
  String _clientName = '';
  String _clientPhone = '';
  String _clientCity = '';
  String _clientState = '';

  double _totalPrice = 0.0;
  double _customizationPrice = 25.0; // Valor padrão inicial
  double get customizationPrice => _customizationPrice; // Getter público

  // --- GETTERS ---
  Component? get selectedBlank => _selectedBlank;
  Component? get selectedCabo => _selectedCabo;
  Component? get selectedReelSeat => _selectedReelSeat;
  Component? get selectedPassadores => _selectedPassadores;
  
  int get caboQuantity => _caboQuantity;
  int get passadoresQuantity => _passadoresQuantity;

  String get corLinha => _corLinha;
  String get gravacao => _gravacao;
  String get clientName => _clientName;
  String get clientPhone => _clientPhone;
  String get clientCity => _clientCity;
  String get clientState => _clientState;
  double get totalPrice => _totalPrice;

  // --- MÉTODO NOVO: Carregar Configurações ---
  Future<void> fetchSettings() async {
    final settings = await _configService.getSettings();
    _customizationPrice = (settings['customizationPrice'] ?? 25.0).toDouble();
    _calculateTotalPrice(); // Recalcula caso já tenha algo selecionado
    notifyListeners();
  }

  // --- SETTERS E MÉTODOS ---

  void selectBlank(Component? blank) {
    _selectedBlank = blank;
    _calculateTotalPrice();
    notifyListeners();
  }

  void selectCabo(Component? cabo) {
    _selectedCabo = cabo;
    _calculateTotalPrice(); // Recalcula com a qtd atual
    notifyListeners();
  }
  
  // (NOVO) Setter para quantidade de Cabo
  void setCaboQuantity(int qtd) {
    if (qtd < 1) return;
    _caboQuantity = qtd;
    _calculateTotalPrice();
    notifyListeners();
  }

  void selectReelSeat(Component? reelSeat) {
    _selectedReelSeat = reelSeat;
    _calculateTotalPrice();
    notifyListeners();
  }

  void selectPassadores(Component? passadores) {
    _selectedPassadores = passadores;
    _calculateTotalPrice();
    notifyListeners();
  }

  // (NOVO) Setter para quantidade de Passadores
  void setPassadoresQuantity(int qtd) {
    if (qtd < 1) return;
    _passadoresQuantity = qtd;
    _calculateTotalPrice();
    notifyListeners();
  }

  void setCorLinha(String cor) {
    _corLinha = cor;
    notifyListeners();
  }
  
  void setGravacao(String texto) {
    _gravacao = texto;
    _calculateTotalPrice();
    notifyListeners();
  }

  void setClientName(String name) { _clientName = name; notifyListeners(); }
  void setClientPhone(String phone) { _clientPhone = phone; notifyListeners(); }
  void setClientCity(String city) { _clientCity = city; notifyListeners(); }
  void setClientState(String state) { _clientState = state; notifyListeners(); }

  // --- CÁLCULO ATUALIZADO ---
  void _calculateTotalPrice() {
    double total = 0.0;
    
    total += _selectedBlank?.price ?? 0.0;
    
    // Multiplica pela quantidade
    total += (_selectedCabo?.price ?? 0.0) * _caboQuantity;
    total += _selectedReelSeat?.price ?? 0.0;
    total += (_selectedPassadores?.price ?? 0.0) * _passadoresQuantity;

    if (_gravacao.isNotEmpty) {
      total += _customizationPrice; 
    }
    
    _totalPrice = total;
  }

  void clearBuild() {
    _selectedBlank = null;
    _selectedCabo = null;
    _selectedReelSeat = null;
    _selectedPassadores = null;
    
    // Reseta quantidades
    _caboQuantity = 1;
    _passadoresQuantity = 1;

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

    final quote = Quote(
      userId: userId,
      status: status,
      createdAt: Timestamp.now(),
      totalPrice: _totalPrice,
      
      clientName: _clientName,
      clientPhone: _clientPhone,
      clientCity: _clientCity,
      clientState: _clientState,

      blankName: _selectedBlank?.name,
      blankPrice: _selectedBlank?.price,
      blankCost: _selectedBlank?.costPrice, // (NOVO)
      
      caboName: _selectedCabo?.name,
      caboPrice: _selectedCabo?.price,
      caboCost: _selectedCabo?.costPrice, // (NOVO)
      caboQuantity: _caboQuantity, // (NOVO)
      
      reelSeatName: _selectedReelSeat?.name,
      reelSeatPrice: _selectedReelSeat?.price,
      reelSeatCost: _selectedReelSeat?.costPrice, // (NOVO)
      
      passadoresName: _selectedPassadores?.name,
      passadoresPrice: _selectedPassadores?.price,
      passadoresCost: _selectedPassadores?.costPrice, // (NOVO)
      passadoresQuantity: _passadoresQuantity, // (NOVO)

      corLinha: _corLinha,
      gravacao: _gravacao,
    );

    try {
      await _quoteService.saveQuote(quote);
      return true;
    } catch (e) {
      print("Erro ao salvar orçamento: $e");
      return false;
    }
  }
}