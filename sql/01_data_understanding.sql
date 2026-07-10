
/* Dataset Overview */
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL
SELECT 'usage_events', COUNT(*) FROM usage_events
UNION ALL
SELECT 'payments', COUNT(*) FROM payments; 

/* Data understanding */ 
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('customers', 'subscriptions', 'usage_events', 'payments')
ORDER BY table_name, ordinal_position; 

select *from usage_events;