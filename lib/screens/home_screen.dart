import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/whatsapp_service.dart';
import 'admin_customers_screen.dart';
import 'rod_builder_screen.dart';

// Import das Telas Admin
import 'admin_dashboard_screen.dart';
import 'admin_quotes_screen.dart';
import 'admin_components_screen.dart';
import 'admin_kits_screen.dart';
import 'admin_low_stock_screen.dart';
import 'admin_settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final userService = UserService();
    final User? currentUser = authService.currentUser;

    return FutureBuilder<bool>(
      future: currentUser != null 
          ? userService.isAdmin(currentUser) 
          : Future.value(false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final bool isAdmin = snapshot.data ?? false;

        return isAdmin 
          ? _AdminHomeStructure(authService: authService) 
          : _ClientHomeStructure(authService: authService);
      },
    );
  }
}

// --- ESTRUTURA DO ADMIN (Mantida igual) ---
class _AdminHomeStructure extends StatefulWidget {
  final AuthService authService;
  const _AdminHomeStructure({required this.authService});

  @override
  State<_AdminHomeStructure> createState() => _AdminHomeStructureState();
}

class _AdminHomeStructureState extends State<_AdminHomeStructure> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5, 
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Painel Administrativo', style: TextStyle(fontSize: 18)),
          backgroundColor: Colors.blueGrey[900],
          elevation: 0,
          centerTitle: false,
          actions: [
            IconButton(
              tooltip: 'Estoque Baixo',
              icon: const Icon(Icons.notifications_active_outlined, color: Colors.amber),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLowStockScreen()));
              },
            ),
            IconButton(
              tooltip: 'Configurações',
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsScreen()));
              },
            ),
            IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await widget.authService.signOut();
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.amber,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: "Dashboard"),
              Tab(icon: Icon(Icons.list_alt), text: "Orçamentos"),
              Tab(icon: Icon(Icons.inventory_2), text: "Componentes"),
              Tab(icon: Icon(Icons.view_quilt), text: "Kits"),
              Tab(icon: Icon(Icons.person), text: "Clientes"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminDashboardScreen(),
            AdminQuotesScreen(),
            AdminComponentsScreen(),
            AdminKitsScreen(),
            AdminCustomersScreen(),
          ],
        ),
      ),
    );
  }
}

// --- ESTRUTURA DO CLIENTE (Atualizada com Logo) ---
class _ClientHomeStructure extends StatelessWidget {
  final AuthService authService;
  const _ClientHomeStructure({required this.authService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Jarbas Custom Rods'),
        centerTitle: true,
        backgroundColor: Colors.blueGrey[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- LOGO JARBAS CUSTOM RODS ---
            Center(
              child: Container(
                height: 120, // Altura ajustada para destaque
                margin: const EdgeInsets.only(bottom: 24),
                child: Image.asset(
                  'assets/logo_jarbas.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback caso a imagem não carregue
                    return Icon(
                      Icons.phishing, 
                      size: 80, 
                      color: Colors.blueGrey[300]
                    );
                  },
                ),
              ),
            ),

            // --- TEXTOS CENTRALIZADOS ---
            const Text(
              "Bem-vindo!", 
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              textAlign: TextAlign.center, // Centraliza o texto
            ),
            const SizedBox(height: 8),
            const Text(
              "Crie sua vara personalizada ou escolha um de nossos modelos prontos.", 
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center, // Centraliza o texto
            ),
            const SizedBox(height: 40),

            // --- CARTÕES DE AÇÃO ---
            _buildActionCard(
              context,
              title: "Montar Nova Vara",
              subtitle: "Personalize cada detalhe do zero ou use um template.",
              icon: Icons.build_circle_outlined,
              color: Colors.blueGrey[800]!,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RodBuilderScreen()));
              },
            ),
            const SizedBox(height: 16),
            
            _buildActionCard(
              context,
              title: "Falar com Especialista",
              subtitle: "Dúvidas? Entre em contato via WhatsApp.",
              icon: Icons.chat, 
              color: Colors.green[700]!,
              onTap: () {
                 _showContactDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Iniciar Contato"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Informe seus dados:"),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nome", border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Telefone", border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: "Cidade/UF", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(ctx);
              WhatsAppService.sendDirectContactRequest(clientName: nameCtrl.text, clientPhone: phoneCtrl.text, city: cityCtrl.text, state: "");
            },
            child: const Text("Enviar"),
          )
        ],
      ),
    );
  }
}