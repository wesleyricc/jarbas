import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_constants.dart';

class ConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Agora usa a constante
  final String _collection = AppConstants.colSettings;
  final String _doc = 'global_config';

  Future<Map<String, dynamic>> getSettings() async {
    try {
      final doc = await _firestore.collection(_collection).doc(_doc).get();
      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      }
      return {
        'defaultMargin': 0.0,
        'supplierDiscount': 0.0,
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
    required double supplierDiscount,
    required double customizationPrice,
    required String supplierPhone,
  }) async {
    await _firestore.collection(_collection).doc(_doc).set({
      'defaultMargin': defaultMargin,
      'supplierDiscount': supplierDiscount,
      'customizationPrice': customizationPrice,
      'supplierPhone': supplierPhone.replaceAll(RegExp(r'[^\d]'), ''),
    }, SetOptions(merge: true));
  }
}