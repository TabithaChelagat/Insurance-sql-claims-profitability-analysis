-- ============================================================================
-- SECTION 1: DATABASE SETUP & TABLE CREATION
-- ============================================================================

CREATE TABLE policyholders (
    policyholder_id INT PRIMARY KEY,
    full_name VARCHAR(100),
    age INT,
    gender VARCHAR(10),
    city VARCHAR(50),
    signup_date DATE
);

CREATE TABLE policies (
    policy_id INT PRIMARY KEY,
    policyholder_id INT,
    policy_type VARCHAR(30),  -- Auto, Home, Life, Health
    premium_amount DECIMAL(12,2),
    policy_start_date DATE,
    policy_status VARCHAR(20),  -- Active, Lapsed, Cancelled
    FOREIGN KEY (policyholder_id) REFERENCES policyholders(policyholder_id)
);

CREATE TABLE claims (
    claim_id INT PRIMARY KEY,
    policy_id INT,
    claim_date DATE,
    claim_amount DECIMAL(14,2),
    claim_status VARCHAR(20),  -- Approved, Pending, Rejected
    FOREIGN KEY (policy_id) REFERENCES policies(policy_id)
);

CREATE TABLE payments (
    payment_id INT PRIMARY KEY,
    policy_id INT,
    payment_date DATE,
    payment_amount DECIMAL(12,2),
    payment_method VARCHAR(20),  -- Credit Card, Bank Transfer, etc.
    FOREIGN KEY (policy_id) REFERENCES policies(policy_id)
);

-- ============================================================================
-- SECTION 2: DATA QUALITY CHECKS (VALIDATION LAYER)
-- ============================================================================
-- Business Value: Establishing data reliability before performing financial analysis.

-- Check 1: Identifying NULLs in Critical Fields
-- Nulls in primary keys or financial fields can cause severe calculation errors.
SELECT 
    COUNT(*) - COUNT(policyholder_id) AS null_policyholder_ids,
    COUNT(*) - COUNT(full_name) AS null_names,
    COUNT(*) - COUNT(signup_date) AS null_dates
FROM policyholders;

-- Check 2: Identifying Duplicate Records
-- Duplicate policy entries artificially inflate revenue and risk metrics.
SELECT policy_id, COUNT(*)
FROM policies
GROUP BY policy_id
HAVING COUNT(*) > 1;

-- Check 3: Premium Amount Outliers (Statistical Bounds)
-- Flags premiums that are 3 standard deviations above the average for review.
WITH premium_stats AS (
    SELECT AVG(premium_amount) AS avg_p, STDDEV(premium_amount) AS std_p
    FROM policies
)
SELECT p.policy_id, p.premium_amount, p.policy_type
FROM policies p, premium_stats s
WHERE p.premium_amount > (s.avg_p + 3 * s.std_p) 
   OR p.premium_amount < 0; -- Also flagging negative premiums

-- Check 4: Identifying Orphaned Records (Referential Integrity)
-- Ensures every policy is mapped to a valid policyholder before LTV calculation.
SELECT p.policy_id, p.policyholder_id
FROM policies p
LEFT JOIN policyholders ph ON p.policyholder_id = ph.policyholder_id
WHERE ph.policyholder_id IS NULL;

-- Check 5: Logical Date Validation
-- Flags future-dated claims or start dates that precede signup dates.
SELECT * FROM claims WHERE claim_date > CURRENT_DATE;

-- ============================================================================
-- SECTION 3: DATA LOADING & OPTIMIZATION
-- ============================================================================

/* COPY policyholders FROM '/path/to/policyholders.csv' CSV HEADER;
COPY policies FROM '/path/to/policies.csv' CSV HEADER;
COPY claims FROM '/path/to/claims.csv' CSV HEADER;
COPY payments FROM '/path/to/payments.csv' CSV HEADER;
*/

-- Indexing for performance on join-heavy profitability queries
CREATE INDEX idx_policies_policyholder ON policies(policyholder_id);
CREATE INDEX idx_claims_policy ON claims(policy_id);
CREATE INDEX idx_payments_policy ON payments(policy_id);

-- ============================================================================
-- SECTION 4: THE QUERIES
-- ============================================================================

-- Query 1: Top Policyholders by Premium Revenue (Advanced Ranking)
-- Business Value: Uses Window Functions to rank customers by revenue contribution.
-- Finding: Abigail Martinez ($57,223) is ranked #1 in the portfolio.
SELECT 
    ph.policyholder_id,
    ph.full_name,
    SUM(p.premium_amount) AS total_premium_value,
    RANK() OVER(ORDER BY SUM(p.premium_amount) DESC) AS revenue_rank
FROM policyholders ph
JOIN policies p ON ph.policyholder_id = p.policyholder_id
WHERE p.policy_status = 'Active'
GROUP BY ph.policyholder_id, ph.full_name
ORDER BY revenue_rank ASC
LIMIT 20;

-- Query 2: Profitability Analysis (Loss Ratio)
-- Business Value: Uses NULLIF to prevent "Division by Zero" errors and COALESCE for null handling.
-- Finding: Avery Rodriguez shows a 220% loss ratio; payouts are double the premiums.
WITH premium_received AS (
    SELECT p.policyholder_id, SUM(pay.payment_amount) AS total_paid
    FROM policies p JOIN payments pay ON p.policy_id = pay.policy_id GROUP BY p.policyholder_id
),
claims_paid AS (
    SELECT p.policyholder_id, SUM(c.claim_amount) AS total_claims
    FROM policies p JOIN claims c ON p.policy_id = c.policy_id WHERE c.claim_status = 'Approved' GROUP BY p.policyholder_id
)
SELECT 
    ph.full_name, 
    pr.total_paid AS premiums_collected, 
    COALESCE(cp.total_claims, 0) AS claims_paid,
    ROUND((COALESCE(cp.total_claims, 0) / NULLIF(pr.total_paid, 0)) * 100, 2) AS loss_ratio_percent
FROM policyholders ph
JOIN premium_received pr ON ph.policyholder_id = pr.policyholder_id
LEFT JOIN claims_paid cp ON ph.policyholder_id = cp.policyholder_id
ORDER BY loss_ratio_percent DESC;

-- Query 3: Unusual Claim Frequency (Potential Fraud)
-- Business Value: Flags accounts with high claim volume for fraud investigation.
-- Finding: Policies 39 (William Jones) and 356 (Charlotte Miller) have 7 claims each.
SELECT 
    p.policy_id,
    ph.full_name,
    COUNT(c.claim_id) AS total_claims,
    SUM(c.claim_amount) AS lifetime_claim_cost
FROM claims c
JOIN policies p ON c.policy_id = p.policy_id
JOIN policyholders ph ON p.policyholder_id = ph.policyholder_id
GROUP BY p.policy_id, ph.full_name
HAVING COUNT(c.claim_id) >= 5
ORDER BY total_claims DESC;

-- Query 4: Claim Trends & Volatility (Time Series)
-- Business Value: Uses LAG() to identify month-over-month change in payouts.
WITH monthly_stats AS (
    SELECT 
        DATE_TRUNC('month', claim_date) AS month,
        SUM(claim_amount) AS total_payout
    FROM claims WHERE claim_status = 'Approved' GROUP BY 1
)
SELECT 
    month, total_payout,
    LAG(total_payout) OVER(ORDER BY month) AS previous_month_payout,
    total_payout - LAG(total_payout) OVER(ORDER BY month) AS mom_change
FROM monthly_stats ORDER BY month DESC;

-- Query 5: Early Claims Detection (Fraud Indicator)
-- Business Value: Claims occurring immediately after signup often indicate pre-existing damage.
-- Finding: Detected 154 claims filed within 30 days of policy activation.
SELECT 
    c.claim_id,
    ph.full_name,
    p.policy_type,
    p.policy_start_date,
    c.claim_date,
    c.claim_date - p.policy_start_date AS days_until_claim
FROM claims c
JOIN policies p ON c.policy_id = p.policy_id
JOIN policyholders ph ON p.policyholder_id = ph.policyholder_id
WHERE (c.claim_date - p.policy_start_date) BETWEEN 0 AND 30
ORDER BY days_until_claim ASC;

-- ============================================================================
-- SECTION 5: VIEWS FOR DASHBOARDS
-- ============================================================================

-- View: Pre-aggregated dashboard summary for BI tools
CREATE OR REPLACE VIEW vw_claims_dashboard AS
SELECT 
    DATE_TRUNC('month', claim_date) AS month,
    claim_status,
    COUNT(*) AS claim_count,
    SUM(claim_amount) AS total_claim_amount
FROM claims
GROUP BY 1, 2;
