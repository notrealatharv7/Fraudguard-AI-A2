import pandas as pd
import numpy as np
from sklearn.tree import DecisionTreeClassifier
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import joblib
import os
import random
from datetime import datetime, timedelta

# Configuration
FAST_DATA_FILE = 'backend/ml/fraud_data_fast.csv'
ACCURATE_DATA_FILE = 'backend/ml/fraud_data_accurate.csv'
FAST_MODEL_FILE = 'backend/ml/model_fast.pkl'
ACCURATE_MODEL_FILE = 'backend/ml/model_accurate.pkl'

def generate_synthetic_data(filename, n_samples=100, difficulty='easy'):
    print(f"Generating {difficulty} dataset: {filename}...")
    
    data = []
    for i in range(n_samples):
        # Base features
        amount = random.uniform(10, 10000)
        deviation = random.uniform(0, 1)
        time_anomaly = random.uniform(0, 1)
        distance = random.uniform(0, 100)
        novelty = random.uniform(0, 1)
        frequency = random.randint(1, 20)
        
        # Fraud Logic
        is_fraud = 0
        
        if difficulty == 'easy':
            # Simple rule for "Fast" model
            if amount > 5000 or distance > 80:
                is_fraud = 1
        else:
            # Complex rule for "Accurate" model
            score = (deviation * 0.3) + (time_anomaly * 0.2) + (novelty * 0.2) + (distance / 200)
            if amount > 8000: score += 0.3
            if frequency > 15: score += 0.2
            
            if score > 0.65:
                is_fraud = 1
                
        # UPI ID generation
        upi_prefix = "scammer" if is_fraud and random.random() > 0.3 else "user"
        upi_id = f"{upi_prefix}{i}@upi"
        
        data.append([
            upi_id, amount, deviation, time_anomaly, distance, novelty, frequency, is_fraud
        ])
        
    df = pd.DataFrame(data, columns=[
        'upi_id', 'amount', 'transactionAmountDeviation', 'timeAnomaly', 
        'locationDistance', 'merchantNovelty', 'transactionFrequency', 'is_fraud'
    ])
    
    # Save to CSV
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    df.to_csv(filename, index=False)
    print(f"Saved {len(df)} records to {filename}")
    return df

def train_and_save(df, model_type, output_file):
    print(f"\nTraining {model_type} model...")
    
    features = [
        'amount', 'transactionAmountDeviation', 'timeAnomaly', 
        'locationDistance', 'merchantNovelty', 'transactionFrequency'
    ]
    
    X = df[features]
    y = df['is_fraud']
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    if model_type == 'fast':
        # Decision Tree is fast and lightweight
        model = DecisionTreeClassifier(max_depth=5, random_state=42)
    else:
        # Random Forest is robust and "accurate" (deeper analysis)
        model = RandomForestClassifier(n_estimators=300, max_depth=None, random_state=42)
        
    model.fit(X_train, y_train)
    
    # Evaluation
    preds = model.predict(X_test)
    acc = accuracy_score(y_test, preds)
    print(f"{model_type.capitalize()} Model Accuracy: {acc:.4f}")
    
    # Save
    joblib.dump(model, output_file)
    print(f"Saved model to {output_file}")

def main():
    print("="*50)
    print("Initializing Dual Model Training System")
    print("="*50)
    
    # 1. Generate Datasets
    # Fast dataset: simple patterns
    df_fast = generate_synthetic_data(FAST_DATA_FILE, n_samples=200, difficulty='easy')
    
    # Accurate dataset: complex patterns
    df_accurate = generate_synthetic_data(ACCURATE_DATA_FILE, n_samples=10000, difficulty='hard')
    
    # 2. Train Models
    train_and_save(df_fast, 'fast', FAST_MODEL_FILE)
    train_and_save(df_accurate, 'accurate', ACCURATE_MODEL_FILE)
    
    print("\n" + "="*50)
    print("Dual Model System Ready!")
    print("1. Fast Model (DecisionTree) -> model_fast.pkl")
    print("2. Accurate Model (RandomForest) -> model_accurate.pkl")
    print("="*50)

if __name__ == "__main__":
    main()
