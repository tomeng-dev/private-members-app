import 'package:flutter/material.dart';
import 'members_table_page.dart';

class MembersPage extends StatelessWidget {
  const MembersPage({super.key, this.openId});
  final String? openId;
  @override
  Widget build(BuildContext context) => MembersTablePage(openId: openId);
}

class DuesPage extends StatelessWidget {
  const DuesPage({super.key});
  @override
  Widget build(BuildContext context) => const MembersTablePage(view: MembersView.dues);
}

class StaffRolesPage extends StatelessWidget {
  const StaffRolesPage({super.key});
  @override
  Widget build(BuildContext context) => const MembersTablePage(view: MembersView.staff);
}
