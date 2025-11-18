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
}