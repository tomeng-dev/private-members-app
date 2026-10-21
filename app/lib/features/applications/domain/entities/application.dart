class MemberApplication {
  MemberApplication({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.vehicleEstimatedValue,
    this.moreInfoMessage,
    this.declineReason,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String status;
  final String vehicleMake;
  final String vehicleModel;
  final int vehicleYear;
  final int vehicleEstimatedValue;
  final String? moreInfoMessage;
  final String? declineReason;

  factory MemberApplication.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'] as Map<String, dynamic>? ?? {};
    return MemberApplication(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      status: json['status'] as String,
      vehicleMake: vehicle['make'] as String? ?? '',
      vehicleModel: vehicle['model'] as String? ?? '',
      vehicleYear: vehicle['year'] as int? ?? 0,
      vehicleEstimatedValue: vehicle['estimatedValue'] as int? ?? 0,
      moreInfoMessage: json['moreInfoMessage'] as String?,
      declineReason: json['declineReason'] as String?,
    );
  }
}
