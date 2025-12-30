import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quote_model.dart';
import '../models/component_model.dart'; // Necessário para acessar lógica de ID, se houver

class QuoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference _quotesCollection;
  late final CollectionReference _componentsCollection;

  // Status que ativam a baixa de estoque
  final List<String> _stockConsumingStatuses = ['aprovado', 'producao', 'concluido'];

  QuoteService() {
    _quotesCollection = _firestore.collection('quotes');
    _componentsCollection = _firestore.collection('components');
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

  // Salvar Novo (Create)
  // Geralmente nasce como 'rascunho' ou 'pendente', não afeta estoque.
  // Se nascer já 'aprovado' (raro), precisaria descontar.
  Future<DocumentReference> saveQuote(Quote quote) async {
    return await _firestore.runTransaction((transaction) async {
      // 1. Prepara referência
      final newQuoteRef = _quotesCollection.doc(); 
      
      // 2. Se o status inicial já consome estoque, desconta
      if (_stockConsumingStatuses.contains(quote.status.toLowerCase())) {
        await _processStockChange(transaction, quote, isDeducting: true);
      }

      // 3. Salva
      transaction.set(newQuoteRef, quote.toMap());
      return newQuoteRef;
    });
  }

  // Atualizar Existente (Update) - O CORAÇÃO DO SISTEMA
  Future<void> updateQuote(String quoteId, Map<String, dynamic> newData) async {
    final quoteRef = _quotesCollection.doc(quoteId);

    await _firestore.runTransaction((transaction) async {
      // 1. Ler o Orçamento Atual (Antes da mudança)
      final snapshot = await transaction.get(quoteRef);
      if (!snapshot.exists) throw Exception("Orçamento não encontrado!");
      
      final oldQuote = Quote.fromFirestore(snapshot);
      
      // 2. Criar o Objeto do Novo Orçamento (Mesclando dados antigos com novos)
      // Precisamos projetar como o objeto ficará para saber o que descontar
      final mergedData = oldQuote.toMap();
      newData.forEach((key, value) {
        mergedData[key] = value;
      });
      // Pequeno ajuste: toMap não tem ID, mas o fromFirestore precisa do snapshot ou map completo
      // Vamos instanciar um Quote temporário apenas com os dados
      // Precisamos garantir que as listas venham corretas do newData se existirem
      
      // Nota: Mesclar mapas complexos (Listas) manualmente é arriscado.
      // O ideal aqui é que o app envie o objeto Quote completo se houver edição de itens.
      // Assumindo que se 'passadoresList' vier no newData, ele substitui o antigo.
      
      // Construção manual do NewQuote para análise de estoque
      final newStatus = (newData['status'] ?? oldQuote.status).toString().toLowerCase();
      
      // Verifica lógica de estoque
      bool wasConsuming = _stockConsumingStatuses.contains(oldQuote.status.toLowerCase());
      bool willConsume = _stockConsumingStatuses.contains(newStatus);

      // LÓGICA DE REVERSÃO E APLICAÇÃO
      // Para garantir integridade, se o orçamento estava consumindo estoque, 
      // primeiro DEVOLVEMOS tudo (como se tivesse cancelado).
      if (wasConsuming) {
        await _processStockChange(transaction, oldQuote, isDeducting: false); // Devolve (Increase)
      }

      // Agora, se o novo status deve consumir estoque, DESCONTAMOS tudo novamente
      // (baseado nos novos dados).
      if (willConsume) {
        // Precisamos reconstruir o objeto Quote novo para ler seus itens corretamente
        // Se newData tem itens, usa eles. Se não, usa os do oldQuote.
        
        // Helper para reconstruir lista
        List<Map<String, dynamic>> getList(String key, List<Map<String, dynamic>> oldList) {
          if (newData.containsKey(key)) {
            return List<Map<String, dynamic>>.from(newData[key]);
          }
          return oldList;
        }

        // Simulação do objeto novo apenas com os campos necessários para estoque
        final tempNewQuote = Quote(
          userId: oldQuote.userId, 
          status: newStatus, 
          createdAt: oldQuote.createdAt, 
          totalPrice: 0, 
          clientName: '', clientPhone: '', clientCity: '', clientState: '',
          
          // Itens Únicos: Se vier no newData (ex: troca de blank), usa. Se não, usa antigo.
          blankName: newData['blankName'] ?? oldQuote.blankName,
          blankVariation: newData['blankVariation'] ?? oldQuote.blankVariation,
          
          caboName: newData['caboName'] ?? oldQuote.caboName,
          caboVariation: newData['caboVariation'] ?? oldQuote.caboVariation,
          caboQuantity: (newData['caboQuantity'] ?? oldQuote.caboQuantity) as int,
          
          reelSeatName: newData['reelSeatName'] ?? oldQuote.reelSeatName,
          reelSeatVariation: newData['reelSeatVariation'] ?? oldQuote.reelSeatVariation,
          
          passadoresList: getList('passadoresList', oldQuote.passadoresList),
          acessoriosList: getList('acessoriosList', oldQuote.acessoriosList),
        );

        await _processStockChange(transaction, tempNewQuote, isDeducting: true); // Deduz (Decrease)
      }

      // 3. Atualiza o documento
      transaction.update(quoteRef, newData);
    });
  }

  // Excluir (Delete)
  Future<void> deleteQuote(String quoteId) async {
    final quoteRef = _quotesCollection.doc(quoteId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(quoteRef);
      if (!snapshot.exists) return; // Já deletado

      final quote = Quote.fromFirestore(snapshot);

      // Se estava consumindo estoque, devolve antes de apagar
      if (_stockConsumingStatuses.contains(quote.status.toLowerCase())) {
        await _processStockChange(transaction, quote, isDeducting: false); // Devolve
      }

      transaction.delete(quoteRef);
    });
  }

  // --- HELPER DE ESTOQUE ---
  
  /// Percorre todos os itens do Quote e atualiza o estoque no Firestore via Transaction.
  /// [isDeducting]: true = Venda (diminui estoque), false = Cancelamento/Devolução (aumenta estoque).
  Future<void> _processStockChange(Transaction t, Quote quote, {required bool isDeducting}) async {
    int multiplier = isDeducting ? -1 : 1;

    // Helper interno para buscar ID pelo Nome e Variação (pois o Quote salva Nome)
    // Isso é um ponto de atenção: Se o nome mudar no catálogo, perde referência.
    // O ideal seria o Quote salvar o ID do componente. 
    // Como o sistema atual salva 'blankName', teremos que buscar pelo nome.
    
    Future<void> updateItem(String? name, String? variation, int qty) async {
      if (name == null || name.isEmpty || qty <= 0) return;

      // Busca o componente pelo nome
      // Nota: Dentro de transação, Queries devem ser feitas com cuidado.
      // O ideal seria ter o ID. Vou assumir busca por query, mas isso não bloqueia a transação de leitura.
      // Para ser atomicamente perfeito, precisaríamos dos IDs. 
      // Vou buscar o snapshot primeiro.
      
      try {
        final querySnap = await _componentsCollection.where('name', isEqualTo: name).limit(1).get();
        if (querySnap.docs.isEmpty) return; // Componente não existe mais ou nome mudou

        final docRef = querySnap.docs.first.reference;
        final currentData = querySnap.docs.first.data() as Map<String, dynamic>;
        
        // Lógica de Variação
        if (variation != null && variation.isNotEmpty) {
          // Atualiza estoque da variação (Map)
          Map<String, dynamic> variations = currentData['variations'] != null 
              ? Map<String, dynamic>.from(currentData['variations']) 
              : {};
          
          if (variations.containsKey(variation)) {
            int currentVarStock = (variations[variation] as num).toInt();
            int newVarStock = currentVarStock + (qty * multiplier);
            variations[variation] = newVarStock;
            
            // Atualiza também o estoque total geral
            int currentTotal = (currentData['stock'] ?? 0).toInt();
            int newTotal = currentTotal + (qty * multiplier);

            t.update(docRef, {
              'variations': variations,
              'stock': newTotal
            });
          }
        } else {
          // Atualiza estoque simples
          int currentStock = (currentData['stock'] ?? 0).toInt();
          int newStock = currentStock + (qty * multiplier);
          t.update(docRef, {'stock': newStock});
        }
      } catch (e) {
        print("Erro ao atualizar estoque item $name: $e");
        // Não rethrow para não travar a edição do orçamento inteiro se um item falhar
      }
    }

    // 1. Itens Principais
    await updateItem(quote.blankName, quote.blankVariation, 1);
    await updateItem(quote.caboName, quote.caboVariation, quote.caboQuantity);
    await updateItem(quote.reelSeatName, quote.reelSeatVariation, 1);

    // 2. Listas
    for (var item in quote.passadoresList) {
      await updateItem(item['name'], item['variation'], (item['quantity'] ?? 1).toInt());
    }
    for (var item in quote.acessoriosList) {
      await updateItem(item['name'], item['variation'], (item['quantity'] ?? 1).toInt());
    }
  }
}