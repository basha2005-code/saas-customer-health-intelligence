-- ============================================
-- 04_engagement_metrics.sql
-- Purpose: Calculate per-customer engagement metrics using Gap & Island logic
--          (longest streak, current gap, current streak length)
--
-- IMPORTANT: analysis_date is derived from MAX(event_date) in usage_events_clean,
-- NOT CURRENT_DATE. This dataset is synthetic/historical (max activity: 2026-02-03),
-- so using the real calendar date would show every customer as having a large,
-- meaningless gap. Always anchor to the data's own timeline, not wall-clock time.
--
-- Findings: Original generator had a bug freezing Active customers' events at a
-- fixed date (2025-12-31) instead of extending to the real analysis ceiling, and
-- a separate data-drift bug where notebook subscriptions data was stale vs. the
-- live database. Both fixed at the source (Python generator + reload from DB).
-- current_streak_length was returning 0 for all customers before this fix

WITH daily_activity AS (
    SELECT customer_id, event_date
    FROM usage_events_clean
    GROUP BY customer_id, event_date
),
prev_date AS (
    SELECT customer_id, event_date,
        LAG(event_date) OVER(PARTITION BY customer_id ORDER BY event_date) AS prev_date
    FROM daily_activity
),
streak_flag AS (
    SELECT customer_id, event_date,
        CASE WHEN prev_date IS NULL THEN 1
             WHEN event_date - prev_date > 1 THEN 1
             ELSE 0 END AS streak_flag
    FROM prev_date
),
running_sum AS (
    SELECT customer_id, event_date,
        SUM(streak_flag) OVER(PARTITION BY customer_id ORDER BY event_date) AS streak_id
    FROM streak_flag
),
length_of_streak AS (
    SELECT customer_id, streak_id, COUNT(*) AS streak_length, MAX(event_date) AS last_active_date
    FROM running_sum
    GROUP BY customer_id, streak_id
),
current_streak AS (
    SELECT customer_id, streak_id, streak_length, last_active_date,
        MAX(streak_length) OVER(PARTITION BY customer_id) AS absolute_longest_streak,
        ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY last_active_date DESC) AS rn
    FROM length_of_streak
),
reference_date AS (
    SELECT MAX(event_date) AS analysis_date FROM usage_events_clean
)
SELECT
    cs.customer_id,
    cs.absolute_longest_streak AS longest_streak,
    rd.analysis_date - cs.last_active_date AS current_gap,
    CASE WHEN rd.analysis_date - cs.last_active_date <= 7 THEN cs.streak_length ELSE 0 END AS current_streak_length,
    cs.last_active_date,
    rd.analysis_date
FROM current_streak cs
CROSS JOIN reference_date rd
WHERE cs.rn = 1
ORDER BY cs.customer_id;