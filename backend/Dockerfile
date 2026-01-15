FROM python:3.10-slim

WORKDIR /app

# Copy requirements from current context (backend/)
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy all backend source code
COPY . .

# Expose port (Railway injects PORT)
EXPOSE 8000

# Run FastAPI
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
