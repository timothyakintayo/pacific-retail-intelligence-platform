USE DATABASE pacificretail_db;
USE pacificretail_db.gold;

-- Customer Dimension
CREATE OR REPLACE VIEW gold.dim_customer AS
SELECT
        customer_id,
        name,
        email,
        country,
        customer_type,
        registration_date,
        age,
        gender,
        total_purchases,
        last_updated_timestamp
FROM silver.customer;
