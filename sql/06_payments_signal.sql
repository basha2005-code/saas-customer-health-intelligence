-- 06_payments_signal.sql
-- Purpose: Per-customer payment health — failure rate + days-since-last-
-- success, with a payment_flag based on a threshold relative to their
-- OWN billing cycle (Monthly: 30+15 grace, Annual: 365+15 grace) rather
-- than one flat number for everyone. Only computed for Active customers.
--
-- BUG FOUND: initial payment_flag rate was ~28% overall — implausible.
-- Root cause: Python payments generator froze Active customers' payment
-- history at a hardcoded 2025-12-31 instead of the real analysis ceiling,
-- same bug class as the usage_events freeze. Fixed generator, reloaded,
-- verified in pandas and live DB. Flag rate now Monthly ~2.1%, Annual ~2.9%.

SELECT
    p.customer_id,
    s.billing_cycle,
    COUNT(*) AS total_attempts,
    COUNT(*) FILTER (WHERE LOWER(p.payment_status) = 'failed') AS failed_attempts,
    ROUND(
        COUNT(*) FILTER (WHERE LOWER(p.payment_status) = 'failed')::numeric
        / COUNT(*), 2
    ) AS failure_rate,
    MAX(p.payment_date) FILTER (WHERE LOWER(p.payment_status) = 'success') AS last_success_date,
    (SELECT MAX(payment_date) FROM payments)
        - MAX(p.payment_date) FILTER (WHERE LOWER(p.payment_status) = 'success') AS days_since_last_success,
    CASE
        WHEN s.billing_cycle = 'Monthly'
             AND (SELECT MAX(payment_date) FROM payments) - MAX(p.payment_date) FILTER (WHERE LOWER(p.payment_status) = 'success') > (30 + 15)
        THEN 1
        WHEN s.billing_cycle = 'Annual'
             AND (SELECT MAX(payment_date) FROM payments) - MAX(p.payment_date) FILTER (WHERE LOWER(p.payment_status) = 'success') > (365 + 15)
        THEN 1
        ELSE 0
    END AS payment_flag
FROM payments p
JOIN subscriptions s ON s.customer_id = p.customer_id
WHERE s.subscription_status = 'Active'
GROUP BY p.customer_id, s.billing_cycle; 


SELECT billing_cycle, payment_flag, MIN(days_since_last_success), MAX(days_since_last_success)
FROM (
    SELECT
    p.customer_id,
    s.billing_cycle,
    COUNT(*) AS total_attempts,
    COUNT(*) FILTER (WHERE LOWER(p.payment_status) = 'failed') AS failed_attempts,
    ROUND(
        COUNT(*) FILTER (WHERE LOWER(p.payment_status) = 'failed')::numeric
        / COUNT(*), 2
    ) AS failure_rate,
    MAX(p.payment_date) FILTER (WHERE LOWER(p.payment_status) = 'success') AS last_success_date,
    (SELECT MAX(payment_date) FROM payments)
        - MAX(p.payment_date) FILTER (WHERE LOWER(p.payment_status) = 'success') AS days_since_last_success,
    CASE
        WHEN s.billing_cycle = 'Monthly'
             AND (SELECT MAX(payment_date) FROM payments) - MAX(p.payment_date) FILTER (WHERE LOWER(p.payment_status) = 'success') > (30 + 15)
        THEN 1
        WHEN s.billing_cycle = 'Annual'
             AND (SELECT MAX(payment_date) FROM payments) - MAX(p.payment_date) FILTER (WHERE LOWER(p.payment_status) = 'success') > (365 + 15)
        THEN 1
        ELSE 0
    END AS payment_flag
FROM payments p
JOIN subscriptions s ON s.customer_id = p.customer_id
WHERE s.subscription_status = 'Active'
GROUP BY p.customer_id, s.billing_cycle
) t
GROUP BY billing_cycle, payment_flag
ORDER BY billing_cycle, payment_flag;