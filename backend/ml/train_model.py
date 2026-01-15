"""
Fraud Detection Model Training Script
This script trains a RandomForestClassifier to detect fraudulent transactions.
"""

import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import joblib
import os

# File paths
CSV_FILE = 'fraud_data.csv'
MODEL_FILE = 'model.pkl'

def load_data():
    """Load the fraud detection dataset from CSV."""
    print(f"Loading data from {CSV_FILE}...")
    df = pd.read_csv(CSV_FILE)
    print(f"Loaded {len(df)} records")
    return df

def prepare_features(df):
    """
    Prepare features and target variable.
    Features must be in this exact order:
    1. transactionAmount
    2. transactionAmountDeviation
    3. timeAnomaly
    4. locationDistance
    5. merchantNovelty
    6. transactionFrequency
    """
    # Define feature columns in the required order
    feature_columns = [
        'transactionAmount',
        'transactionAmountDeviation',
        'timeAnomaly',
        'locationDistance',
        'merchantNovelty',
        'transactionFrequency'
    ]
    
    # Extract features (X) and target (y)
    X = df[feature_columns]
    y = df['fraud']  # 0 = Legit, 1 = Fraud
    
    print(f"Features shape: {X.shape}")
    print(f"Target distribution:\n{y.value_counts()}")
    
    return X, y

def train_model(X, y):
    """
    Train a RandomForestClassifier model.
    Returns the trained model.
    """
    print("\nTraining RandomForestClassifier...")
    
    # Split data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    # Initialize and train the model
    model = RandomForestClassifier(
        n_estimators=100,
        max_depth=10,
        random_state=42,
        n_jobs=-1
    )
    
    model.fit(X_train, y_train)
    
    # Evaluate the model
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    
    print(f"\nModel Accuracy: {accuracy:.4f} ({accuracy*100:.2f}%)")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, target_names=['Legit', 'Fraud']))
    
    return model

def save_model(model):
    """Save the trained model to a pickle file."""
    print(f"\nSaving model to {MODEL_FILE}...")
    joblib.dump(model, MODEL_FILE)
    print(f"Model saved successfully!")

def main():
    """Main training pipeline."""
    print("=" * 50)
    print("Fraud Detection Model Training")
    print("=" * 50)
    
    # Check if CSV file exists
    if not os.path.exists(CSV_FILE):
        print(f"Error: {CSV_FILE} not found!")
        print("Please create a CSV file with the required features.")
        return
    
    # Load data
    df = load_data()
    
    # Prepare features
    X, y = prepare_features(df)
    
    # Train model
    model = train_model(X, y)
    
    # Save model
    save_model(model)
    
    print("\n" + "=" * 50)
    print("Training completed successfully!")
    print("=" * 50)

if __name__ == "__main__":
    main()

