import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'settings';
  final String _doc = 'global_config';

  // Retorna um Map com todas as configurações (com valores padrão)
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final doc = await _firestore.collection(_collection).doc(_doc).get();
      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      }
      // Valores padrão se não existir configuração
      return {
        'defaultMargin': 0.0,
        'customizationPrice': 25.0, // Padrão antigo
        'supplierPhone': '5548996381626', // Padrão antigo
      };
    } catch (e) {
      print("Erro ao buscar configurações: $e");
      return {
        'defaultMargin': 0.0,
        'customizationPrice': 25.0,
        'supplierPhone': '',
      };
    }
  }

  // Salva todas as configurações de uma vez
  Future<void> saveSettings({
    required double defaultMargin,
    required double customizationPrice,
    required String supplierPhone,
  }) async {
    await _firestore.collection(_collection).doc(_doc).set({
      'defaultMargin': defaultMargin,
      'customizationPrice': customizationPrice,
      'supplierPhone': supplierPhone.replaceAll(RegExp(r'[^\d]'), ''), // Salva apenas números
    }, SetOptions(merge: true));
  }
}