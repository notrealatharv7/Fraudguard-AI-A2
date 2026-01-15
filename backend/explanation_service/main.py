from fastapi import FastAPI
from pydantic import BaseModel
import os

app = FastAPI(
    title="Explanation AI Service",
    description="Lightweight explanation generator for fraud predictions",
    version="1.0.0"
)

class PredictionDetails(BaseModel):
    transactionAmount: float
    transactionAmountDeviation: float
    timeAnomaly: float
    locationDistance: float
    merchantNovelty: float
    transactionFrequency: float
    isFraud: bool
    riskScore: float

class ExplanationResponse(BaseModel):
    explanation: str

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.post("/explain", response_model=ExplanationResponse)
async def explain(details: PredictionDetails):
    status = "fraudulent" if details.isFraud else "legitimate"

    reasons = []

    if details.transactionAmountDeviation > 0.5:
        reasons.append("unusually high transaction amount")
    if details.locationDistance > 20:
        reasons.append("transaction from a distant location")
    if details.merchantNovelty > 0.7:
        reasons.append("new or unfamiliar merchant")
    if details.timeAnomaly > 0.6:
        reasons.append("unusual transaction time")
    if details.transactionFrequency > 10:
        reasons.append("abnormally high transaction frequency")

    if not reasons:
        reasons.append("normal spending behavior")

    explanation = (
        f"This transaction was classified as {status} "
        f"with a risk score of {details.riskScore * 100:.1f}%. "
        f"The decision was based on: {', '.join(reasons)}."
    )

    return ExplanationResponse(explanation=explanation)

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8001))
    uvicorn.run(app, host="0.0.0.0", port=port)
