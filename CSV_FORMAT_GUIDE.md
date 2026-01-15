# CSV/Excel Format Guide for Fraud Detection

## Required Format

The CSV/Excel file **MUST** follow this exact format with **UPI ID** as the first column:

```csv
upiId,transactionAmount,transactionAmountDeviation,timeAnomaly,locationDistance,merchantNovelty,transactionFrequency
```

## Column Order (CRITICAL)

Columns must be in this **exact order**:

1. **upiId** (string) - UPI identifier (e.g., "user123@upi", "scammer01@upi")
2. **transactionAmount** (number) - Transaction amount
3. **transactionAmountDeviation** (number) - Amount deviation from normal (0.0-1.0+)
4. **timeAnomaly** (number) - Time anomaly score (0.0-1.0)
5. **locationDistance** (number) - Distance from usual location in kilometers
6. **merchantNovelty** (number) - Merchant novelty score (0.0-1.0)
7. **transactionFrequency** (number) - Transaction frequency count

## Example CSV

```csv
upiId,transactionAmount,transactionAmountDeviation,timeAnomaly,locationDistance,merchantNovelty,transactionFrequency
user001@upi,150.50,0.15,0.2,5.0,0.1,8
scammer01@upi,2500.00,0.65,0.85,45.0,0.9,2
user002@upi,75.25,0.10,0.1,3.0,0.05,12
```

## Column Details

| Column | Type | Description | Example Values |
|--------|------|-------------|----------------|
| `upiId` | String | Unique identifier for the transaction UPI | `user123@upi`, `scammer01@upi` |
| `transactionAmount` | Number | Transaction amount in currency | `150.50`, `2500.00` |
| `transactionAmountDeviation` | Number | Deviation from normal spending (0.0-1.0+) | `0.15`, `0.65` |
| `timeAnomaly` | Number | Time anomaly score indicating unusual timing (0.0-1.0) | `0.2`, `0.85` |
| `locationDistance` | Number | Distance from usual transaction location in kilometers | `5.0`, `45.0` |
| `merchantNovelty` | Number | Merchant novelty score (0.0 = familiar, 1.0 = new merchant) | `0.1`, `0.9` |
| `transactionFrequency` | Number | Number of transactions in the time period | `8`, `2` |

## Important Notes

✅ **Header row is required** - The first row must contain column names  
✅ **7 columns total** - Must include UPI ID as the first column  
✅ **All values must be valid** - Invalid rows will be skipped with error messages  
✅ **UPI ID is used for tracking** - Same UPI ID across uploads will track fraud history  
✅ **No fraud labels** - The CSV should NOT contain fraud prediction labels (this is prediction only, not training data)  

## Recurring Fraud Detection

The system tracks UPI IDs across multiple CSV uploads:
- If a UPI ID has **3 or more fraud records**, it will be flagged as **Recurring Fraud UPI**
- Recurring fraud UPIs are highlighted in the results table
- Fraud history persists across app sessions via `fraud_history.json`

## Sample File

See `sample_transactions.csv` for a ready-to-use test file with:
- 15 sample transactions
- Mix of legitimate and fraudulent patterns
- Example recurring fraud UPIs (scammer01@upi appears multiple times)

## Supported File Formats

- ✅ `.csv` - Comma-separated values
- ✅ `.xlsx` - Excel 2007+ format
- ✅ `.xls` - Excel 97-2003 format

## Batch Processing

- Transactions are processed in batches of 10
- Progress is shown in real-time
- Errors in individual rows don't stop the batch processing
- Results are displayed in an interactive table
