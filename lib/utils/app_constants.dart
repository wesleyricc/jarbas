import 'package:flutter/material.dart';

class AppConstants {
  // --- COLEÇÕES DO FIREBASE ---
  static const String colUsers = 'users';
  static const String colQuotes = 'quotes';
  static const String colComponents = 'components';
  static const String colKits = 'kits';
  static const String colSettings = 'settings';

  // --- CATEGORIAS DE COMPONENTES (Chaves no Banco) ---
  static const String catBlank = 'blank';
  static const String catCabo = 'cabo';
  static const String catReelSeat = 'reel_seat';
  static const String catPassadores = 'passadores';
  static const String catAcessorios = 'acessorios';

  // --- MAPA DE RÓTULOS (Para UI - Exibição) ---
  static const Map<String, String> categoryLabels = {
    catBlank: 'Blanks',
    catCabo: 'Cabos',
    catReelSeat: 'Reel Seats',
    catPassadores: 'Passadores',
    catAcessorios: 'Acessórios',
  };

  // --- STATUS DE ORÇAMENTO (Chaves no Banco) ---
  static const String statusRascunho = 'rascunho';
  static const String statusPendente = 'pendente';
  static const String statusAprovado = 'aprovado';
  static const String statusProducao = 'producao';
  static const String statusConcluido = 'concluido';
  static const String statusEnviado = 'enviado';
  static const String statusCancelado = 'cancelado';

  // --- MAPA DE CORES DE STATUS (Para UI) ---
  static const Map<String, Color> statusColors = {
    statusRascunho: Colors.grey,
    statusPendente: Colors.orange,
    statusAprovado: Colors.blue,
    statusProducao: Colors.purple,
    statusConcluido: Colors.green,
    statusEnviado: Colors.teal,
    statusCancelado: Colors.red,
  };

  // --- PERFIS DE USUÁRIO (Roles) ---
  static const String roleCliente = 'cliente';
  static const String roleFabricante = 'fabricante';
  static const String roleLojista = 'lojista';

  // Verifica se é admin
  static bool isAdmin(String role) {
    return role == roleFabricante || role == roleLojista;
  }
}