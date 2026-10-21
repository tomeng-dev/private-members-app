import 'package:flutter_test/flutter_test.dart';
import 'package:member_app/features/profiles/domain/entities/member_profile.dart';

void main() {
  test('MemberProfile.fromJson maps vehicles and privacy', () {
    final p = MemberProfile.fromJson({
      'id': '1',
      'firstName': 'A',
      'lastName': 'B',
      'showEmail': false,
      'vehicles': [
        {'id': 'v1', 'make': 'Ferrari', 'model': 'F8', 'year': 2021, 'blurPlate': true},
      ],
      'businessPage': {'id': 'b1', 'companyName': 'ACME'},
    });
    expect(p.vehicles.single.make, 'Ferrari');
    expect(p.businessPage!.companyName, 'ACME');
    expect(p.showEmail, false);
  });
}
