import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'admin_login_screen.dart'; // Importa a tela de login do admin

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  // Função para login de cliente (anônimo)
  void _signInAsClient() async {
    setState(() { _isLoading = true; });
    await _authService.signInAnonymously();
    // O AuthGate cuidará do redirecionamento
    // Não precisamos redefinir _isLoading, pois a tela será destruída
  }

  // Função para navegar para o login de admin
  void _goToAdminLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _isLoading
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- LOGO DA EMPRESA ---
                      // Substituímos o Ícone pela sua Imagem
                      Image.asset(
                        'assets/jarbas_logo.png',
                        height: 80, // Você pode ajustar a altura
                        // Adicionamos um errorBuilder para o caso da imagem não ser encontrada
                        errorBuilder: (context, error, stackTrace) {
                          // Se a imagem falhar, mostra o ícone original
                          return Icon(
                            Icons.phishing, // Fallback
                            size: 80,
                            color: Colors.blueGrey[300],
                          );
                        },
                      ),
                      // --- FIM DA LOGO ---
                      const SizedBox(height: 16),
                      //Text(
                        //'Custom Rods',
                        //textAlign: TextAlign.center,
                        //style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              //fontWeight: FontWeight.bold,
                              //color: Colors.white,
                            //),
                      //),
                      Text(
                        'Personalize sua paixão pela pesca.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[400],
                            ),
                      ),
                      const SizedBox(height: 64),

                      // Botão Cliente
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Realizar Orçamento'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[400],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        onPressed: _signInAsClient,
                      ),
                      const SizedBox(height: 16),

                      // Botão Admin
                      ElevatedButton.icon(
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('Modo Administrador'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C2C2C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        onPressed: _goToAdminLogin,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}