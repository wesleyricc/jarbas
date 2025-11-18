import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // --- (NOVA VARIÁVEL DE ESTADO) ---
  bool _isPasswordVisible = false;
  // --- FIM DA NOVA VARIÁVEL ---

  @override
  void initState() {
    super.initState();
    _isPasswordVisible = false;
  }

  void _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    print("[AdminLogin] Tentando logar com e-mail: ${_emailController.text}");

    final userCredential = await _authService.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    setState(() { _isLoading = false; });

    // Se o login falhou
    if (userCredential == null) {
      print("[AdminLogin] Falha no login.");
      setState(() {
        _errorMessage = "Falha no login. Verifique seu e-mail e senha.";
      });
    } 
    // --- ESTA É A CORREÇÃO ---
    // Se o login foi BEM-SUCEDIDO
    else {
      print("[AdminLogin] Login bem-sucedido. Fechando tela de login.");
      // Se a tela ainda estiver "montada" (visível), feche-a.
      if (mounted) {
        // Isso remove a tela AdminLogin da pilha, revelando
        // a HomeScreen que o AuthGate colocou no lugar.
        Navigator.of(context).pop(); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login do Administrador'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 60,
                  color: Colors.red[700], // Cor mais escura para o tema claro
                ),
                const SizedBox(height: 16),
                Text(
                  'Acesso Restrito',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 32),
                
                // Campo de E-mail
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                
                // --- CAMPO DE SENHA ATUALIZADO ---
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible, // Controlado pela variável de estado
                  decoration: InputDecoration(
                    hintText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    // Ícone do olho (suffix)
                    suffixIcon: IconButton(
                      icon: Icon(
                        // Muda o ícone baseado no estado
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        // Atualiza o estado ao clicar
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                // --- FIM DA ATUALIZAÇÃO ---
                const SizedBox(height: 24),

                // Exibir mensagem de erro
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                // Botão de Login
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16)
                        ),
                        child: const Text('Entrar'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}