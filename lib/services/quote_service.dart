import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quote_model.dart';

class QuoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference _quotesCollection;

  QuoteService() {
    _quotesCollection = _firestore.collection('quotes');
  }

  // Salvar um novo orçamento
  Future<DocumentReference> saveQuote(Quote quote) async {
    try {
      return await _quotesCollection.add(quote.toMap());
    } catch (e) {
      print("Erro ao salvar orçamento: $e");
      rethrow;
    }
  }

  // Atualizar um orçamento existente (ex: mudar status)
  Future<void> updateQuote(String quoteId, Map<String, dynamic> data) {
    return _quotesCollection.doc(quoteId).update(data);
  }

  // --- (NOVO MÉTODO) ---
  /// Exclui um orçamento do Firestore
  Future<void> deleteQuote(String quoteId) {
    return _quotesCollection.doc(quoteId).delete();
  }
  // --- FIM DO NOVO MÉTODO ---

  // Buscar orçamentos de um usuário específico
  Stream<List<Quote>> getQuotesStream(String userId) {
    return _quotesCollection
        .where('userId', isEqualTo: userId)
        // .orderBy('createdAt', descending: true) // Descomente se criar o índice
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Quote.fromFirestore(doc)).toList();
    });
  }

  /// Busca TODOS os orçamentos (para o painel admin)
  Stream<List<Quote>> getAllQuotesStream() {
    return _quotesCollection
        // .orderBy('createdAt', descending: true) // Descomente se criar o índice
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Quote.fromFirestore(doc)).toList();
    });
  }
  
  /// Busca um snapshot de um orçamento específico (para recarregar dados)
  Future<DocumentSnapshot> getQuoteSnapshot(String quoteId) {
    return _quotesCollection.doc(quoteId).get();
  }
}