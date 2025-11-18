import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // O GoogleSignIn foi removido

  // Getter para o usuário atual
  User? get currentUser => _auth.currentUser;

  // Login com E-mail e Senha (Para Admin)
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      // Tratar erros (ex: usuário não encontrado, senha errada)
      print(e.message);
      return null;
    }
  }

  // --- NOVO MÉTODO ---
  // Login Anônimo (Para Cliente)
  Future<UserCredential?> signInAnonymously() async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      
      // Opcional: Salvar usuário anônimo no Firestore se quisermos
      // rastrear orçamentos de anônimos, mas a role "cliente"
      // já é tratada como padrão pelo UserService.
      // Vamos deixar o UserService cuidar disso.
      
      return userCredential;
    } catch (e) {
      print("Erro no login anônimo: $e");
      return null;
    }
  }

  // Cadastro com E-mail e Senha (Não usado no fluxo atual, mas pode ser)
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
  
  // O método signInWithGoogle() foi removido.

  // Salvar usuário no Firestore (para informações de perfil)
  Future<void> _saveUserToFirestore(User? user, String? displayName) async {
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': displayName ?? '',
      'role': 'cliente', // Define o papel padrão como 'cliente'
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Logout
  Future<void> signOut() async {
    // await _googleSignIn.signOut(); // Removido
    await _auth.signOut(); // Desconecta do Firebase
  }
}