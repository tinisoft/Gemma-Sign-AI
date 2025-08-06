import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gemma_sign_ai/core/utils/audio_utils.dart';
import 'package:gemma_sign_ai/models/frame.dart';
import 'package:gemma_sign_ai/models/landmark.dart';
import 'package:gemma_sign_ai/models/sign_job.dart';
import 'package:gemma_sign_ai/services/ai_model_service.dart';
import 'package:gemma_sign_ai/services/db_service.dart';
import 'package:gemma_sign_ai/views/animation_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vad/vad.dart';

class InterpreterScreen extends StatefulWidget {
  const InterpreterScreen({super.key});
  @override
  State<InterpreterScreen> createState() => _InterpreterScreenState();
}

class _InterpreterScreenState extends State<InterpreterScreen> {
  final _vadHandler = VadHandler.create(isDebug: false);
  final _aiModelService = AiModelService();
  final _dbService = DatabaseService.instance;

  final GlobalKey<AnimationScreenState> _animationKey = GlobalKey();
  final List<SignJob> _jobQueue = [];
  bool _isQueueProcessing = false;

  bool _isListening = false;
  bool _isSpeaking = false;
  String _currentAnimatingWord = "ASL_GLOSS_WILL_APPEAR_HERE";
  String _sentence = "Your translated sentence will appear here.";

  @override
  void initState() {
    super.initState();
    _setupVadHandler();
    requestMicrophonePermission();
  }

  Future<void> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    debugPrint("Microphone permission status: $status");
  }

  void _setupVadHandler() {
    _vadHandler.onSpeechStart.listen((_) {
      if (mounted) setState(() => _isSpeaking = true);
    });

    _vadHandler.onSpeechEnd.listen((List<double> samples) async {
      if (!mounted) return;
      setState(() => _isSpeaking = false);

      try {
        final audioBytes = AudioUtils.encodeToWav(samples, 16000);
        final response = await _aiModelService.getAslResponse(audioBytes);
        if (!mounted) return;

        final newJob = SignJob(
          sentence: response.description,
          aslGloss: response.aslGloss,
        );
        _jobQueue.add(newJob);

        if (!_isQueueProcessing) {
          _processJobQueue();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _sentence = "Error processing your request.";
          });
        }
      }
    });
  }

  Future<Map<String, String>?> _fetchSignData(String word) async {
    if (word.length == 1 && RegExp(r'^[A-Z]$').hasMatch(word)) {
      debugPrint("Querying 'alphabets' table for: $word");
      final result = await _dbService.getSign(
        DatabaseService.tableAlphabets,
        word,
      );
      if (result != null) return result;
    }

    final number = int.tryParse(word);
    if (number != null && number >= 0 && number <= 30) {
      debugPrint("Querying 'numbers' table for: $word");
      final result = await _dbService.getSign(
        DatabaseService.tableNumbers,
        word,
      );
      if (result != null) return result;
    }

    debugPrint("Querying 'words' table for: $word");
    return _dbService.getSign(DatabaseService.tableWords, word.toLowerCase());
  }

  Future<void> _processJobQueue() async {
    if (_jobQueue.isEmpty || _isQueueProcessing) {
      return;
    }

    _isQueueProcessing = true;

    while (_jobQueue.isNotEmpty) {
      if (!mounted) return;

      final currentJob = _jobQueue.first;

      setState(() {
        _sentence = currentJob.sentence;
      });

      await _playGlossAnimationSequence(currentJob.aslGloss);

      if (mounted) {
        _jobQueue.removeAt(0);
      }
    }

    _isQueueProcessing = false;
    if (mounted) {
      setState(() {
        _currentAnimatingWord = "";
        _sentence = "";
      });
    }
  }

  Future<void> _playGlossAnimationSequence(String gloss) async {
    final words = gloss.toUpperCase().split(' ');

    for (final word in words) {
      if (!mounted) return;
      setState(() {
        _currentAnimatingWord = word;
      });

      final decompressedJsons = await _fetchSignData(word);

      if (decompressedJsons != null) {
        final frames = _parseFrameData(
          json.decode(decompressedJsons['pose_json']!),
          json.decode(decompressedJsons['hand_json']!),
        );
        await _animationKey.currentState?.playAnimation(frames);
      } else {
        print("Word '$word' not found in database. Skipping.");
        setState(() {
          _currentAnimatingWord = "$word (Not Found)";
        });
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    if (mounted) {
      _animationKey.currentState?.clear();
    }
  }

  List<Frame> _parseFrameData(
    Map<String, dynamic> poseData,
    Map<String, dynamic> handData,
  ) {
    final poseFramesData = poseData['frames'] as List;
    final handFramesMap = {
      for (var frame in (handData['frames'] as List))
        frame['frame_index']: frame,
    };
    final List<Frame> combinedFrames = [];

    for (var poseFrameJson in poseFramesData) {
      final int currentIndex = poseFrameJson['frame_index'];
      final landmarks = <String, Landmark>{};

      (poseFrameJson['landmarks'] as Map<String, dynamic>?)?.forEach(
        (key, value) => landmarks[key] = Landmark.fromJson(value),
      );

      if (handFramesMap.containsKey(currentIndex)) {
        final handFrameJson = handFramesMap[currentIndex]!;
        final handLandmarkGroups =
            handFrameJson['landmarks'] as Map<String, dynamic>?;

        if (handLandmarkGroups != null) {
          final rightHandLandmarks =
              handLandmarkGroups['right_hand'] as Map<String, dynamic>?;
          if (rightHandLandmarks != null) {
            rightHandLandmarks.forEach((key, value) {
              landmarks['RIGHT_$key'] = Landmark.fromJson(value);
            });
          }

          final leftHandLandmarks =
              handLandmarkGroups['left_hand'] as Map<String, dynamic>?;
          if (leftHandLandmarks != null) {
            leftHandLandmarks.forEach((key, value) {
              landmarks['LEFT_$key'] = Landmark.fromJson(value);
            });
          }
        }
      }
      combinedFrames.add(Frame(frameIndex: currentIndex, landmarks: landmarks));
    }
    return combinedFrames;
  }

  @override
  void dispose() {
    _vadHandler.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    final bool willBeListening = !_isListening;
    setState(() {
      _isListening = willBeListening;
    });

    if (willBeListening) {
      await _vadHandler.startListening();
      if (_jobQueue.isEmpty && !_isQueueProcessing) {
        setState(() {
          _sentence = "Speak now...";
          _currentAnimatingWord = "";
        });
      }
    } else {
      await _vadHandler.stopListening();
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ASL Interpreter"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _currentAnimatingWord,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFffdba4),
              ),
            ),
            Expanded(
              child: Center(child: AnimationScreen(key: _animationKey)),
            ),
            Text(
              _sentence,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      floatingActionButton: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _isSpeaking ? 90.0 : 80.0,
        height: _isSpeaking ? 90.0 : 80.0,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: _isSpeaking
              ? [
                  BoxShadow(
                    color: Colors.greenAccent.shade700.withOpacity(0.8),
                    blurRadius: 25,
                    spreadRadius: 10,
                  ),
                ]
              : null,
        ),
        child: FloatingActionButton(
          onPressed: _toggleListening,
          backgroundColor: _isListening
              ? Colors.redAccent
              : const Color(0xFFffdba4),
          child: Icon(
            _isListening ? Icons.stop : Icons.mic,
            size: 40,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
