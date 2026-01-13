import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kit_model.dart';
import '../models/component_model.dart';
import '../utils/app_constants.dart';

class KitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference _kitsCollection;
  late final CollectionReference _componentsCollection;

  KitService() {
    _kitsCollection = _firestore.collection(AppConstants.colKits);
    _componentsCollection = _firestore.collection(AppConstants.colComponents);
  }

  Stream<List<KitModel>> getKitsStream() {
    return _kitsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => KitModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> saveKit(KitModel kit) async {
    if (kit.id.isEmpty) {
      await _kitsCollection.add(kit.toMap());
    } else {
      await _kitsCollection.doc(kit.id).update(kit.toMap());
    }
  }

  Future<void> deleteKit(String id) {
    return _kitsCollection.doc(id).delete();
  }

  // --- MÉTODOS AUXILIARES ---

  Future<Component?> getComponentById(String id) async {
    if (id.isEmpty) return null;
    try {
      final doc = await _componentsCollection.doc(id).get();
      if (doc.exists) {
        return Component.fromFirestore(doc);
      }
    } catch (e) {
      print("Erro ao buscar componente do kit ($id): $e");
    }
    return null;
  }

  // Calcula preço total e verifica estoque
  Future<Map<String, dynamic>> getKitSummary(KitModel kit) async {
    double total = 0.0;
    bool available = true;

    Future<void> checkItem(String id, String? variation, int qty) async {
      if (id.isEmpty) return;
      final comp = await getComponentById(id);
      
      if (comp != null) {
        // --- LÓGICA DE PREÇO POR VARIAÇÃO ---
        double itemPrice = comp.price; // Preço base
        int itemStock = comp.stock;    // Estoque total base

        if (variation != null && variation.isNotEmpty) {
          try {
            // Busca a variação específica
            final variant = comp.variations.firstWhere((v) => v.name == variation);
            
            // Se a variação tem preço específico (>0), usa ele
            if (variant.price > 0) itemPrice = variant.price;
            
            // Se achou a variação, usa o estoque DELA para validar
            itemStock = variant.stock; 
          } catch (e) {
            // Variação não encontrada (pode ter sido deletada), usa base
          }
        }
        // ------------------------------------

        total += (itemPrice * qty);
        
        if (itemStock < qty) available = false;
      }
    }

    for (var item in kit.blanksIds) await checkItem(item['id'], item['variation'], (item['quantity'] ?? 1).toInt());
    for (var item in kit.cabosIds) await checkItem(item['id'], item['variation'], (item['quantity'] ?? 1).toInt());
    for (var item in kit.reelSeatsIds) await checkItem(item['id'], item['variation'], (item['quantity'] ?? 1).toInt());
    for (var item in kit.passadoresIds) await checkItem(item['id'], item['variation'], (item['quantity'] ?? 1).toInt());
    for (var item in kit.acessoriosIds) await checkItem(item['id'], item['variation'], (item['quantity'] ?? 1).toInt());

    return {
      'totalPrice': total,
      'isAvailable': available,
    };
  }
}