use DATABASE pacificretail_db;
USE pacificretail_db.gold;

-- FACT MART (Orders fact table/view)

CREATE OR REPLACE VIEW gold.fact_orders AS
SELECT
        o.transaction_id, 
        o.transaction_date,
        o.customer_id, 
        o.product_id, 
        o.quantity, 
        o.store_type, 
        o.payment_method,
        o.total_amount,
        o.last_updated_timestamp
FROM silver.orders o;
