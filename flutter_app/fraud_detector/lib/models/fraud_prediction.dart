/// Model representing fraud prediction response from API
/// Matches the API response format exactly
class FraudPrediction {
  final bool fraud;
  final double riskScore;
  final String modelUsed;
  final bool recurringFraudUpi;
  final int fraudCount;
  final String? explanation;

  FraudPrediction({
    required this.fraud,
    required this.riskScore,
    required this.modelUsed,
    required this.recurringFraudUpi,
    required this.fraudCount,
    this.explanation,
  });

  /// Create from JSON API response
  factory FraudPrediction.fromJson(Map<String, dynamic> json) {
    return FraudPrediction(
      fraud: json['fraud'] as bool,
      riskScore: (json['risk_score'] as num).toDouble(),
      modelUsed: json['model_used'] as String? ?? 'fast',
      recurringFraudUpi: json['recurring_fraud_upi'] as bool? ?? false,
      fraudCount: json['fraud_count'] as int? ?? 0,
      explanation: json['explanation'] as String?,
    );
  }
}
