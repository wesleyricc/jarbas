import 'package:cloud_firestore/cloud_firestore.dart';

class Component {
  final String id;
  final String name;
  final String description;
  final String category;
  final double price;      // Preço de Venda
  final double costPrice;  // (NOVO) Preço de Custo
  final int stock;
  final String imageUrl;
  final Map<String, dynamic> attributes;
  final String? supplierLink;

  Component({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    this.costPrice = 0.0, // (NOVO) Padrão 0
    required this.stock,
    required this.imageUrl,
    required this.attributes,
    this.supplierLink,
  });

  factory Component.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Component(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      costPrice: (data['costPrice'] ?? 0.0).toDouble(), // (NOVO)
      stock: (data['stock'] ?? 0).toInt(),
      imageUrl: data['imageUrl'] ?? '',
      attributes: data['attributes'] ?? {},
      supplierLink: data['supplierLink'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'costPrice': costPrice, // (NOVO)
      'stock': stock,
      'imageUrl': imageUrl,
      'attributes': attributes,
      'supplierLink': supplierLink,
    };
  }
}