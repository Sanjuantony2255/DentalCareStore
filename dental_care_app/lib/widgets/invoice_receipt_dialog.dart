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

class InvoiceReceiptDialog extends StatelessWidget {
  final Invoice invoice;

  const InvoiceReceiptDialog({super.key, required this.invoice});

  /// Generates printable standalone HTML identical to the website invoice
  static String generatePrintableHtml(Invoice inv) {
    return '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Invoice - ${inv.id}</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; padding: 25px; color: #000; background: #fff; margin: 0; }
        .invoice-box { max-width: 680px; margin: auto; border: 2px solid #000; padding: 24px; border-radius: 6px; }
        .hospital-header { text-align: center; border-bottom: 2px solid #000; padding-bottom: 10px; margin-bottom: 14px; }
        .hospital-logo { max-height: 55px; max-width: 180px; display: block; margin: 0 auto 8px auto; object-fit: contain; }
        .hospital-seal { max-height: 65px; max-width: 130px; display: block; margin: 0 auto 6px auto; object-fit: contain; }
        .hospital-name { font-size: 20px; font-weight: 800; letter-spacing: 0.5px; text-transform: uppercase; margin: 0; color: #000; }
        .hospital-sub { font-size: 12px; font-weight: 600; color: #222; margin-top: 4px; }
        .hospital-contact { font-size: 11px; color: #444; margin-top: 3px; }
        .doc-header { display: flex; justify-content: space-between; border-bottom: 1.5px solid #000; padding-bottom: 8px; margin-bottom: 14px; }
        .title { font-size: 16px; font-weight: bold; color: #000; }
        .sub { font-size: 12px; color: #444; margin-top: 2px; }
        .meta { text-align: right; }
        .meta h2 { margin: 0; font-size: 15px; color: #000; font-weight: bold; }
        .meta p { margin: 2px 0; font-size: 12px; color: #222; }
        .patient { background: #fff; border: 1.5px solid #000; padding: 10px 14px; border-radius: 4px; margin-bottom: 16px; display: grid; grid-template-columns: 1fr 1fr; gap: 8px; font-size: 12px; }
        .patient div strong { color: #000; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 18px; border: 1px solid #000; }
        th { background: #f2f2f2; color: #000; padding: 8px 10px; text-align: left; font-size: 12px; font-weight: bold; border: 1px solid #000; }
        td { padding: 8px 10px; border: 1px solid #000; font-size: 12px; color: #000; }
        td.amt { text-align: right; font-weight: 600; }
        th.amt { text-align: right; }
        tr.total td { font-size: 14px; font-weight: bold; color: #000; border-top: 2px solid #000; border-bottom: 3px double #000; background: #fafafa; }
        .signatures { display: flex; justify-content: space-between; margin-top: 35px; margin-bottom: 15px; padding: 0 10px; }
        .sign-col { text-align: center; width: 220px; font-size: 11px; font-weight: bold; text-transform: uppercase; }
        .sign-line { height: 15px; border-bottom: 1.5px solid #000; margin-bottom: 4px; }
        .footer { text-align: center; font-size: 10.5px; color: #333; margin-top: 15px; border-top: 1px solid #000; padding-top: 8px; font-style: italic; }
        @media print {
            body { padding: 0; }
            .invoice-box { border: none; padding: 0; }
        }
    </style>
</head>
<body onload="window.print()">
    <div class="invoice-box">
        <div class="hospital-header">
            <img src="$kInvoiceLogoBase64" alt="Manjaly Multi Speciality Dental Care" class="hospital-logo">
            <h1 class="hospital-name">MANJALY MULTI SPECIALITY DENTAL CARE</h1>
            <div class="hospital-sub">Valakkavu, above MJ supermarket, Thrissur, Kerala 680751</div>
            <div class="hospital-contact">Phone: +91 9072467117, +91 6238497517 • Email: manjalymdc@gmail.com</div>
        </div>
        <div class="doc-header">
            <div>
                <div class="title">Clinical Patient Invoice</div>
                <div class="sub">Official Medical Consultation & Services Receipt</div>
            </div>
            <div class="meta">
                <h2>${inv.id}</h2>
                <p>Date: ${inv.date}</p>
                <p><strong>PAID (${inv.paymentMode})</strong></p>
            </div>
        </div>
        <div class="patient">
            <div><strong>Patient Name:</strong> ${inv.patientName}</div>
            <div><strong>Phone:</strong> ${inv.phone.isNotEmpty ? inv.phone : 'N/A'}</div>
            <div><strong>Doctor Consulted:</strong> ${inv.doctor}</div>
            <div><strong>Payment Mode:</strong> ${inv.paymentMode}</div>
            ${inv.treatment.isNotEmpty ? '<div style="grid-column: span 2;"><strong>Treatment Details:</strong> ${inv.treatment}</div>' : ''}
            ${inv.notes.isNotEmpty ? '<div style="grid-column: span 2;"><strong>Clinical Notes:</strong> ${inv.notes}</div>' : ''}
        </div>
        <table>
            <thead>
                <tr><th>#</th><th>Description</th><th class="amt">Amount</th></tr>
            </thead>
            <tbody>
                ${(() {
                  final rows = <String>[];
                  int rIdx = 1;
                  if (inv.consultationCharge > 0 || (inv.treatmentCharge == 0 && inv.xrayCharge == 0 && inv.pharmacyCharge == 0 && inv.customCharges.isEmpty)) {
                    rows.add('<tr><td>${rIdx++}</td><td>Doctor Consultation Charge</td><td class="amt">₹${inv.consultationCharge.toStringAsFixed(2)}</td></tr>');
                  }
                  if (inv.treatmentCharge > 0) {
                    rows.add('<tr><td>${rIdx++}</td><td>Dental Treatment: ${inv.treatment.isNotEmpty ? inv.treatment : "Procedure"}</td><td class="amt">₹${inv.treatmentCharge.toStringAsFixed(2)}</td></tr>');
                  }
                  if (inv.xrayCharge > 0) {
                    rows.add('<tr><td>${rIdx++}</td><td>X-Ray Examination Charge</td><td class="amt">₹${inv.xrayCharge.toStringAsFixed(2)}</td></tr>');
                  }
                  if (inv.pharmacyCharge > 0) {
                    rows.add('<tr><td>${rIdx++}</td><td>Pharmacy / Medicines Charge</td><td class="amt">₹${inv.pharmacyCharge.toStringAsFixed(2)}</td></tr>');
                  }
                  for (final c in inv.customCharges) {
                    rows.add('<tr><td>${rIdx++}</td><td>${c.title}</td><td class="amt">₹${c.amount.toStringAsFixed(2)}</td></tr>');
                  }
                  rows.add('<tr class="total"><td colspan="2" style="text-align:right;">Total Amount:</td><td class="amt">₹${inv.totalAmount.toStringAsFixed(2)}</td></tr>');
                  return rows.join('');
                })()}
            </tbody>
        </table>
        <div class="signatures">
            <div class="sign-col">
                <div style="display: flex; justify-content: center; align-items: flex-end; gap: 8px; margin-bottom: 6px;">
                    <img src="$kInvoiceSignBase64" alt="Doctor Signature" class="hospital-seal" style="max-height: 52px; max-width: 95px; object-fit: contain;">
                    <img src="$kInvoiceDrSealBase64" alt="Doctor Seal" class="hospital-seal" style="max-height: 52px; max-width: 80px; object-fit: contain;">
                </div>
                <div class="sign-line"></div>
                Doctor's Seal & Signature
            </div>
            <div class="sign-col">
                <div style="display: flex; justify-content: center; align-items: flex-end; margin-bottom: 6px;">
                    <img src="$kInvoiceHospitalSealBase64" alt="Authorized Hospital Seal" class="hospital-seal" style="max-height: 58px; max-width: 125px; object-fit: contain;">
                </div>
                <div class="sign-line"></div>
                Authorized Hospital Seal
            </div>
        </div>
        <div class="footer">* Computer generated clinical invoice issued by Manjaly Multi Speciality Dental Care. Valid for all official and claim purposes.</div>
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

  /// Generates crisp vector PDF bytes of the official invoice
  static Future<Uint8List> generateInvoicePdfBytes(Invoice inv) async {
    final pdf = pw.Document();

    final logoImg = _safeMemoryImage(kInvoiceLogoBase64);
    final signImg = _safeMemoryImage(kInvoiceSignBase64);
    final drSealImg = _safeMemoryImage(kInvoiceDrSealBase64);
    final hospSealImg = _safeMemoryImage(kInvoiceHospitalSealBase64);

    final isPaid = !inv.paymentMode.toLowerCase().contains('pending');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                if (logoImg != null)
                  pw.Center(
                    child: pw.Container(
                      height: 50,
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Image(logoImg, fit: pw.BoxFit.contain),
                    ),
                  ),
                pw.Center(
                  child: pw.Text(
                    'MANJALY MULTI SPECIALITY DENTAL CARE',
                    style: const pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Center(
                  child: pw.Text(
                    'Valakkavu, above MJ supermarket, Thrissur, Kerala 680751',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'Phone: +91 9072467117, +91 6238497517  |  Email: manjalymdc@gmail.com',
                    style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColors.black, thickness: 1.2),
                pw.SizedBox(height: 6),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CLINICAL PATIENT INVOICE',
                          style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Official Medical Consultation & Services Receipt',
                          style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          inv.id,
                          style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Date: ${inv.date}',
                          style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: isPaid ? PdfColors.teal50 : PdfColors.amber50,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                            border: pw.Border.all(
                              color: isPaid ? PdfColors.teal : PdfColors.amber,
                              width: 0.8,
                            ),
                          ),
                          child: pw.Text(
                            isPaid ? 'PAID (${inv.paymentMode})' : 'PAYMENT PENDING',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: isPaid ? PdfColors.teal900 : PdfColors.amber900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),

                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  const pw.TextSpan(
                                    text: 'Patient Name: ',
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.TextSpan(
                                    text: inv.patientName,
                                    style: const pw.TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  const pw.TextSpan(
                                    text: 'Phone: ',
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.TextSpan(
                                    text: inv.phone.isNotEmpty ? inv.phone : 'N/A',
                                    style: const pw.TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  const pw.TextSpan(
                                    text: 'Attending Doctor: ',
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.TextSpan(
                                    text: inv.doctor,
                                    style: const pw.TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  const pw.TextSpan(
                                    text: 'Payment Mode: ',
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.TextSpan(
                                    text: inv.paymentMode,
                                    style: const pw.TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (inv.treatment.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                const pw.TextSpan(
                                  text: 'Treatment Details: ',
                                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                ),
                                pw.TextSpan(
                                  text: inv.treatment,
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (inv.notes.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                const pw.TextSpan(
                                  text: 'Clinical Notes: ',
                                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                ),
                                pw.TextSpan(
                                  text: inv.notes,
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('#', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Description', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text('Amount (INR)', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    ...(() {
                      final rows = <pw.TableRow>[];
                      int idx = 1;
                      if (inv.consultationCharge > 0 || (inv.treatmentCharge == 0 && inv.xrayCharge == 0 && inv.pharmacyCharge == 0 && inv.customCharges.isEmpty)) {
                        rows.add(
                          pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${idx++}', style: const pw.TextStyle(fontSize: 9.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Doctor Consultation Charge', style: const pw.TextStyle(fontSize: 9.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Rs. ${inv.consultationCharge.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9.5)))),
                            ],
                          ),
                        );
                      }
                      if (inv.treatmentCharge > 0) {
                        rows.add(
                          pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${idx++}', style: const pw.TextStyle(fontSize: 9.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Dental Treatment: ${inv.treatment.isNotEmpty ? inv.treatment : "Procedure"}', style: const pw.TextStyle(fontSize: 9.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Rs. ${inv.treatmentCharge.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9.5)))),
                            ],
                          ),
                        );
                      }
                      if (inv.xrayCharge > 0) {
                        rows.add(
                          pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${idx++}', style: const pw.TextStyle(fontSize: 9.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('X-Ray Examination Charge', style: const pw.TextStyle(fontSize: 9.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Rs. ${inv.xrayCharge.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9.5)))),
                            ],
                          ),
                        );
                      }
                      if (inv.pharmacyCharge > 0) {
                        rows.add(
                          pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${idx++}', style: const pw.TextStyle(fontSize: 9.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Pharmacy / Medicines Charge', style: const pw.TextStyle(fontSize: 9.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Rs. ${inv.pharmacyCharge.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9.5)))),
                            ],
                          ),
                        );
                      }
                      for (final c in inv.customCharges) {
                        rows.add(
                          pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${idx++}', style: const pw.TextStyle(fontSize: 9.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(c.title, style: const pw.TextStyle(fontSize: 9.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Rs. ${c.amount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9.5)))),
                            ],
                          ),
                        );
                      }
                      return rows;
                    })(),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text('Total Amount:', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text('Rs. ${inv.totalAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 24),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            if (signImg != null)
                              pw.Container(
                                height: 42,
                                width: 75,
                                child: pw.Image(signImg, fit: pw.BoxFit.contain),
                              ),
                            if (drSealImg != null) ...[
                              pw.SizedBox(width: 6),
                              pw.Container(
                                height: 42,
                                width: 65,
                                child: pw.Image(drSealImg, fit: pw.BoxFit.contain),
                              ),
                            ],
                          ],
                        ),
                        pw.Container(width: 150, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          "Doctor's Seal & Signature",
                          style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (hospSealImg != null)
                          pw.Container(
                            height: 44,
                            width: 100,
                            child: pw.Image(hospSealImg, fit: pw.BoxFit.contain),
                          )
                        else
                          pw.SizedBox(height: 44),
                        pw.Container(width: 150, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Authorized Hospital Seal',
                          style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),

                pw.Divider(color: PdfColors.grey400, thickness: 0.8),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    '* Computer generated clinical invoice issued by Manjaly Multi Speciality Dental Care. Valid for all official and claim purposes.',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                  ),
                ),
              ],
            ),
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

      // 1. Save to temporary app directory so it's always cached and valid
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(pdfBytes, flush: true);

      // 2. Try writing directly to standard Android Downloads directory if permissions allow
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

      // 3. Open native system print/save dialog (which defaults to 'Save as PDF' on Android)
      // This allows the user to download and save the PDF directly to Downloads or Google Drive
      // without failing due to Android Scoped Storage!
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
      // Fallback: If printing plugin encounters any platform issue, share with share_plus
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

      final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
      final breakdownList = <String>[];
      if (inv.consultationCharge > 0) breakdownList.add('• Consultation Fee: ${currency.format(inv.consultationCharge)}');
      if (inv.treatmentCharge > 0) breakdownList.add('• Treatment (${inv.treatment.isNotEmpty ? inv.treatment : "Procedure"}): ${currency.format(inv.treatmentCharge)}');
      if (inv.xrayCharge > 0) breakdownList.add('• X-Ray / Radiology: ${currency.format(inv.xrayCharge)}');
      if (inv.pharmacyCharge > 0) breakdownList.add('• Pharmacy / Medicines: ${currency.format(inv.pharmacyCharge)}');
      for (final c in inv.customCharges) {
        breakdownList.add('• ${c.title}: ${currency.format(c.amount)}');
      }
      if (breakdownList.isEmpty) breakdownList.add('• Consultation Fee: ${currency.format(inv.totalAmount)}');

      final text = '''
🏥 *MANJALY MULTI SPECIALITY DENTAL CARE*
📍 Valakkavu, Thrissur, Kerala 680751
📞 Phone: +91 9072467117, +91 6238497517 | ✉️ manjalymdc@gmail.com
━━━━━━━━━━━━━━━━━━━━━━━━
🧾 *OFFICIAL PATIENT INVOICE & RECEIPT (PDF ATTACHED)*
━━━━━━━━━━━━━━━━━━━━━━━━
*Invoice No:* ${inv.id}
*Date:* ${inv.date}
*Patient Name:* ${inv.patientName}
*Attending Doctor:* ${inv.doctor}
${inv.treatment.isNotEmpty ? '*Treatment Details:* ${inv.treatment}\n' : ''}*CHARGES BREAKDOWN:*
${breakdownList.join('\n')}
────────────────────────
*Total Billed:* ${currency.format(inv.totalAmount)} (${inv.paymentMode})
━━━━━━━━━━━━━━━━━━━━━━━━
Please find attached your official PDF invoice.
Thank you for choosing Manjaly Dental Care!
''';

      await Share.shareXFiles(
        [XFile(tempFile.path, mimeType: 'application/pdf', name: filename)],
        text: text,
        subject: 'PDF Invoice ${inv.id} - Manjaly Dental Care',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF: $e')),
        );
      }
    }
  }

  /// Prints the invoice using system printer
  static Future<void> printInvoice(BuildContext context, Invoice inv) async {
    try {
      final pdfBytes = await generateInvoicePdfBytes(inv);
      await Printing.layoutPdf(
        name: 'Invoice_${inv.id}',
        onLayout: (PdfPageFormat format) async => pdfBytes,
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
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hospital Header with Logo
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySubtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.local_hospital_rounded, color: AppTheme.primaryTeal, size: 28),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'MANJALY MULTI SPECIALITY DENTAL CARE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Valakkavu, above MJ supermarket, Thrissur, Kerala 680751',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Phone: +91 9072467117, +91 6238497517 • Email: manjalymdc@gmail.com',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF0F172A), thickness: 1.5),
              const SizedBox(height: 8),

              // 2. Document Title & Invoice Meta
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clinical Patient Invoice',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Official Consultation & Services Receipt',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        invoice.id,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Date: ${invoice.date}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PAID (${invoice.paymentMode.toUpperCase()})',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Patient Details Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                ),
                child: Column(
                  children: [
                    _infoRow('Patient Name:', invoice.patientName, isBold: true),
                    const SizedBox(height: 5),
                    _infoRow('Phone Number:', invoice.phone.isNotEmpty ? invoice.phone : 'N/A'),
                    const SizedBox(height: 5),
                    _infoRow('Doctor Consulted:', invoice.doctor),
                    const SizedBox(height: 5),
                    _infoRow('Payment Mode:', invoice.paymentMode),
                    if (invoice.treatment.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _infoRow('Treatment / Procedure:', invoice.treatment, isBold: true),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Charges Table
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      color: const Color(0xFFF1F5F9),
                      child: const Row(
                        children: [
                          SizedBox(width: 24, child: Text('#', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          Expanded(child: Text('Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          Text('Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFCBD5E1)),
                    ...(() {
                      final widgets = <Widget>[];
                      int idx = 1;
                      if (invoice.consultationCharge > 0 || (invoice.treatmentCharge == 0 && invoice.xrayCharge == 0 && invoice.pharmacyCharge == 0 && invoice.customCharges.isEmpty)) {
                        widgets.add(_tableRow('${idx++}', 'Doctor Consultation Charge', currency.format(invoice.consultationCharge)));
                      }
                      if (invoice.treatmentCharge > 0) {
                        if (widgets.isNotEmpty) widgets.add(const Divider(height: 1, color: Color(0xFFE2E8F0)));
                        widgets.add(_tableRow('${idx++}', 'Dental Treatment: ${invoice.treatment.isNotEmpty ? invoice.treatment : "Procedure"}', currency.format(invoice.treatmentCharge)));
                      }
                      if (invoice.xrayCharge > 0) {
                        if (widgets.isNotEmpty) widgets.add(const Divider(height: 1, color: Color(0xFFE2E8F0)));
                        widgets.add(_tableRow('${idx++}', 'X-Ray Examination Charge', currency.format(invoice.xrayCharge)));
                      }
                      if (invoice.pharmacyCharge > 0) {
                        if (widgets.isNotEmpty) widgets.add(const Divider(height: 1, color: Color(0xFFE2E8F0)));
                        widgets.add(_tableRow('${idx++}', 'Pharmacy / Medicines Charge', currency.format(invoice.pharmacyCharge)));
                      }
                      for (final c in invoice.customCharges) {
                        if (widgets.isNotEmpty) widgets.add(const Divider(height: 1, color: Color(0xFFE2E8F0)));
                        widgets.add(_tableRow('${idx++}', c.title, currency.format(c.amount)));
                      }
                      return widgets;
                    })(),
                    const Divider(height: 1, color: Color(0xFFCBD5E1), thickness: 1.5),
                    // Total Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      color: const Color(0xFFF8FAFC),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount Due:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            currency.format(invoice.totalAmount),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (invoice.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notes, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Notes: ${invoice.notes}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 5. Doctor Seal & Sign (Left) and Authorized Hospital Seal (Right)
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Image.asset(
                            'assets/images/sign.jpg',
                            height: 44,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.draw, color: AppTheme.primaryTeal, size: 30),
                          ),
                          const SizedBox(width: 6),
                          Image.asset(
                            'assets/images/seal.jpg',
                            height: 44,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.verified, color: AppTheme.primaryTeal, size: 30),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(width: 150, height: 1, color: const Color(0xFF0F172A)),
                      const SizedBox(height: 3),
                      const Text(
                        "Doctor's Seal & Signature",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Image.asset(
                        'assets/images/hospital_seal.jpg',
                        height: 46,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.local_hospital_rounded, color: AppTheme.primaryTeal, size: 30),
                      ),
                      const SizedBox(height: 4),
                      Container(width: 140, height: 1, color: const Color(0xFF0F172A)),
                      const SizedBox(height: 3),
                      const Text(
                        'Authorized Hospital Seal',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 6. Footer Note
              const Text(
                '* Computer generated clinical invoice issued by Manjaly Multi Speciality Dental Care. Valid for all official and claim purposes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 18),

              // 7. Action Buttons (PDF Download, Print, WhatsApp PDF Share, Close)
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

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableRow(String no, String item, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text(no, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
          Expanded(child: Text(item, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
          Text(amount, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
