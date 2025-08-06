import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gemma_sign_ai/models/asl_response.dart';
import 'package:http/http.dart' as http;

class AiModelService {
  static const bool _useMockApi = false;

  String baseUrl = dotenv.env['BASE_URL'] ?? "";

  String get _apiUrl => "$baseUrl/transcribe";

  final String _apiPrompt =
      "Please transcribe this audio and concat with it's ASL gloss with <ASL> </ASL> tag";

  final List<Map<String, String>> _mockResponses = [
    {
      "description": "Hello, how are you today?",
      "asl_gloss": "HELLO HOW YOU TODAY",
    },
    {
      "description": "I need to buy 5 apples and 10 oranges.",
      "asl_gloss": "I NEED BUY 5 APPLE 10 ORANGE", // Tests numbers
    },
    {
      "description": "My name is Bob.",
      "asl_gloss": "MY NAME B O B", // Tests fingerspelled letters
    },
    {
      "description": "The meeting is at 3 P M.",
      "asl_gloss": "MEETING 3 P M", // Tests mix of number and letters
    },
    {
      "description": "What is the W I F I password?",
      "asl_gloss": "WHAT W I F I PASSWORD", // More fingerspelling
    },
    {
      "description": "The quick brown fox jumped over the lazy dog.",
      "asl_gloss":
          "QUICK BROWN FOX JUMPED OVER LAZY DOG", // Tests words that may not be in the DB
    },
    {
      "description": "I will see you on the 22nd.",
      "asl_gloss": "I SEE YOU 22", // Tests a number from your list
    },
    {
      "description": "Can you accept my apology?",
      "asl_gloss":
          "YOU CAN ACCEPT MY APOLOGY", // Assumes 'accept' is in your words table
    },
    {
      "description": "accept actor adjective affect",
      "asl_gloss": "Accept Actor Adjective Affect",
    },
  ];

  Future<AslResponse> getAslResponse(List<int> audioBytes) async {
    if (_useMockApi) {
      return _getMockResponse();
    } else {
      return _getRealResponse(audioBytes);
    }
  }

  Future<AslResponse> _getMockResponse() {
    debugPrint("API Service: Using MOCK data.");
    final random = Random();
    final index = random.nextInt(_mockResponses.length);
    final mockResponseData = _mockResponses[index];
    debugPrint(
      "Mock API is returning gloss: \"${mockResponseData['asl_gloss']}\"",
    );
    return Future.delayed(
      const Duration(milliseconds: 750),
      () => AslResponse.fromJson(mockResponseData),
    );
  }

  Future<AslResponse> _getRealResponse(List<int> audioBytes) async {
    debugPrint("API Service: Sending ${audioBytes.length} bytes to $_apiUrl");

    try {
      final uri = Uri.parse(_apiUrl);
      var request = http.MultipartRequest('POST', uri);

      request.fields['prompt'] = _apiPrompt;

      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: 'speech.wav',
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        debugPrint("API Response: ${response.body}");
        final Map<String, dynamic> responseData = json.decode(response.body);
        return AslResponse.fromJson(responseData);
      } else {
        debugPrint(
          "API Error: Status Code ${response.statusCode}, Body: ${response.body}",
        );
        throw Exception(
          'Failed to get response from model: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint("API Connection Error: $e");
      throw Exception('Failed to connect to the model.');
    }
  }
}
