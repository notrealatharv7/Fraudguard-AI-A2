/// Model representing transaction input data
/// Matches the API request format exactly
class TransactionInput {
  final String upiId;
  final double transactionAmount;
  final double transactionAmountDeviation;
  final double timeAnomaly;
  final double locationDistance;
  final double merchantNovelty;
  final double transactionFrequency;
  final String mode; // "fast" or "accurate"

  TransactionInput({
    required this.upiId,
    required this.transactionAmount,
    required this.transactionAmountDeviation,
    required this.timeAnomaly,
    required this.locationDistance,
    required this.merchantNovelty,
    required this.transactionFrequency,
    this.mode = "fast",
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'upiId': upiId,
      'transactionAmount': transactionAmount,
      'transactionAmountDeviation': transactionAmountDeviation,
      'timeAnomaly': timeAnomaly,
      'locationDistance': locationDistance,
      'merchantNovelty': merchantNovelty,
      'transactionFrequency': transactionFrequency,
      'mode': mode,
    };
  }
}
