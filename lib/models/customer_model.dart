import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String city;
  final String state;
  final String? notes; // NOVO: Campo de observações
  final Timestamp createdAt;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
    required this.state,
    this.notes,
    required this.createdAt,
  });

  factory CustomerModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CustomerModel(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      notes: data['notes'], // Mapeamento
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'city': city,
      'state': state,
      'notes': notes, // Persistência
      'createdAt': createdAt,
    };
  }
}