--YEARLY REVENUE
CREATE OR REPLACE VIEW mart.vw_sales_yearly_summary AS

SELECT
    YEAR(transaction_date) AS year,
    COUNT(*) AS total_transactions,
    SUM(quantity) AS total_units_sold,
    SUM(total_amount) AS total_revenue
FROM gold.fact_orders
WHERE transaction_date IS NOT NULL
GROUP BY YEAR(transaction_date
);


-- REVENUE TREND BY MONTH, AND YEAR

CREATE OR REPLACE VIEW mart.vw_sales_monthly_summary AS

SELECT
    YEAR(transaction_date) AS year,
    MONTH(transaction_date) AS month_number,
    MONTHNAME(transaction_date) AS month_name,

    SUM(total_amount) AS total_revenue,
    SUM(quantity) AS total_units_sold,
    COUNT(*) AS total_transactions

FROM gold.fact_orders
WHERE transaction_date IS NOT NULL

GROUP BY
    YEAR(transaction_date),
    MONTH(transaction_date),
    MONTHNAME(transaction_date);

-- AVERAGE REVENUE BY CALENDAR MONTH
-- Across all years, which month tends to perform best?
CREATE OR REPLACE VIEW mart.vw_sales_monthly_seasonality AS
WITH revenue_performance AS (
    SELECT
        YEAR(o.transaction_date) AS year,
        MONTH(o.transaction_date) AS month_number,
        MONTHNAME(o.transaction_date) AS month_name, 
        SUM(total_amount) AS total_revenue
    FROM gold.fact_orders o
    WHERE o.transaction_date IS NOT NULL
    GROUP BY 
        YEAR(o.transaction_date),
        MONTH(o.transaction_date),
        MONTHNAME(o.transaction_date)
),
revenue_rank_monthly AS (
    SELECT
        month_number,
        month_name,
        AVG(total_revenue) AS average_monthly_revenue,
        ROUND(
            100.0 * AVG(total_revenue)
            / SUM(AVG(total_revenue)) OVER (),
        2) AS pct_revenue
    FROM revenue_performance
    GROUP BY month_number, month_name
)

SELECT
    month_name,
    average_monthly_revenue,
    pct_revenue AS percentage_revenue,
    RANK() OVER (ORDER BY pct_revenue DESC) AS monthly_revenue_rank
FROM revenue_rank_monthly;

/*
Across the four years period 2020-2023 the month with the best performance in terms of average revenue is July with 8.83% of average revenue over the years.
*/

-- Payment Method Analysis: Which Payment Methods has higher order values?
CREATE OR REPLACE VIEW mart.vw_payment_method_performance AS

SELECT
    o.payment_method,
    COUNT(DISTINCT o.transaction_id) AS total_transactions,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value,
    ROUND(SUM(o.total_amount), 2) AS total_revenue,
    ROUND(
        100.0 * COUNT(DISTINCT o.transaction_id)
        / SUM(COUNT(DISTINCT o.transaction_id)) OVER (),
    2) AS transaction_share_percent
FROM gold.fact_orders o
GROUP BY o.payment_method;


--Country Revenue Analysis: Which country has the most contribution to the Pacific Retail's Revenue
CREATE OR REPLACE VIEW mart.vw_country_sales_performance AS

WITH country_metrics AS (
    SELECT
        c.country,
        COUNT(DISTINCT o.customer_id) AS total_customers,
        COUNT(DISTINCT o.transaction_id) AS total_transactions,
        ROUND(AVG(o.total_amount), 2) AS avg_order_value,
        ROUND(SUM(o.total_amount), 2) AS total_revenue
    FROM gold.fact_orders o
    INNER JOIN gold.dim_customer c
        ON c.customer_id = o.customer_id
    GROUP BY c.country
)

SELECT
    country,
    total_customers,
    total_transactions,
    avg_order_value,
    total_revenue,

    ROUND(
        total_customers * 100.0 / SUM(total_customers) OVER (),
    2) AS percentage_total_customers,

    ROUND(
        total_revenue * 100.0 / SUM(total_revenue) OVER (),
    2) AS percentage_total_revenue,

    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank

FROM country_metrics;

-- Daily Sales Overview
CREATE OR REPLACE VIEW mart.vw_sales_overview AS

SELECT
    d.date_day AS transaction_date,
    COUNT(DISTINCT o.transaction_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS total_customers,
    SUM(o.quantity) AS total_quantity,
    ROUND(SUM(o.total_amount), 2) AS total_revenue,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value
FROM gold.fact_orders o
JOIN mart.dim_date d
    ON o.transaction_date = d.date_day
GROUP BY d.date_day;