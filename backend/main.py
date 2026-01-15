"""
Fraud Detection API - FastAPI Backend with Dual Models
This API supports both fast and accurate models, UPI tracking, and recurring fraud detection.
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import joblib
import os
import json
import numpy as np
import requests
from typing import Optional, Literal
from datetime import datetime

# Initialize FastAPI app
app = FastAPI(
    title="Fraud Detection API",
    description="API for detecting fraudulent transactions using dual ML models with UPI tracking",
    version="2.0.0"
)

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables for loaded models
model_fast = None
model_accurate = None

# Explanation service URL
# - Local/Docker: http://explanation_service:8001/explain
# - Railway: set EXPLANATION_SERVICE_URL in Railway Variables
EXPLANATION_SERVICE_URL = os.getenv(
    "EXPLANATION_SERVICE_URL",
    "https://fraudguard-ai-m3-production-619d.up.railway.app"
)


# # Model paths - works both locally and in Docker
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

FAST_MODEL_PATH = os.path.join(BASE_DIR, "ml", "model_fast.pkl")
ACCURATE_MODEL_PATH = os.path.join(BASE_DIR, "ml", "model_accurate.pkl")

FRAUD_HISTORY_FILE = os.path.join(BASE_DIR, "fraud_history.json")


# Pydantic model for request input
class TransactionInput(BaseModel):
    """Input model for transaction data - must match training features exactly."""
    upiId: str = Field(..., description="UPI ID of the transaction")
    transactionAmount: float = Field(..., description="Transaction amount")
    transactionAmountDeviation: float = Field(..., description="Amount deviation from normal")
    timeAnomaly: float = Field(..., ge=0, le=1, description="Time anomaly score (0-1)")
    locationDistance: float = Field(..., description="Distance from usual location")
    merchantNovelty: float = Field(..., ge=0, le=1, description="Merchant novelty score (0-1)")
    transactionFrequency: float = Field(..., description="Transaction frequency")
    mode: Literal["fast", "accurate"] = Field(default="fast", description="Model mode: 'fast' or 'accurate'")

# Pydantic model for response output
class FraudPrediction(BaseModel):
    """Output model for fraud prediction results."""
    fraud: bool
    risk_score: float
    model_used: str
    recurring_fraud_upi: bool
    fraud_count: int
    explanation: Optional[str] = None

# Fraud History Management
def load_fraud_history():
    if os.path.exists(FRAUD_HISTORY_FILE):
        try:
            with open(FRAUD_HISTORY_FILE, "r") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_fraud_history(history):
    with open(FRAUD_HISTORY_FILE, "w") as f:
        json.dump(history, f, indent=2)

def update_fraud_history(upi_id: str, is_fraud: bool):
    history = load_fraud_history()

    if upi_id not in history:
        history[upi_id] = {"fraud_count": 0}

    if is_fraud:
        history[upi_id]["fraud_count"] += 1

    history[upi_id]["last_seen"] = datetime.utcnow().isoformat()
    save_fraud_history(history)

    return history[upi_id]["fraud_count"]

def is_recurring_fraud_upi(upi_id: str) -> bool:
    history = load_fraud_history()
    return history.get(upi_id, {}).get("fraud_count", 0) >= 3

def load_models():
    global model_fast, model_accurate
    model_fast = joblib.load(FAST_MODEL_PATH)
    model_accurate = joblib.load(ACCURATE_MODEL_PATH)

@app.on_event("startup")
async def startup_event():
    load_models()
    if not os.path.exists(FRAUD_HISTORY_FILE):
        save_fraud_history({})

@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "fast_model_loaded": model_fast is not None,
        "accurate_model_loaded": model_accurate is not None
    }

@app.post("/predict", response_model=FraudPrediction)
async def predict_fraud(transaction: TransactionInput):
    model = model_fast if transaction.mode == "fast" else model_accurate

    base_features = [
        transaction.transactionAmount,
        transaction.transactionAmountDeviation,
        transaction.timeAnomaly,
        transaction.locationDistance,
        transaction.merchantNovelty,
        transaction.transactionFrequency
    ]

    if transaction.mode == "accurate":
        features = np.array([base_features + [
            transaction.transactionAmount * transaction.locationDistance,
            transaction.transactionAmountDeviation * transaction.merchantNovelty,
            transaction.timeAnomaly / (transaction.transactionFrequency + 1)
        ]])
    else:
        features = np.array([base_features])

    prediction = model.predict(features)[0]
    probability = model.predict_proba(features)[0][1]
    is_fraud = prediction == 1

    fraud_count = update_fraud_history(transaction.upiId, is_fraud)
    recurring = fraud_count >= 3

    explanation = get_ai_explanation(transaction, is_fraud, probability)

    return FraudPrediction(
        fraud=is_fraud,
        risk_score=round(float(probability), 4),
        model_used=transaction.mode,
        recurring_fraud_upi=recurring,
        fraud_count=fraud_count,
        explanation=explanation
    )

def get_ai_explanation(transaction: TransactionInput, is_fraud: bool, risk_score: float) -> Optional[str]:
    payload = {
        "transactionAmount": transaction.transactionAmount,
        "transactionAmountDeviation": transaction.transactionAmountDeviation,
        "timeAnomaly": transaction.timeAnomaly,
        "locationDistance": transaction.locationDistance,
        "merchantNovelty": transaction.merchantNovelty,
        "transactionFrequency": transaction.transactionFrequency,
        "isFraud": is_fraud,
        "riskScore": risk_score
    }

    try:
        response = requests.post(EXPLANATION_SERVICE_URL, json=payload, timeout=30)
        response.raise_for_status()
        return response.json().get("explanation")
    except Exception:
        return "AI explanation service is currently unavailable."

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
