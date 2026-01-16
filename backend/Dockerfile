FROM python:3.10-slim

WORKDIR /app

# Copy requirements
COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --force-reinstall -r requirements.txt

# Create ml directory before copying model
RUN mkdir -p ml

# Copy backend files
COPY backend/main.py ./main.py
COPY backend/ml/model.pkl ./ml/model.pkl

EXPOSE 8000

CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
