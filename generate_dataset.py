import pandas as pd
import random
from datetime import datetime, timedelta
import os

def generate_random_time():
    """Generates a random timestamp within the last 30 days."""
    end = datetime.now()
    start = end - timedelta(days=30)
    random_seconds = random.randint(0, int((end - start).total_seconds()))
    return (start + timedelta(seconds=random_seconds)).strftime("%Y-%m-%d %H:%M:%S")

def main():
    input_file = 'sample_transactions.csv'
    output_file = 'fraudguard_ai_m3_transactions.csv'

    print(f"Reading from {input_file}...")
    
    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found.")
        return

    try:
        df = pd.read_csv(input_file)
    except Exception as e:
        print(f"Error reading {input_file}: {e}")
        return

    # 1. Rename columns to match requirements
    # upiId -> upi_id
    # transactionAmount -> amount
    df = df.rename(columns={
        'upiId': 'upi_id',
        'transactionAmount': 'amount'
    })

    # 2. Generate 'transaction_time'
    print("Generating random transaction times...")
    df['transaction_time'] = [generate_random_time() for _ in range(len(df))]

    # 3. Generate 'is_fraud'
    # Logic: If 'scammer' is in the upi_id, mark as 1 (Fraud), else 0 (Legit)
    print("Generating fraud labels...")
    df['is_fraud'] = df['upi_id'].apply(lambda x: 1 if isinstance(x, str) and 'scammer' in x.lower() else 0)

    # 4. Ensure all requested columns exist
    requested_columns = [
        'upi_id', 
        'amount', 
        'transaction_time', 
        'transactionAmountDeviation', 
        'timeAnomaly', 
        'locationDistance', 
        'merchantNovelty', 
        'transactionFrequency', 
        'is_fraud'
    ]

    # Check for missing columns and fill with 0 if necessary (though they should essentially be there from sample_transactions)
    for col in requested_columns:
        if col not in df.columns:
            print(f"Warning: Column '{col}' missing from source. initializing with 0.")
            df[col] = 0

    # 5. Reorder and Select columns
    final_df = df[requested_columns]

    # 6. Save to CSV
    print(f"Saving to {output_file}...")
    final_df.to_csv(output_file, index=False)
    print(f"Success! Generated {output_file} with {len(final_df)} rows.")

if __name__ == "__main__":
    main()
