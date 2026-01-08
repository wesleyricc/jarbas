import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../utils/app_constants.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference _userCollection;

  UserService() {
    _userCollection = _firestore.collection(AppConstants.colUsers);
  }

  // --- MÉTODOS EXISTENTES ---

  Future<DocumentSnapshot> getUserData(String uid) {
    return _userCollection.doc(uid).get();
  }

  Future<String> getUserRole(String uid) async {
    try {
      final doc = await getUserData(uid);
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        // Usa a constante como fallback
        return (data['role'] as String?)?.toLowerCase() ?? AppConstants.roleCliente;
      } else {
        return AppConstants.roleCliente;
      }
    } catch (e) {
      print("[UserService] Erro ao buscar role: $e");
      return AppConstants.roleCliente;
    }
  }

  Future<bool> isAdmin(User user) async {
    final role = await getUserRole(user.uid);
    // Usa o método auxiliar do AppConstants para verificar
    return AppConstants.isAdmin(role);
  }

  // --- MÉTODOS DE ADMINISTRAÇÃO ---

  Stream<List<UserModel>> getAllUsersStream() {
    return _userCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> updateUserRole(String uid, String newRole) {
    return _userCollection.doc(uid).update({
      'role': newRole,
    });
  }
}