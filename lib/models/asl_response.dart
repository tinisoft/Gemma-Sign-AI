class AslResponse {
  final String description;
  final String aslGloss;

  AslResponse({required this.description, required this.aslGloss});

  factory AslResponse.fromJson(Map<String, dynamic> json) {
    return AslResponse(
      description: json['description'] ?? 'Error: No sentence found',
      aslGloss: json['asl_gloss'] ?? 'Error: No gloss found',
    );
  }
}
