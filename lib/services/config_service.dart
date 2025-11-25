import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'settings';
  final String _doc = 'global_config';

  Future<Map<String, dynamic>> getSettings() async {
    try {
      final doc = await _firestore.collection(_collection).doc(_doc).get();
      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      }
      return {
        'defaultMargin': 0.0,
        'supplierDiscount': 0.0, // (NOVO) Padrão 0% de desconto
        'customizationPrice': 25.0,
        'supplierPhone': '',
      };
    } catch (e) {
      print("Erro: $e");
      return {};
    }
  }

  Future<void> saveSettings({
    required double defaultMargin,
    required double supplierDiscount, // (NOVO)
    required double customizationPrice,
    required String supplierPhone,
  }) async {
    await _firestore.collection(_collection).doc(_doc).set({
      'defaultMargin': defaultMargin,
      'supplierDiscount': supplierDiscount, // (NOVO)
      'customizationPrice': customizationPrice,
      'supplierPhone': supplierPhone.replaceAll(RegExp(r'[^\d]'), ''),
    }, SetOptions(merge: true));
  }
}