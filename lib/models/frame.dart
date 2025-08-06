import 'package:gemma_sign_ai/models/landmark.dart';

class Frame {
  final int frameIndex;
  final Map<String, Landmark> landmarks;

  Frame({required this.frameIndex, required this.landmarks});

  factory Frame.fromJson(Map<String, dynamic> json) {
    Map<String, Landmark> landmarksMap = {};
    var poseLandmarks = json['landmarks'] as Map<String, dynamic>?;

    if (poseLandmarks != null) {
      poseLandmarks.forEach((key, value) {
        landmarksMap[key] = Landmark.fromJson(value as Map<String, dynamic>?);
      });
    }

    return Frame(frameIndex: json['frame_index'], landmarks: landmarksMap);
  }
}
