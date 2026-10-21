class MemberProfile {
  MemberProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.company,
    this.title,
    this.city,
    this.state,
    this.bio,
    this.foundingMember = false,
    this.showEmail = false,
    this.showPhone = false,
    this.vehicles = const [],
    this.businessPage,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? company;
  final String? title;
  final String? city;
  final String? state;
  final String? bio;
  final bool foundingMember;
  final bool showEmail;
  final bool showPhone;
  final List<VehicleItem> vehicles;
  final BusinessPageItem? businessPage;

  factory MemberProfile.fromJson(Map<String, dynamic> json) {
    return MemberProfile(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      company: json['company'] as String?,
      title: json['title'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      bio: json['bio'] as String?,
      foundingMember: json['foundingMember'] as bool? ?? false,
      showEmail: json['showEmail'] as bool? ?? false,
      showPhone: json['showPhone'] as bool? ?? false,
      vehicles: ((json['vehicles'] as List?) ?? []).map((e) => VehicleItem.fromJson(e as Map<String, dynamic>)).toList(),
      businessPage: json['businessPage'] is Map ? BusinessPageItem.fromJson(json['businessPage'] as Map<String, dynamic>) : null,
    );
  }
}

class VehicleItem {
  VehicleItem({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    this.color,
    this.plateNumber,
    this.blurPlate = true,
    this.isPrimary = false,
  });
  final String id;
  final String make;
  final String model;
  final int year;
  final String? color;
  final String? plateNumber;
  final bool blurPlate;
  final bool isPrimary;

  factory VehicleItem.fromJson(Map<String, dynamic> json) => VehicleItem(
    id: json['id'] as String,
    make: json['make'] as String? ?? '',
    model: json['model'] as String? ?? '',
    year: json['year'] as int? ?? 0,
    color: json['color'] as String?,
    plateNumber: json['plateNumber'] as String?,
    blurPlate: json['blurPlate'] as bool? ?? true,
    isPrimary: json['isPrimary'] as bool? ?? false,
  );
}

class BusinessPageItem {
  BusinessPageItem({required this.id, required this.companyName, this.services, this.background, this.website, this.contactEmail});
  final String id;
  final String companyName;
  final String? services;
  final String? background;
  final String? website;
  final String? contactEmail;

  factory BusinessPageItem.fromJson(Map<String, dynamic> json) => BusinessPageItem(
    id: json['id'] as String,
    companyName: json['companyName'] as String? ?? '',
    services: json['services'] as String?,
    background: json['background'] as String?,
    website: json['website'] as String?,
    contactEmail: json['contactEmail'] as String?,
  );
}

class MemberListItem {
  MemberListItem({required this.id, required this.firstName, required this.lastName, this.company, this.title, this.city, this.foundingMember = false});
  final String id;
  final String firstName;
  final String lastName;
  final String? company;
  final String? title;
  final String? city;
  final bool foundingMember;

  factory MemberListItem.fromJson(Map<String, dynamic> json) => MemberListItem(
    id: json['id'] as String,
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    company: json['company'] as String?,
    title: json['title'] as String?,
    city: json['city'] as String?,
    foundingMember: json['foundingMember'] as bool? ?? false,
  );
}
