import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quote_model.dart';
import '../utils/app_constants.dart';

class QuoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference _quotesCollection;
  late final CollectionReference _componentsCollection;

  // Status que ativam a baixa de estoque (Usando constantes para segurança)
  final List<String> _stockConsumingStatuses = [
    AppConstants.statusAprovado,
    AppConstants.statusProducao,
    AppConstants.statusConcluido
  ];

  QuoteService() {
    _quotesCollection = _firestore.collection(AppConstants.colQuotes);
    _componentsCollection = _firestore.collection(AppConstants.colComponents);
  }

  // --- LEITURA ---

  Stream<List<Quote>> getQuotesStream(String userId) {
    return _quotesCollection.where('userId', isEqualTo: userId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Quote.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Quote>> getAllQuotesStream() {
    return _quotesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Quote.fromFirestore(doc)).toList();
    });
  }

  Future<DocumentSnapshot> getQuoteSnapshot(String quoteId) {
    return _quotesCollection.doc(quoteId).get();
  }

  // --- ESCRITA COM TRANSAÇÃO DE ESTOQUE ---

  Future<DocumentReference> saveQuote(Quote quote) async {
    return await _firestore.runTransaction((transaction) async {
      final newQuoteRef = _quotesCollection.doc();

      if (_stockConsumingStatuses.contains(quote.status.toLowerCase())) {
        await _processStockChange(transaction, quote, isDeducting: true);
      }

      transaction.set(newQuoteRef, quote.toMap());
      return newQuoteRef;
    });
  }

  Future<void> updateQuote(String quoteId, Map<String, dynamic> newData) async {
    final quoteRef = _quotesCollection.doc(quoteId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(quoteRef);
      if (!snapshot.exists) throw Exception("Orçamento não encontrado!");

      final oldQuote = Quote.fromFirestore(snapshot);
      final newStatus = (newData['status'] ?? oldQuote.status).toString().toLowerCase();

      bool wasConsuming = _stockConsumingStatuses.contains(oldQuote.status.toLowerCase());
      bool willConsume = _stockConsumingStatuses.contains(newStatus);

      // 1. REVERTER ESTOQUE ANTIGO SE NECESSÁRIO
      if (wasConsuming) {
        await _processStockChange(transaction, oldQuote, isDeducting: false); // Devolve
      }

      // 2. APLICAR NOVO ESTOQUE SE NECESSÁRIO
      if (willConsume) {
        // Helper para mesclar listas
        List<Map<String, dynamic>> getList(String key, List<Map<String, dynamic>> oldList) {
          if (newData.containsKey(key)) {
            return List<Map<String, dynamic>>.from(newData[key]);
          }
          return oldList;
        }

        final tempNewQuote = Quote(
          userId: oldQuote.userId,
          status: newStatus,
          createdAt: oldQuote.createdAt,
          totalPrice: 0,
          clientName: '', clientPhone: '', clientCity: '', clientState: '',
          extraLaborCost: 0,
          blanksList: getList('blanksList', oldQuote.blanksList),
          cabosList: getList('cabosList', oldQuote.cabosList),
          reelSeatsList: getList('reelSeatsList', oldQuote.reelSeatsList),
          passadoresList: getList('passadoresList', oldQuote.passadoresList),
          acessoriosList: getList('acessoriosList', oldQuote.acessoriosList),
        );

        await _processStockChange(transaction, tempNewQuote, isDeducting: true); // Deduz
      }

      transaction.update(quoteRef, newData);
    });
  }

  Future<void> deleteQuote(String quoteId) async {
    final quoteRef = _quotesCollection.doc(quoteId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(quoteRef);
      if (!snapshot.exists) return;

      final quote = Quote.fromFirestore(snapshot);

      if (_stockConsumingStatuses.contains(quote.status.toLowerCase())) {
        await _processStockChange(transaction, quote, isDeducting: false); // Devolve
      }

      transaction.delete(quoteRef);
    });
  }

  // --- HELPER DE ESTOQUE ---

  Future<void> _processStockChange(Transaction t, Quote quote, {required bool isDeducting}) async {
    int multiplier = isDeducting ? -1 : 1;

    Future<void> updateItem(String? name, String? variation, int qty) async {
      if (name == null || name.isEmpty || qty <= 0) return;

      try {
        final querySnap = await _componentsCollection.where('name', isEqualTo: name).limit(1).get();
        if (querySnap.docs.isEmpty) return;

        final docRef = querySnap.docs.first.reference;
        final currentData = querySnap.docs.first.data() as Map<String, dynamic>;

        if (variation != null && variation.isNotEmpty) {
          Map<String, dynamic> variations = currentData['variations'] != null
              ? Map<String, dynamic>.from(currentData['variations'])
              : {};

          if (variations.containsKey(variation)) {
            int currentVarStock = (variations[variation] as num).toInt();
            int newVarStock = currentVarStock + (qty * multiplier);
            variations[variation] = newVarStock;

            int currentTotal = (currentData['stock'] ?? 0).toInt();
            int newTotal = currentTotal + (qty * multiplier);

            t.update(docRef, {
              'variations': variations,
              'stock': newTotal
            });
          }
        } else {
          int currentStock = (currentData['stock'] ?? 0).toInt();
          int newStock = currentStock + (qty * multiplier);
          t.update(docRef, {'stock': newStock});
        }
      } catch (e) {
        print("Erro ao atualizar estoque: $e");
      }
    }

    for (var item in quote.blanksList) await updateItem(item['name'], item['variation'], (item['quantity'] ?? 1).toInt());
    for (var item in quote.cabosList) await updateItem(item['name'], item['variation'], (item['quantity'] ?? 1).toInt());
    for (var item in quote.reelSeatsList) await updateItem(item['name'], item['variation'], (item['quantity'] ?? 1).toInt());
    for (var item in quote.passadoresList) await updateItem(item['name'], item['variation'], (item['quantity'] ?? 1).toInt());
    for (var item in quote.acessoriosList) await updateItem(item['name'], item['variation'], (item['quantity'] ?? 1).toInt());
  }
}