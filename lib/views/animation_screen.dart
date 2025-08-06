import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gemma_sign_ai/models/frame.dart';
import 'package:gemma_sign_ai/views/signer_painter.dart';

class AnimationScreen extends StatefulWidget {
  const AnimationScreen({super.key});

  @override
  State<AnimationScreen> createState() => AnimationScreenState();
}

class AnimationScreenState extends State<AnimationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  List<Frame> _frames = [];
  int _currentFrameIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addListener(() {
        if (_frames.isNotEmpty) {
          final newIndex = (_controller.value * (_frames.length - 1)).round();
          if (newIndex != _currentFrameIndex) {
            setState(() {
              _currentFrameIndex = newIndex;
            });
          }
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> playAnimation(List<Frame> frames) {
    final completer = Completer<void>();

    if (frames.isEmpty) {
      completer.complete();
      return completer.future;
    }

    setState(() {
      _frames = frames;
      _currentFrameIndex = 0;
    });

    _controller.duration = Duration(milliseconds: (frames.length * 33).round());

    void statusListener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _controller.removeStatusListener(statusListener);
        completer.complete();
      }
    }

    _controller.addStatusListener(statusListener);
    _controller.forward(from: 0.0);

    return completer.future;
  }

  void clear() {
    setState(() {
      _frames = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_frames.isEmpty) {
      return Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(150),
        ),
        child: CircleAvatar(
          radius: 100,
          backgroundImage: AssetImage("assets/images/dummy_image.png"),
        ),
      );
    }

    return CustomPaint(
      painter: SignerPainter(landmarks: _frames[_currentFrameIndex].landmarks),
      size: const Size(300, 300),
    );
  }
}
