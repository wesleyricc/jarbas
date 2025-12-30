import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/component_model.dart';

class ComponentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference _componentsCollection;

  ComponentService() {
    _componentsCollection = _firestore.collection('components');
  }

  // --- LEITURA ---

  Stream<List<Component>> getComponentsStream() {
    return _componentsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Component.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Component>> getComponentsByCategoryStream(String category) {
    return _componentsCollection.where('category', isEqualTo: category).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Component.fromFirestore(doc)).toList();
    });
  }

  // (NOVO) Busca itens com estoque baixo (Ex: < 3 unidades)
  Stream<List<Component>> getLowStockComponentsStream({int threshold = 3}) {
    return _componentsCollection
        .where('stock', isLessThan: threshold)
        .snapshots() // Nota: Para ordenar, precisaria de um índice composto no Firebase
        .map((snapshot) {
      return snapshot.docs.map((doc) => Component.fromFirestore(doc)).toList();
    });
  }

  Future<Component?> getComponentByName(String? name) async {
    if (name == null || name.isEmpty) return null;
    try {
      final query = await _componentsCollection.where('name', isEqualTo: name).limit(1).get();
      if (query.docs.isNotEmpty) return Component.fromFirestore(query.docs.first);
      return null;
    } catch (e) {
      print("Erro ao buscar componente por nome: $e");
      return null;
    }
  }

  // --- ESCRITA (CRUD) ---

  Future<void> addComponent(Component component) {
    return _componentsCollection.add(component.toMap());
  }

  Future<void> updateComponent(String id, Component component) {
    return _componentsCollection.doc(id).update(component.toMap());
  }

  Future<void> deleteComponent(String id) {
    return _componentsCollection.doc(id).delete();
  }

  // --- MANIPULAÇÃO DE ESTOQUE (BATCH) ---

  Future<void> batchRecalculateSellingPrices(double marginPercent) async {
    // ... (Código existente mantido) ...
    final snapshot = await _componentsCollection.get();
    WriteBatch batch = _firestore.batch();
    int count = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      double cost = (data['costPrice'] ?? 0.0).toDouble();
      if (cost > 0) {
        double newSellingPrice = cost * (1 + (marginPercent / 100));
        newSellingPrice = double.parse(newSellingPrice.toStringAsFixed(2));
        batch.update(doc.reference, {'price': newSellingPrice});
        count++;
        if (count % 400 == 0) { await batch.commit(); batch = _firestore.batch(); }
      }
    }
    if (count > 0) await batch.commit();
  }

  Future<void> batchUpdateSpecificComponents({
    required List<Component> componentsToUpdate,
    required double increasePercent,
    required double currentMargin,
    required double supplierDiscount,
  }) async {
    // ... (Código existente mantido) ...
    WriteBatch batch = _firestore.batch();
    int count = 0;
    for (var comp in componentsToUpdate) {
      double currentSupplierPrice = comp.supplierPrice;
      if (currentSupplierPrice > 0) {
        double newSupplierPrice = currentSupplierPrice * (1 + (increasePercent / 100));
        newSupplierPrice = double.parse(newSupplierPrice.toStringAsFixed(2));
        double newCostPrice = newSupplierPrice * (1 - (supplierDiscount / 100));
        newCostPrice = double.parse(newCostPrice.toStringAsFixed(2));
        double newSellingPrice = newCostPrice * (1 + (currentMargin / 100));
        newSellingPrice = double.parse(newSellingPrice.toStringAsFixed(2));

        batch.update(_componentsCollection.doc(comp.id), {
          'supplierPrice': newSupplierPrice,
          'costPrice': newCostPrice,
          'price': newSellingPrice
        });
        count++;
        if (count % 400 == 0) { await batch.commit(); batch = _firestore.batch(); }
      }
    }
    if (count > 0) await batch.commit();
  }
}