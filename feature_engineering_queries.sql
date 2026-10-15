-- Olist E-Commerce: Key SQL Queries
-- Late Delivery Prediction Project

-- ============================================================
-- 1. Define the target: is_late (delivered orders only)
-- ============================================================
SELECT
    o.order_id,
    o.customer_id,
    CASE WHEN julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) > 0
         THEN 1 ELSE 0 END as is_late,
    julianday(o.order_estimated_delivery_date) - julianday(o.order_purchase_timestamp) as estimated_delivery_days,
    strftime('%w', o.order_purchase_timestamp) as purchase_day_of_week,
    strftime('%m', o.order_purchase_timestamp) as purchase_month
FROM orders o
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL;

-- ============================================================
-- 2. Order-level item aggregation (order_items is one-row-per-item)
-- ============================================================
SELECT
    order_id,
    COUNT(*) as num_items,
    SUM(price) as total_price,
    SUM(freight_value) as total_freight,
    AVG(price) as avg_item_price,
    COUNT(DISTINCT seller_id) as num_sellers
FROM order_items
GROUP BY order_id;

-- ============================================================
-- 3. Order-level payment aggregation (orders can have multiple payment rows)
-- ============================================================
SELECT
    order_id,
    SUM(payment_value) as total_payment_value,
    AVG(payment_installments) as avg_installments,
    COUNT(DISTINCT payment_type) as num_payment_types
FROM payments
GROUP BY order_id;

-- ============================================================
-- 4. Product physical attributes per order (JOIN + aggregation)
-- ============================================================
SELECT
    oi.order_id,
    AVG(p.product_weight_g) as avg_weight_g,
    AVG(p.product_length_cm * p.product_height_cm * p.product_width_cm) as avg_volume_cm3,
    COUNT(DISTINCT p.product_category_name) as num_categories
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY oi.order_id;

-- ============================================================
-- 5. Product category, translated to English (3-table join with LEFT JOIN)
-- ============================================================
SELECT
    oi.order_id,
    ct.product_category_name_english as category
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_translation ct ON p.product_category_name = ct.product_category_name
GROUP BY oi.order_id;

-- ============================================================
-- 6. Geolocation: collapse ~1M messy rows to one lat/lng per zip code
-- ============================================================
SELECT
    geolocation_zip_code_prefix as zip_code,
    AVG(geolocation_lat) as lat,
    AVG(geolocation_lng) as lng
FROM geolocation
GROUP BY geolocation_zip_code_prefix;

-- ============================================================
-- 7. Order status breakdown (used to decide which orders are usable)
-- ============================================================
SELECT
    order_status,
    COUNT(*) as count,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) as missing_delivered_date
FROM orders
GROUP BY order_status
ORDER BY count DESC;