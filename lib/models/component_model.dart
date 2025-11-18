import 'package:cloud_firestore/cloud_firestore.dart';

class Component {
  final String id;
  final String name;
  final String description;
  final String category;
  final double price;
  final int stock;
  final String imageUrl;
  final Map<String, dynamic> attributes;
  final String? supplierLink; // Link do fornecedor

  Component({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.stock,
    required this.imageUrl,
    required this.attributes,
    this.supplierLink, // Adicionado ao construtor
  });

  // Método 'factory' para criar um Component a partir de um DocumentSnapshot do Firestore
  factory Component.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Component(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      stock: (data['stock'] ?? 0).toInt(),
      imageUrl: data['imageUrl'] ?? '',
      attributes: data['attributes'] ?? {},
      supplierLink: data['supplierLink'], // Adicionado
    );
  }

  // Método para converter um Component em um Map (útil para salvar dados no Firestore)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'stock': stock,
      'imageUrl': imageUrl,
      'attributes': attributes,
      'supplierLink': supplierLink, // Adicionado
    };
  }
}