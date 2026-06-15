--PRODUCT ANALYTICS
-- Top 10 products with the most average transaction value in the last 60 days

CREATE OR REPLACE VIEW mart.vw_product_value_performance AS

WITH max_date AS (
SELECT 
    MAX(transaction_date) AS latest_date
FROM gold.fact_orders
WHERE transaction_date IS NOT NULL
),

recent_performance AS (
SELECT
        o.product_id,
        p.name AS product_name,
        p.category,
        p.brand,
        COUNT(*) AS total_transactions,
        SUM(o.total_amount) AS total_revenue,
        AVG(o.total_amount) AS avg_transaction_value,
        SUM(o.quantity) AS total_units_sold
FROM gold.fact_orders o
JOIN gold.dim_product p
    ON o.product_id = p.product_id
CROSS JOIN max_date m
WHERE o.transaction_date >= DATEADD(day, -60, m.latest_date)
GROUP BY
    o.product_id,
    p.name,
    p.category,
    p.brand
)

SELECT
    product_id,
    product_name,
    category,
    brand,
    total_transactions,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(avg_transaction_value, 2) AS avg_transaction_value,
    total_units_sold,
    RANK() OVER (
    ORDER BY avg_transaction_value DESC
    ) AS value_rank
FROM recent_performance;

-- PRODUCT CATEGORY WITH THE HIGHEST REVENUE FOR EACH MONTH ACROSS THE YEARS
CREATE OR REPLACE VIEW mart.vw_monthly_top_revenue_category AS

WITH revenue_trend AS (
SELECT
        YEAR(o.transaction_date) AS year,
        DATE_TRUNC('month', o.transaction_date) AS month_start,
        p.category,
        SUM(o.total_amount) AS revenue
FROM gold.fact_orders o
JOIN gold.dim_product p
    ON o.product_id = p.product_id
WHERE o.transaction_date IS NOT NULL
GROUP BY
        YEAR(o.transaction_date),
        DATE_TRUNC('month', o.transaction_date),
        p.category
),

ranking_revenue AS (
SELECT
    year,
    MONTHNAME(month_start) AS month_name,
    category,
    revenue,
    RANK() OVER (
    PARTITION BY year, month_start
    ORDER BY revenue DESC
    ) AS revenue_rank
FROM revenue_trend
)

SELECT
    year,
    month_name,
    category,
    revenue
FROM ranking_revenue
WHERE revenue_rank = 1;

-- TOP 3 PRODUCTS BY CATEGORIES
CREATE OR REPLACE VIEW mart.vw_top_products_by_category AS

SELECT
    category,
    product_name,
    revenue,
    category_rank
FROM (
SELECT
    category,
    product_name,
    revenue,
    RANK() OVER (
    PARTITION BY category
    ORDER BY revenue DESC
    ) AS category_rank
FROM (
SELECT
    p.category,
    p.name AS product_name,
    SUM(o.total_amount) AS revenue
FROM gold.fact_orders o
JOIN gold.dim_product p
ON o.product_id = p.product_id
GROUP BY
    p.category,
    p.name
) t
) ranked
WHERE category_rank <= 3;

-- Category Share of Revenue (Market Dominance)
-- What % of total revenue does each category contribute?
CREATE OR REPLACE VIEW mart.vw_category_revenue_share AS

WITH category_revenue AS (
SELECT
    p.category,
    SUM(o.total_amount) AS revenue
FROM gold.fact_orders o
JOIN gold.dim_product p
    ON o.product_id = p.product_id
GROUP BY p.category
)

SELECT
    category,
    revenue,
    ROUND(
    100.0 * revenue / SUM(revenue) OVER (),
    2
    ) AS revenue_share_percentage
FROM category_revenue

/*
Clothing contributes the highest revenue to the total revenue out of the 10 product categories
*/

-- PRODUCTS DRIVING THE HIGHES REVENUE AND PRODUCTS DRIVING THE LEAST REVENUE
-- Revenue per product
CREATE OR REPLACE VIEW mart.vw_product_revenue_contribution AS

WITH product_revenue AS (
SELECT
    p.product_id,
    p.name,
    p.category,
    SUM(o.total_amount) AS revenue
FROM gold.fact_orders o
JOIN gold.dim_product p
    ON o.product_id = p.product_id
GROUP BY
    p.product_id,
    p.name,
    p.category
)

SELECT
    product_id,
    name,
    category,
    revenue,
    ROUND(
    100.0 * SUM(revenue) OVER (
    ORDER BY revenue DESC
    ) / SUM(revenue) OVER (),
    2
    ) AS cumulative_share
FROM product_revenue;

-- PARETO (80/20) BY BREAKDOWN PER CATEGORY
-- Does 20% of products drive 80% of revenue in each category?
-- Revenue per product inside category
CREATE OR REPLACE VIEW mart.vw_category_pareto_analysis AS

WITH product_revenue AS (
SELECT
    p.product_id,
    p.name,
    p.category,
    SUM(o.total_amount) AS revenue
FROM gold.fact_orders o
JOIN gold.dim_product p
    ON o.product_id = p.product_id
GROUP BY
        p.product_id,
        p.name,
        p.category
)

SELECT
        category,
        product_id,
        name,
        revenue,
        cumulative_share,
        CASE
        WHEN cumulative_share <= 80
        THEN 'Top 80% Revenue Drivers'
        ELSE 'Long Tail'
        END AS pareto_segment
FROM (
SELECT
    category,
    product_id,
    name,
    revenue,
    ROUND(
    100.0 * SUM(revenue) OVER (
    PARTITION BY category
    ORDER BY revenue DESC
    ROWS BETWEEN UNBOUNDED PRECEDING
    AND CURRENT ROW
    )
    /
    SUM(revenue) OVER (
    PARTITION BY category
    ),
    2
    ) AS cumulative_share
FROM product_revenue
) t;


-- Identify the top 10 products that experienced the largest increase in revenue between:
    -- the last 30 days, and
    -- the previous 30 days (31–60 days ago).
-- Which products are growing?
-- Which products are newly selling?
-- Which products had the biggest revenue increase?
CREATE OR REPLACE VIEW mart.vw_product_revenue_growth AS

WITH date_anchor AS (
SELECT 
        MAX(transaction_date) AS latest_date
FROM gold.fact_orders
),

rev_last_30 AS (
SELECT
        o.product_id,
        SUM(o.total_amount) AS revenue_last_30
FROM gold.fact_orders o
CROSS JOIN date_anchor
WHERE o.transaction_date >= DATEADD(day, -30, latest_date)
GROUP BY o.product_id
),

rev_prev_30 AS (
SELECT
    o.product_id,
    SUM(o.total_amount) AS revenue_prev_30
FROM gold.fact_orders o
CROSS JOIN date_anchor
WHERE o.transaction_date >= DATEADD(day, -60, latest_date)
AND o.transaction_date < DATEADD(day, -30, latest_date)
GROUP BY o.product_id
)

SELECT
        p.product_id,
        p.name,
        
        COALESCE(r30.revenue_last_30, 0) AS revenue_last_30,
        COALESCE(p30.revenue_prev_30, 0) AS revenue_prev_30,
        
        COALESCE(r30.revenue_last_30, 0)
            - COALESCE(p30.revenue_prev_30, 0) AS revenue_increase,
        
        CASE
            WHEN COALESCE(p30.revenue_prev_30, 0) = 0
                 AND COALESCE(r30.revenue_last_30, 0) > 0
                THEN 'Newly Selling'
        
            WHEN COALESCE(p30.revenue_prev_30, 0) > 0
                 AND COALESCE(r30.revenue_last_30, 0) = 0
                THEN 'Discontinued'
        
            WHEN COALESCE(r30.revenue_last_30, 0)
                 > COALESCE(p30.revenue_prev_30, 0)
                THEN 'Growing'
        
            WHEN COALESCE(r30.revenue_last_30, 0)
                 < COALESCE(p30.revenue_prev_30, 0)
                THEN 'Declining'
        
            ELSE 'Flat'
        END AS product_status

FROM rev_last_30 r30
FULL OUTER JOIN rev_prev_30 p30
    ON r30.product_id = p30.product_id
JOIN gold.dim_product p
    ON p.product_id = COALESCE(r30.product_id, p30.product_id);

/*
The top 10 products with the largest revenue increases over the last 30 days are all newly selling products rather than existing products experiencing growth.
*/


-- Top 10 growing products most in the last 30 days

CREATE OR REPLACE VIEW mart.vw_top_growing_products AS

SELECT *
FROM mart.vw_product_revenue_growth
WHERE product_status = 'Growing';

-- 10 products with the most decling revenue in the last 30 days

CREATE OR REPLACE VIEW mart.vw_top_declining_products AS

SELECT *
FROM mart.vw_product_revenue_growth
WHERE product_status = 'Declining';