import 'package:flutter/material.dart';
import 'admin_components_screen.dart';
import 'admin_quotes_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_kits_screen.dart';
import 'admin_alerts_screen.dart'; 
import '../../services/component_service.dart'; 
import '../../models/component_model.dart'; 

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  final ComponentService _compService = ComponentService();

  final List<Widget> _pages = [
    const AdminDashboardScreen(),
    const AdminComponentsScreen(),
    const AdminQuotesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    String title = 'Painel Administrativo';
    if (_selectedIndex == 1) title = 'Gerenciar Catálogo';
    if (_selectedIndex == 2) title = 'Gerenciar Orçamentos';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // --- ÍCONE DE ALERTAS (CORRIGIDO: Clique Fácil) ---
          StreamBuilder<List<Component>>(
            stream: _compService.getLowStockComponentsStream(),
            builder: (context, snapshot) {
              bool hasAlerts = snapshot.hasData && snapshot.data!.isNotEmpty;
              int count = hasAlerts ? snapshot.data!.length : 0;

              // CORREÇÃO: O IconButton é o pai, garantindo área de toque de 48px
              return IconButton(
                tooltip: 'Alertas de Estoque',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAlertsScreen()));
                },
                icon: Stack(
                  clipBehavior: Clip.none, // Permite que a bolinha saia da área do ícone
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (hasAlerts)
                      Positioned(
                        right: -2, // Ajuste fino da posição
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.red, 
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5) // Borda branca para destacar
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 9, 
                              fontWeight: FontWeight.bold
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          // ----------------------------------------------------

          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined),
            tooltip: 'Kits Prontos',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminKitsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSettingsScreen()));
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'Catálogo'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orçamentos'),
        ],
      ),
    );
  }
}