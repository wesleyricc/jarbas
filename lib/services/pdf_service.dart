import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/quote_model.dart';

class PdfService {
  static final _currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');

  static Future<void> generateAndPrintQuote(Quote quote) async {
    final pdf = pw.Document();

    // Fontes
    final font = await PdfGoogleFonts.nunitoExtraLight();
    final fontBold = await PdfGoogleFonts.nunitoExtraBold();
    final fontItalic = await PdfGoogleFonts.nunitoExtraLightItalic(); // <--- NOVO


    // Tenta carregar a logo
    pw.MemoryImage? profileImage;
    try {
      final byteData = await rootBundle.load('assets/logo_jarbas.png');
      profileImage = pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (e) {
      print("Erro ao carregar logo: $e. O PDF será gerado sem imagem.");
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        // Margens ajustadas para dar mais respiro
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold, italic: fontItalic),
        build: (context) => [
          // 1. Logo Centralizada e Grande
          _buildCenteredLogoHeader(profileImage),

          pw.SizedBox(height: 20),

          // 2. Dados do Cliente e do Orçamento (reorganizado)
          _buildClientAndQuoteInfo(quote),

          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),

          // 3. Lista de Itens Simplificada
          _buildSimpleItemsList(quote),

          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),

          // 4. Total Simplificado
          _buildSimpleTotal(quote),

          pw.Spacer(),

          // 5. Rodapé
          _buildFooter(),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Orcamento_${quote.clientName.trim()}.pdf',
    );
  }

  // --- 1. CABEÇALHO: LOGO CENTRALIZADA E MAIOR ---
  static pw.Widget _buildCenteredLogoHeader(pw.MemoryImage? image) {
    if (image == null) {
      // Fallback se não tiver imagem
      return pw.Center(
        child: pw.Column(
          children: [
            pw.Text(
              "JARBAS CUSTOM RODS",
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.Text(
              "Excelência em Customização",
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
            ),
          ],
        ),
      );
    }

    return pw.Center(
      child: pw.Container(
        // AJUSTE O TAMANHO AQUI SE NECESSÁRIO
        width: 180,
        height: 120,
        child: pw.Image(image, fit: pw.BoxFit.contain),
      ),
    );
  }

  // --- 2. SEÇÃO DE DADOS (CLIENTE + ORÇAMENTO) ---
  static pw.Widget _buildClientAndQuoteInfo(Quote quote) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Lado Esquerdo: Cliente
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "CLIENTE",
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              quote.clientName,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            if (quote.clientPhone.isNotEmpty)
              pw.Text(
                quote.clientPhone,
                style: const pw.TextStyle(fontSize: 12),
              ),
          ],
        ),
        // Lado Direito: Dados do Orçamento
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              "ORÇAMENTO",
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              "Data: ${DateFormat('dd/MM/yyyy').format(quote.createdAt.toDate())}",
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              "${quote.clientCity} - ${quote.clientState}",
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- 3. LISTA DE ITENS SIMPLIFICADA (MANTIDA) ---
  static pw.Widget _buildSimpleItemsList(Quote quote) {
    final List<pw.Widget> itemWidgets = [];

    void addCategoryBlock(
      String categoryTitle,
      List<Map<String, dynamic>> items,
    ) {
      if (items.isEmpty) return;

      itemWidgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                categoryTitle.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey700,
                ),
              ),
              pw.SizedBox(height: 6),
              ...items.map((item) {
                String name = item['name'];
                if (item['variation'] != null &&
                    item['variation'].toString().isNotEmpty) {
                  name += " [${item['variation']}]";
                }
                int qty = (item['quantity'] ?? 1) as int;

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, bottom: 3),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 4,
                        height: 4,
                        margin: const pw.EdgeInsets.only(top: 6, right: 8),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.blueGrey400,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          "${qty}x  $name",
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );
    }

    addCategoryBlock("Blanks", quote.blanksList);
    addCategoryBlock("Cabos", quote.cabosList);
    addCategoryBlock("Reel Seats", quote.reelSeatsList);
    addCategoryBlock("Passadores", quote.passadoresList);
    addCategoryBlock("Acessórios", quote.acessoriosList);

    if (itemWidgets.isEmpty) {
      return pw.Center(child: pw.Text("Nenhum item selecionado."));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: itemWidgets,
    );
  }

  // --- 4. TOTAL SIMPLIFICADO (MANTIDO) ---
  static pw.Widget _buildSimpleTotal(Quote quote) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            "VALOR TOTAL",
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey600,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _currencyFormat.format(quote.totalPrice),
            style: pw.TextStyle(
              fontSize: 26,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
          ),

          // 2. O trecho corrigido (sem const no TextStyle e garantindo que o pai não é const)
          if (quote.customizationText != null &&
              quote.customizationText!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                "* Inclui personalização: ${quote.customizationText}",
                // Removi o 'const' daqui para garantir compatibilidade
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- 5. RODAPÉ (MANTIDO) ---
  static pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(color: PdfColors.grey200),
        pw.SizedBox(height: 10),
        pw.Text(
          "Jarbas Custom Rods",
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.Text(
          "Excelência e alta performance em cada detalhe.",
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      ],
    );
  }
}
