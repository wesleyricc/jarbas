import 'package:url_launcher/url_launcher.dart';
import '../providers/rod_builder_provider.dart';

class WhatsAppService {
  // Substitua pelo número do Admin (lojista)
  // Formato: CodigoPais + DDD + Numero (sem + ou traços)
  static const String _adminPhoneNumber = "5511999999999"; 

  // --- Método 1: Enviar Orçamento Completo (Usado no Final do Builder) ---
  static Future<void> sendNewQuoteRequest({required RodBuilderProvider provider}) async {
    final buffer = StringBuffer();
    
    buffer.writeln("*NOVO ORÇAMENTO - APP*");
    buffer.writeln("-------------------------");
    buffer.writeln("*Cliente:* ${provider.clientName}");
    buffer.writeln("*Tel:* ${provider.clientPhone}");
    buffer.writeln("*Cidade:* ${provider.clientCity}/${provider.clientState}");
    buffer.writeln("-------------------------");
    
    // Helper interno para listar itens
    void writeList(String title, List<RodItem> items) {
      if (items.isNotEmpty) {
        buffer.writeln("*$title:*");
        for (var item in items) {
          String varText = item.variation != null ? " [${item.variation}]" : "";
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

    final message = buffer.toString();
    await _launchWhatsApp(message);
  }

  // --- Método 2: Contato Direto (Usado na Home Screen) ---
  // CORREÇÃO: Agora aceita os parâmetros nomeados que o home_screen está enviando
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

  // --- Helper Privado ---
  static Future<void> _launchWhatsApp(String message) async {
    // Codifica a mensagem para URL
    final url = Uri.parse("https://wa.me/$_adminPhoneNumber?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Não foi possível abrir o WhatsApp.';
    }
  }
}