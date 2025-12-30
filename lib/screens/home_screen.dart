import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para o User
import '../services/auth_service.dart';
import '../services/user_service.dart'; // Para verificar o admin
import '../services/whatsapp_service.dart';
import 'admin_kits_screen.dart';
import 'catalog_screen.dart'; // Para o Catálogo
import 'rod_builder_screen.dart'; // Para o Montador
import 'quote_history_screen.dart'; // Para o Histórico (Admin)
import 'admin_quotes_screen.dart'; // Para o Gerenciar Orçamentos (Admin)
import 'admin_components_screen.dart';
import 'admin_home_screen.dart';
import 'admin_users_screen.dart'; // Para o Gerenciar Usuários (Admin)

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  late Future<Map<String, dynamic>> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUserData();
  }

  // --- ATUALIZAÇÃO AQUI ---
  // Agora buscamos o nome do Firestore, não apenas do Auth
  Future<Map<String, dynamic>> _loadUserData() async {
    final user = _authService.currentUser;
    if (user == null) {
      // Usuário anônimo ou deslogado
      return {'isAdmin': false, 'user': null, 'firestoreName': 'Visitante'};
    }

    // Busca o documento do usuário no Firestore
    final doc = await _userService.getUserData(user.uid);
    String firestoreName = 'Visitante';
    bool isAdmin = false;

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      
      // 1. Pega o nome do Firestore
      firestoreName = (data['displayName'] as String?) ?? user.email ?? 'Visitante';
      if (firestoreName.isEmpty) {
        firestoreName = user.email ?? 'Visitante';
      }

      // 2. Pega a 'role'
      final role = (data['role'] as String?)?.toLowerCase() ?? 'cliente';
      isAdmin = role == 'fabricante' || role == 'lojista';

    } else {
      // Usuário existe no Auth mas não no Firestore (ex: Anônimo)
      firestoreName = 'Visitante';
      isAdmin = false;
    }

    // Retorna todos os dados que a UI precisa
    return {'isAdmin': isAdmin, 'user': user, 'firestoreName': firestoreName};
  }
  // --- FIM DA ATUALIZAÇÃO ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jarbas Custom Rods'),
        elevation: 1.0, // Elevação para o tema claro
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.blueGrey[800]),
            tooltip: 'Sair',
            onPressed: () {
              _authService.signOut();
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Erro ao carregar dados do usuário.'));
          }

          final bool isAdmin = snapshot.data?['isAdmin'] ?? false;
          final User? user = snapshot.data?['user'];
          // --- ATUALIZAÇÃO AQUI ---
          final String firestoreName = snapshot.data?['firestoreName'] ?? 'Visitante';
          // --- FIM DA ATUALIZAÇÃO ---

          // A UI agora é construída com base no status de admin
          return _buildUserMenu(context, isAdmin, user, firestoreName); // Passa o nome
        },
      ),
    );
  }

  // Constrói o menu (seja do Cliente ou do Admin)
  // --- ATUALIZAÇÃO AQUI ---
  Widget _buildUserMenu(BuildContext context, bool isAdmin, User? user, String firestoreName) {
  // --- FIM DA ATUALIZAÇÃO ---
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWelcomeHeader(context, user, isAdmin, firestoreName), // Passa o nome
          const SizedBox(height: 48),

          // --- MENU CONDICIONAL ---
          if (isAdmin)
            ..._buildAdminMenu(context) // Botões do Admin
          else
            ..._buildClientMenu(context), // Botões do Cliente
        ],
      ),
    );
  }

  // Cabeçalho de Boas-Vindas
  // --- ATUALIZAÇÃO AQUI ---
  Widget _buildWelcomeHeader(BuildContext context, User? user, bool isAdmin, String firestoreName) {
    // --- FIM DA ATUALIZAÇÃO ---
    
    // --- ATUALIZAÇÃO AQUI ---
    // Usamos o 'firestoreName' que veio do FutureBuilder, 
    // que é o nome salvo no banco de dados.
    String displayName = firestoreName;
    // --- FIM DA ATUALIZAÇÃO ---
    
    return Column(
      children: [
        // --- ADIÇÃO DA LOGO (com Fallback) ---
        Image.asset(
          'assets/jarbas_logo.png',
          height: 60, // Ajuste a altura conforme necessário
          errorBuilder: (context, error, stackTrace) {
            // Se a imagem falhar, mostra o ícone de fallback
            return Icon(
              Icons.phishing, // Fallback
              size: 60,
              color: Colors.blueGrey[800], // Cor escura para fundo claro
            );
          },
        ),
        const SizedBox(height: 16),
        // --- FIM DA ADIÇÃO ---

        Text(
          'Bem-vindo,',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.grey[700] // Cor mais suave para o tema claro
          ),
        ),
        Text(
          displayName, // <- AGORA USA O NOME DO FIRESTORE
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                // Cor do nome do usuário (Admin = Vermelho, Cliente = Padrão escuro)
                color: isAdmin ? Colors.red[700] : Colors.blueGrey[900],
              ),
        ),
        if (isAdmin)
          Text(
            '(MODO ADMINISTRADOR)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
          ),
      ],
    );
  }

  // Botões do Menu Cliente
  List<Widget> _buildClientMenu(BuildContext context) {
    return [
      // Botão para o Montador
      ElevatedButton.icon(
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        label: const Text('Customizar'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueGrey[500],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RodBuilderScreen()),
          );
        },
      ),
      const SizedBox(height: 16),

      /*
      // --- NOVO BOTÃO: Meus Pedidos ---
      ElevatedButton.icon(
        icon: const Icon(Icons.history, color: Colors.blueGrey),
        label: const Text('Rascunhos'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.blueGrey[800],
          side: BorderSide(color: Colors.blueGrey[200]!),
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        onPressed: () {
          Navigator.push(
            context,
            // A tela QuoteHistoryScreen já filtra pelo ID do usuário logado
            // então funciona perfeitamente para o cliente também.
            MaterialPageRoute(builder: (context) => const QuoteHistoryScreen()),
          );
        },
      ),
      const SizedBox(height: 16),
      */
      
      // Botão para o Catálogo
      ElevatedButton.icon(
        icon: const Icon(Icons.view_list_outlined),
        label: const Text('Catálogo de Componentes'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFFFFF), // Fundo branco
          foregroundColor: Colors.blueGrey[800], // Texto escuro
          side: BorderSide(color: Colors.grey[400]!), // Borda leve
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CatalogScreen()),
          );
        },
      ),

      const SizedBox(height: 16),

      // --- NOVO BOTÃO: Falar com Fornecedor ---
      ElevatedButton.icon(
        icon: const Icon(Icons.chat_outlined, color: Colors.white),
        label: const Text('Falar com Fornecedor'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366), // Verde WhatsApp
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        onPressed: () => _showDirectContactDialog(context), // Abre o formulário
      ),

    ];
  }

  // --- MÉTODO PARA MOSTRAR O FORMULÁRIO DE CONTATO ---
  void _showDirectContactDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final cityController = TextEditingController();
    final stateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Contato Rápido'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Informe seus dados para iniciarmos a conversa no WhatsApp:'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Informe seu nome' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.isEmpty ? 'Informe seu telefone' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: cityController,
                          decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: stateController,
                          decoration: const InputDecoration(labelText: 'UF', border: OutlineInputBorder()),
                          //maxLength: 2,
                          textCapitalization: TextCapitalization.characters,
                          validator: (v) => v == null || v.isEmpty ? 'Obrig.' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Iniciar Conversa'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                // Aumentamos o padding e a fonte
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                elevation: 2,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Fecha o diálogo primeiro
                  Navigator.pop(context);
                  
                  try {
                    await WhatsAppService.sendDirectContactRequest(
                      clientName: nameController.text,
                      clientPhone: phoneController.text,
                      city: cityController.text,
                      state: stateController.text,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao abrir WhatsApp: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Botões do Menu Admin
  // Botões do Menu Admin
  List<Widget> _buildAdminMenu(BuildContext context) {
    return [
      // 1. ACESSO AO PAINEL COMPLETO (Dashboard + Catálogo + Orçamentos)
      ElevatedButton.icon(
        icon: const Icon(Icons.dashboard, color: Colors.white),
        label: const Text('Painel Administrativo'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueGrey[800],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          // Navega para a tela que tem o BottomNavigationBar (Dashboard, Componentes, Quotes)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
          );
        },
      ),
      
      const SizedBox(height: 16),

      // 2. Customizar (Rascunho Rápido) - Mantivemos caso o admin queira fazer um orçamento rápido
      ElevatedButton.icon(
        icon: const Icon(Icons.add_circle_outline, color: Colors.blueGrey),
        label: const Text('Novo Orçamento (Rascunho)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.blueGrey[800],
          side: BorderSide(color: Colors.blueGrey[200]!),
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RodBuilderScreen()),
          );
        },
      ),

      const SizedBox(height: 16),

      // 3. Gerenciar Usuários
      ElevatedButton.icon(
        icon: const Icon(Icons.manage_accounts_outlined, color: Colors.white),
        label: const Text('Gerenciar Usuários'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminUsersScreen()),
          );
        },
      ),
    ];
  }
    
  }