import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_constants.dart';

class Quote {
  final String? id;
  final String userId;
  final String? customerId; // NOVO: ID do Cliente vinculado
  final String status; // 'pendente', 'aprovado', 'em_producao', 'concluido'
  final Timestamp createdAt;
  final String clientName;
  final String clientPhone;
  final String clientCity;
  final String clientState;

  
  // Listas de Itens
  final List<Map<String, dynamic>> blanksList;
  final List<Map<String, dynamic>> cabosList;
  final List<Map<String, dynamic>> reelSeatsList;
  final List<Map<String, dynamic>> passadoresList;
  final List<Map<String, dynamic>> acessoriosList;
  
  // Valores Financeiros
  final double extraLaborCost; // Mão de Obra
  final double totalPrice;     // Total Final Calculado
  final double generalDiscount; // NOVO: Valor do desconto geral
  final String generalDiscountType; // NOVO: 'fixed' (R$) ou 'percent' (%)

  // Outros
  final String? customizationText;
  final List<String> finishedImages;

  Quote({
    this.id,
    required this.userId,
    this.customerId,
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
    required this.extraLaborCost,
    required this.totalPrice,
    this.generalDiscount = 0.0, // Padrão 0
    this.generalDiscountType = 'fixed', // Padrão Fixo
    this.customizationText,
    this.finishedImages = const [],
  });

  factory Quote.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Quote(
      id: doc.id,
      userId: data['userId'] ?? '',
      customerId: data['customerId'],
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
      // Recupera do banco (com segurança se for antigo)
      generalDiscount: (data['generalDiscount'] ?? 0.0).toDouble(),
      generalDiscountType: data['generalDiscountType'] ?? 'fixed',
      customizationText: data['customizationText'],
      finishedImages: List<String>.from(data['finishedImages'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'customerId': customerId,
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
      'generalDiscount': generalDiscount, // Salva no banco
      'generalDiscountType': generalDiscountType, // Salva no banco
      'customizationText': customizationText,
      'finishedImages': finishedImages,
    };
}
}