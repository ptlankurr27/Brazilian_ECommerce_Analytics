# Brazilian-ECommerece-Analysis

# Olist E-Commerce: Late Delivery Prediction

An end-to-end machine learning project that predicts late deliveries using the Olist Brazilian E-Commerce dataset. The workflow combines **Python, SQL, SQLite, and machine learning** to transform raw data into actionable delivery-risk insights.

## Project Workflow

Raw CSVs → Data Cleaning → SQL Feature Engineering → EDA → Model Training → Evaluation → Power BI Dashboard

## Tech Stack

- **Python:** Pandas, NumPy, Scikit-learn, Matplotlib, Seaborn
- **SQL:** SQLite, JOINs, aggregations, date functions
- **Machine Learning:** Logistic Regression, Random Forest, Gradient Boosting
- **Evaluation:** Precision, Recall, F1-score, Confusion Matrix


## Key Steps

1. **Data preparation:** Loaded nine relational CSV tables into SQLite.
2. **SQL feature engineering:** Joined and aggregated order, payment, product, seller, and customer data.
3. **Target creation:** Classified delivered orders as late or on-time using actual versus estimated delivery dates.
4. **Data leakage prevention:** Removed features that relied on information unavailable at prediction time.
5. **Model comparison:** Evaluated Logistic Regression, Random Forest, and Gradient Boosting.

## Model Results

| Model | Accuracy | Late Recall | Late Precision | Late-class F1 (CV) |
|---|---:|---:|---:|---:|
| Logistic Regression | 60.6% | 61% | 12% | 0.200 |
| Random Forest | 74.5% | 60% | 18% | **0.270** |
| Gradient Boosting | 91.9% | 2% | 54% | 0.026 |

**Best model: Random Forest**, selected based on cross-validated F1-score for late deliveries.

Only about 8.1% of delivered orders were late, making accuracy alone misleading. The project prioritizes late-delivery recall, precision, and F1-score.

## Key Findings

- Purchase month and estimated delivery window were the strongest reported predictors.
- Seller-to-customer distance and freight charges also contributed to predictions.
- Removing post-delivery information prevented target leakage and produced more realistic results.
- Predicting delays using order-time features alone remains challenging.

Activate the virtual environment before installing dependencies if required. Update the commands if your scripts use different paths.

## Dataset

[Olist Brazilian E-Commerce Dataset — Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

The dataset contains nine related tables covering orders, customers, products, sellers, payments, reviews, and delivery information.

## Limitations

The model's late-delivery F1-score is modest, reflecting the difficulty of predicting delays without post-shipment information. Results are based on historical Olist data and should not be interpreted as guarantees of future delivery performance.

*This project demonstrates relational data preparation, SQL-based feature engineering, machine learning, and evaluation under class imbalance.*
