import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/user_service.dart';
import 'admin_user_edit_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Usuários'),
      ),
      body: Column(
        children: [
          // Campo de Busca
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Filtrar por nome ou e-mail...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          // Lista de Usuários
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _userService.getAllUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Nenhum usuário encontrado.'));
                }

                List<UserModel> allUsers = snapshot.data!;

                // Aplica o filtro da busca
                final filteredUsers = allUsers.where((user) {
                  final nameMatches = user.displayName.toLowerCase().contains(_searchQuery);
                  final emailMatches = user.email.toLowerCase().contains(_searchQuery);
                  return nameMatches || emailMatches;
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(child: Text('Nenhum usuário encontrado para esta busca.'));
                }

                // Ordena por nome
                filteredUsers.sort((a, b) => a.displayName.compareTo(b.displayName));

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    UserModel user = filteredUsers[index];
                    return _buildUserCard(user);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    // Define o nome de exibição (fallback para e-mail)
    String displayName = user.displayName.isNotEmpty ? user.displayName : user.email;
    if (displayName.isEmpty) displayName = "Usuário Anônimo";

    // Define a cor da função
    Color roleColor = Colors.grey[600]!;
    if (user.role == 'fabricante' || user.role == 'lojista') {
      roleColor = Colors.red[700]!;
    } else if (user.role == 'cliente') {
      roleColor = Colors.blueGrey[700]!;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        title: Text(displayName),
        subtitle: Text(
          user.role.toUpperCase(),
          style: TextStyle(
            color: roleColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.edit_note_outlined),
        onTap: () {
          // Navega para a tela de edição
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminUserEditScreen(user: user),
            ),
          );
        },
      ),
    );
  }
}