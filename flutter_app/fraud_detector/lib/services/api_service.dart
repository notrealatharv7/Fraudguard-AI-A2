import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fraud_detector/models/transaction_input.dart';
import 'package:fraud_detector/models/fraud_prediction.dart';

/// API Service for communicating with the Fraud Detection backend
/// Handles HTTP requests and error handling
class ApiService {
  // Base URL - configurable, not hardcoded
  // IMPORTANT: Change this based on your setup!
  // 
  // For Android Emulator: use 'http://10.0.2.2:8000'
  // For iOS Simulator: use 'http://localhost:8000'
  // For Physical Device: use 'http://YOUR_COMPUTER_IP:8000'
  //   (Find your IP with: ipconfig on Windows, ifconfig on Mac/Linux)
  
  // Base URL - Production
  static const String baseUrl = 'https://ml-service-production-3886.up.railway.app';
  
  // Uncomment for local testing:
  // static const String baseUrl = 'http://127.0.0.1:8000';

  /// Predicts if a transaction is fraudulent
  /// Returns FraudPrediction with fraud status and risk score
  Future<FraudPrediction> predictFraud(TransactionInput transaction) async {
    try {
      final url = Uri.parse('$baseUrl/predict');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(transaction.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return FraudPrediction.fromJson(jsonData);
      } else {
        throw Exception(
          'API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
          'Cannot connect to server. Please check:\n'
          '1. Backend is running\n'
          '2. Correct IP address/URL\n'
          '3. Network connection',
        );
      }
      rethrow;
    }
  }
}


