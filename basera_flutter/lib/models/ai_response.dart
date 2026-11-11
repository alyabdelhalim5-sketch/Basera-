/// Data model for the JSON response from the FastAPI /describe endpoint.
class AiResponse {
  final String description;
  final bool sceneChanged;
  final bool skipped;
  final int inferenceMs;
  final int totalLatencyMs;
  final String language;

  const AiResponse({
    required this.description,
    required this.sceneChanged,
    required this.skipped,
    required this.inferenceMs,
    required this.totalLatencyMs,
    required this.language,
  });

  factory AiResponse.fromJson(Map<String, dynamic> json) {
    return AiResponse(
      description: json['description'] as String? ?? '',
      sceneChanged: json['scene_changed'] as bool? ?? true,
      skipped: json['skipped'] as bool? ?? false,
      inferenceMs: (json['inference_ms'] as num?)?.toInt() ?? 0,
      totalLatencyMs: (json['total_latency_ms'] as num?)?.toInt() ?? 0,
      language: json['language'] as String? ?? 'ar',
    );
  }

  String get latencySeconds => '${(totalLatencyMs / 1000).toStringAsFixed(1)}s';

  @override
  String toString() =>
      'AiResponse(lang=$language, changed=$sceneChanged, ${latencySeconds}, "${description.substring(0, description.length.clamp(0, 60))}...")';
}
