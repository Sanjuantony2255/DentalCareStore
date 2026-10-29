class CustomChargeItem {
  final String title;
  final double amount;

  CustomChargeItem({
    required this.title,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'amount': amount,
  };

  factory CustomChargeItem.fromJson(Map<String, dynamic> json) => CustomChargeItem(
    title: json['title'] ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
  );
}

class Invoice {
  final String id;
  final String patientName;
  final String phone;
  final String doctor;
  final String date; // YYYY-MM-DD
  final double consultationCharge;
  final double xrayCharge;
  final double pharmacyCharge;
  final double treatmentCharge;
  final String treatment;
  final List<CustomChargeItem> customCharges;
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
    this.treatmentCharge = 0.0,
    this.treatment = '',
    List<CustomChargeItem>? customCharges,
    required this.totalAmount,
    required this.paymentMode,
    this.notes = '',
  }) : customCharges = customCharges ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientName': patientName,
    'phone': phone,
    'doctor': doctor,
    'date': date,
    'consultationCharge': consultationCharge,
    'xrayCharge': xrayCharge,
    'pharmacyCharge': pharmacyCharge,
    'treatmentCharge': treatmentCharge,
    'treatment': treatment,
    'customCharges': customCharges.map((c) => c.toJson()).toList(),
    'totalAmount': totalAmount,
    'paymentMode': paymentMode,
    'notes': notes,
  };

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    id: json['id'] ?? '',
    patientName: json['patientName'] ?? '',
    phone: json['phone'] ?? '',
    doctor: json['doctor'] ?? 'Dr. Jeswin Jose BDS',
    date: json['date'] ?? '',
    consultationCharge: (json['consultationCharge'] as num?)?.toDouble() ?? 0.0,
    xrayCharge: (json['xrayCharge'] as num?)?.toDouble() ?? 0.0,
    pharmacyCharge: (json['pharmacyCharge'] as num?)?.toDouble() ?? 0.0,
    treatmentCharge: (json['treatmentCharge'] as num?)?.toDouble() ?? 0.0,
    treatment: json['treatment'] ?? '',
    customCharges: (json['customCharges'] as List<dynamic>?)
            ?.map((e) => CustomChargeItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
    paymentMode: json['paymentMode'] ?? 'Cash',
    notes: json['notes'] ?? '',
  );
}
