
class VisitRecord {
  final String date;
  final String doctor;
  final String notes;
  final String invoiceId;
  final double amount;

  VisitRecord({
    required this.date,
    required this.doctor,
    required this.notes,
    required this.invoiceId,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'doctor': doctor,
    'notes': notes,
    'invoiceId': invoiceId,
    'amount': amount,
  };

  factory VisitRecord.fromJson(Map<String, dynamic> json) => VisitRecord(
    date: json['date'] ?? '',
    doctor: json['doctor'] ?? '',
    notes: json['notes'] ?? '',
    invoiceId: json['invoiceId'] ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
  );
}

class Patient {
  final String id;
  final String opNumber;
  final String name;
  final String phone;
  final String email;
  final String dob;
  final int age;
  final String gender;
  final String address;
  final String doctor;
  final String medicalHistory;
  final String drugAllergies;
  final String diseaseHistory;
  final String registrationDate;
  int totalVisits;
  double totalBilled;
  List<VisitRecord> visits;

  Patient({
    required this.id,
    required this.opNumber,
    required this.name,
    required this.phone,
    this.email = '',
    this.dob = '',
    this.age = 0,
    required this.gender,
    this.address = '',
    required this.doctor,
    this.medicalHistory = 'None',
    this.drugAllergies = 'None',
    this.diseaseHistory = 'None',
    required this.registrationDate,
    this.totalVisits = 1,
    this.totalBilled = 0.0,
    List<VisitRecord>? visits,
  }) : visits = visits ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'opNumber': opNumber,
    'name': name,
    'phone': phone,
    'email': email,
    'dob': dob,
    'age': age,
    'gender': gender,
    'address': address,
    'doctor': doctor,
    'medicalHistory': medicalHistory,
    'drugAllergies': drugAllergies,
    'diseaseHistory': diseaseHistory,
    'registrationDate': registrationDate,
    'totalVisits': totalVisits,
    'totalBilled': totalBilled,
    'visits': visits.map((v) => v.toJson()).toList(),
  };

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
    id: json['id'] ?? '',
    opNumber: json['opNumber'] ?? '',
    name: json['name'] ?? '',
    phone: json['phone'] ?? '',
    email: json['email'] ?? '',
    dob: json['dob'] ?? '',
    age: (json['age'] as num?)?.toInt() ?? 0,
    gender: json['gender'] ?? 'Not Specified',
    address: json['address'] ?? '',
    doctor: json['doctor'] ?? 'Dr. Sanju Antony',
    medicalHistory: json['medicalHistory'] ?? 'None',
    drugAllergies: json['drugAllergies'] ?? 'None',
    diseaseHistory: json['diseaseHistory'] ?? 'None',
    registrationDate: json['registrationDate'] ?? '',
    totalVisits: (json['totalVisits'] as num?)?.toInt() ?? 1,
    totalBilled: (json['totalBilled'] as num?)?.toDouble() ?? 0.0,
    visits: (json['visits'] as List<dynamic>?)
            ?.map((e) => VisitRecord.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}
