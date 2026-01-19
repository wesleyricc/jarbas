import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';
import '../models/quote_model.dart';
import '../utils/app_constants.dart';

class CustomerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'customers'; // Nova coleção

  // Criar ou Atualizar Cliente
  Future<void> saveCustomer(CustomerModel customer) async {
    final data = customer.toMap();
    if (customer.id.isEmpty) {
      await _firestore.collection(_collection).add(data);
    } else {
      await _firestore.collection(_collection).doc(customer.id).update(data);
    }
  }

  // Deletar Cliente e seus Orçamentos (Cascata)
  Future<void> deleteCustomer(String customerId) async {
    final batch = _firestore.batch();

    // 1. Referência do cliente
    final customerRef = _firestore.collection(_collection).doc(customerId);
    batch.delete(customerRef);

    // 2. Buscar orçamentos vinculados a este cliente
    final quotesQuery = await _firestore
        .collection(AppConstants.colQuotes)
        .where('customerId', isEqualTo: customerId)
        .get();

    // 3. Adicionar deleção dos orçamentos ao batch
    for (var doc in quotesQuery.docs) {
      batch.delete(doc.reference);
    }

    // 4. Executar tudo atomicamente
    await batch.commit();
  }

  // Listar Clientes (Stream para tempo real)
  Stream<List<CustomerModel>> getCustomers() {
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CustomerModel.fromFirestore(doc)).toList();
    });
  }

  // Buscar apenas 1 cliente
  Future<CustomerModel?> getCustomerById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return CustomerModel.fromFirestore(doc);
    }
    return null;
  }
  
  // Buscar orçamentos de um cliente específico
  Stream<List<Quote>> getCustomerQuotes(String customerId) {
    return _firestore
        .collection(AppConstants.colQuotes)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Quote.fromFirestore(doc)).toList();
    });
  }
}