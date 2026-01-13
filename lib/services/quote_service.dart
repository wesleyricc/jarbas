import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quote_model.dart';
import '../models/component_model.dart'; // Necessário para acessar a classe ComponentVariation
import '../utils/app_constants.dart';

class QuoteService {
  final CollectionReference _quotesCollection = FirebaseFirestore.instance.collection(AppConstants.colQuotes);
  final CollectionReference _componentsCollection = FirebaseFirestore.instance.collection(AppConstants.colComponents);

  // --- CRUD BÁSICO ---
  
  Future<void> saveQuote(Quote quote) {
    if (quote.id == null || quote.id!.isEmpty) {
      return _quotesCollection.add(quote.toMap());
    } else {
      return _quotesCollection.doc(quote.id).set(quote.toMap());
    }
  }

  Stream<List<Quote>> getQuotesStream(String userId) {
    return _quotesCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Quote.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Quote>> getAllQuotesStream() {
    return _quotesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Quote.fromFirestore(doc)).toList();
    });
  }

  Future<void> updateQuote(String id, Map<String, dynamic> data) {
    return _quotesCollection.doc(id).update(data);
  }

  Future<void> deleteQuote(String id) {
    return _quotesCollection.doc(id).delete();
  }

  // --- CONTROLE DE ESTOQUE (NOVO) ---

  /// Atualiza o estoque com base nos itens do orçamento.
  /// [isDeducting]: true para BAIXAR (venda), false para ESTORNAR (cancelamento).
  Future<void> updateStockFromQuote(Quote quote, {required bool isDeducting}) async {
    final firestore = FirebaseFirestore.instance;

    // Função auxiliar para processar uma lista de itens do orçamento
    Future<void> processItems(List<Map<String, dynamic>> items) async {
      for (var item in items) {
        String compId = item['id']; 
        String? variationName = item['variation'];
        int qty = (item['quantity'] ?? 1).toInt();
        
        // Define se soma ou subtrai
        int change = isDeducting ? -qty : qty;

        DocumentReference docRef = _componentsCollection.doc(compId);

        // Executa uma transação para cada componente para garantir integridade
        await firestore.runTransaction((transaction) async {
          DocumentSnapshot snapshot = await transaction.get(docRef);
          
          if (!snapshot.exists) return; // Componente não existe mais, ignora.

          // Reconstrói o objeto Component a partir do snapshot
          Component comp = Component.fromFirestore(snapshot);
          
          // Prepara as listas para modificação
          List<ComponentVariation> updatedVars = List.from(comp.variations);
          int newTotalStock = comp.stock;
          bool hasChanges = false;

          // Cenário 1: Item tem variação selecionada
          if (variationName != null && variationName.isNotEmpty && updatedVars.isNotEmpty) {
             int index = updatedVars.indexWhere((v) => v.name == variationName);
             if (index != -1) {
               var v = updatedVars[index];
               int newVarStock = v.stock + change;
               
               // Atualiza o objeto da variação
               updatedVars[index] = ComponentVariation(
                 id: v.id, 
                 name: v.name, 
                 stock: newVarStock, 
                 price: v.price, 
                 supplierPrice: v.supplierPrice, 
                 costPrice: v.costPrice, 
                 imageUrl: v.imageUrl
               );
               hasChanges = true;
             }
          } 
          // Cenário 2: Item sem variação (ou variação não encontrada), mas lista de variações vazia
          else if (updatedVars.isEmpty) {
             // É um produto simples, atualiza direto o estoque total
             newTotalStock += change;
             hasChanges = true;
          }

          // Recalcula o estoque total se houver variações
          if (updatedVars.isNotEmpty) {
             newTotalStock = updatedVars.fold(0, (sum, v) => sum + v.stock);
             hasChanges = true; // Sempre marca como alterado para salvar a consistência
          }

          if (hasChanges) {
             transaction.update(docRef, {
               'stock': newTotalStock,
               'variations': updatedVars.map((v) => v.toMap()).toList()
             });
          }
        });
      }
    }

    // Processa todas as listas do orçamento
    await processItems(quote.blanksList);
    await processItems(quote.cabosList);
    await processItems(quote.reelSeatsList);
    await processItems(quote.passadoresList);
    await processItems(quote.acessoriosList);
  }
}