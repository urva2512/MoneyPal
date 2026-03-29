import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import '../groups/my_groups_screen.dart';
import '../../theme/app_colors.dart';

class AuthWrapper extends StatelessWidget {
  AuthWrapper({super.key});

  final auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: auth.authState,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.green)),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const MyGroupsScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
