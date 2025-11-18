import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart'; // Importa o novo modelo

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference _userCollection;

  UserService() {
    _userCollection = _firestore.collection('users');
  }

  // --- MÉTODOS EXISTENTES ---

  /// Busca os dados brutos de um usuário (usado internamente)
  Future<DocumentSnapshot> getUserData(String uid) {
    print("[UserService] Buscando dados para o UID: $uid");
    return _userCollection.doc(uid).get();
  }

  /// Busca a 'role' de um usuário. Retorna 'cliente' se não encontrar.
  Future<String> getUserRole(String uid) async {
    try {
      final doc = await getUserData(uid);
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        // Garante que a role seja lida, minúscula, e 'cliente' por padrão
        final role = (data['role'] as String?)?.toLowerCase() ?? 'cliente';
        print("[UserService] Role encontrada: $role");
        return role;
      } else {
        print("[UserService] Documento não encontrado, retornando 'cliente'");
        return 'cliente'; // Padrão se o usuário não tiver doc (ex: anônimo)
      }
    } catch (e) {
      print("[UserService] Erro ao buscar role: $e");
      return 'cliente'; // Padrão em caso de erro
    }
  }

  /// Verifica se um usuário é admin (fabricante ou lojista)
  Future<bool> isAdmin(User user) async {
    final role = await getUserRole(user.uid);
    return role == 'fabricante' || role == 'lojista';
  }

  // --- MÉTODOS NOVOS (PARA O GERENCIADOR DE USUÁRIOS) ---

  /// (NOVO) Retorna um Stream de TODOS os usuários
  Stream<List<UserModel>> getAllUsersStream() {
    return _userCollection.snapshots().map((snapshot) {
      // Converte cada documento em um UserModel
      return snapshot.docs.map((doc) {
        return UserModel.fromFirestore(doc);
      }).toList();
    });
  }

  /// (NOVO) Atualiza a 'role' de um usuário específico
  Future<void> updateUserRole(String uid, String newRole) {
    // Atualiza apenas o campo 'role' do documento do usuário
    return _userCollection.doc(uid).update({
      'role': newRole,
    });
  }
}