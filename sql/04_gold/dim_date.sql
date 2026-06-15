CREATE OR REPLACE TABLE mart.dim_date AS
SELECT
    date_day,
    YEAR(date_day) AS year,
    QUARTER(date_day) AS quarter,
    MONTH(date_day) AS month_num,
    MONTHNAME(date_day) AS month_name,
    WEEKOFYEAR(date_day) AS week_num,
    DAYOFMONTH(date_day) AS day_num
FROM (
    SELECT
        DATEADD(
            DAY,
            ROW_NUMBER() OVER (ORDER BY seq4()) - 1,
            '2020-01-01'
        ) AS date_day
    FROM TABLE(GENERATOR(ROWCOUNT => 1461))
);
