import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:gemma_sign_ai/services/db_service.dart';

class WordSeeder {
  static Future<void> seedWords() async {
    final dbService = DatabaseService.instance;

    if (!await dbService.isTableEmpty(DatabaseService.tableWords)) {
      print("INFO: Words table is already seeded. Skipping.");
      return;
    }

    print("INFO: Seeding 'words' table... This may take a moment.");

    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    final poseAssetPaths = manifestMap.keys.where(
      (path) => path.startsWith('assets/signs/words/pose/'),
    );

    int successCount = 0;
    int totalWords = poseAssetPaths.length;

    for (final posePath in poseAssetPaths) {
      try {
        final filename = posePath.split('/').last;
        final word = filename.replaceAll('.json', '');

        final handPath = 'assets/signs/words/hand/$word.json';

        final poseJson = await rootBundle.loadString(posePath);
        final handJson = await rootBundle.loadString(handPath);

        await dbService.insertSign(
          tableName: DatabaseService.tableWords,
          name: word,
          poseJson: poseJson,
          handJson: handJson,
        );

        print(" -> Successfully seeded word: $word");
        successCount++;
      } catch (e) {
        print("ERROR: Failed to seed from path '$posePath'. Reason: $e");
      }
    }

    print("--------------------------------------------------");
    print(
      "INFO: Word seeding complete. $successCount/$totalWords words seeded.",
    );
    print("--------------------------------------------------");
  }
}
