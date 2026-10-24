class Invoice {
  final String id;
  final String patientName;
  final String phone;
  final String doctor;
  final String date; // YYYY-MM-DD
  final double consultationCharge;
  final double xrayCharge;
  final double pharmacyCharge;
  final double totalAmount;
  final String paymentMode; // 'Cash', 'UPI / Online', 'Card', 'Pending'
  final String notes;

  Invoice({
    required this.id,
    required this.patientName,
    required this.phone,
    required this.doctor,
    required this.date,
    this.consultationCharge = 0.0,
    this.xrayCharge = 0.0,
    this.pharmacyCharge = 0.0,
    required this.totalAmount,
    required this.paymentMode,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientName': patientName,
    'phone': phone,
    'doctor': doctor,
    'date': date,
    'consultationCharge': consultationCharge,
    'xrayCharge': xrayCharge,
    'pharmacyCharge': pharmacyCharge,
    'totalAmount': totalAmount,
    'paymentMode': paymentMode,
    'notes': notes,
  };

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    id: json['id'] ?? '',
    patientName: json['patientName'] ?? '',
    phone: json['phone'] ?? '',
    doctor: json['doctor'] ?? 'Dr. Sanju Antony',
    date: json['date'] ?? '',
    consultationCharge: (json['consultationCharge'] as num?)?.toDouble() ?? 0.0,
    xrayCharge: (json['xrayCharge'] as num?)?.toDouble() ?? 0.0,
    pharmacyCharge: (json['pharmacyCharge'] as num?)?.toDouble() ?? 0.0,
    totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
    paymentMode: json['paymentMode'] ?? 'Cash',
    notes: json['notes'] ?? '',
  );
}
