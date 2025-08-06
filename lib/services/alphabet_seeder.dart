import 'package:flutter/services.dart';
import 'package:gemma_sign_ai/services/db_service.dart';

class AlphabetSeeder {
  static Future<void> seedAlphabets() async {
    final dbService = DatabaseService.instance;

    if (!await dbService.isTableEmpty(DatabaseService.tableAlphabets)) {
      print("INFO: Alphabet table is already seeded. Skipping.");
      return;
    }

    print("INFO: Seeding 'alphabets' table...");

    const List<String> alphabets = [
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
      'I',
      'J',
      'K',
      'L',
      'M',
      'N',
      'O',
      'P',
      'Q',
      'R',
      'S',
      'T',
      'U',
      'V',
      'W',
      'X',
      'Y',
      'Z',
    ];

    int successCount = 0;

    for (final String letter in alphabets) {
      try {
        final poseJsonPath =
            'assets/signs/alphabets/pose/${letter}_pose_landmarks.json';
        final handJsonPath =
            'assets/signs/alphabets/hand/${letter}_landmarks.json';

        final poseJson = await rootBundle.loadString(poseJsonPath);
        final handJson = await rootBundle.loadString(handJsonPath);

        await dbService.insertSign(
          tableName: DatabaseService.tableAlphabets,
          name: letter,
          poseJson: poseJson,
          handJson: handJson,
        );

        print(" -> Successfully seeded: $letter");
        successCount++;
      } catch (e) {
        print("ERROR: Failed to seed letter '$letter'. Reason: $e");
      }
    }

    print("--------------------------------------------------");
    print(
      "INFO: Alphabet seeding complete. $successCount/${alphabets.length} letters seeded.",
    );
    print("--------------------------------------------------");
  }
}
