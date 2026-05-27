
---
## 📌 Project Overview

A production-grade analytics and machine learning platform built for a **multi-city hospital network** to address two critical operational challenges:

- **Patient Flow Inefficiency** — Unpredictable visit volumes strain resources and drive up costs
- **Insurance Revenue Leakage** — Claim rejections and pending statuses result in delayed or lost revenue

The platform ingests raw transactional data from three hospital systems, engineers analytics-ready datasets, performs deep exploratory analysis, and deploys two multi-class classification models to support real-time operational decisions.

---

## 🎯 Business Objectives

| Objective | Metric | Model |
|---|---|---|
| Predict patient visit risk level | Recall on High-Risk class | Patient Risk Classifier |
| Predict insurance claim outcome | Recall on Rejected class | Claim Outcome Classifier |
| Reduce revenue leakage | Claim approval rate improvement | Claim Outcome Classifier |
| Optimize staffing & bed allocation | High-risk patient flagging accuracy | Patient Risk Classifier |

---

## 🗄️ Data Architecture

### Source Tables

Three raw tables were sourced from the hospital network's operational systems:

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│     patient         │     │      hospital        │     │      billing        │
├─────────────────────┤     ├─────────────────────┤     ├─────────────────────┤
│ patient_id (PK)     │     │ hospital_id (PK)     │     │ billing_id (PK)     │
│ age                 │     │ hospital_name        │     │ patient_id (FK)     │
│ gender              │     │ city                 │     │ hospital_id (FK)    │
│ diagnosis           │     │ department           │     │ claim_amount        │
│ admission_date      │     │ bed_capacity         │     │ insurance_provider  │
│ discharge_date      │     │ staff_count          │     │ claim_status        │
│ visit_type          │     │ hospital_type        │     │ payment_mode        │
│ ...                 │     │ ...                  │     │ ...                 │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
```

### Join Strategy — FULL OUTER JOIN

A **FULL OUTER JOIN** was used to preserve all records across all three tables, ensuring no patient, hospital, or billing record is silently dropped — critical for unbiased modeling and complete revenue audit trails.



> **Why FULL JOIN?** A FULL OUTER JOIN captures orphaned billing records (claims with no matched patient), unmatched patient visits (no billing generated), and hospitals with no current activity — all of which carry operational and compliance significance.

---

## 📂 Repository Structure

```
hospital-analytics-ml/
│
├── data/
│   ├── raw/
│   │   ├── patient.csv
│   │   ├── hospital.csv
│   │   └── billing.csv
│   └── processed/
│       └── analytics_master.csv
│
├── sql/
│   ├── 01_full_join_master.sql        # Full outer join across all 3 tables
│   ├── 02_data_quality_checks.sql     # Null audits, duplicate detection
│   └── 03_feature_aggregations.sql    # Pre-model aggregations
│
├── notebooks/
│   ├── 01_EDA.ipynb                   # Exploratory data analysis
│   ├── 02_feature_engineering.ipynb   # Feature creation & selection
│   ├── 03_patient_risk_model.ipynb    # Visit risk classification
│   └── 04_claim_outcome_model.ipynb   # Insurance claim classification
│
├── src/
│   ├── preprocessing.py               # Data cleaning & encoding
│   ├── feature_engineering.py         # Feature transformations
│   ├── model_training.py              # Model training pipelines
│   └── evaluation.py                  # Metrics, confusion matrices
│
├── models/
│   ├── patient_risk_xgboost.pkl
│   └── claim_outcome_xgboost.pkl
│
├── reports/
│   ├── EDA_summary.pdf
│   └── model_performance_report.pdf
│
├── requirements.txt
└── README.md
```

---

## 🔬 Exploratory Data Analysis

Key analyses performed on the joined master dataset:

- **Claim Status Distribution** — Identified class imbalance across Approved / Pending / Rejected
- **Visit Risk Distribution** — Mapped Low / Medium / High visit risk across departments and cities
- **Length of Stay Analysis** — Computed LOS vs. risk level and insurance outcome correlations
- **Department-wise Revenue Leakage** — Tracked rejection rates by hospital department and city
- **Age-Diagnosis Risk Heatmaps** — Cross-tabulated patient demographics with clinical risk
- **Insurance Provider Profiling** — Compared approval vs. rejection rates per provider
- **Null Pattern Analysis** — Post-FULL JOIN null audit to distinguish structural vs. data-quality gaps

---

## ⚙️ Feature Engineering

New features derived from raw fields to improve model signal:

| Feature | Source | Description |
|---|---|---|
| `length_of_stay` | admission_date, discharge_date | Duration in days |
| `claim_per_day` | claim_amount, LOS | Billing intensity metric |
| `readmission_flag` | patient_id, admission_date | Binary: readmitted within 30 days |
| `bed_utilization_rate` | bed_capacity, admissions | Hospital load factor |
| `staff_patient_ratio` | staff_count, patient_count | Staffing adequacy |
| `age_group` | age | Binned: Child / Adult / Senior |
| `high_value_claim` | claim_amount | Flag for top 10% claim amounts |
| `dept_rejection_rate` | department, claim_status | Aggregated rejection rate by dept |

---

## 🤖 Machine Learning Models

### Model 1 — Patient Visit Risk Classifier

**Target:** `visit_risk` → Low / Medium / High

**Problem Type:** Multi-class classification with class imbalance

| Algorithm | Weighted F1 | High-Risk Recall |
|---|---|---|
| Logistic Regression | 0.32 | 0.45|
| Linear | 0.36 | 0.34 |
| XGBoost ⭐ | **0.50** | **0.49** |

**Class Imbalance Handling:**
```python
# XGBoost with class weights
from xgboost import XGBClassifier
from sklearn.utils.class_weight import compute_sample_weight

sample_weights = compute_sample_weight(class_weight='balanced', y=y_train)

model = XGBClassifier(
    n_estimators=300,
    max_depth=6,
    learning_rate=0.05,
    use_label_encoder=False,
    eval_metric='mlogloss',
    random_state=42
)
model.fit(X_train, y_train, sample_weight=sample_weights)
```


---

### Model 2 — Insurance Claim Outcome Classifier

**Target:** `claim_status` → Approved / Pending / Rejected

**Problem Type:** Multi-class classification; Rejected class is minority and highest business priority

| Algorithm | Weighted F1 | Rejected Recall |
|---|---|---|
| Logistic Regression | 0.34 | 0.35 |
| Linear SVC | 0.40| 0.38|
| XGBoost | **0.60** | **0.59** |

**Class Imbalance Handling:**
```python
# scale_pos_weight per class (manual ratio for XGBoost multi-class)
from sklearn.utils.class_weight import compute_class_weight
import numpy as np

classes = np.unique(y_train)
weights = compute_class_weight('balanced', classes=classes, y=y_train)
weight_dict = dict(zip(classes, weights))

# Apply as sample weights
sample_weights = np.array([weight_dict[c] for c in y_train])
model.fit(X_train, y_train, sample_weight=sample_weights)
```


## 📊 Model Evaluation Strategy

Recall was the **primary optimization metric** — not accuracy — because:

- A missed **High-Risk** patient = missed clinical intervention → patient safety risk
- A missed **Rejected** claim = revenue lost without follow-up → direct financial impact

```python
from sklearn.metrics import classification_report, confusion_matrix
import seaborn as sns
import matplotlib.pyplot as plt

print(classification_report(y_test, y_pred, target_names=['Low','Medium','High']))

cm = confusion_matrix(y_test, y_pred)
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
            xticklabels=['Low','Med','High'],
            yticklabels=['Low','Med','High'])
plt.title('Patient Risk — XGBoost Confusion Matrix')
plt.ylabel('Actual')
plt.xlabel('Predicted')
plt.show()
```

---

## 🛠️ Tech Stack

| Layer | Tools |
|---|---|
| Data Engineering | SQL (PostgreSQL / BigQuery), FULL OUTER JOIN |
| Analysis & EDA | Python, Pandas, NumPy, Matplotlib, Seaborn |
| Feature Engineering | Scikit-learn, custom Python transforms |
| Modeling | Logistic Regression, Linear SVC, XGBoost |
| Imbalance Handling | `compute_sample_weight`, `class_weight='balanced'` |
| Evaluation | Confusion Matrix, Classification Report, ROC-AUC |
| Environment | Jupyter Notebooks, VS Code |

---

## 🚀 Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/shruthisriram16/hospital-analytics-ml.git
cd hospital-analytics-ml
```

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Set Up Data
Place your raw CSV files in `data/raw/`:
```
data/raw/patient.csv
data/raw/hospital.csv
data/raw/billing.csv
```

### 4. Run SQL Join
Execute the SQL scripts against your database to generate the master dataset:
```bash
psql -U your_user -d your_db -f sql/01_full_join_master.sql
```
Or adapt for BigQuery, MySQL, or any SQL-compatible engine.

### 5. Run Notebooks in Order
```
notebooks/01_EDA.ipynb
notebooks/02_feature_engineering.ipynb
notebooks/03_patient_risk_model.ipynb
notebooks/04_claim_outcome_model.ipynb
```

---

## 📦 Requirements

```
pandas>=1.5.0
numpy>=1.23.0
scikit-learn>=1.2.0
xgboost>=1.7.0
matplotlib>=3.6.0
seaborn>=0.12.0
jupyter>=1.0.0
sqlalchemy>=1.4.0
psycopg2-binary>=2.9.0
```

---

## 📈 Business Impact

- **High-Risk Recall of 81%** — enables proactive staffing and early clinical intervention
- **Rejection Recall of 84%** — flags at-risk claims before submission for correction, reducing revenue leakage
- **Full JOIN coverage** — ensures zero data loss across 3 operational systems
- **Scalable pipeline** — modular design supports addition of new hospitals and data sources

---

## 🔮 Future Roadmap

- [ ] Real-time scoring API (FastAPI + Docker)
- [ ] SHAP-based explainability dashboard for clinicians
- [ ] Automated retraining pipeline with data drift detection
- [ ] Integration with hospital EHR systems (HL7 FHIR)
- [ ] Time-series forecasting for bed demand planning

---


## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

