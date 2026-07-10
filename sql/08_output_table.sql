-- 08_output_table.sql
-- Purpose: Final Power BI-ready output. Reads from risk_tiering (single
-- source of truth for tier logic — see 07_risk_tiering.sql) and adds a
-- plain-English reason column. Does NOT recompute trend or payment logic.

SELECT
    customer_id,
    mrr,
    risk_tier,
    trend_direction,
    payment_flag,
    CASE
        WHEN risk_tier = 'Churned' THEN 'Subscription already cancelled'
        WHEN risk_tier = 'Insufficient Data' THEN 'Not enough usage or payment history to assess'
        WHEN risk_tier = 'At-Risk' THEN 'Usage declining and payment failure — compounding risk'
        WHEN risk_tier = 'Watch' AND trend_direction = 'Worsening' THEN 'Usage declining, payments currently fine'
        WHEN risk_tier = 'Watch' AND payment_flag = 1 THEN 'Payment issue, usage currently fine'
        ELSE 'No current risk signals'
    END AS reason
FROM risk_tiering
ORDER BY
    CASE risk_tier
        WHEN 'At-Risk' THEN 1
        WHEN 'Watch' THEN 2
        WHEN 'Insufficient Data' THEN 3
        WHEN 'Healthy' THEN 4
        WHEN 'Churned' THEN 5
    END,
    mrr DESC; 
-------------------- 
SELECT risk_tier, COUNT(*) FROM ( 
SELECT
    customer_id,
    mrr,
    risk_tier,
    trend_direction,
    payment_flag,
    CASE
        WHEN risk_tier = 'Churned' THEN 'Subscription already cancelled'
        WHEN risk_tier = 'Insufficient Data' THEN 'Not enough usage or payment history to assess'
        WHEN risk_tier = 'At-Risk' THEN 'Usage declining and payment failure — compounding risk'
        WHEN risk_tier = 'Watch' AND trend_direction = 'Worsening' THEN 'Usage declining, payments currently fine'
        WHEN risk_tier = 'Watch' AND payment_flag = 1 THEN 'Payment issue, usage currently fine'
        ELSE 'No current risk signals'
    END AS reason
FROM risk_tiering
ORDER BY
    CASE risk_tier
        WHEN 'At-Risk' THEN 1
        WHEN 'Watch' THEN 2
        WHEN 'Insufficient Data' THEN 3
        WHEN 'Healthy' THEN 4
        WHEN 'Churned' THEN 5
    END,
    mrr DESC   
) t
GROUP BY risk_tier ORDER BY risk_tier;