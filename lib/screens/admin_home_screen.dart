import 'package:flutter/material.dart';
import 'admin_components_screen.dart';
import 'admin_quotes_screen.dart';
import 'admin_settings_screen.dart'; // (NOVO) Importe a tela de configurações

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const AdminComponentsScreen(), // Tela para gerenciar componentes
    const AdminQuotesScreen(),     // Tela para gerenciar orçamentos
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Gerenciar Componentes' : 'Gerenciar Orçamentos'),
        // --- AÇÃO ADICIONADA ---
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações Globais',
            onPressed: () {
              // Navega para a tela de configurações de margem
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminSettingsScreen(),
                ),
              );
            },
          ),
        ],
        // -----------------------
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
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Componentes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orçamentos',
          ),
        ],
      ),
    );
  }
}