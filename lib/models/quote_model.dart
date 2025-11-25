import 'package:cloud_firestore/cloud_firestore.dart';

class Quote {
  final String? id;
  final String userId;
  final String status;
  final Timestamp createdAt;
  final double totalPrice;
  final String? blankVariation; // (NOVO)
  final String? caboVariation; // (NOVO)
  final String? reelSeatVariation; // (NOVO)

  final String clientName;
  final String clientPhone;
  final String clientCity;
  final String clientState;

  final String? blankName;
  final double? blankPrice;
  final double? blankCost;
  
  final String? caboName;
  final double? caboPrice;
  final double? caboCost;
  final int caboQuantity;

  final String? reelSeatName;
  final double? reelSeatPrice;
  final double? reelSeatCost;
  
  // --- CAMPOS ANTIGOS (LEGADO - NECESSÁRIOS PARA O ERRO SUMIR) ---
  final String? passadoresName;
  final double? passadoresPrice;
  final double? passadoresCost;
  final int passadoresQuantity;
  // ---------------------------------------------------------------

  // --- CAMPO NOVO (LISTA) ---
  final List<Map<String, dynamic>> passadoresList; 
  final List<Map<String, dynamic>> acessoriosList;

  final String? corLinha;
  final String? gravacao;

  Quote({
    this.id,
    required this.userId,
    required this.status,
    required this.createdAt,
    required this.totalPrice,
    required this.clientName,
    required this.clientPhone,
    required this.clientCity,
    required this.clientState,
    this.blankName,
    this.blankVariation,
    this.blankPrice,
    this.blankCost,
    this.caboName,
    this.caboVariation,
    this.caboPrice,
    this.caboCost,
    this.caboQuantity = 1,
    this.reelSeatName,
    this.reelSeatVariation,
    this.reelSeatPrice,
    this.reelSeatCost,
    
    // Legado
    this.passadoresName,
    this.passadoresPrice,
    this.passadoresCost,
    this.passadoresQuantity = 1,

    // Novo
    this.passadoresList = const [],
    this.acessoriosList = const [],
    
    this.corLinha,
    this.gravacao,
  });

  factory Quote.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Lógica de Lista:
    List<Map<String, dynamic>> loadedPassadores = [];
    if (data['passadoresList'] != null) {
      loadedPassadores = List<Map<String, dynamic>>.from(data['passadoresList']);
    } else if (data['passadoresName'] != null) {
      // Se não tem lista, mas tem o antigo, cria uma lista na memória
      loadedPassadores.add({
        'name': data['passadoresName'],
        'price': (data['passadoresPrice'] ?? 0.0).toDouble(),
        'cost': (data['passadoresCost'] ?? 0.0).toDouble(),
        'quantity': (data['passadoresQuantity'] ?? 1).toInt(),
      });
    }

    // (NOVO) Carrega Acessórios
    List<Map<String, dynamic>> loadedAcessorios = [];
    if (data['acessoriosList'] != null) {
      loadedAcessorios = List<Map<String, dynamic>>.from(data['acessoriosList']);
    }

    return Quote(
      id: doc.id,
      userId: data['userId'] ?? '',
      status: data['status'] ?? 'rascunho',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      totalPrice: (data['totalPrice'] ?? 0.0).toDouble(),
      clientName: data['clientName'] ?? '',
      clientPhone: data['clientPhone'] ?? '',
      clientCity: data['clientCity'] ?? '',
      clientState: data['clientState'] ?? '',
      blankName: data['blankName'],
      blankPrice: (data['blankPrice'] ?? 0.0).toDouble(),
      blankCost: (data['blankCost'] ?? 0.0).toDouble(),
      blankVariation: data['blankVariation'],
      caboName: data['caboName'],
      caboPrice: (data['caboPrice'] ?? 0.0).toDouble(),
      caboCost: (data['caboCost'] ?? 0.0).toDouble(),
      caboQuantity: (data['caboQuantity'] ?? 1).toInt(),
      caboVariation: data['caboVariation'],
      reelSeatName: data['reelSeatName'],
      reelSeatPrice: (data['reelSeatPrice'] ?? 0.0).toDouble(),
      reelSeatCost: (data['reelSeatCost'] ?? 0.0).toDouble(),
      reelSeatVariation: data['reelSeatVariation'],

      passadoresList: loadedPassadores,
      acessoriosList: loadedAcessorios,

      corLinha: data['corLinha'],
      gravacao: data['gravacao'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'status': status,
      'createdAt': createdAt,
      'totalPrice': totalPrice,

      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientCity': clientCity,
      'clientState': clientState,
      
      'blankName': blankName,
      'blankPrice': blankPrice,
      'blankCost': blankCost,
      'blankVariation': blankVariation,
      
      'caboName': caboName,
      'caboPrice': caboPrice,
      'caboCost': caboCost,
      'caboQuantity': caboQuantity,
      'caboVariation': caboVariation,
      
      'reelSeatName': reelSeatName,
      'reelSeatPrice': reelSeatPrice,
      'reelSeatCost': reelSeatCost,
      'reelSeatVariation': reelSeatVariation,
      
      // Não precisamos salvar os campos antigos (passadoresName) no banco, 
      // salvamos apenas a lista nova.
      'passadoresList': passadoresList,
      'acessoriosList': acessoriosList,

      'corLinha': corLinha,
      'gravacao': gravacao,
    };
  }
}