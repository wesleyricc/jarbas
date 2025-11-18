import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para o User
import '../services/auth_service.dart';
import '../services/user_service.dart'; // Para verificar o admin
import 'catalog_screen.dart'; // Para o Catálogo
import 'rod_builder_screen.dart'; // Para o Montador
import 'quote_history_screen.dart'; // Para o Histórico (Admin)
// import 'admin/components/admin_components_screen.dart'; // Não é mais necessário
import 'admin_quotes_screen.dart'; // Para o Gerenciar Orçamentos (Admin)
// --- (NOVA IMPORTAÇÃO) ---
import 'admin_users_screen.dart'; // Para o Gerenciar Usuários (Admin)
// --- FIM DA IMPORTAÇÃO ---

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
    ];
  }

  // Botões do Menu Admin
  List<Widget> _buildAdminMenu(BuildContext context) {
    return [

      // Botão para o Montador (Admin usa para criar rascunhos)
      ElevatedButton.icon(
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        label: const Text('Customizar (Rascunho)'),
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
      
      // Botão para o Histórico Pessoal (Meus Rascunhos)
      ElevatedButton.icon(
        icon: const Icon(Icons.bookmark_border),
        label: const Text('Meus Rascunhos'),
         style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFFFFF), // Fundo branco
          foregroundColor: Colors.blueGrey[800], // Texto escuro
          side: BorderSide(color: Colors.grey[400]!), // Borda leve
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QuoteHistoryScreen()),
          );
        },
      ),
      const SizedBox(height: 16),

      // Botão para Gerenciar Orçamentos (Admin vê TODOS)
      ElevatedButton.icon(
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('Gerenciar Orçamentos'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFFFFF), // Fundo branco
          foregroundColor: Colors.blueGrey[800], // Texto escuro
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        onPressed: () {
          // Navega para a lista de orçamentos (onde o admin pode ver todos)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminQuotesScreen()),
          );
        },
      ),
      const SizedBox(height: 16),

      // Botão para Gerenciar Catálogo (Admin)
      ElevatedButton.icon(
        icon: const Icon(Icons.edit_note_outlined),
        label: const Text('Gerenciar Catálogo'),
         style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFFFFF), // Fundo branco
          foregroundColor: Colors.blueGrey[800], // Texto escuro
          side: BorderSide(color: Colors.grey[400]!), // Borda leve
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        onPressed: () {
          // Vai para a tela de catálogo refatorada (onde o admin edita)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CatalogScreen()),
          );
        },
      ),
      const SizedBox(height: 16),
      
      // --- (NOVO BOTÃO) ---
      // Botão para Gerenciar Usuários (Admin)
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
      const SizedBox(height: 16),
      // --- FIM DO NOVO BOTÃO ---
    ];
  }
}