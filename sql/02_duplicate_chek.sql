-- Duplicates in Usage_events  

select event_id,
		event_date,
		event_type,
		count(*) as duplicate_count 
from usage_events ue  
group by event_id,event_date ,event_type   
having count(*) > 1 
order by duplicate_count desc  
limit 20 ; 
 
--  total duplicate rows in usage events 
-- quantifying exact scale of duplication problem  
-- duplicates pairs or 20 and rows to remvoe 20  

select count(*) as duplicate_pairs,
		count(*) * 1 as rows_to_remove 
from 
(select event_id,
		event_date,
		event_type,
		count(*) as duplicate_count 
from usage_events ue  
group by event_id,event_date ,event_type   
having count(*) > 1 
order by duplicate_count desc  
) as dups;  

-- duplicates in payment  
-- a geniune payment should be unique  

select customer_id,
	subscription_id, 
	payment_date,
	amount, 
	count(*) as duplicate_count 
from payments p  
group by customer_id , p.subscription_id ,p.payment_date,amount  
having count(*) > 1  
order by duplicate_count desc ;  

-- total duplicate rows in payments - pairs 
select count(*) as duplicate_pairs 
from
(select customer_id,
	subscription_id, 
	payment_date,
	amount, 
	count(*) as duplicate_count 
from payments p  
group by customer_id , p.subscription_id ,p.payment_date,amount  
having count(*) > 1  
order by duplicate_count desc 
) as dups; 

-- Creating the clenaed date by removing the duplicates  
-- preserving the raw table  

create table usage_events_clean as      
select distinct on (customer_id,event_date,event_type) * 
from usage_events 
order by customer_id,event_date,event_type,event_id; 

select count(*) as clenaed_row_count from usage_events_clean; 

-- creating the cleaned payments remvoing duplicates 
-- preserving raw table remain and untouched  

create table payments_clean as 
select distinct on (customer_id,subscription_id,payment_date,amount) * 
from payments 
order by customer_id,subscription_id,payment_date,amount,payment_id; 


select count(*) as cleaned_payments_count from payments_clean

