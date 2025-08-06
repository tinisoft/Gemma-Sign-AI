import 'package:flutter/services.dart';
import 'package:gemma_sign_ai/services/db_service.dart';

class NumberSeeder {
  static Future<void> seedNumbers() async {
    final dbService = DatabaseService.instance;

    if (!await dbService.isTableEmpty(DatabaseService.tableNumbers)) {
      print("INFO: Numbers table is already seeded. Skipping.");
      return;
    }

    print("INFO: Seeding 'numbers' table from 0 to 30...");

    final List<int> numbersToSeed = List.generate(31, (index) => index);

    int successCount = 0;

    for (final int number in numbersToSeed) {
      final String numberString = number.toString();
      try {
        final poseJsonPath =
            'assets/signs/numbers/pose/${numberString}_pose_landmarks.json';
        final handJsonPath =
            'assets/signs/numbers/hand/${numberString}_landmarks.json';

        final poseJson = await rootBundle.loadString(poseJsonPath);
        final handJson = await rootBundle.loadString(handJsonPath);

        await dbService.insertSign(
          tableName: DatabaseService.tableNumbers,
          name: numberString,
          poseJson: poseJson,
          handJson: handJson,
        );

        print(" -> Successfully seeded number: $numberString");
        successCount++;
      } catch (e) {
        print("ERROR: Failed to seed number '$numberString'. Reason: $e");
      }
    }

    print("--------------------------------------------------");
    print(
      "INFO: Number seeding complete. $successCount/${numbersToSeed.length} numbers seeded.",
    );
    print("--------------------------------------------------");
  }
}
