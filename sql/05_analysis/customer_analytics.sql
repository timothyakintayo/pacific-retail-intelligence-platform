-- CREATE mart schema
CREATE SCHEMA IF NOT EXISTS mart;


-- Customer Segment Are premium customers actually worth more?
CREATE OR REPLACE VIEW mart.vw_customer_segment_performance AS
SELECT
        c.customer_type AS customer_segment,
        COUNT(DISTINCT o.transaction_id) AS total_transactions,
        COUNT(DISTINCT o.customer_id) AS unique_customers,
        ROUND(AVG(o.total_amount), 2) AS avg_order_value,
        ROUND(SUM(o.total_amount), 2) AS total_revenue,
        ROUND(
            SUM(o.total_amount) * 1.0
            / COUNT(DISTINCT o.customer_id),
            2
        ) AS revenue_per_customer
FROM gold.fact_orders o
INNER JOIN gold.dim_customer c
ON c.customer_id = o.customer_id
GROUP BY c.customer_type;


-- Age group with the highest customer spending
CREATE OR REPLACE VIEW mart.vw_age_group_spending AS

WITH age_bucket_spend AS (
SELECT
        c.age,
        CASE
            WHEN c.age < 25 THEN '18-24'
            WHEN c.age < 35 THEN '25-34'
            WHEN c.age < 45 THEN '35-44'
            WHEN c.age < 55 THEN '45-54'
            ELSE '55+'
        END AS customer_age_bracket,
        o.total_amount
FROM gold.dim_customer c
INNER JOIN gold.fact_orders o
ON c.customer_id = o.customer_id
)

SELECT
    customer_age_bracket,
    ROUND(SUM(total_amount),2) AS total_spend,
    ROUND(AVG(total_amount),2) AS avg_spend
FROM age_bucket_spend
GROUP BY customer_age_bracket;

-- Which customer groups generate revenue: Which demographics drive sales?
CREATE OR REPLACE VIEW mart.vw_demographic_sales_drivers AS
SELECT
        c.country,
        c.gender,
        c.customer_type,
        COUNT(DISTINCT c.customer_id) AS total_customers,
        ROUND(AVG(c.total_purchases),2) AS avg_total_purchases
FROM gold.dim_customer c
GROUP BY
        c.country,
        c.gender,
        c.customer_type;

-- Best Customer Analysis: Which customers generate the most value and purchase most frequently?
CREATE OR REPLACE VIEW mart.vw_rfm_segmentation AS

WITH transaction_end_date AS (
SELECT TO_DATE('2023-12-31') AS as_of_date
),

rfm_base AS (
SELECT
        o.customer_id,
        MAX(o.transaction_date) AS last_purchase_date,
        COUNT(DISTINCT transaction_id) AS frequency,
        SUM(o.total_amount) AS monetary
FROM gold.fact_orders o
WHERE o.transaction_date IS NOT NULL
GROUP BY o.customer_id
),

rfm_calculations AS (
SELECT
        customer_id,
        DATEDIFF(DAY, last_purchase_date, as_of_date) AS recency,
        frequency,
        monetary
FROM rfm_base
CROSS JOIN transaction_end_date t
),

rfm_scores AS (
SELECT
    customer_id,

    NTILE(5) OVER (ORDER BY recency DESC) r_score,

    NTILE(5) OVER (ORDER BY frequency ASC) f_score,

    NTILE(5) OVER (ORDER BY monetary ASC) m_score

FROM rfm_calculations
)

SELECT
        r.customer_id,
        r.recency,
        r.frequency,
        r.monetary,
        s.r_score,
        s.f_score,
        s.m_score,
        CONCAT(s.r_score,s.f_score,s.m_score) AS rfm_code,

        CASE
            WHEN s.r_score >= 4
                AND s.f_score >= 4
                AND s.m_score >= 4
                    THEN 'Champions'

            WHEN s.r_score >= 4
                AND s.f_score >= 4
                    THEN 'Loyal Customers'

            WHEN s.r_score >= 4
                AND s.f_score <= 2
                    THEN 'New Customers'

            WHEN s.m_score >= 4
                    THEN 'Big Spenders'

            WHEN s.r_score <= 2
                AND s.f_score >= 4
                    THEN 'At Risk'

            WHEN s.r_score <= 2
                AND s.f_score <= 2
                AND s.m_score <= 2
                    THEN 'Lost Customers'

            ELSE 'Regular Customers'
        END AS customer_segment

FROM rfm_calculations r
INNER JOIN rfm_scores s
ON s.customer_id = r.customer_id;



-- Revenue Concentration
CREATE OR REPLACE VIEW mart.vw_rfm_revenue_concentration AS
SELECT
    customer_segment,

    ROUND(SUM(monetary),2) AS segment_revenue,

    COUNT(*) AS customers,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS customer_segment_pct,

    ROUND(
        SUM(monetary) * 100.0 /
        SUM(SUM(monetary)) OVER (),
        2
    ) AS revenue_pct

FROM mart.vw_rfm_segmentation
GROUP BY customer_segment;

-- List customers who have ordered before but not in the last 90 days
CREATE OR REPLACE VIEW mart.vw_inactive_customers_90_days AS

WITH max_date AS (
SELECT
    MAX(o.transaction_date) AS latest_date
FROM gold.fact_orders o
)

SELECT
        c.customer_id,
        c.name AS customer_name
FROM gold.dim_customer c
WHERE EXISTS
(
SELECT 1
FROM gold.fact_orders o
WHERE c.customer_id = o.customer_id
)
AND NOT EXISTS
(
SELECT 1
FROM gold.fact_orders o
CROSS JOIN max_date m
WHERE c.customer_id = o.customer_id
AND o.transaction_date >= DATEADD(day, -90, m.latest_date)
);

-- Cohort Analysis (Customer Retention by Month)
CREATE OR REPLACE VIEW mart.vw_customer_retention_cohort AS
WITH customer_first_purchase AS (
    SELECT
        customer_id,
        MIN(transaction_date) AS first_purchase_date
    FROM gold.fact_orders
    GROUP BY customer_id
),

cohort_data AS (
    SELECT
        o.customer_id,
        DATE_TRUNC('month', c.first_purchase_date) AS cohort_month,
        DATE_TRUNC('month', o.transaction_date) AS activity_month
    FROM gold.fact_orders o
    JOIN customer_first_purchase c
        ON o.customer_id = c.customer_id
    WHERE o.transaction_date IS NOT NULL
),

retention AS (
    SELECT
        cohort_month,
        DATEDIFF(month, cohort_month, activity_month) AS month_number,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM cohort_data
    GROUP BY cohort_month, month_number
),

cohort_size AS (
    SELECT
        cohort_month,
        active_customers AS cohort_size
    FROM retention
    WHERE month_number = 0
),

final AS (
    SELECT
        r.cohort_month,
        r.month_number,
        ROUND(
            100.0 * r.active_customers / c.cohort_size,
            2
        ) AS retention_rate
    FROM retention r
    JOIN cohort_size c
        ON r.cohort_month = c.cohort_month
    WHERE r.month_number <= 12
),

cohort_avg AS (
    SELECT
        cohort_month,
        ROUND(AVG(retention_rate), 2) AS avg_retention_1_12
    FROM final
    WHERE month_number > 0
    GROUP BY cohort_month
),

best_month AS (
    SELECT
        cohort_month,
        month_number AS best_month,
        retention_rate AS best_retention
    FROM (
        SELECT
            cohort_month,
            month_number,
            retention_rate,
            RANK() OVER (
                PARTITION BY cohort_month
                ORDER BY retention_rate DESC
            ) AS rn
        FROM final
        WHERE month_number > 0
    )
    WHERE rn = 1
)

SELECT
    p.*,
    a.avg_retention_1_12,
    b.best_month,
    b.best_retention
FROM (
    SELECT *
    FROM final
    PIVOT (
        MAX(retention_rate)
        FOR month_number IN (
            0,1,2,3,4,5,6,7,8,9,10,11,12
        )
    )
) p
LEFT JOIN cohort_avg a
    ON p.cohort_month = a.cohort_month
LEFT JOIN best_month b
    ON p.cohort_month = b.cohort_month;

-- DECLINING CUSTOMER FREQUENCY 
-- Which top 10 customers' purchase frequency (number of orders) in the last 30 days has dropped the most compared to the previous 30 days window and how many customers are active/churned?
CREATE OR REPLACE VIEW mart.vw_customer_activity_trend AS
WITH date_anchor AS (
    SELECT MAX(transaction_date) AS latest_date
    FROM gold.fact_orders
),
last_30_days AS (
    SELECT
        o.customer_id,
        COUNT(*) AS num_orders_last_30
    FROM gold.fact_orders o
    CROSS JOIN date_anchor
    WHERE o.transaction_date >= DATEADD(day, -30, date_anchor.latest_date)
    GROUP BY o.customer_id
),
prev_30_days AS (
    SELECT
        o.customer_id,
        COUNT(*) AS num_orders_prev_30
    FROM gold.fact_orders o
    CROSS JOIN date_anchor
    WHERE o.transaction_date >= DATEADD(day, -60, date_anchor.latest_date)
    AND o.transaction_date < DATEADD(day, -30, date_anchor.latest_date)
    GROUP BY o.customer_id
)
SELECT
    COALESCE(l.customer_id, p.customer_id) AS customer_id,
    COALESCE(num_orders_last_30, 0) AS num_orders_last_30,
    COALESCE(num_orders_prev_30, 0) AS num_orders_prev_30,
    COALESCE(num_orders_last_30, 0) - COALESCE(num_orders_prev_30, 0) AS diff_prev_last_orders,
    CASE
            WHEN COALESCE(num_orders_last_30, 0) = 0
             AND COALESCE(num_orders_prev_30, 0) > 0
            THEN 'Churned'
            ELSE 'Active'
    END AS customer_status
FROM last_30_days l
FULL OUTER JOIN prev_30_days p
    ON l.customer_id = p.customer_id



-- Customers spend in the last 60 days and previous 60 alongside their drop in spending, and customers who are deemed active, churned, new.
CREATE OR REPLACE VIEW mart.vw_customer_lifecycle_snapshot AS
WITH date_anchor AS (
    SELECT MAX(transaction_date) AS latest_date
    FROM gold.fact_orders
),

last_60 AS (
    SELECT
        customer_id,
        SUM(total_amount) AS spend_last_60,
        COUNT(*) AS orders_last_60
    FROM gold.fact_orders o
    CROSS JOIN date_anchor d
    WHERE transaction_date >= DATEADD(day, -60, d.latest_date)
    GROUP BY customer_id
),

prev_60 AS (
    SELECT
        customer_id,
        SUM(total_amount) AS spend_prev_60,
        COUNT(*) AS orders_prev_60
    FROM gold.fact_orders o
    CROSS JOIN date_anchor d
    WHERE transaction_date >= DATEADD(day, -120, d.latest_date)
      AND transaction_date < DATEADD(day, -60, d.latest_date)
    GROUP BY customer_id
)

SELECT
    COALESCE(l.customer_id, p.customer_id) AS customer_id,

    COALESCE(l.spend_last_60, 0) AS spend_last_60,
    COALESCE(p.spend_prev_60, 0) AS spend_prev_60,

    COALESCE(l.orders_last_60, 0) AS orders_last_60,
    COALESCE(p.orders_prev_60, 0) AS orders_prev_60,

    (COALESCE(p.spend_prev_60, 0) - COALESCE(l.spend_last_60, 0)) AS spend_drop,

    CASE
        WHEN COALESCE(l.spend_last_60, 0) > 0
         AND COALESCE(p.spend_prev_60, 0) > 0
        THEN 'Active'

        WHEN COALESCE(l.spend_last_60, 0) = 0
         AND COALESCE(p.spend_prev_60, 0) > 0
        THEN 'Churned'

        WHEN COALESCE(l.spend_last_60, 0) > 0
         AND COALESCE(p.spend_prev_60, 0) = 0
        THEN 'New'

        ELSE 'No Activity'
    END AS customer_status

FROM last_60 l
FULL OUTER JOIN prev_60 p
    ON l.customer_id = p.customer_id;