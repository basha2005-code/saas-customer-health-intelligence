-- 05_trend_analysis.sql
-- Purpose: Build the scaffold and raw gap-over-time data that the router-
-- based trend classifier (07_risk_tiering.sql) consumes. This file does
-- NOT compute a final trend_direction itself anymore — that logic lives
-- entirely in 07, which reads gap_as_of_checkpoint directly.
--
-- SUPERSEDED: an earlier version of this file built gap_trend using a
-- simple LAG-based 3-checkpoint classifier (Stable/Worsening/Improving).
-- That approach was tested and found to flip-flop on cyclical customers
-- (see interview_notes.md Part 2). It has been fully replaced by the
-- sparsity-router + peak-slope logic in 07 and is no longer part of the
-- pipeline. gap_trend is not rebuilt here and is not a dependency of
-- anything downstream.
--
-- Spine resolution: 3-day checkpoints (not the original 7-day version),
-- chosen after testing showed 7-day sampling aliased real signal for
-- customers with fast gap-and-burst cycles. Capped at the earlier of
-- ANALYSIS_DATE or the customer's own subscription_end_date, so Cancelled
-- customers don't accumulate meaningless post-churn checkpoints.


DROP TABLE IF EXISTS customer_date_spine;
DROP TABLE IF EXISTS gap_as_of_checkpoint;

CREATE TABLE customer_date_spine AS
SELECT
    c.customer_id,
    d.check_date::date AS check_date
FROM customers c
JOIN subscriptions s ON s.customer_id = c.customer_id
CROSS JOIN LATERAL generate_series(
    c.signup_date::date,
    LEAST('2026-02-04'::date, COALESCE(s.subscription_end_date, '2026-02-04'::date)),
    interval '3 days'
) AS d(check_date);

CREATE INDEX IF NOT EXISTS idx_usage_events_clean_customer_date
ON usage_events_clean(customer_id, event_date);

CREATE TABLE gap_as_of_checkpoint AS
SELECT
    s.customer_id,
    s.check_date,
    e.event_date AS last_active_before_checkpoint,
    s.check_date - e.event_date AS gap_as_of
FROM customer_date_spine s
JOIN LATERAL (
    SELECT MAX(u.event_date) AS event_date
    FROM usage_events_clean u
    WHERE u.customer_id = s.customer_id
      AND u.event_date <= s.check_date
) e ON true; 


select * from gap_as_of_checkpoint; 
select * from customer_date_spine;