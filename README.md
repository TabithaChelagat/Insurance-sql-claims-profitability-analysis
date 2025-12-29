# Insurance Claims Risk, Customer Profitability & Fraud Detection
## 📌 Project Overview
This project demonstrates advanced SQL analytics within the insurance industry. It focuses on identifying high-value customers, assessing policy risk through loss ratio analysis, and detecting suspicious claim patterns. The project utilizes a robust database schema to bridge the gap between technical data management and actionable business intelligence.

## 📊 Business Questions Answered
* Who are our most valuable policyholders? Identified top-tier customers by lifetime value (LTV) for retention programs.

* Which policies are profitable vs. unprofitable? Calculated loss ratios to find segments where payouts exceed premiums.

* Who files unusually many claims? Detected potential opportunistic fraud through frequency analysis.

* What are claim trends over time? Analyzed seasonal volatility to assist in cash reserve planning.

* How do we optimize data delivery for dashboards? Implemented materialized views and strategic indexing for scalable reporting.

## 💡 Key Findings & Insights
* Revenue Leaders: Abigail Martinez ($57,223), Robert Davis ($53,735), and Isabella Lopez ($48,348) represent the highest revenue-generating segment.

* Risk Mitigation: High-risk outliers like Avery Rodriguez were identified with loss ratios exceeding 200%, signaling an immediate need for underwriting review.

* Fraud Detection: The analysis flagged 154 claims filed within the first 30 days of policy activation, a major indicator of pre-existing damage.

* Anomaly Alerts: Policy IDs 39 and 356 were flagged for filing 7 claims each, significantly above the statistical norm.

* Transaction Patterns: 38.7% of high-value customers prefer Credit Card payments, suggesting an opportunity to increase "Auto-Pay" enrollment.

## 🛠️ Technical Implementation
* Data Quality Layer: Implemented rigorous checks for NULL values, duplicate records, and logical date validation to ensure financial accuracy.

* Advanced Analytics: Utilized Window Functions (RANK, LAG, PERCENT_RANK) for complex customer segmentation and trend analysis.

* Performance Optimization: Created B-Tree indexes and Materialized Views to ensure sub-second query response times for executive dashboards.

* Robust Calculations: Applied NULLIF and COALESCE to prevent division-by-zero errors and handle missing data gracefully.

## 📂 Project Structure
* insurance_sql_portfolio.sql: The main script containing schema creation, data validation, and analytical queries.

* policyholders.csv, policies.csv, claims.csv, payments.csv: The raw datasets used for the analysis.

## 🎯 Conclusion
This project provides a clear roadmap for transitioning from reactive claims processing to proactive risk management. By identifying high-LTV customers and automating fraud triggers, the organization can significantly reduce operational overhead and improve the overall health of its insurance portfolio.
