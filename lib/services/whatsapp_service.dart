import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Necessário para kIsWeb
import 'package:url_launcher/url_launcher.dart';
import '../providers/rod_builder_provider.dart';
import '../models/quote_model.dart'; 

class WhatsAppService {
  
  // ADICIONADO: Método público genérico para abrir conversa
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

  // --- Método 1: Novo Orçamento ---
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

  // --- Método 3: Admin Envia para Cliente ---
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

  // --- Helper Privado (UNIVERSAL: IOS, ANDROID E WEB) ---
  static Future<void> _launchWhatsApp(String message, {required String targetPhone}) async {
    String phone = targetPhone.replaceAll(RegExp(r'[^\d]+'), '');
    if (phone.length >= 10 && !phone.startsWith('55')) {
      phone = '55$phone';
    }

    final Uri appUrl = Uri.parse("whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}");
    final Uri webUrl = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

    // LÓGICA ESPECÍFICA PARA WEB (PWA)
    if (kIsWeb) {
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir o WhatsApp Web.';
      }
      return;
    }

    // LÓGICA PARA NATIVO (ANDROID / IOS)
    try {
      // 1. Tenta abrir o App Nativo
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      } 
      // 2. Fallback para Web Link
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