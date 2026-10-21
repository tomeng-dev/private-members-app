class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roles,
    required this.foundingMember,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final List<String> roles;
  final bool foundingMember;
}
