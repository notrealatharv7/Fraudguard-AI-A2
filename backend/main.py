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

# Model path - works both locally and in Docker
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

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
    language: Literal["en", "hi", "mr"] = Field(default="en", description="Language for explanation: 'en', 'hi', 'mr'")

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

# Explanation service URL
# - Local/Docker: http://explanation_service:8001/explain
# - Railway: set EXPLANATION_SERVICE_URL in Railway Variables
EXPLANATION_SERVICE_URL = os.getenv(
    "EXPLANATION_SERVICE_URL",
    "http://127.0.0.1:8001"
)

import asyncio

# Global variables for loaded models
models = {
    "fast": None,
    "accurate": None
}

# Model paths
MODEL_FAST_PATH = os.path.join(BASE_DIR, "ml", "model_fast.pkl")
MODEL_ACCURATE_PATH = os.path.join(BASE_DIR, "ml", "model_accurate.pkl")
# Fallback to old model if specific ones don't exist
MODEL_DEFAULT_PATH = os.path.join(BASE_DIR, "ml", "model.pkl")

def load_model():
    """Load the trained ML models from disk."""
    global models
    try:
        # Load Fast Model
        if os.path.exists(MODEL_FAST_PATH):
            models["fast"] = joblib.load(MODEL_FAST_PATH)
            print(f"[OK] Fast model loaded from {MODEL_FAST_PATH}")
        elif os.path.exists(MODEL_DEFAULT_PATH):
             models["fast"] = joblib.load(MODEL_DEFAULT_PATH)
             print(f"[WARN] Fast model not found, using default {MODEL_DEFAULT_PATH}")

        # Load Accurate Model
        if os.path.exists(MODEL_ACCURATE_PATH):
            models["accurate"] = joblib.load(MODEL_ACCURATE_PATH)
            print(f"[OK] Accurate model loaded from {MODEL_ACCURATE_PATH}")
        elif os.path.exists(MODEL_DEFAULT_PATH):
             models["accurate"] = joblib.load(MODEL_DEFAULT_PATH)
             print(f"[WARN] Accurate model not found, using default {MODEL_DEFAULT_PATH}")

        if models["fast"] is None and models["accurate"] is None:
             raise FileNotFoundError("No models could be loaded")

    except Exception as e:
        print(f"[ERROR] Error loading models: {str(e)}")
        raise

@app.on_event("startup")
async def startup_event():
    load_model()
    if not os.path.exists(FRAUD_HISTORY_FILE):
        save_fraud_history({})

@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "models_loaded": {
            "fast": models["fast"] is not None,
            "accurate": models["accurate"] is not None
        }
    }

@app.post("/predict", response_model=FraudPrediction)
async def predict_fraud(transaction: TransactionInput):
    print(f"[DEBUG] Received prediction request. Mode: {transaction.mode}")
    # Select mode and model
    mode = transaction.mode
    model = models.get(mode)
    
    # Fallback if specific model not loaded
    if model is None:
        model = models.get("fast") or models.get("accurate")
    
    if model is None:
        raise HTTPException(status_code=500, detail="No models loaded")
    
    try:
        # Artificial delay for "Deep Analysis" to simulate complexity
        if mode == "accurate":
            await asyncio.sleep(2)  # 2 second delay

        # Prepare features in the exact order used during training
        features = np.array([[
            transaction.transactionAmount,
            transaction.transactionAmountDeviation,
            transaction.timeAnomaly,
            transaction.locationDistance,
            transaction.merchantNovelty,
            transaction.transactionFrequency
        ]])
        
        # Get prediction (0 = Legit, 1 = Fraud)
        prediction = model.predict(features)[0]
        
        # Get probability/confidence score
        probabilities = model.predict_proba(features)[0]
        fraud_probability = probabilities[1]  # Probability of fraud (class 1)
        
        # Convert to boolean and return
        is_fraud = bool(prediction == 1)
        
        # Get AI explanation
        explanation = get_ai_explanation(transaction, is_fraud, fraud_probability)

        # Update history and check for recurring fraud
        fraud_count = update_fraud_history(transaction.upiId, is_fraud)
        is_recurring = is_recurring_fraud_upi(transaction.upiId)

        return FraudPrediction(
            fraud=is_fraud,
            risk_score=round(float(fraud_probability), 4),
            model_used=mode,
            recurring_fraud_upi=is_recurring,
            fraud_count=fraud_count,
            explanation=explanation
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Prediction error: {str(e)}"
        )

def get_ai_explanation(transaction: TransactionInput, is_fraud: bool, risk_score: float) -> Optional[str]:
    """Calls the explanation service to get an AI-generated explanation."""
    url = f"{EXPLANATION_SERVICE_URL}/explain"
    
    payload = {
        "transactionAmount": transaction.transactionAmount,
        "transactionAmountDeviation": transaction.transactionAmountDeviation,
        "timeAnomaly": transaction.timeAnomaly,
        "locationDistance": transaction.locationDistance,
        "merchantNovelty": transaction.merchantNovelty,
        "transactionFrequency": transaction.transactionFrequency,
        "isFraud": is_fraud,
        "riskScore": risk_score,
        "language": transaction.language
    }
    
    try:
        # Increased timeout to 30 seconds to handle model generation time
        response = requests.post(url, json=payload, timeout=30)
        response.raise_for_status() # Raise an exception for bad status codes (4xx or 5xx)
        result = response.json().get("explanation")
        if result:
            return result
        else:
            print("[WARNING] Explanation service returned empty explanation")
            return None
    except requests.exceptions.Timeout:
        print("[ERROR] Explanation service timeout (exceeded 30 seconds)")
        return "AI explanation service is taking too long to respond."
    except requests.exceptions.ConnectionError as e:
        print(f"[ERROR] Could not connect to explanation service at {url}: {e}")
        return "AI explanation service is currently unavailable."
    except requests.exceptions.RequestException as e:
        print(f"[ERROR] Error calling explanation service: {type(e).__name__}: {e}")
        return "AI explanation service encountered an error."
    except Exception as e:
        print(f"[ERROR] Unexpected error getting explanation: {type(e).__name__}: {e}")
        return None

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
