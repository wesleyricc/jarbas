import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/component_model.dart';
import '../utils/app_constants.dart';

class ComponentService {
  final CollectionReference _componentsCollection = FirebaseFirestore.instance.collection(AppConstants.colComponents);

  // --- LEITURA BÁSICA ---

  Stream<List<Component>> getComponentsStream() {
    return _componentsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Component.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Component>> getComponentsByCategoryStream(String category) {
    return _componentsCollection
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Component.fromFirestore(doc)).toList();
    });
  }
  
  // Buscar um único componente
  Future<Component?> getComponentById(String id) async {
    try {
      final doc = await _componentsCollection.doc(id).get();
      if (doc.exists) {
        return Component.fromFirestore(doc);
      }
    } catch (e) {
      print("Erro ao buscar componente: $e");
    }
    return null;
  }

  // --- FUNÇÕES ESPECÍFICAS ---

  // Monitorar Estoque Baixo (Alertas)
  Stream<List<Component>> getLowStockComponentsStream({int threshold = 3}) {
    return _componentsCollection
        .where('stock', isLessThanOrEqualTo: threshold)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Component.fromFirestore(doc))
            .toList());
  }

  // --- ESCRITA ---

  Future<void> addComponent(Component component) {
    return _componentsCollection.add(component.toMap());
  }

  Future<void> updateComponent(Component component) {
    return _componentsCollection.doc(component.id).update(component.toMap());
  }

  Future<void> deleteComponent(String id) {
    return _componentsCollection.doc(id).delete();
  }
  
  // --- ATUALIZAÇÃO EM MASSA (MASS UPDATE) ---

  // Recalcular Preço de TODOS (Margem Global)
  Future<void> batchRecalculateSellingPrices(double marginPercentage) async {
    final snapshot = await _componentsCollection.get();
    final batch = FirebaseFirestore.instance.batch();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final cost = (data['costPrice'] ?? 0).toDouble();
      final newPrice = cost * (1 + (marginPercentage / 100));
      batch.update(doc.reference, {'price': newPrice});
    }

    await batch.commit();
  }

  // Atualizar Preço de Itens ESPECÍFICOS
  Future<void> batchUpdateSpecificComponents({
    required List<String> componentsToUpdate,
    double increasePercent = 0.0,
    double currentMargin = 0.0,
    double supplierDiscount = 0.0,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    for (var id in componentsToUpdate) {
      final docRef = _componentsCollection.doc(id);
      final docSnap = await docRef.get();
      
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        double newPrice = 0.0;
        
        if (increasePercent != 0) {
          final currentPrice = (data['price'] ?? 0).toDouble();
          newPrice = currentPrice * (1 + (increasePercent / 100));
        } else {
          final cost = (data['costPrice'] ?? 0).toDouble();
          double realCost = cost * (1 - (supplierDiscount / 100));
          newPrice = realCost * (1 + (currentMargin / 100));
        }
        
        batch.update(docRef, {'price': newPrice});
      }
    }

    await batch.commit();
  }
}