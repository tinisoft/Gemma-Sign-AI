class Landmark {
  final double x;
  final double y;
  final double z;

  Landmark({required this.x, required this.y, required this.z});

  factory Landmark.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Landmark(x: 0.0, y: 0.0, z: 0.0);
    }
    return Landmark(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      z: (json['z'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
