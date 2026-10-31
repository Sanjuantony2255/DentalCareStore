class Appointment {
  final String id;
  final String opNumber;
  final String patientName;
  final String phone;
  final String doctor;
  String date; // YYYY-MM-DD
  String timeSlot; // e.g. 10:30 AM
  final String reason;
  String status; // 'Upcoming', 'Completed', 'Cancelled'
  String notes;

  Appointment({
    required this.id,
    this.opNumber = '',
    required this.patientName,
    required this.phone,
    required this.doctor,
    required this.date,
    required this.timeSlot,
    this.reason = 'Regular Checkup & Consultation',
    this.status = 'Upcoming',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'opNumber': opNumber,
    'patientName': patientName,
    'phone': phone,
    'doctor': doctor,
    'date': date,
    'timeSlot': timeSlot,
    'reason': reason,
    'status': status,
    'notes': notes,
  };

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    id: json['id'] ?? '',
    opNumber: json['opNumber'] ?? '',
    patientName: json['patientName'] ?? '',
    phone: json['phone'] ?? '',
    doctor: json['doctor'] ?? 'Dr. Jeswin Jose BDS',
    date: json['date'] ?? '',
    timeSlot: json['timeSlot'] ?? '10:00 AM',
    reason: json['reason'] ?? 'Dental Consultation',
    status: json['status'] ?? 'Upcoming',
    notes: json['notes'] ?? '',
  );
}
