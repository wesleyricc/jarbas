import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'package:flutter/foundation.dart'; // Necessário para kIsWeb

class WebScrapingService {
  
  /// Busca o preço atual de um produto dado um URL.
  /// Retorna null se falhar ou não encontrar.
  Future<double?> fetchPriceFromUrl(String url) async {
    if (url.isEmpty) return null;

    try {
      String targetUrl = url;

      // --- CORREÇÃO PARA FLUTTER WEB (CORS) ---
      // Se estiver rodando na Web, usamos um proxy para evitar o erro "Failed to fetch"
      if (kIsWeb) {
        // Usando o serviço 'allorigins' como proxy transparente
        targetUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
      }
      
      final uri = Uri.parse(targetUrl);
      
      // Headers para simular um navegador real e evitar bloqueios simples
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      });

      if (response.statusCode != 200) {
        print('[Scraper] Erro HTTP: ${response.statusCode}');
        return null;
      }

      var document = parser.parse(response.body);
      Element? priceElement;

      // --- LÓGICA DE SELEÇÃO DO PREÇO (Moro Fishing / OpenCart) ---
      
      // Tentativa 1: Padrão exato identificado no arquivo enviado (F3J782EX...)
      // O preço está em um <h2> dentro da div #content.
      final contentH2s = document.querySelectorAll('#content h2');
      for (var h2 in contentH2s) {
        if (h2.text.contains('R\$')) {
          priceElement = h2;
          break;
        }
      }

      // Tentativa 2: Classe específica de preço promocional (comum em outros itens)
      if (priceElement == null) {
        priceElement = document.querySelector('.price-new');
      }
      
      // Tentativa 3: Busca genérica por qualquer H2 com R$ (Fallback)
      if (priceElement == null) {
        final h2Tags = document.querySelectorAll('h2');
        for (var h2 in h2Tags) {
          if (h2.text.contains('R\$')) {
            priceElement = h2;
            break;
          }
        }
      }

      // Tentativa 4: Busca ultra genérica (último recurso)
      if (priceElement == null) {
        final allElements = document.querySelectorAll('*');
        for (var el in allElements) {
          if (el.text.contains('R\$') && (el.className.contains('price') || el.className.contains('valor'))) {
             priceElement = el;
             break;
          }
        }
      }

      if (priceElement != null) {
        return _parsePriceString(priceElement.text);
      }

    } catch (e) {
      print('[Scraper] Erro ao processar URL $url: $e');
    }
    return null;
  }

  /// Converte string "R$ 1.250,50" para double 1250.50
  double? _parsePriceString(String rawPrice) {
    try {
      // 1. Remove "R$" e espaços
      String clean = rawPrice.toUpperCase().replaceAll('R\$', '').trim();
      
      // 2. Remove pontos de milhar
      if (clean.contains(',') && clean.contains('.')) {
        clean = clean.replaceAll('.', ''); 
      }
      
      // 3. Troca vírgula decimal por ponto
      clean = clean.replaceAll(',', '.');

      // 4. Limpeza final
      clean = clean.replaceAll(RegExp(r'[^\d.]'), '');

      return double.tryParse(clean);
    } catch (e) {
      print('[Scraper] Erro ao converter preço: $rawPrice -> $e');
      return null;
    }
  }
}