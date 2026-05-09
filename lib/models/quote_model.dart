import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_constants.dart';

class Quote {
  final String? id;
  final String userId;
  final String? customerId; 
  final String status; 
  final Timestamp createdAt;
  final Timestamp? statusUpdatedAt; 
  final String clientName;
  final String clientPhone;
  final String clientCity;
  final String clientState;

  // --- CAMPOS DE PRODUÇÃO ---
  final Timestamp? deliveryDate; 
  final String priority;         

  // --- CAMPOS FINANCEIROS / PAGAMENTO ---
  final double amountPaid;       
  final String paymentStatus; 
  final List<Map<String, dynamic>> paymentHistory; // NOVO: Histórico de Pagamentos

  // Listas de Itens
  final List<Map<String, dynamic>> blanksList;
  final List<Map<String, dynamic>> cabosList;
  final List<Map<String, dynamic>> reelSeatsList;
  final List<Map<String, dynamic>> passadoresList;
  final List<Map<String, dynamic>> acessoriosList;
  
  // Valores Financeiros Básicos
  final double extraLaborCost; 
  final double totalPrice;     
  final double generalDiscount; 
  final String generalDiscountType; 

  // Outros
  final String? customizationText;
  final List<String> finishedImages;

  Quote({
    this.id,
    required this.userId,
    this.customerId,
    required this.status,
    required this.createdAt,
    this.statusUpdatedAt,
    required this.clientName,
    required this.clientPhone,
    required this.clientCity,
    required this.clientState,
    
    this.deliveryDate,
    this.priority = AppConstants.priorityNormal,

    this.amountPaid = 0.0,
    this.paymentStatus = AppConstants.paymentPendente,
    this.paymentHistory = const [], // Inicia vazio

    required this.blanksList,
    required this.cabosList,
    required this.reelSeatsList,
    required this.passadoresList,
    required this.acessoriosList,
    required this.extraLaborCost,
    required this.totalPrice,
    this.generalDiscount = 0.0, 
    this.generalDiscountType = 'fixed', 
    this.customizationText,
    this.finishedImages = const [],
  });

  Quote copyWith({
    String? id,
    String? userId,
    String? customerId,
    String? status,
    Timestamp? createdAt,
    Timestamp? statusUpdatedAt,
    String? clientName,
    String? clientPhone,
    String? clientCity,
    String? clientState,
    Timestamp? deliveryDate,
    String? priority,
    double? amountPaid,
    String? paymentStatus,
    List<Map<String, dynamic>>? paymentHistory,
    List<Map<String, dynamic>>? blanksList,
    List<Map<String, dynamic>>? cabosList,
    List<Map<String, dynamic>>? reelSeatsList,
    List<Map<String, dynamic>>? passadoresList,
    List<Map<String, dynamic>>? acessoriosList,
    double? extraLaborCost,
    double? totalPrice,
    double? generalDiscount,
    String? generalDiscountType,
    String? customizationText,
    List<String>? finishedImages,
  }) {
    return Quote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      customerId: customerId ?? this.customerId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientCity: clientCity ?? this.clientCity,
      clientState: clientState ?? this.clientState,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      priority: priority ?? this.priority,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      blanksList: blanksList ?? this.blanksList,
      cabosList: cabosList ?? this.cabosList,
      reelSeatsList: reelSeatsList ?? this.reelSeatsList,
      passadoresList: passadoresList ?? this.passadoresList,
      acessoriosList: acessoriosList ?? this.acessoriosList,
      extraLaborCost: extraLaborCost ?? this.extraLaborCost,
      totalPrice: totalPrice ?? this.totalPrice,
      generalDiscount: generalDiscount ?? this.generalDiscount,
      generalDiscountType: generalDiscountType ?? this.generalDiscountType,
      customizationText: customizationText ?? this.customizationText,
      finishedImages: finishedImages ?? this.finishedImages,
    );
  }

  factory Quote.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Quote(
      id: doc.id,
      userId: data['userId'] ?? '',
      customerId: data['customerId'],
      status: data['status'] ?? AppConstants.statusPendente,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      statusUpdatedAt: data['statusUpdatedAt'],
      clientName: data['clientName'] ?? '',
      clientPhone: data['clientPhone'] ?? '',
      clientCity: data['clientCity'] ?? '',
      clientState: data['clientState'] ?? '',
      
      deliveryDate: data['deliveryDate'],
      priority: data['priority'] ?? AppConstants.priorityNormal,

      amountPaid: (data['amountPaid'] ?? 0.0).toDouble(),
      paymentStatus: data['paymentStatus'] ?? AppConstants.paymentPendente,
      paymentHistory: List<Map<String, dynamic>>.from(data['paymentHistory'] ?? []),

      blanksList: List<Map<String, dynamic>>.from(data['blanksList'] ?? []),
      cabosList: List<Map<String, dynamic>>.from(data['cabosList'] ?? []),
      reelSeatsList: List<Map<String, dynamic>>.from(data['reelSeatsList'] ?? []),
      passadoresList: List<Map<String, dynamic>>.from(data['passadoresList'] ?? []),
      acessoriosList: List<Map<String, dynamic>>.from(data['acessoriosList'] ?? []),
      extraLaborCost: (data['extraLaborCost'] ?? 0.0).toDouble(),
      totalPrice: (data['totalPrice'] ?? 0.0).toDouble(),
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
      'statusUpdatedAt': statusUpdatedAt, 
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientCity': clientCity,
      'clientState': clientState,
      
      'deliveryDate': deliveryDate,
      'priority': priority,

      'amountPaid': amountPaid,
      'paymentStatus': paymentStatus,
      'paymentHistory': paymentHistory,

      'blanksList': blanksList,
      'cabosList': cabosList,
      'reelSeatsList': reelSeatsList,
      'passadoresList': passadoresList,
      'acessoriosList': acessoriosList,
      'extraLaborCost': extraLaborCost,
      'totalPrice': totalPrice,
      'generalDiscount': generalDiscount,
      'generalDiscountType': generalDiscountType,
      'customizationText': customizationText,
      'finishedImages': finishedImages,
    };
  }
}