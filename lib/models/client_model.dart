import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String id;
  final String name;
  final String phone;
  final String city;
  final String state;
  final Timestamp createdAt;

  Client({
    this.id = '',
    required this.name,
    required this.phone,
    required this.city,
    required this.state,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'city': city,
      'state': state,
      'createdAt': createdAt,
      'searchKey': name.toLowerCase(), // Para facilitar busca
    };
  }

  factory Client.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Client(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}