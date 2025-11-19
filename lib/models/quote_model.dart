import 'package:cloud_firestore/cloud_firestore.dart';

class Quote {
  final String? id;
  final String userId;
  final String status;
  final Timestamp createdAt;
  final double totalPrice;

  final String clientName;
  final String clientPhone;
  final String clientCity;
  final String clientState;

  final String? blankName;
  final double? blankPrice;
  final double? blankCost; // (NOVO)
  
  final String? caboName;
  final double? caboPrice;
  final double? caboCost; // (NOVO)
  final int caboQuantity; // (NOVO)

  final String? reelSeatName;
  final double? reelSeatPrice;
  final double? reelSeatCost; // (NOVO)
  
  final String? passadoresName;
  final double? passadoresPrice;
  final double? passadoresCost; // (NOVO)
  final int passadoresQuantity; // (NOVO)

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
    this.blankPrice,
    this.blankCost, // (NOVO)
    this.caboName,
    this.caboPrice,
    this.caboCost, // (NOVO)
    this.caboQuantity = 1, // Padrão 1
    this.reelSeatName,
    this.reelSeatPrice,
    this.reelSeatCost, // (NOVO)
    this.passadoresName,
    this.passadoresPrice,
    this.passadoresCost, // (NOVO)
    this.passadoresQuantity = 1, // Padrão 1
    this.corLinha,
    this.gravacao,
  });

  factory Quote.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

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
      blankCost: (data['blankCost'] ?? 0.0).toDouble(), // (NOVO)
      
      caboName: data['caboName'],
      caboPrice: (data['caboPrice'] ?? 0.0).toDouble(),
      caboCost: (data['caboCost'] ?? 0.0).toDouble(), // (NOVO)
      caboQuantity: (data['caboQuantity'] ?? 1).toInt(), // (NOVO)
      
      reelSeatName: data['reelSeatName'],
      reelSeatPrice: (data['reelSeatPrice'] ?? 0.0).toDouble(),
      reelSeatCost: (data['reelSeatCost'] ?? 0.0).toDouble(), // (NOVO)
      
      passadoresName: data['passadoresName'],
      passadoresPrice: (data['passadoresPrice'] ?? 0.0).toDouble(),
      passadoresCost: (data['passadoresCost'] ?? 0.0).toDouble(), // (NOVO)
      passadoresQuantity: (data['passadoresQuantity'] ?? 1).toInt(), // (NOVO)

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
      'blankCost': blankCost, // (NOVO)
      
      'caboName': caboName,
      'caboPrice': caboPrice,
      'caboCost': caboCost, // (NOVO)
      'caboQuantity': caboQuantity, // (NOVO)
      
      'reelSeatName': reelSeatName,
      'reelSeatPrice': reelSeatPrice,
      'reelSeatCost': reelSeatCost, // (NOVO)
      
      'passadoresName': passadoresName,
      'passadoresPrice': passadoresPrice,
      'passadoresCost': passadoresCost, // (NOVO)
      'passadoresQuantity': passadoresQuantity, // (NOVO)

      'corLinha': corLinha,
      'gravacao': gravacao,
    };
  }
}