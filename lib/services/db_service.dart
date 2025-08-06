import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  static const _databaseName = "SignLanguage.db";
  static const _databaseVersion = 1;

  // Table names
  static const tableAlphabets = 'alphabets';
  static const tableNumbers = 'numbers';
  static const tableWords = 'words';

  // Column names
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnPoseJson = 'pose_json_gz';
  static const columnHandJson = 'hand_json_gz';

  // Make this a singleton class.
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  // Only have a single app-wide reference to the database.
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Open the database and create it if it doesn't exist.
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  // SQL code to create the database tables.
  Future _onCreate(Database db, int version) async {
    const textType = 'TEXT NOT NULL';
    const blobType = 'BLOB NOT NULL'; // Compressed data is binary

    // Alphabets Table
    await db.execute('''
          CREATE TABLE $tableAlphabets (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnName $textType,
            $columnPoseJson $blobType,
            $columnHandJson $blobType
          )
          ''');

    // Numbers Table
    await db.execute('''
          CREATE TABLE $tableNumbers (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnName $textType,
            $columnPoseJson $blobType,
            $columnHandJson $blobType
          )
          ''');

    // Words Table
    await db.execute('''
          CREATE TABLE $tableWords (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnName $textType,
            $columnPoseJson $blobType,
            $columnHandJson $blobType
          )
          ''');
  }

  // --- Data Insertion with Gzip Compression ---

  Future<int> insertSign({
    required String tableName,
    required String name,
    required String poseJson,
    required String handJson,
  }) async {
    Database db = await instance.database;

    // 1. Compress the JSON strings using Gzip
    final GZipCodec gzip = GZipCodec();
    final compressedPose = gzip.encode(utf8.encode(poseJson));
    final compressedHand = gzip.encode(utf8.encode(handJson));

    Map<String, dynamic> row = {
      columnName: name,
      columnPoseJson: compressedPose,
      columnHandJson: compressedHand,
    };

    return await db.insert(tableName, row);
  }

  // --- Data Retrieval with Gzip Decompression ---

  Future<Map<String, String>?> getSign(String tableName, String name) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: '$columnName = ?',
      whereArgs: [name],
    );

    if (maps.isNotEmpty) {
      final row = maps.first;

      // 1. Get the compressed BLOB data
      final compressedPose = row[columnPoseJson] as List<int>;
      final compressedHand = row[columnHandJson] as List<int>;

      // 2. Decompress the data using Gzip
      final GZipCodec gzip = GZipCodec();
      final poseJson = utf8.decode(gzip.decode(compressedPose));
      final handJson = utf8.decode(gzip.decode(compressedHand));

      return {'pose_json': poseJson, 'hand_json': handJson};
    }
    return null;
  }

  // Helper to check if a table is empty, used for seeding
  Future<bool> isTableEmpty(String tableName) async {
    Database db = await instance.database;
    var count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableName'),
    );
    return count == 0;
  }

  Future<String> getDatabasePath() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, _databaseName);
  }

  Future<int> getDatabaseSize() async {
    final path = await getDatabasePath();
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// Formats a byte value into a human-readable string (B, KB, MB, GB, etc.).
  static String formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}
