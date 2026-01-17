from fastapi import FastAPI
from pydantic import BaseModel
import os

app = FastAPI(
    title="Explanation AI Service",
    description="Lightweight explanation generator for fraud predictions",
    version="1.0.0"
)
@app.get("/")
def root():
    return {"service": "FraudGuard Explanation API"}


class PredictionDetails(BaseModel):
    transactionAmount: float
    transactionAmountDeviation: float
    timeAnomaly: float
    locationDistance: float
    merchantNovelty: float
    transactionFrequency: float
    isFraud: bool
    riskScore: float
    language: str = "en"

class ExplanationResponse(BaseModel):
    explanation: str

# Localization dictionary
LOCALIZATION = {
    "en": {
        "fraudulent": "fraudulent",
        "legitimate": "legitimate",
        "intro": "This transaction was classified as {status} with a risk score of {score}%.",
        "decision": "The decision was based on: {reasons}.",
        "reasons": {
            "amount": "unusually high transaction amount",
            "location": "transaction from a distant location",
            "merchant": "new or unfamiliar merchant",
            "time": "unusual transaction time",
            "frequency": "abnormally high transaction frequency",
            "normal": "normal spending behavior"
        }
    },
    "hi": {
        "fraudulent": "धोखाधड़ी (fraudulent)",
        "legitimate": "वैध (legitimate)",
        "intro": "इस लेन-देन को {score}% जोखिम स्कोर के साथ {status} वर्गीकृत किया गया था।",
        "decision": "यह निर्णय निम्नलिखित कारणों पर आधारित था: {reasons}।",
        "reasons": {
            "amount": "असामान्य रूप से उच्च लेनदेन राशि",
            "location": "दूर के स्थान से लेनदेन",
            "merchant": "नया या अपरिचित व्यापारी",
            "time": "असामान्य लेनदेन का समय",
            "frequency": "असामान्य रूप से उच्च लेनदेन आवृत्ति",
            "normal": "सामान्य खर्च व्यवहार"
        }
    },
    "mr": {
        "fraudulent": "फसवणूक (fraudulent)",
        "legitimate": "कायदेशीर (legitimate)",
        "intro": "हा व्यवहार {score}% जोखीम स्कोअरसह {status} म्हणून वर्गीकृत केला गेला.",
        "decision": "हा निर्णय खालील कारणांवर आधारित होता: {reasons}.",
        "reasons": {
            "amount": "असाधारणपणे जास्त व्यवहाराची रक्कम",
            "location": "दूरच्या ठिकाणाहून व्यवहार",
            "merchant": "नवीन किंवा अपरिचित व्यापारी",
            "time": "व्यवहाराची असामान्य वेळ",
            "frequency": "असाधारणपणे जास्त व्यवहार वारंवारता",
            "normal": "सामान्य खर्च वर्तन"
        }
    }
}

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.post("/explain", response_model=ExplanationResponse)
async def explain(details: PredictionDetails):
    # Default to English if language not supported
    lang = details.language if details.language in LOCALIZATION else "en"
    loc = LOCALIZATION[lang]
    
    status = loc["fraudulent"] if details.isFraud else loc["legitimate"]

    reasons = []
    r_text = loc["reasons"]

    if details.transactionAmountDeviation > 0.5:
        reasons.append(r_text["amount"])
    if details.locationDistance > 20:
        reasons.append(r_text["location"])
    if details.merchantNovelty > 0.7:
        reasons.append(r_text["merchant"])
    if details.timeAnomaly > 0.6:
        reasons.append(r_text["time"])
    if details.transactionFrequency > 10:
        reasons.append(r_text["frequency"])

    if not reasons:
        reasons.append(r_text["normal"])

    explanation = (
        f"{loc['intro'].format(status=status, score=f'{details.riskScore * 100:.1f}')} "
        f"{loc['decision'].format(reasons=', '.join(reasons))}"
    )

    return ExplanationResponse(explanation=explanation)

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8001))
    uvicorn.run(app, host="0.0.0.0", port=port)
