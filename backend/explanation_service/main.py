from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch
import os

app = FastAPI(
    title="Explanation AI Service",
    description="LLM-based explanation generator using SmolLM2-360M",
    version="2.0.0"
)

# Global model variables
model = None
tokenizer = None
MODEL_NAME = "HuggingFaceTB/SmolLM2-360M-Instruct"

class PredictionDetails(BaseModel):
    transactionAmount: float
    transactionAmountDeviation: float
    timeAnomaly: float
    locationDistance: float
    merchantNovelty: float
    transactionFrequency: float
    isFraud: bool
    riskScore: float
    language: str = "en"  # "en", "hi", "mr"

class ExplanationResponse(BaseModel):
    explanation: str

# ----------------- PROMPTS -----------------

SYSTEM_PROMPT = """You are FraudGuard AI, a financial fraud explanation assistant.

Your job is to explain why a transaction is marked as FRAUD or SAFE
using simple, factual language.

Rules:
- Do NOT guess or add new facts
- Only use the values provided
- Keep explanations short and clear
- No emojis
- No technical jargon
- Max 5 bullet points
- Be calm and professional
"""

USER_PROMPT_TEMPLATE = """Explain this transaction decision.

Language: {language}

Transaction details:
- Amount: ₹{transactionAmount}
- Amount deviation score: {transactionAmountDeviation}
- Time anomaly score: {timeAnomaly}
- Location distance (km): {locationDistance}
- Merchant novelty score: {merchantNovelty}
- Transaction frequency score: {transactionFrequency}

Final prediction:
- Fraud: {isFraud}

Output format:
1-line verdict
Bullet point reasons (max 5)
Short safety advice (1 line)
"""

# ----------------- LOGIC -----------------

def load_model():
    global model, tokenizer
    print(f"Loading model: {MODEL_NAME}...")
    try:
        tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
        model = AutoModelForCausalLM.from_pretrained(
            MODEL_NAME,
            torch_dtype=torch.float32, # CPU friendly
            device_map="cpu",          # Force CPU for Railway compatibility
            low_cpu_mem_usage=True
        )
        print("Model loaded successfully.")
    except Exception as e:
        print(f"Error loading model: {e}")
        # In production, we might want to crash if model fails, or fallback
        raise e

@app.on_event("startup")
async def startup_event():
    load_model()

@app.get("/")
def root():
    return {"service": "FraudGuard LLM Explanation Service"}

@app.get("/health")
async def health():
    return {
        "status": "ok", 
        "model_loaded": model is not None
    }

@app.post("/explain", response_model=ExplanationResponse)
async def explain(details: PredictionDetails):
    if model is None or tokenizer is None:
        raise HTTPException(status_code=503, detail="Model not initialized")

    # Format the user prompt
    user_prompt = USER_PROMPT_TEMPLATE.format(
        language=details.language,
        transactionAmount=details.transactionAmount,
        transactionAmountDeviation=details.transactionAmountDeviation,
        timeAnomaly=details.timeAnomaly,
        locationDistance=details.locationDistance,
        merchantNovelty=details.merchantNovelty,
        transactionFrequency=details.transactionFrequency,
        isFraud=str(details.isFraud)
    )

    # ChatML structure
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": user_prompt}
    ]

    try:
        input_text = tokenizer.apply_chat_template(messages, tokenize=False)
        inputs = tokenizer(input_text, return_tensors="pt").to("cpu")

        # Generate
        with torch.no_grad():
            outputs = model.generate(
                **inputs, 
                max_new_tokens=200,
                temperature=0.2, # Low temperature for deterministic output
                top_p=0.9,
                do_sample=True 
            )

        # Decode output
        generated_text = tokenizer.decode(outputs[0], skip_special_tokens=True)
        
        # Extract only the response (removing the prompt if included, though decode usually handles this nicely with ChatML if we parse carefully)
        # However, apply_chat_template + decode(skip_special_tokens=True) usually returns the whole conversation in raw text if not careful, 
        # OR just the generation if we handle inputs right.
        # Actually `model.generate` returns input + output. We need to slice.
        
        response_text = tokenizer.decode(outputs[0][inputs.input_ids.shape[1]:], skip_special_tokens=True)
        
        return ExplanationResponse(explanation=response_text.strip())

    except Exception as e:
        print(f"Generation error: {e}")
        return ExplanationResponse(explanation="Error generating explanation.")

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8001))
    uvicorn.run(app, host="0.0.0.0", port=port)
