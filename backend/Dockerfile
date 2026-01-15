# Use Python 3.10 base image
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Copy requirements from current context (backend/)
COPY backend/requirements.txt ./requirements.txt

# Install dependencies with no cache to force fresh install
RUN pip install --no-cache-dir --force-reinstall -r requirements.txt

# Copy backend main.py
COPY backend/main.py ./main.py

# Copy ML model
COPY backend/ml/model.pkl ./ml/model.pkl

# Expose port (Railway injects PORT)
EXPOSE 8000

# Run FastAPI
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
