import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gemma_sign_ai/services/alphabet_seeder.dart';
import 'package:gemma_sign_ai/services/number_seeder.dart';
import 'package:gemma_sign_ai/services/word_seeder.dart';
import 'package:gemma_sign_ai/views/home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // --- IMPORTANT ---
  // To populate the database for the first time, follow these steps:
  // 1. Download and place the 'signs' asset folder as instructed in the README.
  // 2. Uncomment the asset paths in 'pubspec.yaml'.
  // 3. Uncomment the line below to enable the one-time seeding.
  // 4. Run the app once and wait for seeding to complete (monitor debug console).

  // await databaseSeeding();

  runApp(HomeView());
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: const InterpreterScreen()),
    );
  }
}

// A single function to run all the seeding operations.
Future<void> databaseSeeding() async {
  await AlphabetSeeder.seedAlphabets();
  await NumberSeeder.seedNumbers();
  await WordSeeder.seedWords();
}
