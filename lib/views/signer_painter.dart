import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gemma_sign_ai/models/landmark.dart';

class SignerPainter extends CustomPainter {
  final Map<String, Landmark> landmarks;

  SignerPainter({required this.landmarks});

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    _drawBodyAndArms(canvas, size);

    if (landmarks.containsKey('RIGHT_WRIST')) {
      _drawHand(canvas, size, 'RIGHT_');
    }
    if (landmarks.containsKey('LEFT_WRIST')) {
      _drawHand(canvas, size, 'LEFT_');
    }
  }

  void _drawBodyAndArms(Canvas canvas, Size size) {
    final paintBodyFill = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.fill;

    final paintArmFill = Paint()
      ..color = paintBodyFill.color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    Offset? getOffset(String name) => landmarks[name] != null
        ? Offset(
            landmarks[name]!.x * size.width,
            landmarks[name]!.y * size.height,
          )
        : null;

    final leftShoulder = getOffset('LEFT_SHOULDER');
    final rightShoulder = getOffset('RIGHT_SHOULDER');
    if (leftShoulder == null || rightShoulder == null) return;

    final shoulderWidth = (leftShoulder.dx - rightShoulder.dx).abs();

    final headRadius = shoulderWidth * 0.5;
    final headCenter = Offset(
      (leftShoulder.dx + rightShoulder.dx) / 2,
      leftShoulder.dy - headRadius * 1.1,
    );
    canvas.drawCircle(headCenter, headRadius, paintBodyFill);

    final torsoHeight = shoulderWidth * 1.3;
    final torsoPath = Path()
      ..moveTo(leftShoulder.dx, leftShoulder.dy)
      ..lineTo(rightShoulder.dx, rightShoulder.dy)
      ..lineTo(
        rightShoulder.dx + shoulderWidth * 0.15,
        rightShoulder.dy + torsoHeight,
      )
      ..lineTo(
        leftShoulder.dx - shoulderWidth * 0.15,
        leftShoulder.dy + torsoHeight,
      )
      ..close();
    canvas.drawPath(torsoPath, paintBodyFill);

    final leftElbow = getOffset('LEFT_ELBOW');
    final leftWrist = getOffset('LEFT_WRIST');
    final rightElbow = getOffset('RIGHT_ELBOW');
    final rightWrist = getOffset('RIGHT_WRIST');

    paintArmFill.strokeWidth = (shoulderWidth * 0.25).clamp(12.0, 30.0);

    if (leftElbow != null) {
      canvas.drawLine(leftShoulder, leftElbow, paintArmFill);
    }
    if (leftWrist != null) canvas.drawLine(leftElbow!, leftWrist, paintArmFill);
    if (rightElbow != null) {
      canvas.drawLine(rightShoulder, rightElbow, paintArmFill);
    }
    if (rightWrist != null) {
      canvas.drawLine(rightElbow!, rightWrist, paintArmFill);
    }
  }

  void _drawHand(Canvas canvas, Size size, String prefix) {
    final paintHandFill = Paint()
      ..color = const Color(0xFFc58a5e)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    final paintJoints = Paint()
      ..color = const Color(0xFFffdba4)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    Offset? getOffset(String name) => landmarks[prefix + name] != null
        ? Offset(
            landmarks[prefix + name]!.x * size.width,
            landmarks[prefix + name]!.y * size.height,
          )
        : null;

    final palmVertices = [
      getOffset('WRIST'),
      getOffset('THUMB_CMC'),
      getOffset('INDEX_FINGER_MCP'),
      getOffset('MIDDLE_FINGER_MCP'),
      getOffset('RING_FINGER_MCP'),
      getOffset('PINKY_MCP'),
    ].whereType<Offset>().toList();

    if (palmVertices.length > 3) {
      final palmPath = Path();
      final firstMid = Offset(
        (palmVertices.last.dx + palmVertices.first.dx) / 2,
        (palmVertices.last.dy + palmVertices.first.dy) / 2,
      );
      palmPath.moveTo(firstMid.dx, firstMid.dy);
      for (int i = 0; i < palmVertices.length; i++) {
        final p1 = palmVertices[i];
        final p2 = palmVertices[(i + 1) % palmVertices.length];
        final midpoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        palmPath.quadraticBezierTo(p1.dx, p1.dy, midpoint.dx, midpoint.dy);
      }
      canvas.drawPath(palmPath, paintHandFill);
    }

    final indexMcp = getOffset('INDEX_FINGER_MCP');
    final pinkyMcp = getOffset('PINKY_MCP');
    double fingerWidth = 12.0;
    if (indexMcp != null && pinkyMcp != null) {
      fingerWidth = (indexMcp - pinkyMcp).distance * 0.25;
      fingerWidth = fingerWidth.clamp(8.0, 24.0);
    }
    paintHandFill.strokeWidth = fingerWidth;

    void drawSegment(String from, String to) {
      final fromOffset = getOffset(from);
      final toOffset = getOffset(to);
      if (fromOffset != null && toOffset != null) {
        canvas.drawLine(fromOffset, toOffset, paintHandFill);
      }
    }

    final fingers = [
      'THUMB',
      'INDEX_FINGER',
      'MIDDLE_FINGER',
      'RING_FINGER',
      'PINKY',
    ];
    final thumbSegments = [
      ['CMC', 'MCP'],
      ['MCP', 'IP'],
      ['IP', 'TIP'],
    ];
    final fingerSegments = [
      ['MCP', 'PIP'],
      ['PIP', 'DIP'],
      ['DIP', 'TIP'],
    ];
    for (var seg in thumbSegments) {
      drawSegment('${fingers[0]}_${seg[0]}', '${fingers[0]}_${seg[1]}');
    }
    for (int i = 1; i < fingers.length; i++) {
      for (var seg in fingerSegments) {
        drawSegment('${fingers[i]}_${seg[0]}', '${fingers[i]}_${seg[1]}');
      }
    }

    final allJoints = landmarks.keys
        .where((key) => key.startsWith(prefix))
        .map((key) => getOffset(key.replaceFirst(prefix, '')))
        .whereType<Offset>()
        .toList();

    canvas.drawPoints(
      PointMode.points,
      allJoints,
      paintJoints..strokeWidth = fingerWidth * 0.5,
    );
  }

  @override
  bool shouldRepaint(covariant SignerPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks;
  }
}
