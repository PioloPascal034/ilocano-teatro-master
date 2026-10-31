
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  runApp(const TeatroApp());
}

class TeatroApp extends StatelessWidget {
  const TeatroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ilocano Teatro Master',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Ilocano Teatro Master'),
        ),
        body: const Center(
          child: Text(
            'Flutter and Supabase initialized!',
          ),
        ),
      ),
    );
  }
}
