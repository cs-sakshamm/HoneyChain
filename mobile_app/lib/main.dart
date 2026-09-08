import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'features/authentication/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ChangeNotifierProvider<AuthController>(
      create: (_) => AuthController(),
      child: const HoneyChainApp(),
    ),
  );
}


