import 'package:url_launcher/url_launcher.dart';
import '../providers/rod_builder_provider.dart';
import '../models/quote_model.dart'; 

class WhatsAppService {
  // Número do Admin (lojista) - Substitua pelo seu número real
  static const String _adminPhoneNumber = "5511999999999"; 

  // --- Método 1: Enviar Orçamento Completo (Cliente -> Admin) ---
  static Future<void> sendNewQuoteRequest({required RodBuilderProvider provider}) async {
    final buffer = StringBuffer();
    
    buffer.writeln("*NOVO ORÇAMENTO - APP*");
    buffer.writeln("-------------------------");
    buffer.writeln("*Cliente:* ${provider.clientName}");
    buffer.writeln("*Tel:* ${provider.clientPhone}");
    buffer.writeln("*Cidade:* ${provider.clientCity}/${provider.clientState}");
    buffer.writeln("-------------------------");
    
    void writeList(String title, List<RodItem> items) {
      if (items.isNotEmpty) {
        buffer.writeln("*$title:*");
        for (var item in items) {
          String varText = (item.variation != null && item.variation!.isNotEmpty) ? " [${item.variation}]" : "";
          buffer.writeln(" - ${item.quantity}x ${item.component.name}$varText");
        }
        buffer.writeln("");
      }
    }

    writeList("Blanks", provider.selectedBlanksList);
    writeList("Cabos", provider.selectedCabosList);
    writeList("Reel Seats", provider.selectedReelSeatsList);
    writeList("Passadores", provider.selectedPassadoresList);
    writeList("Acessórios", provider.selectedAcessoriosList);

    if (provider.customizationText.isNotEmpty) {
      buffer.writeln("*Personalização:*");
      buffer.writeln(provider.customizationText);
      buffer.writeln("");
    }

    if (provider.extraLaborCost > 0) {
      buffer.writeln("*Custo Extra/Mão de Obra:* R\$ ${provider.extraLaborCost.toStringAsFixed(2)}");
    }

    buffer.writeln("-------------------------");
    buffer.writeln("*VALOR TOTAL: R\$ ${provider.totalPrice.toStringAsFixed(2)}*");
    buffer.writeln("-------------------------");
    buffer.writeln("Aguardo retorno para confirmação!");

    await _launchWhatsApp(buffer.toString());
  }

  // --- Método 2: Contato Direto (Home Screen) ---
  static Future<void> sendDirectContactRequest({
    required String clientName,
    required String clientPhone,
    required String city,
    required String state,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln("*CONTATO VIA APP*");
    buffer.writeln("-------------------------");
    buffer.writeln("*Nome:* $clientName");
    buffer.writeln("*Telefone:* $clientPhone");
    buffer.writeln("*Local:* $city/$state");
    buffer.writeln("-------------------------");
    buffer.writeln("Olá! Gostaria de tirar algumas dúvidas sobre as varas customizadas.");
    
    await _launchWhatsApp(buffer.toString());
  }

  // --- Método 3: Admin Envia Orçamento (Admin -> Cliente) ---
  static Future<void> sendQuoteToClient(Quote quote) async {
    final buffer = StringBuffer();
    
    buffer.writeln("*Olá ${quote.clientName}, aqui está o resumo do seu orçamento:*");
    buffer.writeln("-------------------------");
    
    // Helper para ler listas do Mapa (Quote Model)
    void writeMapList(String title, List<Map<String, dynamic>> items) {
      if (items.isNotEmpty) {
        buffer.writeln("*$title:*");
        for (var item in items) {
          String name = item['name'] ?? 'Item';
          int qty = item['quantity'] ?? 1;
          String variation = item['variation'] ?? '';
          String varText = variation.isNotEmpty ? " [$variation]" : "";
          
          buffer.writeln(" - ${qty}x $name$varText");
        }
        buffer.writeln("");
      }
    }

    writeMapList("Blanks", quote.blanksList);
    writeMapList("Cabos", quote.cabosList);
    writeMapList("Reel Seats", quote.reelSeatsList);
    writeMapList("Passadores", quote.passadoresList);
    writeMapList("Acessórios", quote.acessoriosList);

    // CORREÇÃO AQUI: Verificação de nulo antes de acessar isNotEmpty
    if (quote.customizationText != null && quote.customizationText!.isNotEmpty) {
      buffer.writeln("*Notas:* ${quote.customizationText}");
      buffer.writeln("");
    }

    buffer.writeln("-------------------------");
    buffer.writeln("*TOTAL: R\$ ${quote.totalPrice.toStringAsFixed(2)}*");
    buffer.writeln("-------------------------");
    buffer.writeln("Podemos aprovar?");

    // Envia para o telefone do CLIENTE
    await _launchWhatsApp(buffer.toString(), targetPhone: quote.clientPhone);
  }

  // --- Helper Privado ---
  static Future<void> _launchWhatsApp(String message, {String? targetPhone}) async {
    // Se targetPhone for nulo, usa o do Admin.
    String phone = targetPhone ?? _adminPhoneNumber;
    
    // Limpeza do número (mantém apenas dígitos)
    phone = phone.replaceAll(RegExp(r'[^\d]+'), '');

    // Se o número não começar com 55 e tiver tamanho de celular BR (10 ou 11 dígitos), adiciona 55
    if (phone.length >= 10 && !phone.startsWith('55')) {
      phone = '55$phone';
    }

    final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Não foi possível abrir o WhatsApp.';
    }
  }
}