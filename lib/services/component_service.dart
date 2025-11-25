import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/component_model.dart';

class ComponentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Referência para a coleção 'components'
  late final CollectionReference _componentsCollection;

  ComponentService() {
    _componentsCollection = _firestore.collection('components');
  }

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

  /// Adiciona um novo componente (mais usado pelo painel admin)
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

  // --- NOVO MÉTODO (MOVIDO E CORRIGIDO) ---
  /// Busca um componente pelo nome (usado no editor de orçamento)
  Future<Component?> getComponentByName(String? name) async {
    if (name == null || name.isEmpty) return null;
    
    try {
      // Agora tem acesso ao _componentsCollection
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

  // --- NOVOS MÉTODOS DE ATUALIZAÇÃO EM MASSA ---

  /// 1. Recalcula o Preço de Venda de TODOS os itens baseado na nova margem
  Future<void> batchRecalculateSellingPrices(double marginPercent) async {
    // Busca todos os componentes
    final snapshot = await _componentsCollection.get();
    
    WriteBatch batch = _firestore.batch();
    int count = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      double cost = (data['costPrice'] ?? 0.0).toDouble();
      
      // Se o custo for 0, não faz sentido aplicar margem
      if (cost > 0) {
        // Fórmula: Custo + (Custo * Margem%)
        double newSellingPrice = cost * (1 + (marginPercent / 100));
        
        // Arredonda para 2 casas decimais
        newSellingPrice = double.parse(newSellingPrice.toStringAsFixed(2));

        batch.update(doc.reference, {'price': newSellingPrice});
        count++;

        // Firestore limita batch a 500 ops. Se passar, commita e abre outro.
        if (count % 400 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
    }

    if (count > 0) await batch.commit();
  }

  // --- NOVO MÉTODO: Atualização em Lote por Lista Específica ---
  Future<void> batchUpdateSpecificComponents({
    required List<Component> componentsToUpdate,
    required double increasePercent,
    required double currentMargin,
  }) async {
    WriteBatch batch = _firestore.batch();
    int count = 0;

    for (var comp in componentsToUpdate) {
      double currentCost = comp.costPrice;
      
      // Se custo for 0, não altera, ou assume que o aumento é sobre 0 (continua 0)
      if (currentCost > 0) {
        // 1. Novo Custo
        double newCost = currentCost * (1 + (increasePercent / 100));
        newCost = double.parse(newCost.toStringAsFixed(2));

        // 2. Nova Venda (Mantendo a margem configurada)
        double newSellingPrice = newCost * (1 + (currentMargin / 100));
        newSellingPrice = double.parse(newSellingPrice.toStringAsFixed(2));

        batch.update(_componentsCollection.doc(comp.id), {
          'costPrice': newCost,
          'price': newSellingPrice
        });

        count++;
        // Batch limit safety
        if (count % 400 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
    }

    if (count > 0) await batch.commit();
  }

  /// 2. Aumenta o Custo (e consequentemente a Venda) por um percentual
  /// Pode filtrar por categoria ou aplicar em todos (category = null)
  Future<void> batchIncreaseCostPrices({
    required double increasePercent, 
    required double currentMargin,
    String? categoryFilter
  }) async {
    Query query = _componentsCollection;
    
    // Aplica filtro se houver
    if (categoryFilter != null && categoryFilter != 'todos') {
      query = query.where('category', isEqualTo: categoryFilter);
    }

    final snapshot = await query.get();
    
    WriteBatch batch = _firestore.batch();
    int count = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      double currentCost = (data['costPrice'] ?? 0.0).toDouble();

      if (currentCost > 0) {
        // 1. Calcula novo Custo
        double newCost = currentCost * (1 + (increasePercent / 100));
        newCost = double.parse(newCost.toStringAsFixed(2));

        // 2. Calcula nova Venda (para manter a margem correta sobre o novo custo)
        double newSellingPrice = newCost * (1 + (currentMargin / 100));
        newSellingPrice = double.parse(newSellingPrice.toStringAsFixed(2));

        batch.update(doc.reference, {
          'costPrice': newCost,
          'price': newSellingPrice
        });
        
        count++;
        if (count % 400 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
    }

    if (count > 0) await batch.commit();
  }
}
