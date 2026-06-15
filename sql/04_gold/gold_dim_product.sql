USE DATABASE pacificretail_db;
USE pacificretail_db.gold;

-- Product Dimension
CREATE OR REPLACE VIEW gold.dim_product AS 
SELECT
        p.product_id, 
        p.name, 
        p.category, 
        p.price,
        p.brand, 
        p.stock_quantity, 
        p.rating, is_active,
        p.last_updated_timestamp
FROM silver.product p;