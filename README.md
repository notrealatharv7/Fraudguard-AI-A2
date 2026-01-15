# Fraud Detection System

A hackathon-ready fraud detection application with ML-powered backend and Flutter frontend.

## Project Structure

```
fraudguard/
├── ml/                    # Machine Learning
│   ├── train_model.py     # Model training script
│   ├── fraud_data.csv     # Training dataset (350 rows)
│   └── model.pkl          # Trained model (generated after training)
│
├── backend/               # FastAPI Backend
│   ├── main.py            # API server
│   ├── requirements.txt   # Python dependencies
│   └── Dockerfile         # Docker configuration
│
└── flutter_app/           # Flutter Frontend
    └── fraud_detector/    # Flutter application
        ├── lib/
        │   ├── main.dart
        │   ├── screens/
        │   ├── models/
        │   └── services/
        └── pubspec.yaml
```

## Quick Start

### 1. Train the ML Model

```bash
cd ml
python train_model.py
```

This will:
- Load `fraud_data.csv`
- Train a RandomForestClassifier
- Save the model as `model.pkl`
- Display accuracy metrics

### 2. Run the Backend API

#### Option A: Using Docker (Recommended)

```bash
# Build the Docker image (from project root)
docker build -f backend/Dockerfile -t fraud-api .

# Run the container
docker run -p 8000:8000 fraud-api
```

#### Option B: Local Python

```bash
# Install dependencies (from project root)
pip install -r backend/requirements.txt

# Start server (from project root)
python start_backend.py
```

**Note:** The server must run from the project root so it can find the `ml/model.pkl` file.

The API will be available at:
- API: `http://localhost:8000`
- Swagger Docs: `http://localhost:8000/docs`

### 3. Run the Flutter App

```bash
cd flutter_app/fraud_detector
flutter pub get
flutter run
```

**Important:** Update the API URL in `lib/services/api_service.dart`:
- Android Emulator: `http://10.0.2.2:8000`
- iOS Simulator: `http://localhost:8000`
- Physical Device: `http://YOUR_COMPUTER_IP:8000`

## Features

### Backend
- ✅ FastAPI REST API
- ✅ `/predict` endpoint with JSON I/O
- ✅ Swagger documentation at `/docs`
- ✅ Dockerized deployment
- ✅ RandomForestClassifier ML model
- ✅ CORS enabled for Flutter

### Frontend
- ✅ Material 3 UI design
- ✅ Form-based input for 6 transaction features
- ✅ Real-time fraud prediction
- ✅ Visual feedback (Green = Legit, Red = Fraud)
- ✅ Risk score percentage display
- ✅ Error handling and loading states

## API Endpoint

**POST** `/predict`

**Request:**
```json
{
  "transactionAmount": 150.50,
  "transactionAmountDeviation": 0.25,
  "timeAnomaly": 0.3,
  "locationDistance": 25.0,
  "merchantNovelty": 0.2,
  "transactionFrequency": 5
}
```

**Response:**
```json
{
  "fraud": false,
  "risk_score": 0.23
}
```

## Input Features

The model uses exactly these 6 features (in order):
1. `transactionAmount` (float) - Transaction amount
2. `transactionAmountDeviation` (float) - Amount deviation from normal
3. `timeAnomaly` (float, 0-1) - Time anomaly score
4. `locationDistance` (float) - Distance from usual location
5. `merchantNovelty` (float, 0-1) - Merchant novelty score
6. `transactionFrequency` (float) - Transaction frequency

## Technologies

- **Backend:** Python 3.10, FastAPI, scikit-learn, Docker
- **Frontend:** Flutter, Material 3, HTTP package
- **ML:** RandomForestClassifier, pandas, joblib

## Development Order

1. ✅ ML training script
2. ✅ Backend API
3. ✅ Dockerization
4. ✅ Flutter UI
5. ✅ API integration
6. ✅ UI polish

## License

Hackathon Project - Educational Use

