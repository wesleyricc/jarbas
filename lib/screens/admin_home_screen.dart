import 'package:flutter/material.dart';
import 'admin_components_screen.dart';
import 'admin_quotes_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_kits_screen.dart';
import 'admin_alerts_screen.dart'; 
import 'admin_production_board_screen.dart'; // NOVA TELA
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
    const AdminProductionBoardScreen(), // KANBAN ADICIONADO AQUI NO INDEX 1
    const AdminComponentsScreen(),
    const AdminQuotesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    String title = 'Painel Administrativo';
    if (_selectedIndex == 1) title = 'Painel de Produção';
    if (_selectedIndex == 2) title = 'Gerenciar Catálogo';
    if (_selectedIndex == 3) title = 'Todos os Orçamentos';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          StreamBuilder<List<Component>>(
            stream: _compService.getLowStockComponentsStream(),
            builder: (context, snapshot) {
              bool hasAlerts = snapshot.hasData && snapshot.data!.isNotEmpty;
              int count = hasAlerts ? snapshot.data!.length : 0;

              return IconButton(
                tooltip: 'Alertas de Estoque',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAlertsScreen()));
                },
                icon: Stack(
                  clipBehavior: Clip.none, 
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (hasAlerts)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.red, 
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5) 
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
        type: BottomNavigationBarType.fixed, // OBRIGATÓRIO QUANDO TEM MAIS DE 3 ITENS
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueGrey[900],
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.view_kanban_outlined), activeIcon: Icon(Icons.view_kanban), label: 'Produção'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'Catálogo'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orçamentos'),
        ],
      ),
    );
  }
}