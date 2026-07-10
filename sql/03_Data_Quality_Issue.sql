-- NULL value inspection  
-- Purpose: Check missing values across all 4 tables
-- Note: subscription_end_date nulls are EXPECTED for active
--  subscriptions, not a data quality issue   

-- customers table 

SELECT 
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(region) AS null_region,
    COUNT(*) - COUNT(company_size_tier) AS null_size_tier,
    COUNT(*) - COUNT(acquisition_channel) AS null_channel
FROM customers; 

-- ORPHAN RECORDS CHECK
-- Purpose: Find usage_events with customer_ids that don't exist
--          in the customers table - a referential integrity failure


SELECT 
    ue.customer_id,
    COUNT(*) AS orphan_event_count
FROM usage_events_clean ue
LEFT JOIN customers c ON ue.customer_id = c.customer_id
WHERE c.customer_id IS NULL
GROUP BY ue.customer_id
ORDER BY ue.customer_id; 


-- Confirm total orphan event count
SELECT 
    COUNT(*) AS total_orphan_events,
    COUNT(DISTINCT ue.customer_id) AS distinct_orphan_customers
FROM usage_events_clean ue
LEFT JOIN customers c ON ue.customer_id = c.customer_id
WHERE c.customer_id IS NULL; 

