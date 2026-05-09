import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Necessário para kIsWeb
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; // Necessário para formatar datas e moeda
import '../providers/rod_builder_provider.dart';
import '../models/quote_model.dart'; 

class WhatsAppService {
  
  // Método público genérico para abrir conversa
  Future<void> openWhatsApp({required String phone, required String message}) async {
    await _launchWhatsApp(message, targetPhone: phone);
  }

  // --- Helper: Busca o Telefone do Fornecedor ---
  static Future<String> _getAdminPhoneNumber() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('global_config').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['supplierPhone'] != null && data['supplierPhone'].toString().isNotEmpty) {
          return data['supplierPhone'].toString();
        }
      }
    } catch (e) {
      print("Erro ao buscar telefone: $e");
    }
    return "5511999999999"; 
  }

  // --- Método 1: Novo Orçamento (Cliente envia para Oficina) ---
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
    buffer.writeln("Aguardo retorno do orçamento!");

    String adminPhone = await _getAdminPhoneNumber();
    await _launchWhatsApp(buffer.toString(), targetPhone: adminPhone);
  }

  // --- Método 2: Contato Direto ---
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
    
    String adminPhone = await _getAdminPhoneNumber();
    await _launchWhatsApp(buffer.toString(), targetPhone: adminPhone);
  }

  // --- Método 3: Envio do Orçamento Fechado (Oficina envia para Cliente) ---
  static Future<void> sendQuoteToClient(Quote quote) async {
    final buffer = StringBuffer();
    buffer.writeln("*Olá ${quote.clientName}, aqui está o resumo do seu orçamento:*");
    buffer.writeln("-------------------------");
    
    void writeMapList(String title, List<Map<String, dynamic>> items) {
      if (items.isNotEmpty) {
        buffer.writeln("*$title:*");
        for (var item in items) {
          String name = item['name'] ?? 'Item';
          int qty = item['quantity'] ?? 1;
          String variation = item['variation']?.toString() ?? '';
          String varText = (variation.isNotEmpty && !name.contains(variation)) ? " [$variation]" : "";
          
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

    if (quote.customizationText != null && quote.customizationText!.isNotEmpty) {
      buffer.writeln("*Notas:* ${quote.customizationText}");
      buffer.writeln("");
    }

    buffer.writeln("-------------------------");
    buffer.writeln("*TOTAL: R\$ ${quote.totalPrice.toStringAsFixed(2)}*");
    buffer.writeln("-------------------------");
    buffer.writeln("Podemos aprovar?");

    await _launchWhatsApp(buffer.toString(), targetPhone: quote.clientPhone);
  }

  // --- Método 4: Atualização e Resumo de Andamento (Painel Kanban / Financeiro) ---
  static Future<void> sendOrderStatusToClient(Quote quote) async {
    final buffer = StringBuffer();
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');
    
    buffer.writeln("*ATUALIZAÇÃO DO SEU PEDIDO* 🎣");
    buffer.writeln("Olá ${quote.clientName}, aqui está o resumo atualizado do seu projeto na Jarbas Custom Rods:");
    buffer.writeln("-------------------------");
    
    buffer.writeln("*📌 Status Atual:* ${quote.status.toUpperCase()}");
    
    if (quote.deliveryDate != null) {
      String dateStr = DateFormat('dd/MM/yyyy').format(quote.deliveryDate!.toDate());
      buffer.writeln("*📅 Prazo Estimado:* $dateStr");
    } else {
      buffer.writeln("*📅 Prazo Estimado:* A definir");
    }
    buffer.writeln("-------------------------");
    
    buffer.writeln("*📋 ITENS DO SEU PEDIDO:*");
    void writeMapList(List<Map<String, dynamic>> items) {
      for (var item in items) {
        String name = item['name'] ?? 'Item';
        int qty = item['quantity'] ?? 1;
        String variation = item['variation']?.toString() ?? '';
        String varText = (variation.isNotEmpty && !name.contains(variation)) ? " [$variation]" : "";
        buffer.writeln(" - ${qty}x $name$varText");
      }
    }

    writeMapList(quote.blanksList);
    writeMapList(quote.cabosList);
    writeMapList(quote.reelSeatsList);
    writeMapList(quote.passadoresList);
    writeMapList(quote.acessoriosList);

    if (quote.customizationText != null && quote.customizationText!.isNotEmpty) {
      buffer.writeln("");
      buffer.writeln("*🛠️ Notas de Personalização:* ${quote.customizationText}");
    }
    buffer.writeln("-------------------------");

    // DADOS FINANCEIROS
    double balance = quote.totalPrice - quote.amountPaid;
    if (balance < 0) balance = 0.0;

    buffer.writeln("*💰 RESUMO FINANCEIRO:*");
    buffer.writeln("*Valor Total:* ${currencyFormat.format(quote.totalPrice)}");
    buffer.writeln("*Valor Pago:* ${currencyFormat.format(quote.amountPaid)}");
    buffer.writeln("*Saldo em Aberto:* ${currencyFormat.format(balance)}");
    
    if (quote.paymentHistory.isNotEmpty) {
      buffer.writeln("");
      buffer.writeln("*Histórico de Pagamentos:*");
      for (var pay in quote.paymentHistory) {
         final date = (pay['date'] as Timestamp).toDate();
         final amount = (pay['amount'] as num).toDouble();
         final method = pay['method'] as String;
         buffer.writeln("✅ ${DateFormat('dd/MM/yy').format(date)} - $method: ${currencyFormat.format(amount)}");
      }
    }

    buffer.writeln("-------------------------");
    buffer.writeln("Qualquer dúvida, estamos à disposição!");

    await _launchWhatsApp(buffer.toString(), targetPhone: quote.clientPhone);
  }

  // --- Helper Privado (UNIVERSAL: IOS, ANDROID E WEB) ---
  static Future<void> _launchWhatsApp(String message, {required String targetPhone}) async {
    String phone = targetPhone.replaceAll(RegExp(r'[^\d]+'), '');
    if (phone.length >= 10 && !phone.startsWith('55')) {
      phone = '55$phone';
    }

    // CORREÇÃO: Utilizando a classe Uri com queryParameters para garantir a codificação UTF-8 dos emojis
    final Uri appUrl = Uri(
      scheme: 'whatsapp',
      host: 'send',
      queryParameters: {
        'phone': phone,
        'text': message,
      }
    );
    
    final Uri webUrl = Uri.https(
      'api.whatsapp.com',
      '/send',
      {
        'phone': phone,
        'text': message,
      }
    );

    if (kIsWeb) {
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir o WhatsApp Web.';
      }
      return;
    }

    try {
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      } 
      else if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir o WhatsApp.';
      }
    } catch (e) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }
}