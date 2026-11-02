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
  final String address;
  final String opNumber;
  final double consultationCharge;
  final double xrayCharge;
  final double pharmacyCharge;
  final double treatmentCharge;
  final String treatment;
  final int treatmentNos;
  final double treatmentRate;
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
    this.address = '',
    this.opNumber = '',
    this.consultationCharge = 0.0,
    this.xrayCharge = 0.0,
    this.pharmacyCharge = 0.0,
    this.treatmentCharge = 0.0,
    this.treatment = '',
    this.treatmentNos = 1,
    this.treatmentRate = 0.0,
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
    'address': address,
    'opNumber': opNumber,
    'consultationCharge': consultationCharge,
    'xrayCharge': xrayCharge,
    'pharmacyCharge': pharmacyCharge,
    'treatmentCharge': treatmentCharge,
    'treatment': treatment,
    'treatmentNos': treatmentNos,
    'treatmentRate': treatmentRate > 0 ? treatmentRate : treatmentCharge,
    'customCharges': customCharges.map((c) => c.toJson()).toList(),
    'totalAmount': totalAmount,
    'paymentMode': paymentMode,
    'notes': notes,
  };

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final tCharge = (json['treatmentCharge'] as num?)?.toDouble() ?? 0.0;
    final tNos = (json['treatmentNos'] as num?)?.toInt() ?? 1;
    final tRate = (json['treatmentRate'] as num?)?.toDouble() ?? (tNos > 0 && tCharge > 0 ? (tCharge / tNos) : tCharge);

    return Invoice(
      id: json['id'] ?? '',
      patientName: json['patientName'] ?? '',
      phone: json['phone'] ?? '',
      doctor: json['doctor'] ?? 'Dr. Jeswin Jose BDS',
      date: json['date'] ?? '',
      address: json['address'] ?? '',
      opNumber: json['opNumber'] ?? '',
      consultationCharge: (json['consultationCharge'] as num?)?.toDouble() ?? 0.0,
      xrayCharge: (json['xrayCharge'] as num?)?.toDouble() ?? 0.0,
      pharmacyCharge: (json['pharmacyCharge'] as num?)?.toDouble() ?? 0.0,
      treatmentCharge: tCharge,
      treatment: json['treatment'] ?? '',
      treatmentNos: tNos,
      treatmentRate: tRate,
      customCharges: (json['customCharges'] as List<dynamic>?)
              ?.map((e) => CustomChargeItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: json['paymentMode'] ?? 'Cash',
      notes: json['notes'] ?? '',
    );
  }
}
