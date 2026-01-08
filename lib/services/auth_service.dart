import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Getter para o usuário atual
  User? get currentUser => _auth.currentUser;

  // Login com E-mail e Senha (Para Admin)
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      print(e.message);
      return null;
    }
  }

  // Login Anônimo (Para Cliente)
  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      print("Erro no login anônimo: $e");
      return null;
    }
  }

  // Cadastro com E-mail e Senha
  Future<UserCredential?> signUpWithEmail(String email, String password, String displayName) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      await userCredential.user?.updateDisplayName(displayName);
      await _saveUserToFirestore(userCredential.user, displayName);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print(e.message);
      return null;
    }
  }

  // Salvar usuário no Firestore
  Future<void> _saveUserToFirestore(User? user, String? displayName) async {
    if (user == null) return;

    await _firestore.collection(AppConstants.colUsers).doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': displayName ?? '',
      'role': AppConstants.roleCliente, // Padrão 'cliente' via constante
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }
}