import 'package:url_launcher/url_launcher.dart';
import '../models/quote_model.dart';
import '../providers/rod_builder_provider.dart';
import 'config_service.dart'; 

class WhatsAppService {

  // --- MÉTODOS PÚBLICOS ---

  /// (Cliente -> Jarbas)
  /// Envia para o telefone do Fornecedor (Configurado no Admin)
  static Future<void> sendNewQuoteRequest({required RodBuilderProvider provider}) async {
    final message = _buildRequestMessage(
       clientName: provider.clientName,
       clientPhone: provider.clientPhone,
       city: provider.clientCity,
       state: provider.clientState,
       
       blank: provider.selectedBlank?.name,
       blankVar: provider.selectedBlankVariation,
       
       cabo: provider.selectedCabo?.name,
       caboVar: provider.selectedCaboVariation,
       caboQty: provider.caboQuantity,
       
       reelSeat: provider.selectedReelSeat?.name,
       reelSeatVar: provider.selectedReelSeatVariation,
       
       // Converte RodItem para Map
       passadoresList: provider.selectedPassadoresList.map((e) => {
         'name': e.component.name,
         'quantity': e.quantity,
         'variation': e.variation
       }).toList(),

       // Converte RodItem para Map (Acessórios)
       acessoriosList: provider.selectedAcessoriosList.map((e) => {
         'name': e.component.name,
         'quantity': e.quantity,
         'variation': e.variation
       }).toList(),
       
       // corLinha: provider.corLinha, // Removido conforme solicitado
       gravacao: provider.gravacao,
    );

    await _launchWhatsApp(message: message);
  }

  /// (Cliente -> Jarbas)
  /// Reenvia um orçamento já existente (Quote) para o Fornecedor
  static Future<void> resendQuoteRequest(Quote quote) async {
    final message = _buildRequestMessage(
      clientName: quote.clientName,
      clientPhone: quote.clientPhone,
      city: quote.clientCity,
      state: quote.clientState,
      
      blank: quote.blankName,
      blankVar: quote.blankVariation,
      
      cabo: quote.caboName,
      caboVar: quote.caboVariation,
      caboQty: quote.caboQuantity,
      
      reelSeat: quote.reelSeatName,
      reelSeatVar: quote.reelSeatVariation,
      
      passadoresList: quote.passadoresList,
      acessoriosList: quote.acessoriosList, // (NOVO)
      
      // corLinha: quote.corLinha,
      gravacao: quote.gravacao,
      quoteId: quote.id,
    );

    await _launchWhatsApp(message: message);
  }

  /// (Admin -> Cliente)
  /// Envia a proposta finalizada com o preço para o Cliente
  static Future<void> sendProposalToClient({
    required Quote quote,
    required double finalPrice,
    
    String? blankName, String? blankVar,
    String? caboName, String? caboVar, int? caboQty,
    String? reelSeatName, String? reelSeatVar,
    
    List<Map<String, dynamic>>? passadoresList,
    List<Map<String, dynamic>>? acessoriosList, // (NOVO)
    
    String? gravacao,
  }) async {
    if (quote.clientPhone.length < 8) {
      throw 'Telefone do cliente inválido.';
    }

    final message = _buildProposalMessage(
      clientName: quote.clientName,
      quoteId: quote.id,
      
      blank: blankName ?? quote.blankName,
      blankVar: blankVar ?? quote.blankVariation,
      
      cabo: caboName ?? quote.caboName,
      caboVar: caboVar ?? quote.caboVariation,
      caboQty: caboQty ?? quote.caboQuantity,
      
      reelSeat: reelSeatName ?? quote.reelSeatName,
      reelSeatVar: reelSeatVar ?? quote.reelSeatVariation,
      
      passadoresList: passadoresList ?? quote.passadoresList,
      acessoriosList: acessoriosList ?? quote.acessoriosList, // (NOVO)
      
      gravacao: gravacao ?? quote.gravacao,
      price: finalPrice,
    );

    await _launchWhatsApp(message: message, targetPhone: quote.clientPhone);
  }

  /// (Cliente -> Jarbas)
  /// Contato Direto
  static Future<void> sendDirectContactRequest({
    required String clientName,
    required String clientPhone,
    required String city,
    required String state,
  }) async {
    final message = '''
Olá! Gostaria de entrar em contato para solicitar um orçamento ou tirar dúvidas.

*Meus Dados:*
*Nome:* $clientName
*Telefone:* $clientPhone
*Local:* $city/$state

Aguardo retorno. Obrigado!
''';
    await _launchWhatsApp(message: message);
  }

  // --- MÉTODOS PRIVADOS ---

  static Future<void> _launchWhatsApp({required String message, String? targetPhone}) async {
    String phoneToUse;

    if (targetPhone != null && targetPhone.isNotEmpty) {
      phoneToUse = targetPhone; // Usa telefone específico (ex: cliente)
    } else {
      final ConfigService configService = ConfigService();
      final settings = await configService.getSettings();
      phoneToUse = settings['supplierPhone'] ?? '';
      if (phoneToUse.isEmpty) throw 'Telefone do fornecedor não configurado no Painel Admin.';
    }

    final cleanPhone = phoneToUse.replaceAll(RegExp(r'[^\d]'), ''); 
    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Não foi possível abrir o WhatsApp ($cleanPhone).';
    }
  }

  // --- FORMATADORES DE TEXTO ---

  static String _buildRequestMessage({
    required String clientName, required String clientPhone, required String city, required String state,
    String? blank, String? blankVar,
    String? cabo, String? caboVar, int? caboQty,
    String? reelSeat, String? reelSeatVar,
    required List<Map<String, dynamic>>? passadoresList,
    required List<Map<String, dynamic>>? acessoriosList,
    String? gravacao, String? quoteId,
  }) {
    // Helpers de formatação
    String fmtVar(String? v) => (v != null && v.isNotEmpty) ? " ($v)" : "";
    String fmtQty(int? q) => (q != null && q > 1) ? " ($q un)" : "";

    // Formata Listas
    String formatList(List<Map<String, dynamic>>? list, String emptyText) {
      if (list == null || list.isEmpty) return emptyText;
      return list.map((p) {
        String n = p['name'] ?? 'Item';
        String v = fmtVar(p['variation']);
        String q = "";
        if (p['quantity'] != null && (p['quantity'] as num) > 1) {
          q = " (${p['quantity']} un)";
        }
        return "- $n$v$q";
      }).join("\n");
    }

    return '''
Olá! Gostaria de solicitar um orçamento:
*Cliente:* $clientName ($city/$state)
${quoteId != null ? '*(Ref: $quoteId)*' : ''}

*Componentes:*
- *Blank:* ${blank ?? 'N/A'}${fmtVar(blankVar)}
- *Cabo:* ${cabo ?? 'N/A'}${fmtVar(caboVar)}${fmtQty(caboQty)}
- *Reel Seat:* ${reelSeat ?? 'N/A'}${fmtVar(reelSeatVar)}

*Passadores:*
${formatList(passadoresList, "Nenhum selecionado")}

*Acessórios:*
${formatList(acessoriosList, "Nenhum selecionado")}

*Personalização:*
*Gravação:* ${gravacao ?? 'N/A'}
''';
  }

  static String _buildProposalMessage({
    required String clientName, String? quoteId,
    String? blank, String? blankVar,
    String? cabo, String? caboVar, int? caboQty,
    String? reelSeat, String? reelSeatVar,
    required List<Map<String, dynamic>>? passadoresList,
    required List<Map<String, dynamic>>? acessoriosList,
    String? gravacao, required double price,
  }) {
    String fmtVar(String? v) => (v != null && v.isNotEmpty) ? " ($v)" : "";
    String fmtQty(int? q) => (q != null && q > 1) ? " ($q un)" : "";

    String formatList(List<Map<String, dynamic>>? list, String emptyText) {
      if (list == null || list.isEmpty) return emptyText;
      return list.map((p) {
        String n = p['name'] ?? 'Item';
        String v = fmtVar(p['variation']);
        String q = "";
        if (p['quantity'] != null && (p['quantity'] as num) > 1) {
          q = " (${p['quantity']} un)";
        }
        return "- $n$v$q";
      }).join("\n");
    }

    return '''
Olá, $clientName! Proposta final da Jarbas Custom Rods ${quoteId != null ? '(Ref: $quoteId)' : ''}:

*Componentes:*
- *Blank:* ${blank ?? 'N/A'}${fmtVar(blankVar)}
- *Cabo:* ${cabo ?? 'N/A'}${fmtVar(caboVar)}${fmtQty(caboQty)}
- *Reel Seat:* ${reelSeat ?? 'N/A'}${fmtVar(reelSeatVar)}

*Passadores:*
${formatList(passadoresList, "Nenhum selecionado")}

*Acessórios:*
${formatList(acessoriosList, "Nenhum selecionado")}

*Personalização:*
*Gravação:* ${gravacao ?? 'N/A'}

*VALOR TOTAL: R\$ ${price.toStringAsFixed(2)}*
Podemos aprovar?
''';
  }
}