# ✅ DEPLOYMENT GUIDE — FRAUDGUARD AI A2 (UPDATED)

This guide is updated for the **A2** version of the project. I have already configured the Dockerfiles and requirements to match the instructions below.

> **Goal:** Deploy the FraudGuard A2 system with ML backend, Explanation Service, and Flutter Web App.

---

## 🔹 STEP 1: Repository Structure (VERIFIED)

Your project is already structured correctly:

```
Fraudguard-AI-A2/
├── backend/                       # ML Service (Root Directory)
│   ├── Dockerfile                 # UPDATED
│   ├── main.py
│   ├── requirements.txt
│   └── ml/                        # Contains model_fast.pkl & model_accurate.pkl
│
├── backend/explanation_service/   # Explanation Service (Root Directory)
│   ├── Dockerfile                 # UPDATED
│   ├── main.py
│   └── requirements.txt           # OPTIMIZED
│
└── flutter_app/fraud_detector/    # Flutter Web App
    ├── lib/
    ├── web/
    └── pubspec.yaml
```

---

## 🔹 STEP 2: Deploy Explanation Service (Railway)

1. Create a **new Railway service** (GitHub Repo).
2. Connect `Fraudguard-AI-A2` repo.
3. **Settings > General > Build Command**: Leave empty.
4. **Settings > General > Root Directory**:
   *   Set to: `backend/explanation_service`
   *   *(This is crucial so it finds the correct Dockerfile)*
5. **Deploy**.
6. **Settings > Networking**: Generate a Domain (e.g., `explanation-production.up.railway.app`).
7. **Verify**:
   ```
   GET https://<your-explanation-domain>/health → {"status":"ok"}
   ```

---

## 🔹 STEP 3: Deploy ML Service (Railway)

1. Create another **Railway service** (GitHub Repo).
2. Connect `Fraudguard-AI-A2` repo.
3. **Settings > General > Root Directory**:
   *   Set to: `backend`
4. **Settings > Variables**:
   *   Add variable: `EXPLANATION_SERVICE_URL`
   *   Value: `https://<your-explanation-domain>` (No trailing slash, or `/explain` if using complete path from code logic. *Code expects base URL*, it appends `/explain` itself. So use `https://...up.railway.app`)
     *   *Correction based on code:* `backend/main.py` does `f"{EXPLANATION_SERVICE_URL}/explain"`.
     *   So set `EXPLANATION_SERVICE_URL` to: `https://<your-explanation-domain>`
5. **Deploy**.
6. **Settings > Networking**: Generate a Domain (e.g., `ml-production.up.railway.app`).
7. **Verify**:
   ```
   GET https://<your-ml-domain>/health → {"status":"ok", "models_loaded": ...}
   ```

---

## 🔹 STEP 4: Configure Flutter App

1. Open `flutter_app/fraud_detector/lib/services/api_service.dart`.
2. Update the `baseUrl`:
   ```dart
   static const String baseUrl = "https://<your-ml-domain>";
   ```
   *(Remove any trailing slash)*

---

## 🔹 STEP 5: Build & Deploy Flutter Web

1. **Open Terminal** in `flutter_app/fraud_detector`:
   ```bash
   cd flutter_app/fraud_detector
   ```

2. **Build Web**:
   *   **Important**: The `base-href` must match your GitHub Repository name exactly.
   *   If your repo is `Fraudguard-AI-A2`, run:
     ```bash
     flutter build web --base-href "/Fraudguard-AI-A2/"
     ```

3. **Deploy to GitHub Pages**:
   ```bash
   npx gh-pages -d build/web
   ```

4. **GitHub Settings**:
   *   Go to Verification > Pages.
   *   Source: Deploy from branch `gh-pages` / `root`.

---

## 🔹 STEP 6: Final Verification

1. Open your GitHub Pages URL: `https://<user>.github.io/Fraudguard-AI-A2/`
2. Upload `test_transactions.csv` (found in project root).
3. Verify that predictions appear and clicking one shows an AI explanation.
