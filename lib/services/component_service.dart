import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/component_model.dart';

class ComponentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference _componentsCollection;

  ComponentService() {
    _componentsCollection = _firestore.collection('components');
  }

  // --- LEITURA ---

  /// Retorna um Stream de todos os componentes.
  Stream<List<Component>> getComponentsStream() {
    return _componentsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Component.fromFirestore(doc);
      }).toList();
    });
  }

  /// Retorna um Stream de componentes filtrados por categoria.
  Stream<List<Component>> getComponentsByCategoryStream(String category) {
    return _componentsCollection
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Component.fromFirestore(doc);
      }).toList();
    });
  }

  /// Busca um componente pelo nome (usado no editor de orçamento)
  Future<Component?> getComponentByName(String? name) async {
    if (name == null || name.isEmpty) return null;
    
    try {
      final query = await _componentsCollection
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return Component.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      print("Erro ao buscar componente por nome: $e");
      return null;
    }
  }

  // --- ESCRITA (CRUD) ---

  /// Adiciona um novo componente
  Future<void> addComponent(Component component) {
    return _componentsCollection.add(component.toMap());
  }

  /// Atualiza um componente existente
  Future<void> updateComponent(String id, Component component) {
    return _componentsCollection.doc(id).update(component.toMap());
  }

  /// Exclui um componente
  Future<void> deleteComponent(String id) {
    return _componentsCollection.doc(id).delete();
  }

  // --- MÉTODOS DE ATUALIZAÇÃO EM MASSA (BATCH) ---

  /// 1. Recalcula APENAS o Preço de Venda de TODOS os itens
  /// Baseado no Custo Atual (que não muda) e na Nova Margem informada.
  Future<void> batchRecalculateSellingPrices(double marginPercent) async {
    final snapshot = await _componentsCollection.get();
    
    WriteBatch batch = _firestore.batch();
    int count = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      double cost = (data['costPrice'] ?? 0.0).toDouble();
      
      // Se o custo for 0, não faz sentido aplicar margem
      if (cost > 0) {
        // Fórmula: Custo * (1 + Margem%)
        double newSellingPrice = cost * (1 + (marginPercent / 100));
        
        // Arredonda para 2 casas decimais
        newSellingPrice = double.parse(newSellingPrice.toStringAsFixed(2));

        batch.update(doc.reference, {'price': newSellingPrice});
        count++;

        // Firestore limita batch a 500 operações.
        if (count % 400 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
    }

    if (count > 0) await batch.commit();
  }

  /// 2. Reajuste em Massa Completo (Cascata)
  /// Atualiza: Fornecedor -> Custo -> Venda
  Future<void> batchUpdateSpecificComponents({
    required List<Component> componentsToUpdate,
    required double increasePercent, // Percentual de aumento/redução
    required double currentMargin,   // Margem de Lucro Global (%)
    required double supplierDiscount, // Desconto do Fornecedor Global (%)
  }) async {
    WriteBatch batch = _firestore.batch();
    int count = 0;

    for (var comp in componentsToUpdate) {
      double currentSupplierPrice = comp.supplierPrice;
      
      // Só atualiza se tiver preço de fornecedor base
      if (currentSupplierPrice > 0) {
        
        // 1. Novo Preço Fornecedor (Aplica o reajuste sobre o valor atual)
        double newSupplierPrice = currentSupplierPrice * (1 + (increasePercent / 100));
        newSupplierPrice = double.parse(newSupplierPrice.toStringAsFixed(2));

        // 2. Novo Preço de Custo (Aplica o desconto global sobre o novo preço do fornecedor)
        // Fórmula: Fornecedor * (1 - Desconto%)
        double newCostPrice = newSupplierPrice * (1 - (supplierDiscount / 100));
        newCostPrice = double.parse(newCostPrice.toStringAsFixed(2));

        // 3. Novo Preço de Venda (Aplica a margem global sobre o novo custo)
        // Fórmula: Custo * (1 + Margem%)
        double newSellingPrice = newCostPrice * (1 + (currentMargin / 100));
        newSellingPrice = double.parse(newSellingPrice.toStringAsFixed(2));

        // Adiciona ao lote de atualização
        batch.update(_componentsCollection.doc(comp.id), {
          'supplierPrice': newSupplierPrice,
          'costPrice': newCostPrice,
          'price': newSellingPrice
        });

        count++;
        
        // Commit parcial para evitar estouro de limite (500)
        if (count % 400 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
    }

    // Commit final dos itens restantes
    if (count > 0) await batch.commit();
  }
}