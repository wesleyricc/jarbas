import 'package:cloud_firestore/cloud_firestore.dart';

class ComponentVariation {
  final String id; 
  final String name; 
  final int stock;
  
  // NOVOS CAMPOS DE PRECIFICAÇÃO
  final double supplierPrice; // Preço Tabela
  final double costPrice;     // Preço Custo
  final double price;         // Preço Venda
  
  final String? imageUrl;

  ComponentVariation({
    required this.id,
    required this.name,
    required this.stock,
    this.supplierPrice = 0.0, // Default 0
    this.costPrice = 0.0,     // Default 0
    required this.price,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'stock': stock,
      'supplierPrice': supplierPrice, // Salva
      'costPrice': costPrice,         // Salva
      'price': price,
      'imageUrl': imageUrl,
    };
  }

  factory ComponentVariation.fromMap(Map<String, dynamic> map) {
    return ComponentVariation(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      stock: (map['stock'] ?? 0).toInt(),
      
      // Carrega com segurança (se for antigo, vem 0.0)
      supplierPrice: (map['supplierPrice'] ?? 0.0).toDouble(),
      costPrice: (map['costPrice'] ?? 0.0).toDouble(),
      price: (map['price'] ?? 0.0).toDouble(),
      
      imageUrl: map['imageUrl'],
    );
  }
}

class Component {
  final String id;
  final String name;
  final String description;
  final String category;
  
  final double supplierPrice;
  final double costPrice;
  final double price; 
  
  final int stock; 
  final String imageUrl; 
  final Map<String, dynamic> attributes;
  final String? supplierLink;
  
  final List<ComponentVariation> variations; 

  Component({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.supplierPrice = 0.0,
    this.costPrice = 0.0,
    required this.price,
    required this.stock,
    required this.imageUrl,
    required this.attributes,
    this.supplierLink,
    this.variations = const [],
  });

  factory Component.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    List<ComponentVariation> parsedVariations = [];
    if (data['variations'] != null && data['variations'] is List) {
      parsedVariations = (data['variations'] as List).map((v) {
        return ComponentVariation.fromMap(v as Map<String, dynamic>);
      }).toList();
    } 

    return Component(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      supplierPrice: (data['supplierPrice'] ?? 0.0).toDouble(),
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
      'supplierPrice': supplierPrice,
      'costPrice': costPrice,
      'price': price,
      'stock': stock,
      'imageUrl': imageUrl,
      'attributes': attributes,
      'supplierLink': supplierLink,
      'variations': variations.map((v) => v.toMap()).toList(),
    };
  }
}