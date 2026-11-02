import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/invoice.dart';
import '../theme/app_theme.dart';
import '../constants/invoice_assets.dart';

class InvoiceItemRow {
  final int index;
  final String treatment;
  final int nos;
  final double rate;
  final double amount;

  InvoiceItemRow({
    required this.index,
    required this.treatment,
    required this.nos,
    required this.rate,
    required this.amount,
  });
}

class InvoiceReceiptDialog extends StatelessWidget {
  final Invoice invoice;

  const InvoiceReceiptDialog({super.key, required this.invoice});

  static String formatDate(String d) {
    if (d.isEmpty) return DateFormat('dd/MM/yyyy').format(DateTime.now());
    try {
      final parsed = DateTime.tryParse(d);
      if (parsed != null) {
        return DateFormat('dd/MM/yyyy').format(parsed);
      }
      final parts = d.split(RegExp(r'[-/]'));
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          return '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}';
        }
        return '${parts[0].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[2]}';
      }
    } catch (_) {}
    return d;
  }

  static String cleanBillNo(String id) {
    if (id.isEmpty) return '1';
    final stripped = id.replaceAll(RegExp(r'^INV-'), '');
    return stripped.isNotEmpty ? stripped : id;
  }

  static List<InvoiceItemRow> getInvoiceItemRows(Invoice inv) {
    final rows = <InvoiceItemRow>[];
    int rIdx = 1;

    if (inv.treatment.isNotEmpty) {
      final nos = inv.treatmentNos > 0 ? inv.treatmentNos : 1;
      final amt = inv.treatmentCharge > 0 ? inv.treatmentCharge : inv.totalAmount;
      final rate = inv.treatmentRate > 0 ? inv.treatmentRate : (amt / nos);
      rows.add(InvoiceItemRow(
        index: rIdx++,
        treatment: inv.treatment,
        nos: nos,
        rate: rate,
        amount: amt,
      ));
    }

    if (inv.consultationCharge > 0) {
      rows.add(InvoiceItemRow(
        index: rIdx++,
        treatment: 'Doctor Consultation Charge',
        nos: 1,
        rate: inv.consultationCharge,
        amount: inv.consultationCharge,
      ));
    }

    if (inv.xrayCharge > 0) {
      rows.add(InvoiceItemRow(
        index: rIdx++,
        treatment: 'X-Ray Examination Charge',
        nos: 1,
        rate: inv.xrayCharge,
        amount: inv.xrayCharge,
      ));
    }

    if (inv.pharmacyCharge > 0) {
      rows.add(InvoiceItemRow(
        index: rIdx++,
        treatment: 'Pharmacy / Medicines Charge',
        nos: 1,
        rate: inv.pharmacyCharge,
        amount: inv.pharmacyCharge,
      ));
    }

    for (final c in inv.customCharges) {
      rows.add(InvoiceItemRow(
        index: rIdx++,
        treatment: c.title,
        nos: 1,
        rate: c.amount,
        amount: c.amount,
      ));
    }

    if (rows.isEmpty) {
      rows.add(InvoiceItemRow(
        index: 1,
        treatment: 'Dental Consultation & Treatment',
        nos: 1,
        rate: inv.totalAmount,
        amount: inv.totalAmount,
      ));
    }

    return rows;
  }

  /// Generates printable standalone HTML matching reference image exactly
  static String generatePrintableHtml(Invoice inv) {
    final items = getInvoiceItemRows(inv);
    final billNo = cleanBillNo(inv.id);
    final dateStr = formatDate(inv.date);

    final itemRowsHtml = items.map((it) {
      return '''<tr>
        <td style="text-align: center; border-left: 1px solid #000; border-right: 1px solid #000; padding: 6px 8px;">${it.index}</td>
        <td style="text-align: left; border-right: 1px solid #000; padding: 6px 8px;">${it.treatment}</td>
        <td style="text-align: center; border-right: 1px solid #000; padding: 6px 8px;">${it.nos}</td>
        <td style="text-align: right; border-right: 1px solid #000; padding: 6px 8px;">${it.rate.toStringAsFixed(2)}</td>
        <td style="text-align: right; border-right: 1px solid #000; padding: 6px 8px;">${it.amount.toStringAsFixed(2)}</td>
      </tr>''';
    }).join('\n');

    return '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Bill No : $billNo - Manjaly Dental Care</title>
    <style>
        @page { size: A4; margin: 20mm 15mm; }
        body { font-family: Arial, Helvetica, sans-serif; color: #000; background: #fff; margin: 0; padding: 25px; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
        .invoice-box { max-width: 740px; margin: 0 auto; background: #fff; }
        .inv-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 24px; }
        .clinic-info { text-align: left; }
        .clinic-name { font-size: 19px; font-weight: 700; letter-spacing: 0.5px; text-transform: uppercase; margin: 0 0 6px 0; color: #000; font-family: Arial, sans-serif; }
        .clinic-address { font-size: 13px; color: #111; margin-bottom: 4px; }
        .clinic-mobile { font-size: 13px; color: #111; }
        .clinic-logo-wrap { width: 95px; height: 95px; }
        .clinic-logo { width: 95px; height: 95px; object-fit: contain; }
        
        .inv-meta-row { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 20px; font-size: 13.5px; }
        .meta-left { display: flex; flex-direction: column; gap: 4px; }
        .meta-field { display: flex; align-items: baseline; }
        .meta-label { width: 68px; font-weight: 700; }
        .meta-sep { margin-right: 12px; font-weight: 700; }
        .meta-val { font-weight: 500; }
        .meta-right { font-weight: 700; font-size: 13.5px; }
        
        table.inv-table { width: 100%; border-collapse: collapse; border: 1px solid #000; margin-bottom: 30px; }
        table.inv-table th { border: 1px solid #000; padding: 6px 8px; font-size: 13px; font-weight: 700; background: #fff; color: #000; }
        table.inv-table tr.spacer-row td { height: 160px; border-left: 1px solid #000; border-right: 1px solid #000; }
        table.inv-table tr.total-row td { border-top: 1px solid #000; border-bottom: 1px solid #000; border-left: 1px solid #000; border-right: 1px solid #000; padding: 7px 10px; font-weight: 700; font-size: 13.5px; }
        
        .inv-footer { display: flex; justify-content: space-between; align-items: center; margin-top: 25px; padding: 0 10px; }
        .hosp-seal-col { width: 140px; text-align: left; }
        .hosp-seal-img { width: 110px; height: 110px; object-fit: contain; }
        .center-text-col { flex: 1; text-align: center; font-size: 12.5px; font-weight: 700; color: #000; padding: 0 15px; }
        .doctor-col { width: 180px; text-align: center; display: flex; flex-direction: column; align-items: center; }
        .sign-img { max-height: 55px; max-width: 120px; object-fit: contain; }
        .drseal-img { max-height: 58px; max-width: 145px; object-fit: contain; margin-top: 4px; }

        @media print {
            body { padding: 0; }
            .invoice-box { max-width: 100%; }
        }
    </style>
</head>
<body onload="window.print()">
    <div class="invoice-box">
        <div class="inv-header">
            <div class="clinic-info">
                <div class="clinic-name">MANJALY MULTI SPECIALITY DENTAL CARE</div>
                <div class="clinic-address">Near MJ Supermarket ,Valakkavu Mulayam p.o,Thrissur,Kerala-680751</div>
                <div class="clinic-mobile">Mobile: 6238497517,9072467117</div>
            </div>
            <div class="clinic-logo-wrap">
                <img src="$kInvoiceLogoBase64" alt="Clinic Logo" class="clinic-logo">
            </div>
        </div>

        <div class="inv-meta-row">
            <div class="meta-left">
                <div class="meta-field">
                    <span class="meta-label">Bill No</span>
                    <span class="meta-sep">:</span>
                    <span class="meta-val">$billNo</span>
                </div>
                <div class="meta-field">
                    <span class="meta-label">Name</span>
                    <span class="meta-sep">:</span>
                    <span class="meta-val">${inv.patientName}</span>
                </div>
                <div class="meta-field">
                    <span class="meta-label">Address</span>
                    <span class="meta-sep">:</span>
                    <span class="meta-val">${inv.address}</span>
                </div>
            </div>
            <div class="meta-right">
                Date : $dateStr
            </div>
        </div>

        <table class="inv-table">
            <thead>
                <tr>
                    <th style="width: 5%; text-align: center;">#</th>
                    <th style="width: 55%; text-align: left;">Treatment</th>
                    <th style="width: 10%; text-align: center;">Nos</th>
                    <th style="width: 15%; text-align: right;">Rate</th>
                    <th style="width: 15%; text-align: right;">Amount</th>
                </tr>
            </thead>
            <tbody>
                $itemRowsHtml
                <tr class="spacer-row">
                    <td></td><td></td><td></td><td></td><td></td>
                </tr>
                <tr class="total-row">
                    <td colspan="4" style="text-align: right; border-right: 1px solid #000;">Net Amount Rs:</td>
                    <td style="text-align: right;">${inv.totalAmount.toStringAsFixed(2)}</td>
                </tr>
            </tbody>
        </table>

        <div class="inv-footer">
            <div class="hosp-seal-col">
                <img src="$kInvoiceHospitalSealBase64" alt="Hospital Seal" class="hosp-seal-img">
            </div>
            <div class="center-text-col">
                FOR MANJALY MULTI SPECIALITY DENTAL CARE
            </div>
            <div class="doctor-col">
                <img src="$kInvoiceSignBase64" alt="Doctor Signature" class="sign-img">
                <img src="$kInvoiceDrSealBase64" alt="Doctor Seal" class="drseal-img">
            </div>
        </div>
    </div>
</body>
</html>''';
  }

  static pw.MemoryImage? _safeMemoryImage(String base64Str) {
    try {
      final clean = base64Str.contains(',') ? base64Str.split(',').last : base64Str;
      final bytes = base64Decode(clean.trim());
      if (bytes.isNotEmpty) {
        return pw.MemoryImage(bytes);
      }
    } catch (_) {}
    return null;
  }

  /// Generates crisp vector PDF matching the reference invoice image exactly
  static Future<Uint8List> generateInvoicePdfBytes(Invoice inv) async {
    final pdf = pw.Document();

    final logoImg = _safeMemoryImage(kInvoiceLogoBase64);
    final signImg = _safeMemoryImage(kInvoiceSignBase64);
    final drSealImg = _safeMemoryImage(kInvoiceDrSealBase64);
    final hospSealImg = _safeMemoryImage(kInvoiceHospitalSealBase64);

    final items = getInvoiceItemRows(inv);
    final billNo = cleanBillNo(inv.id);
    final dateStr = formatDate(inv.date);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. Header (Left: Hospital Info, Right: Tooth Logo)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MANJALY MULTI SPECIALITY DENTAL CARE',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Near MJ Supermarket ,Valakkavu Mulayam p.o,Thrissur,Kerala-680751',
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Mobile: 6238497517,9072467117',
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                    ],
                  ),
                  if (logoImg != null)
                    pw.Container(
                      width: 65,
                      height: 65,
                      child: pw.Image(logoImg, fit: pw.BoxFit.contain),
                    ),
                ],
              ),
              pw.SizedBox(height: 22),

              // 2. Patient & Bill Metadata
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(children: [
                        pw.Container(
                          width: 55,
                          child: pw.Text('Bill No', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Text(':  ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text(billNo, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ]),
                      pw.SizedBox(height: 4),
                      pw.Row(children: [
                        pw.Container(
                          width: 55,
                          child: pw.Text('Name', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Text(':  ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text(inv.patientName, style: const pw.TextStyle(fontSize: 10)),
                      ]),
                      pw.SizedBox(height: 4),
                      pw.Row(children: [
                        pw.Container(
                          width: 55,
                          child: pw.Text('Address', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Text(':  ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text(inv.address, style: const pw.TextStyle(fontSize: 10)),
                      ]),
                    ],
                  ),
                  pw.Text('Date : $dateStr', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 16),

              // 3. Treatment Table
              pw.Table(
                border: const pw.TableBorder(
                  top: pw.BorderSide(color: PdfColors.black, width: 1),
                  bottom: pw.BorderSide(color: PdfColors.black, width: 1),
                  left: pw.BorderSide(color: PdfColors.black, width: 1),
                  right: pw.BorderSide(color: PdfColors.black, width: 1),
                  verticalInside: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(26),
                  1: const pw.FlexColumnWidth(5),
                  2: const pw.FixedColumnWidth(38),
                  3: const pw.FixedColumnWidth(65),
                  4: const pw.FixedColumnWidth(75),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        child: pw.Center(child: pw.Text('#', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                        child: pw.Text('Treatment', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        child: pw.Center(child: pw.Text('Nos', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text('Rate', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text('Amount', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),

                  // Data Rows
                  ...items.map((it) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: pw.Center(child: pw.Text('${it.index}', style: const pw.TextStyle(fontSize: 9.5))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                          child: pw.Text(it.treatment, style: const pw.TextStyle(fontSize: 9.5)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: pw.Center(child: pw.Text('${it.nos}', style: const pw.TextStyle(fontSize: 9.5))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(it.rate.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9.5)),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(it.amount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9.5)),
                          ),
                        ),
                      ],
                    );
                  }),

                  // Spacer row to match real paper receipt height
                  pw.TableRow(
                    children: [
                      pw.Container(height: 150),
                      pw.Container(height: 150),
                      pw.Container(height: 150),
                      pw.Container(height: 150),
                      pw.Container(height: 150),
                    ],
                  ),
                ],
              ),

              // Bottom Net Amount Box
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text('Net Amount Rs:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                      ),
                    ),
                    pw.Container(
                      width: 76,
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(left: pw.BorderSide(color: PdfColors.black, width: 1)),
                      ),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(inv.totalAmount.toStringAsFixed(2), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 35),

              // 4. Footer: Hospital Seal, Text, Doctor Sign & Seal
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Left: Hospital Circular Seal
                  pw.Container(
                    width: 95,
                    height: 95,
                    child: hospSealImg != null
                        ? pw.Image(hospSealImg, fit: pw.BoxFit.contain)
                        : pw.SizedBox(),
                  ),

                  // Center: FOR MANJALY MULTI SPECIALITY DENTAL CARE
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                      child: pw.Center(
                        child: pw.Text(
                          'FOR MANJALY MULTI SPECIALITY DENTAL CARE',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                  // Right: Doctor's Signature & Doctor Stamp Seal
                  pw.Container(
                    width: 140,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (signImg != null)
                          pw.Container(
                            height: 48,
                            width: 100,
                            child: pw.Image(signImg, fit: pw.BoxFit.contain),
                          ),
                        if (drSealImg != null)
                          pw.Container(
                            height: 48,
                            width: 130,
                            child: pw.Image(drSealImg, fit: pw.BoxFit.contain),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Backward compatible alias for downloadInvoicePdf
  static Future<void> downloadInvoiceFile(BuildContext context, Invoice inv) =>
      downloadInvoicePdf(context, inv);

  /// Downloads and saves the PDF invoice file to device Downloads
  static Future<void> downloadInvoicePdf(BuildContext context, Invoice inv) async {
    try {
      final pdfBytes = await generateInvoicePdfBytes(inv);
      final cleanName = inv.patientName.replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      final filename = 'Invoice_${inv.id}_$cleanName.pdf';

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(pdfBytes, flush: true);

      bool savedToDownloads = false;
      final candidateDirs = [
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Downloads'),
        Directory('/sdcard/Download'),
      ];

      for (final dir in candidateDirs) {
        try {
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          if (dir.existsSync()) {
            final targetFile = File('${dir.path}/$filename');
            await targetFile.writeAsBytes(pdfBytes, flush: true);
            if (targetFile.existsSync() && targetFile.lengthSync() > 0) {
              savedToDownloads = true;
              break;
            }
          }
        } catch (_) {}
      }

      await Printing.layoutPdf(
        name: 'Invoice_${inv.id}_$cleanName',
        onLayout: (format) async => pdfBytes,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(savedToDownloads
                ? '✓ Invoice saved to Downloads: $filename'
                : '✓ PDF Invoice ready: $filename'),
            backgroundColor: AppTheme.primaryTeal,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () {
                Printing.sharePdf(bytes: pdfBytes, filename: filename);
              },
            ),
          ),
        );
      }
    } catch (e) {
      try {
        final pdfBytes = await generateInvoicePdfBytes(inv);
        final cleanName = inv.patientName.replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
        final filename = 'Invoice_${inv.id}_$cleanName.pdf';
        final tempFile = File('${Directory.systemTemp.path}/$filename');
        await tempFile.writeAsBytes(pdfBytes, flush: true);
        await Share.shareXFiles(
          [XFile(tempFile.path, mimeType: 'application/pdf', name: filename)],
          subject: 'Invoice: ${inv.id}',
        );
      } catch (fallbackErr) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF Download failed: $e')),
          );
        }
      }
    }
  }

  /// Shares the invoice directly as a PDF document on WhatsApp
  static Future<void> shareInvoicePdfOnWhatsApp(BuildContext context, Invoice inv) async {
    try {
      final pdfBytes = await generateInvoicePdfBytes(inv);
      final cleanName = inv.patientName.replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      final filename = 'Invoice_${inv.id}_$cleanName.pdf';

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(pdfBytes, flush: true);

      final items = getInvoiceItemRows(inv);
      final breakdownList = items.map((it) => '• ${it.treatment} (x${it.nos}): Rs. ${it.amount.toStringAsFixed(2)}').toList();

      final text = '''
🏥 *MANJALY MULTI SPECIALITY DENTAL CARE*
📍 Near MJ Supermarket, Valakkavu Mulayam p.o, Thrissur, Kerala-680751
📞 Mobile: 6238497517, 9072467117
━━━━━━━━━━━━━━━━━━━━━━━━
🧾 *OFFICIAL PATIENT INVOICE & RECEIPT*
━━━━━━━━━━━━━━━━━━━━━━━━
*Bill No:* ${cleanBillNo(inv.id)}
*Date:* ${formatDate(inv.date)}
*Patient Name:* ${inv.patientName}
${inv.address.isNotEmpty ? '*Address:* ${inv.address}\n' : ''}*TREATMENTS / CHARGES:*
${breakdownList.join('\n')}
────────────────────────
*Net Amount Rs:* ${inv.totalAmount.toStringAsFixed(2)}
*Payment Mode:* ${inv.paymentMode}
━━━━━━━━━━━━━━━━━━━━━━━━
* Valid for all official and claim purposes.
''';

      await Share.shareXFiles(
        [XFile(tempFile.path, mimeType: 'application/pdf', name: filename)],
        text: text,
        subject: 'Dental Care Invoice: ${inv.id}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WhatsApp share failed: $e')),
        );
      }
    }
  }

  /// Print directly to printer
  static Future<void> printInvoice(BuildContext context, Invoice inv) async {
    try {
      final pdfBytes = await generateInvoicePdfBytes(inv);
      await Printing.layoutPdf(
        name: 'Invoice_${inv.id}',
        onLayout: (format) async => pdfBytes,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = getInvoiceItemRows(invoice);
    final billNo = cleanBillNo(invoice.id);
    final dateStr = formatDate(invoice.date);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header (Left: Hospital Info, Right: Logo)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'MANJALY MULTI SPECIALITY DENTAL CARE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Near MJ Supermarket ,Valakkavu Mulayam p.o,Thrissur,Kerala-680751',
                          style: TextStyle(fontSize: 11, color: Color(0xFF334155)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mobile: 6238497517,9072467117',
                          style: TextStyle(fontSize: 11, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Image.asset(
                    'assets/images/logo.png',
                    width: 58,
                    height: 58,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.local_hospital, color: AppTheme.primaryTeal, size: 40),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 2. Metadata (Bill No, Name, Address & Date)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 60, child: Text('Bill No', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black))),
                          const Text(':  ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                          Text(billNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SizedBox(width: 60, child: Text('Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black))),
                          const Text(':  ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                          Text(invoice.patientName, style: const TextStyle(fontSize: 12, color: Colors.black)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SizedBox(width: 60, child: Text('Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black))),
                          const Text(':  ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                          Text(invoice.address.isNotEmpty ? invoice.address : '-', style: const TextStyle(fontSize: 12, color: Colors.black)),
                        ],
                      ),
                    ],
                  ),
                  Text('Date : $dateStr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Treatment Table
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                      ),
                      child: Row(
                        children: const [
                          SizedBox(width: 24, child: Center(child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)))),
                          VerticalDivider(width: 8, color: Colors.black),
                          Expanded(child: Text('Treatment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                          SizedBox(width: 40, child: Center(child: Text('Nos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)))),
                          SizedBox(width: 65, child: Align(alignment: Alignment.centerRight, child: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)))),
                          SizedBox(width: 75, child: Align(alignment: Alignment.centerRight, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)))),
                        ],
                      ),
                    ),

                    // Items Rows
                    ...items.map((it) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(width: 24, child: Center(child: Text('${it.index}', style: const TextStyle(fontSize: 11, color: Colors.black)))),
                            Expanded(child: Text(it.treatment, style: const TextStyle(fontSize: 11, color: Colors.black))),
                            SizedBox(width: 40, child: Center(child: Text('${it.nos}', style: const TextStyle(fontSize: 11, color: Colors.black)))),
                            SizedBox(width: 65, child: Align(alignment: Alignment.centerRight, child: Text(it.rate.toStringAsFixed(2), style: const TextStyle(fontSize: 11, color: Colors.black)))),
                            SizedBox(width: 75, child: Align(alignment: Alignment.centerRight, child: Text(it.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 11, color: Colors.black)))),
                          ],
                        ),
                      );
                    }),

                    // Spacer height
                    const SizedBox(height: 70),

                    // Net Amount Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.black, width: 1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Net Amount Rs:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          Text(
                            invoice.totalAmount.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // 4. Footer: Hospital Seal, Text & Doctor Sign / Dr Seal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Hospital Seal
                  Image.asset(
                    'assets/images/Hospital Seal.jpg',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/hospital_seal.jpg',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 80, height: 80),
                    ),
                  ),

                  // Center Text
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        'FOR MANJALY MULTI SPECIALITY DENTAL CARE',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  ),

                  // Doctor Signature & Seal
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/sign.jpg',
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox(height: 40),
                      ),
                      Image.asset(
                        'assets/images/drseal.jpg',
                        height: 42,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/seal.jpg',
                          height: 42,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox(height: 42),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 5. Action Buttons (Download PDF, Print, Share WhatsApp, Close)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => downloadInvoicePdf(context, invoice),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text('Download PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => printInvoice(context, invoice),
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Print', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => shareInvoicePdfOnWhatsApp(context, invoice),
                      icon: const Icon(Icons.share_rounded, size: 15),
                      label: const Text('Share PDF on WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        foregroundColor: const Color(0xFF475569),
                      ),
                      child: const Text('Close', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
