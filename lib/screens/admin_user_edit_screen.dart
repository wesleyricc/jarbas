import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/user_service.dart';
import '../../../utils/app_constants.dart'; // Import Constants

class AdminUserEditScreen extends StatefulWidget {
  final UserModel user;

  const AdminUserEditScreen({super.key, required this.user});

  @override
  State<AdminUserEditScreen> createState() => _AdminUserEditScreenState();
}

class _AdminUserEditScreenState extends State<AdminUserEditScreen> {
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late String _currentRole;
  
  // Usa as constantes para definir as opções de Role
  final List<String> _roleOptions = [
    AppConstants.roleCliente,
    AppConstants.roleFabricante,
    AppConstants.roleLojista
  ];

  @override
  void initState() {
    super.initState();
    _currentRole = widget.user.role;
    // Fallback caso a role do usuário não esteja na lista (ex: legado)
    if (!_roleOptions.contains(_currentRole)) {
      _currentRole = AppConstants.roleCliente;
    }
  }

  Future<void> _saveRole() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() { _isLoading = true; });

    try {
      await _userService.updateUserRole(widget.user.uid, _currentRole);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Função do usuário atualizada!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); 
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar função: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Usuário'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Usuário:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                widget.user.displayName.isNotEmpty 
                  ? widget.user.displayName 
                  : 'Nome não cadastrado',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold
                ),
              ),
              Text(
                widget.user.email,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[700]
                ),
              ),
              const Divider(height: 48),

              Text(
                'Função (Role)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _currentRole,
                items: _roleOptions.map((String role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(role.toUpperCase()),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _currentRole = newValue;
                    });
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Selecione uma função',
                ),
              ),
              const SizedBox(height: 32),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveRole,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700], 
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Salvar Alterações'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}