import os
import sys

# Add the current directory to path so we can import from main
sys.path.append(os.getcwd())

try:
    print("Checking imports...")
    from transformers import AutoModelForCausalLM, AutoTokenizer
    import torch
    print("Imports effective.")

    MODEL_NAME = "HuggingFaceTB/SmolLM2-360M-Instruct"
    print(f"Loading model {MODEL_NAME}...")
    
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModelForCausalLM.from_pretrained(MODEL_NAME)
    print("Model loaded.")
    
    input_text = "Explain why fraud detection is important."
    inputs = tokenizer(input_text, return_tensors="pt")
    
    print("Generating text...")
    outputs = model.generate(**inputs, max_new_tokens=50)
    print(tokenizer.decode(outputs[0]))
    
    print("\nSUCCESS: Model works.")
except ImportError as e:
    print(f"FAILED: Missing dependencies. {e}")
    print("Run: pip install -r requirements.txt")
except Exception as e:
    print(f"FAILED: {e}")
