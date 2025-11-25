import 'package:cloud_firestore/cloud_firestore.dart';

class Component {
  final String id;
  final String name;
  final String description;
  final String category;
  
  final double supplierPrice; // (NOVO) Preço Tabela Fornecedor
  final double costPrice;     // Preço de Custo (Calculado com desconto)
  final double price;         // Preço de Venda (Calculado com margem)
  
  final int stock;
  final String imageUrl;
  final Map<String, dynamic> attributes;
  final String? supplierLink;
  final Map<String, int> variations;

  Component({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    
    this.supplierPrice = 0.0, // (NOVO)
    this.costPrice = 0.0,
    required this.price,
    
    required this.stock,
    required this.imageUrl,
    required this.attributes,
    this.supplierLink,
    this.variations = const {},
  });

  factory Component.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Helper para variações
    Map<String, int> parsedVariations = {};
    if (data['variations'] != null) {
      (data['variations'] as Map<String, dynamic>).forEach((key, value) {
        parsedVariations[key] = (value as num).toInt();
      });
    }

    return Component(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      
      supplierPrice: (data['supplierPrice'] ?? 0.0).toDouble(), // (NOVO)
      costPrice: (data['costPrice'] ?? 0.0).toDouble(),
      price: (data['price'] ?? 0.0).toDouble(),
      
      stock: (data['stock'] ?? 0).toInt(),
      imageUrl: data['imageUrl'] ?? '',
      attributes: data['attributes'] ?? {},
      supplierLink: data['supplierLink'],
      variations: parsedVariations,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      
      'supplierPrice': supplierPrice, // (NOVO)
      'costPrice': costPrice,
      'price': price,
      
      'stock': stock,
      'imageUrl': imageUrl,
      'attributes': attributes,
      'supplierLink': supplierLink,
      'variations': variations,
    };
  }
}