FROM python:3.10-slim

WORKDIR /app

# Copy requirements
# Copy requirements
COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --force-reinstall -r requirements.txt

# Copy backend files
COPY ml ./ml
COPY main.py ./main.py

EXPOSE 8000

CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
