CREATE OR REPLACE VIEW mart.vw_daily_sales_analysis AS
SELECT 
    o.transaction_date,
    p.product_id,
    p.name AS product_name,
    p.category AS product_category,
    c.customer_id,
    c.customer_type,
    SUM(o.quantity) AS total_quantity,
    SUM(o.total_amount) AS total_sales,
    COUNT(DISTINCT o.transaction_id) AS num_transactions,
    SUM(o.total_amount) / NULLIF(SUM(o.quantity), 0) AS avg_price_per_unit,
    SUM(o.total_amount) / NULLIF(COUNT(DISTINCT o.transaction_id), 0) AS avg_transaction_value
FROM SILVER.ORDERs o
JOIN SILVER.PRODUCT p ON o.product_id = p.product_id
JOIN SILVER.CUSTOMER c ON o.customer_id = c.customer_id
GROUP BY 
    o.transaction_date,
    p.product_id,
    p.name,
    p.category,
    c.customer_id,
    c.customer_type;


-- Sales Overview
CREATE OR REPLACE VIEW mart.vw_sales_overview AS

SELECT
    transaction_date,

    COUNT(DISTINCT transaction_id) AS total_orders,

    COUNT(DISTINCT customer_id) AS total_customers,

    SUM(quantity) AS total_quantity,

    ROUND(SUM(total_amount),2) AS total_revenue,

    ROUND(
        AVG(total_amount),
        2
    ) AS avg_order_value

FROM gold.fact_orders
GROUP BY transaction_date;