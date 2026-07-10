-- 07_risk_tiering.sql
-- Purpose: Single source of truth for customer risk tier. Combines the
-- router-based trend classifier (sparsity-split: continuous vs cyclical
-- logic) with the payment signal into one materialized table.
-- Downstream files (08_output_table.sql) READ from this table — they do
-- not recompute tier logic themselves. One place to update when the
-- classifier changes, not two.

DROP TABLE IF EXISTS risk_tiering;

CREATE TABLE risk_tiering AS
WITH customer_sparsity AS (
    SELECT customer_id,
        COUNT(CASE WHEN gap_as_of > 0 THEN 1 END)::float / COUNT(*) AS sparsity_score
    FROM gap_as_of_checkpoint WHERE gap_as_of IS NOT NULL GROUP BY customer_id
),
deltas AS (
    SELECT g.customer_id, g.check_date, g.gap_as_of,
        g.gap_as_of - LAG(g.gap_as_of) OVER (PARTITION BY g.customer_id ORDER BY g.check_date) AS gap_delta
    FROM gap_as_of_checkpoint g WHERE g.gap_as_of IS NOT NULL
),
peak_flag AS (
    SELECT customer_id, check_date, gap_as_of,
        LEAD(gap_as_of) OVER (PARTITION BY customer_id ORDER BY check_date) AS next_gap
    FROM gap_as_of_checkpoint WHERE gap_as_of IS NOT NULL
),
peaks AS (
    SELECT customer_id, check_date, gap_as_of,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY check_date) AS peak_seq
    FROM peak_flag WHERE next_gap < gap_as_of OR next_gap IS NULL
),
peak_slopes AS (
    SELECT customer_id, COUNT(*) AS total_peaks,
        CASE WHEN COUNT(*) >= 5 THEN REGR_SLOPE(gap_as_of, peak_seq) ELSE NULL END AS lifetime_peak_slope
    FROM peaks GROUP BY customer_id
),
continuous_trend AS (
    SELECT d.customer_id,
        COUNT(*) OVER (PARTITION BY d.customer_id) AS total_checkpoints,
        AVG(d.gap_delta) OVER (PARTITION BY d.customer_id ORDER BY d.check_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS avg_delta,
        ROW_NUMBER() OVER (PARTITION BY d.customer_id ORDER BY d.check_date DESC) AS rn
    FROM deltas d
),
router_output AS (
    SELECT cs.customer_id,
        CASE
            WHEN cs.sparsity_score < 0.25 THEN
                CASE WHEN ct.total_checkpoints < 5 THEN 'Insufficient Data'
                     WHEN ct.avg_delta > 0.5 THEN 'Worsening'
                     WHEN ct.avg_delta < -0.5 THEN 'Improving'
                     ELSE 'Sustained' END
            ELSE
                CASE WHEN ps.total_peaks IS NULL OR ps.total_peaks < 5 THEN 'Insufficient Data'
                     WHEN ps.lifetime_peak_slope > 0.15 THEN 'Worsening'
                     WHEN ps.lifetime_peak_slope < -0.15 THEN 'Improving'
                     ELSE 'Dormant' END
        END AS final_trend_direction
    FROM customer_sparsity cs
    LEFT JOIN peak_slopes ps ON ps.customer_id = cs.customer_id
    LEFT JOIN continuous_trend ct ON ct.customer_id = cs.customer_id AND ct.rn = 1
),
latest_payment_flag AS (
    SELECT p.customer_id,
        CASE
            WHEN s.billing_cycle = 'Monthly' AND (SELECT MAX(payment_date) FROM payments) - MAX(p.payment_date) FILTER (WHERE LOWER(p.payment_status) = 'success') > 45 THEN 1
            WHEN s.billing_cycle = 'Annual' AND (SELECT MAX(payment_date) FROM payments) - MAX(p.payment_date) FILTER (WHERE LOWER(p.payment_status) = 'success') > 380 THEN 1
            ELSE 0
        END AS payment_flag
    FROM payments p JOIN subscriptions s ON s.customer_id = p.customer_id
    WHERE s.subscription_status = 'Active' GROUP BY p.customer_id, s.billing_cycle
)
SELECT
    s.customer_id,
    s.monthly_recurring_revenue AS mrr,
    s.subscription_status,
    rt.final_trend_direction AS trend_direction,
    lpf.payment_flag,
    CASE
        WHEN s.subscription_status = 'Cancelled' THEN 'Churned'
        WHEN rt.final_trend_direction = 'Insufficient Data' THEN 'Insufficient Data'
        WHEN lpf.payment_flag IS NULL THEN 'Insufficient Data'
        WHEN rt.final_trend_direction = 'Worsening' AND lpf.payment_flag = 1 THEN 'At-Risk'
        WHEN rt.final_trend_direction = 'Worsening' AND lpf.payment_flag = 0 THEN 'Watch'
        WHEN lpf.payment_flag = 1 THEN 'Watch'
        ELSE 'Healthy'
    END AS risk_tier
FROM subscriptions s
LEFT JOIN router_output rt ON rt.customer_id = s.customer_id
LEFT JOIN latest_payment_flag lpf ON lpf.customer_id = s.customer_id; 

SELECT risk_tier, COUNT(*) FROM risk_tiering GROUP BY risk_tier ORDER BY risk_tier;