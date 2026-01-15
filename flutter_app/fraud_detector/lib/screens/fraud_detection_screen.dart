import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fraud_detector/models/fraud_prediction.dart';
import 'package:fraud_detector/models/transaction_input.dart';
import 'package:fraud_detector/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;

class FraudDetectionScreen extends StatefulWidget {
  const FraudDetectionScreen({super.key});

  @override
  State<FraudDetectionScreen> createState() => _FraudDetectionScreenState();
}

/// Model to store batch processing results
class BatchResult {
  final TransactionInput transaction;
  final FraudPrediction prediction;
  final int rowNumber;
  final String? error;

  BatchResult({
    required this.transaction,
    required this.prediction,
    required this.rowNumber,
    this.error,
  });
}

class _FraudDetectionScreenState extends State<FraudDetectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = {
    'upiId': TextEditingController(),
    'amount': TextEditingController(),
    'deviation': TextEditingController(),
    'anomaly': TextEditingController(),
    'distance': TextEditingController(),
    'novelty': TextEditingController(),
    'frequency': TextEditingController(),
  };

  String _selectedMode = 'fast'; // 'fast' or 'accurate'
  bool _isLoading = false;
  FraudPrediction? _prediction;
  String? _errorMessage;
  final ApiService _apiService = ApiService();

  // Batch processing state variables
  bool _isProcessingBatch = false;
  List<BatchResult> _batchResults = [];
  int _currentBatch = 0;
  int _totalBatches = 0;
  int _processedCount = 0;
  int _totalRecords = 0;
  bool _showOnlyFraud = false;

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _prediction = null;
      _errorMessage = null;
    });

    try {
      final transaction = TransactionInput(
        upiId: _controllers['upiId']!.text.trim(),
        transactionAmount: double.parse(_controllers['amount']!.text),
        transactionAmountDeviation: double.parse(_controllers['deviation']!.text),
        timeAnomaly: double.parse(_controllers['anomaly']!.text),
        locationDistance: double.parse(_controllers['distance']!.text),
        merchantNovelty: double.parse(_controllers['novelty']!.text),
        transactionFrequency: double.parse(_controllers['frequency']!.text),
        mode: _selectedMode,
      );

      final prediction = await _apiService.predictFraud(transaction);
      setState(() => _prediction = prediction);
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    for (var controller in _controllers.values) {
      controller.clear();
    }
    setState(() {
      _prediction = null;
      _errorMessage = null;
    });
  }

  /// Handle CSV/Excel file upload and parsing
  Future<void> _handleFileUpload() async {
    try {
      // Pick file using file_picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = result.files.first;
      final fileName = file.name.toLowerCase();

      List<List<dynamic>> rows = [];

      if (fileName.endsWith('.csv')) {
        // Parse CSV file
        final String csvContent = utf8.decode(file.bytes!);
        rows = const CsvToListConverter().convert(csvContent);
      } else if (fileName.endsWith('.xlsx') || fileName.endsWith('.xls')) {
        // Parse Excel file
        final excel = Excel.decodeBytes(file.bytes!);
        final sheet = excel.tables[excel.tables.keys.first]!;
        rows = sheet.rows.map((row) => row.map((cell) => cell?.value).toList()).toList();
      } else {
        _showSnackBar('Unsupported file format. Please use CSV or Excel files.');
        return;
      }

      if (rows.isEmpty) {
        _showSnackBar('File is empty or invalid.');
        return;
      }

      // Parse header row (skip if present)
      int startRowIndex = 0;
      final firstRow = rows[0].map((e) => e?.toString().toLowerCase().trim() ?? '').toList();
      
      // Check if first row is header (contains expected column names)
      if (firstRow.any((cell) => 
          cell.contains('upiid') || 
          cell.contains('transactionamount') || 
          cell.contains('amount') ||
          cell.contains('deviation'))) {
        startRowIndex = 1; // Skip header row
      }

      // Parse data rows to TransactionInput objects
      List<TransactionInput> transactions = [];
      List<String> parseErrors = [];

      for (int i = startRowIndex; i < rows.length; i++) {
        try {
          final row = rows[i];
          if (row.length < 7) {
            parseErrors.add('Row ${i + 1}: Insufficient columns (expected 7: upiId + 6 features)');
            continue;
          }

          final transaction = TransactionInput(
            upiId: row[0]?.toString().trim() ?? 'unknown@upi',
            transactionAmount: _parseDouble(row[1], 'transactionAmount', i + 1),
            transactionAmountDeviation: _parseDouble(row[2], 'transactionAmountDeviation', i + 1),
            timeAnomaly: _parseDouble(row[3], 'timeAnomaly', i + 1),
            locationDistance: _parseDouble(row[4], 'locationDistance', i + 1),
            merchantNovelty: _parseDouble(row[5], 'merchantNovelty', i + 1),
            transactionFrequency: _parseDouble(row[6], 'transactionFrequency', i + 1),
            mode: _selectedMode, // Use selected mode for batch processing
          );

          transactions.add(transaction);
        } catch (e) {
          parseErrors.add('Row ${i + 1}: ${e.toString()}');
        }
      }

      if (transactions.isEmpty) {
        _showSnackBar('No valid transactions found in file. ${parseErrors.isNotEmpty ? parseErrors.first : ""}');
        return;
      }

      if (parseErrors.isNotEmpty) {
        _showSnackBar('Parsed ${transactions.length} transactions. ${parseErrors.length} rows had errors.');
      }

      // Start batch processing
      await _processBatchTransactions(transactions);
    } catch (e) {
      _showSnackBar('Error reading file: ${e.toString()}');
    }
  }

  /// Parse double value from cell with error handling
  double _parseDouble(dynamic value, String fieldName, int rowNum) {
    if (value == null || value.toString().trim().isEmpty) {
      throw FormatException('$fieldName is empty');
    }
    final parsed = double.tryParse(value.toString().trim());
    if (parsed == null) {
      throw FormatException('$fieldName is not a valid number: $value');
    }
    return parsed;
  }

  /// Process transactions in batches of 10
  Future<void> _processBatchTransactions(List<TransactionInput> transactions) async {
    setState(() {
      _isProcessingBatch = true;
      _batchResults = [];
      _currentBatch = 0;
      _processedCount = 0;
      _totalRecords = transactions.length;
      _totalBatches = (transactions.length / 10).ceil();
    });

    const batchSize = 10;
    
    for (int i = 0; i < transactions.length; i += batchSize) {
      if (!_isProcessingBatch) break; // Allow cancellation

      final batch = transactions.sublist(
        i,
        i + batchSize > transactions.length ? transactions.length : i + batchSize,
      );

      setState(() {
        _currentBatch = (i / batchSize).floor() + 1;
      });

      // Process batch concurrently
      final batchFutures = batch.asMap().entries.map((entry) async {
        final index = entry.key;
        final transaction = entry.value;
        final rowNumber = i + index + 1;

        try {
          final prediction = await _apiService.predictFraud(transaction);
          return BatchResult(
            transaction: transaction,
            prediction: prediction,
            rowNumber: rowNumber,
          );
        } catch (e) {
          return BatchResult(
            transaction: transaction,
            prediction: FraudPrediction(
              fraud: false,
              riskScore: 0.0,
              modelUsed: 'fast',
              recurringFraudUpi: false,
              fraudCount: 0,
              explanation: 'Error: ${e.toString()}',
            ),
            rowNumber: rowNumber,
            error: e.toString(),
          );
        }
      });

      final batchResults = await Future.wait(batchFutures);

      setState(() {
        _batchResults.addAll(batchResults);
        _processedCount = _batchResults.length;
      });

      // Small delay to allow UI updates
      await Future.delayed(const Duration(milliseconds: 100));
    }

    setState(() {
      _isProcessingBatch = false;
    });

    _showSnackBar('Batch processing complete! Processed $_processedCount transactions.');
  }

  /// Show snackbar message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /// Get filtered batch results (based on showOnlyFraud filter)
  List<BatchResult> get _filteredBatchResults {
    if (_showOnlyFraud) {
      return _batchResults.where((r) => r.prediction.fraud).toList();
    }
    return _batchResults;
  }

  /// Get summary statistics
  Map<String, dynamic> get _summaryStats {
    final total = _batchResults.length;
    final fraudCount = _batchResults.where((r) => r.prediction.fraud).length;
    final safeCount = total - fraudCount;
    final fraudPercentage = total > 0 ? (fraudCount / total * 100) : 0.0;
    final recurringFraud = _batchResults.where((r) => r.prediction.recurringFraudUpi).length;

    return {
      'total': total,
      'fraud': fraudCount,
      'safe': safeCount,
      'fraudPercentage': fraudPercentage,
      'recurringFraud': recurringFraud,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fraudguard AI'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(   
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Real-Time Fraud Analysis',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('Enter transaction details or upload CSV/Excel file to analyze for potential fraud.',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  // File Upload Section
                  _buildFileUploadSection(),
                  const SizedBox(height: 24),
                  // Summary Statistics (show when batch results exist)
                  if (_batchResults.isNotEmpty) ...[
                    _buildSummarySection(),
                    const SizedBox(height: 24),
                  ],
                  // Batch Processing Progress
                  if (_isProcessingBatch) _buildBatchProgressSection(),
                  // Main Content: Manual Input + Results OR Batch Results Table
                  if (_batchResults.isNotEmpty && !_isProcessingBatch)
                    _buildBatchResultsSection()
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 800) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildInputSection()),
                              const SizedBox(width: 24),
                              Expanded(flex: 3, child: _buildResultsSection()),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildInputSection(),
                              const SizedBox(height: 24),
                              _buildResultsSection(),
                            ],
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build file upload section
  Widget _buildFileUploadSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.upload_file, size: 24),
                const SizedBox(width: 12),
                Text('Batch Processing', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text('Upload CSV or Excel file to process multiple transactions',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: (_isLoading || _isProcessingBatch) ? null : _handleFileUpload,
              icon: const Icon(Icons.file_upload),
              label: const Text('Upload CSV / Excel'),
            ),
            const SizedBox(height: 8),
            Text(
              'Supported formats: .csv, .xlsx, .xls',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build summary statistics section
  Widget _buildSummarySection() {
    final stats = _summaryStats;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, size: 24),
                const SizedBox(width: 12),
                Text('Summary Statistics', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Transactions',
                    stats['total'].toString(),
                    Icons.receipt_long,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Fraud Detected',
                    stats['fraud'].toString(),
                    Icons.warning_amber_rounded,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Safe Transactions',
                    stats['safe'].toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Fraud Rate',
                    '${stats['fraudPercentage'].toStringAsFixed(1)}%',
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            // Recurring Fraud Row
            if (stats['recurringFraud'] > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade900, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recurring Fraud UPIs Detected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${stats['recurringFraud']} UPI ID(s) with 3+ fraud records',
                            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _showOnlyFraud,
                  onChanged: (value) {
                    setState(() {
                      _showOnlyFraud = value ?? false;
                    });
                  },
                ),
                const Text('Show only fraud transactions'),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _batchResults = [];
                      _showOnlyFraud = false;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Results'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build individual stat card
  Widget _buildStatCard(String label, String value, IconData icon, [Color? color]) {
    final displayColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: displayColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: displayColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: displayColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build batch processing progress section
  Widget _buildBatchProgressSection() {
    final progress = _totalRecords > 0 ? _processedCount / _totalRecords : 0.0;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Processing Batch $_currentBatch of $_totalBatches',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text(
              'Processed $_processedCount of $_totalRecords transactions (${(progress * 100).toStringAsFixed(1)}%)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transaction Details', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              _buildTextField(
                  controller: _controllers['upiId']!,
                  label: 'UPI ID',
                  hint: 'e.g., user123@upi',
                  icon: Icons.person,
                  validator: _validateRequiredText,
                  keyboardType: TextInputType.text),
              const SizedBox(height: 16),
              // Model Mode Selection
              Text('Model Mode', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('⚡ Fast Scan'),
                      subtitle: const Text('Quick prediction'),
                      value: 'fast',
                      groupValue: _selectedMode,
                      onChanged: (value) => setState(() => _selectedMode = value!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('🧠 Deep Analysis'),
                      subtitle: const Text('High accuracy'),
                      value: 'accurate',
                      groupValue: _selectedMode,
                      onChanged: (value) => setState(() => _selectedMode = value!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _controllers['amount']!,
                  label: 'Amount (₹)',
                  hint: 'e.g., 150.50',
                  icon: Icons.currency_rupee,
                  validator: _validateRequiredNumber),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _controllers['deviation']!,
                  label: 'Amount Deviation',
                  hint: 'e.g., 0.25',
                  icon: Icons.trending_up,
                  validator: _validateRequiredNumber),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _controllers['anomaly']!,
                  label: 'Time Anomaly (0-1)',
                  hint: 'e.g., 0.3',
                  icon: Icons.timer,
                  validator: _validateRange),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _controllers['distance']!,
                  label: 'Location Distance (km)',
                  hint: 'e.g., 25.0',
                  icon: Icons.location_on,
                  validator: _validateRequiredNumber),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _controllers['novelty']!,
                  label: 'Merchant Novelty (0-1)',
                  hint: 'e.g., 0.2',
                  icon: Icons.store,
                  validator: _validateRange),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _controllers['frequency']!,
                  label: 'Transaction Frequency',
                  hint: 'e.g., 5',
                  icon: Icons.history,
                  validator: _validateRequiredNumber),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Check for Fraud'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: _resetForm, child: const Text('Reset')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: _isLoading
          ? _buildLoadingIndicator()
          : _errorMessage != null
              ? _buildErrorCard(_errorMessage!)
              : _prediction != null
                  ? _buildResultCard(_prediction!)
                  : _buildPlaceholderCard(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon, size: 20)),
      keyboardType: keyboardType ?? const TextInputType.numberWithOptions(decimal: true),
      validator: validator,
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      key: const ValueKey('loading'),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text('Analyzing transaction...', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String errorMessage) {
    return Container(
      key: const ValueKey('error'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(errorMessage, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(FraudPrediction prediction) {
    final isFraud = prediction.fraud;
    final riskScore = prediction.riskScore;
    final riskPercentage = (riskScore * 100).toStringAsFixed(1);
    final color = isFraud ? Theme.of(context).colorScheme.error : const Color(0xFF059669);
    final containerColor = isFraud ? Theme.of(context).colorScheme.errorContainer : const Color(0xFFD1FAE5);

    return Container(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isFraud ? Icons.warning_amber_rounded : Icons.check_circle, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(isFraud ? 'Potential Fraud Detected!' : 'Transaction is Safe',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Confidence: $riskPercentage%', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: prediction.modelUsed == 'accurate' ? Colors.blue : Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  prediction.modelUsed == 'accurate' ? '🧠 Deep' : '⚡ Fast',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          // Recurring Fraud Warning
          if (prediction.recurringFraudUpi) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚠️ RECURRING FRAUD UPI',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'This UPI ID has ${prediction.fraudCount} fraud record(s). High risk!',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (prediction.explanation != null && prediction.explanation!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Divider(color: color.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('AI Analysis', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
            const SizedBox(height: 8),
            Text(prediction.explanation!, 
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isFraud 
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : const Color(0xFF065F46), // Dark green for readability on light green background
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard() {
    return Container(
      key: const ValueKey('placeholder'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Transaction Analysis', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Submit transaction details to check for potential fraud', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  String? _validateRequiredNumber(String? value) {
    if (value == null || value.isEmpty) return 'This field is required';
    if (double.tryParse(value) == null) return 'Please enter a valid number';
    return null;
  }

  String? _validateRange(String? value) {
    final numberError = _validateRequiredNumber(value);
    if (numberError != null) return numberError;
    final val = double.parse(value!);
    if (val < 0 || val > 1) return 'Must be between 0 and 1';
    return null;
  }

  String? _validateRequiredText(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required';
    return null;
  }

  /// Build batch results table section
  Widget _buildBatchResultsSection() {
    if (_filteredBatchResults.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  _showOnlyFraud ? 'No fraud transactions found' : 'No results to display',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.table_chart, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Batch Results (${_filteredBatchResults.length} of ${_batchResults.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.resolveWith(
                (states) => Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              columns: const [
                DataColumn(label: Text('Row #')),
                DataColumn(label: Text('UPI ID')),
                DataColumn(label: Text('Amount'), numeric: true),
                DataColumn(label: Text('Distance (km)'), numeric: true),
                DataColumn(label: Text('Time Anomaly'), numeric: true),
                DataColumn(label: Text('Risk %'), numeric: true),
                DataColumn(label: Text('Model')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Explanation'), tooltip: 'AI Analysis Explanation'),
              ],
              rows: _filteredBatchResults.map((result) {
                final isFraud = result.prediction.fraud;
                final isRecurringFraud = result.prediction.recurringFraudUpi;
                final riskPercentage = (result.prediction.riskScore * 100).toStringAsFixed(1);
                
                // Highlight recurring fraud more prominently
                final backgroundColor = isRecurringFraud
                    ? Colors.red.shade900.withOpacity(0.2)
                    : isFraud
                        ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.3)
                        : const Color(0xFFD1FAE5).withOpacity(0.5);

                return DataRow(
                  color: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return backgroundColor;
                    }
                    return backgroundColor;
                  }),
                  cells: [
                    DataCell(Text('#${result.rowNumber}')),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              result.transaction.upiId,
                              style: TextStyle(
                                fontWeight: isRecurringFraud ? FontWeight.bold : FontWeight.normal,
                                color: isRecurringFraud ? Colors.red.shade900 : null,
                              ),
                            ),
                          ),
                          if (isRecurringFraud) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.warning, size: 16, color: Colors.red),
                          ],
                        ],
                      ),
                    ),
                    DataCell(Text(
                      result.transaction.transactionAmount.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    )),
                    DataCell(Text(result.transaction.locationDistance.toStringAsFixed(1))),
                    DataCell(Text(result.transaction.timeAnomaly.toStringAsFixed(2))),
                    DataCell(Text(
                      riskPercentage,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isFraud ? Colors.red : Colors.green,
                      ),
                    )),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: result.prediction.modelUsed == 'accurate' ? Colors.blue : Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          result.prediction.modelUsed == 'accurate' ? '🧠' : '⚡',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(_buildStatusBadge(isFraud)),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isRecurringFraud)
                              Text(
                                '⚠️ ${result.prediction.fraudCount} fraud records',
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            Text(
                              result.prediction.explanation ?? 'No explanation available',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Build status badge widget
  Widget _buildStatusBadge(bool isFraud) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isFraud
            ? Theme.of(context).colorScheme.errorContainer
            : const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFraud ? Icons.warning_amber_rounded : Icons.check_circle,
            size: 16,
            color: isFraud
                ? Theme.of(context).colorScheme.onErrorContainer
                : const Color(0xFF065F46),
          ),
          const SizedBox(width: 4),
          Text(
            isFraud ? 'FRAUD' : 'SAFE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isFraud
                  ? Theme.of(context).colorScheme.onErrorContainer
                  : const Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }
}


