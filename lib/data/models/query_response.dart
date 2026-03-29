class QueryResponse {
  const QueryResponse({
    required this.intent,
    required this.reply,
  });

  final String intent;
  final String reply;

  factory QueryResponse.fromJson(Map<String, dynamic> json) {
    return QueryResponse(
      intent: json['intent'] as String? ?? 'unknown',
      reply: json['reply'] as String? ?? '',
    );
  }
}
