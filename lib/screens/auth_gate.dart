import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'welcome_screen.dart'; 
import 'home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Escuta as mudanças no estado de autenticação
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Se houver um usuário logado (seja anônimo ou admin)
        if (snapshot.hasData) {
          // Mostra a tela principal
          return const HomeScreen();
        }

        // Se não houver usuário logado, mostra a tela de boas-vindas
        return const WelcomeScreen();
      },
    );
  }
}