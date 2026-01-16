FROM python:3.10-slim

WORKDIR /app

# Copy requirements
COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --force-reinstall -r requirements.txt

# Copy service code
COPY main.py ./main.py

EXPOSE 8000

CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
