import 'package:url_launcher/url_launcher.dart';
import '../models/quote_model.dart';
import '../providers/rod_builder_provider.dart';

class WhatsAppService {
  // --- CONFIGURAÇÃO ---
  // Número da Jarbas Custom Rods
  static const String _supplierPhone = '+5548996381626'; 

  // --- MÉTODOS PÚBLICOS ---

  /// (Cliente -> Jarbas)
  /// Envia um NOVO orçamento recém-criado no RodBuilder.
  /// CORREÇÃO: Agora aceita apenas o 'provider' e extrai os dados dele.
  static Future<void> sendNewQuoteRequest({
    required RodBuilderProvider provider,
  }) async {
    final message = _buildRequestMessage(
      clientName: provider.clientName,
      clientPhone: provider.clientPhone,
      city: provider.clientCity,
      state: provider.clientState,
      blank: provider.selectedBlank?.name,
      cabo: provider.selectedCabo?.name,
      caboQty: provider.caboQuantity,
      reelSeat: provider.selectedReelSeat?.name,
      passadores: provider.selectedPassadores?.name,
      passadoresQty: provider.passadoresQuantity,
      corLinha: provider.corLinha,
      gravacao: provider.gravacao,
    );

    await _launchWhatsApp(phone: _supplierPhone, message: message);
  }

  /// (Cliente -> Jarbas)
  /// Reenvia um orçamento já existente (da lista de histórico)
  static Future<void> resendQuoteRequest(Quote quote) async {
    final message = _buildRequestMessage(
      clientName: quote.clientName,
      clientPhone: quote.clientPhone,
      city: quote.clientCity,
      state: quote.clientState,
      blank: quote.blankName,
      cabo: quote.caboName,
      caboQty: quote.caboQuantity,
      reelSeat: quote.reelSeatName,
      passadores: quote.passadoresName,
      passadoresQty: quote.passadoresQuantity,
      corLinha: quote.corLinha,
      gravacao: quote.gravacao,
      quoteId: quote.id,
    );

    await _launchWhatsApp(phone: _supplierPhone, message: message);
  }

  /// (Admin -> Cliente)
  /// Envia a proposta finalizada com o preço para o cliente.
  static Future<void> sendProposalToClient({
    required Quote quote,
    required double finalPrice,
    // Opcional: passar componentes atualizados caso o admin tenha trocado na edição
    String? blankName,
    String? caboName,
    int? caboQty,
    String? reelSeatName,
    String? passadoresName,
    int? passadoresQty,
  }) async {
    // Validação de segurança
    if (quote.clientPhone.length < 8) {
      throw 'Telefone do cliente inválido.';
    }

    final message = _buildProposalMessage(
      clientName: quote.clientName,
      quoteId: quote.id,
      blank: blankName ?? quote.blankName,
      cabo: caboName ?? quote.caboName,
      caboQty: caboQty ?? quote.caboQuantity,
      reelSeat: reelSeatName ?? quote.reelSeatName,
      passadores: passadoresName ?? quote.passadoresName,
      passadoresQty: passadoresQty ?? quote.passadoresQuantity,
      corLinha: quote.corLinha,
      gravacao: quote.gravacao,
      price: finalPrice,
    );

    await _launchWhatsApp(phone: quote.clientPhone, message: message);
  }

  // --- MÉTODOS PRIVADOS (Lógica Interna) ---

  static Future<void> _launchWhatsApp({required String phone, required String message}) async {
    // Limpa o telefone deixando apenas números e o +
    final cleanPhone = phone.replaceAll(RegExp(r'[^\+\d]'), '');
    
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Não foi possível abrir o WhatsApp ($cleanPhone).';
    }
  }

  static String _buildRequestMessage({
    required String clientName,
    required String clientPhone,
    required String city,
    required String state,
    String? blank,
    String? cabo,
    int? caboQty,
    String? reelSeat,
    String? passadores,
    int? passadoresQty,
    String? corLinha,
    String? gravacao,
    String? quoteId,
  }) {
    // Formata string de quantidade
    String cQty = (caboQty != null && caboQty > 1) ? " ($caboQty un)" : "";
    String pQty = (passadoresQty != null && passadoresQty > 1) ? " ($passadoresQty un)" : "";

    return '''
Olá! Gostaria de solicitar um orçamento para a seguinte vara personalizada:

*Cliente:* $clientName
*Telefone:* $clientPhone
*Local:* $city/$state
${quoteId != null ? '*(Ref: $quoteId)*' : ''}

*Componentes:*
- *Blank:* ${blank ?? 'N/A'}
- *Cabo:* ${cabo ?? 'N/A'}$cQty
- *Reel Seat:* ${reelSeat ?? 'N/A'}
- *Passadores:* ${passadores ?? 'N/A'}$pQty

*Personalização:*
- *Cor da Linha:* ${corLinha?.isNotEmpty == true ? corLinha : 'N/A'}
- *Gravação:* ${gravacao?.isNotEmpty == true ? gravacao : 'N/A'}
''';
  }

  static String _buildProposalMessage({
    required String clientName,
    String? quoteId,
    String? blank,
    String? cabo,
    int? caboQty,
    String? reelSeat,
    String? passadores,
    int? passadoresQty,
    String? corLinha,
    String? gravacao,
    required double price,
  }) {
    String cQty = (caboQty != null && caboQty > 1) ? " ($caboQty un)" : "";
    String pQty = (passadoresQty != null && passadoresQty > 1) ? " ($passadoresQty un)" : "";

    return '''
Olá, $clientName!
Aqui é da Jarbas Custom Rods.

Seguindo seu pedido, aqui está a proposta final ${quoteId != null ? '(Ref: $quoteId)' : ''}:

*PROPOSTA FINAL:*

*Componentes:*
- *Blank:* ${blank ?? 'N/A'}
- *Cabo:* ${cabo ?? 'N/A'}$cQty
- *Reel Seat:* ${reelSeat ?? 'N/A'}
- *Passadores:* ${passadores ?? 'N/A'}$pQty

*Personalização:*
- *Cor da Linha:* ${corLinha?.isNotEmpty == true ? corLinha : 'N/A'}
- *Gravação:* ${gravacao?.isNotEmpty == true ? gravacao : 'N/A'}

*VALOR TOTAL: R\$ ${price.toStringAsFixed(2)}*

Podemos aprovar para produção?
''';
  }
}