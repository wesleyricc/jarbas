import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_constants.dart';

class Quote {
  final String? id;
  final String userId;
  final String status; // Usa as constantes de AppConstants
  final Timestamp createdAt;
  
  // Dados do Cliente
  final String clientName;
  final String clientPhone;
  final String clientCity;
  final String clientState;

  // Listas de Componentes
  final List<Map<String, dynamic>> blanksList;
  final List<Map<String, dynamic>> cabosList;
  final List<Map<String, dynamic>> reelSeatsList;
  final List<Map<String, dynamic>> passadoresList;
  final List<Map<String, dynamic>> acessoriosList;

  // Custos e Totais
  final double extraLaborCost; 
  final double totalPrice;

  // Personalização
  final String? customizationText;

  Quote({
    this.id,
    required this.userId,
    required this.status,
    required this.createdAt,
    required this.clientName,
    required this.clientPhone,
    required this.clientCity,
    required this.clientState,
    required this.blanksList,
    required this.cabosList,
    required this.reelSeatsList,
    required this.passadoresList,
    required this.acessoriosList,
    this.extraLaborCost = 0.0,
    required this.totalPrice,
    this.customizationText,
  });

  factory Quote.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Quote(
      id: doc.id,
      userId: data['userId'] ?? '',
      // Fallback seguro usando a constante
      status: data['status'] ?? AppConstants.statusPendente,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      clientName: data['clientName'] ?? '',
      clientPhone: data['clientPhone'] ?? '',
      clientCity: data['clientCity'] ?? '',
      clientState: data['clientState'] ?? '',
      
      blanksList: List<Map<String, dynamic>>.from(data['blanksList'] ?? []),
      cabosList: List<Map<String, dynamic>>.from(data['cabosList'] ?? []),
      reelSeatsList: List<Map<String, dynamic>>.from(data['reelSeatsList'] ?? []),
      passadoresList: List<Map<String, dynamic>>.from(data['passadoresList'] ?? []),
      acessoriosList: List<Map<String, dynamic>>.from(data['acessoriosList'] ?? []),
      
      extraLaborCost: (data['extraLaborCost'] ?? 0.0).toDouble(),
      totalPrice: (data['totalPrice'] ?? 0.0).toDouble(),
      customizationText: data['customizationText'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'status': status,
      'createdAt': createdAt,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientCity': clientCity,
      'clientState': clientState,
      'blanksList': blanksList,
      'cabosList': cabosList,
      'reelSeatsList': reelSeatsList,
      'passadoresList': passadoresList,
      'acessoriosList': acessoriosList,
      'extraLaborCost': extraLaborCost,
      'totalPrice': totalPrice,
      'customizationText': customizationText,
    };
  }
}