-- =====================================================================
-- OLIST PROJECT - PHASE 2 (SQL)  |  FILE 2 OF 2: ANALYSIS QUERIES
-- Run AFTER 01_create_tables.sql and after importing all 8 clean CSVs.
--
-- HOW TO RUN in pgAdmin: open Query Tool, paste this file, then run ONE query
-- at a time: select the query text with the mouse and press F5.
-- (If you press F5 without selecting, pgAdmin runs the whole file and shows
-- only the last result.)
--
-- Parts:  0 = setup view (run first)
--         A = sanity checks and the definition of "late"
--         B = MUST-HAVE business analysis (14 queries)
--         C = ADVANCED queries: windows, CTEs, ranking, views (8 queries)
-- Each query has 3 comment lines: What / Why / Watch out.
-- =====================================================================


-- =====================================================================
-- PART 0: SETUP (run this first, only once)
-- What: creates a view that holds delivered orders with delivery_days, delay_days and is_late.
-- Why: "late" is defined in ONE place. Every query below reuses it, so the ML target stays consistent.
-- Watch out: is_late = 1 when the delivery DATE is after the promised DATE (see query A2 for why).
-- =====================================================================
CREATE OR REPLACE VIEW v_delivered_orders AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_purchase_timestamp,
    o.order_estimated_delivery_date,
    o.order_delivered_customer_date,
    ROUND(CAST(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0 AS NUMERIC), 2) AS delivery_days,
    ROUND(CAST(EXTRACT(EPOCH FROM (o.order_estimated_delivery_date - o.order_purchase_timestamp)) / 86400.0 AS NUMERIC), 2) AS estimated_days,
    (CAST(o.order_delivered_customer_date AS DATE) - CAST(o.order_estimated_delivery_date AS DATE)) AS delay_days,
    CASE WHEN CAST(o.order_delivered_customer_date AS DATE) > CAST(o.order_estimated_delivery_date AS DATE)
         THEN 1 ELSE 0 END AS is_late
FROM orders o
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;


-- =====================================================================
-- PART A: SANITY CHECKS AND DEFINITIONS
-- =====================================================================

-- A1. Row counts of all 8 tables
-- What: counts rows in every table.
-- Why: confirms your CSV import worked.
-- Watch out: must match Phase 1 exactly (99,441 / 3,095 / 19,004 / 32,951 / 99,441 / 112,650 / 103,886 / 98,673).
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
ORDER BY row_count DESC;


-- A2. How "late" is defined (timestamp vs date)
-- What: counts late orders using two possible definitions.
-- Why: the estimated date is always at 00:00, so a delivery at 3 pm ON the promised day looks late by timestamp.
-- Watch out: we use the DATE definition (is_late in the view). This is the ML target, so decide it once.
SELECT
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_by_timestamp,
    SUM(is_late) AS late_by_date,
    ROUND(100.0 * SUM(is_late) / COUNT(*), 2) AS late_pct_by_date
FROM v_delivered_orders;


-- =====================================================================
-- PART B: MUST-HAVE BUSINESS ANALYSIS
-- =====================================================================

-- B1. Order status distribution
-- What: how many orders are in each status, with the percentage.
-- Why: shows how much of the data is delivered vs canceled.
-- Watch out: SUM(COUNT(*)) OVER () gives the grand total without a second query.
SELECT
    order_status,
    COUNT(*) AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- B2. Business summary: revenue, freight, average order value
-- What: headline numbers for delivered orders.
-- Why: first thing any manager asks. Revenue = item price (freight shown separately).
-- Watch out: COUNT(DISTINCT order_id), because an order has many item rows.
SELECT
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(SUM(i.price), 2) AS revenue,
    ROUND(SUM(i.freight_value), 2) AS freight,
    ROUND(SUM(i.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items i ON o.order_id = i.order_id
WHERE o.order_status = 'delivered';

-- B3. Monthly orders and revenue
-- What: orders and revenue for every purchase month.
-- Why: shows growth and seasonality (look at Nov 2017).
-- Watch out: first and last months have very few orders (partial months in the dataset).
SELECT
    TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM') AS month,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(i.price), 2) AS revenue
FROM orders o
JOIN order_items i ON o.order_id = i.order_id
WHERE o.order_status = 'delivered'
GROUP BY TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM')
ORDER BY month;

-- B4. Top 10 product categories by revenue
-- What: best categories with items sold and average price.
-- Why: shows where the money comes from.
-- Watch out: we use the English name we added in Phase 1.
SELECT
    p.product_category_name_english AS category,
    COUNT(*) AS items_sold,
    ROUND(SUM(i.price), 2) AS revenue,
    ROUND(AVG(i.price), 2) AS avg_price
FROM order_items i
JOIN orders o ON i.order_id = o.order_id
JOIN products p ON i.product_id = p.product_id
WHERE o.order_status = 'delivered'
GROUP BY p.product_category_name_english
ORDER BY revenue DESC
LIMIT 10;

-- B5. Top 10 customer states by revenue
-- What: orders and revenue per customer state.
-- Why: shows how concentrated the business is (SP vs the rest).
-- Watch out: the join order -> customers -> items must not multiply rows, so we count DISTINCT orders.
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(i.price), 2) AS revenue
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items i ON o.order_id = i.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC
LIMIT 10;

-- B6. Payment types
-- What: number of payments, total value, share of value and average installments per type.
-- Why: shows how customers pay (credit card, boleto, voucher ...).
-- Watch out: not_defined (3 rows, value 0) is kept on purpose.
SELECT
    payment_type,
    COUNT(*) AS payments,
    ROUND(SUM(payment_value), 2) AS total_value,
    ROUND(100.0 * SUM(payment_value) / SUM(SUM(payment_value)) OVER (), 2) AS pct_of_value,
    ROUND(AVG(payment_installments), 2) AS avg_installments
FROM order_payments
GROUP BY payment_type
ORDER BY total_value DESC;

-- B7. Review score distribution
-- What: how many reviews for each score 1 to 5.
-- Why: shows overall customer satisfaction.
-- Watch out: reviews exist only for 98,673 orders (not every order has one).
SELECT
    review_score,
    COUNT(*) AS reviews,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM order_reviews
GROUP BY review_score
ORDER BY review_score DESC;

-- B8. Delivery performance overview (the core of the project)
-- What: average actual vs promised delivery days and the overall late rate.
-- Why: this is the problem the ML model will predict.
-- Watch out: only delivered orders with a delivery date are used (view v_delivered_orders).
SELECT
    COUNT(*) AS delivered_orders,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(AVG(estimated_days), 2) AS avg_estimated_days,
    SUM(is_late) AS late_orders,
    ROUND(100.0 * SUM(is_late) / COUNT(*), 2) AS late_pct
FROM v_delivered_orders;

-- B9. Late rate by customer state
-- What: late orders, late % and average delivery days for every state.
-- Why: finds the regions with delivery problems.
-- Watch out: look at order counts too, a small state can have an extreme % from few orders.
SELECT
    c.customer_state,
    COUNT(*) AS orders,
    SUM(d.is_late) AS late_orders,
    ROUND(100.0 * SUM(d.is_late) / COUNT(*), 2) AS late_pct,
    ROUND(AVG(d.delivery_days), 2) AS avg_delivery_days
FROM v_delivered_orders d
JOIN customers c ON d.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY late_pct DESC;

-- B10. Late rate by purchase month
-- What: late % for every month.
-- Why: shows seasonality (holiday peaks overload carriers).
-- Watch out: the month comes from the purchase date, not the delivery date.
SELECT
    TO_CHAR(order_purchase_timestamp, 'YYYY-MM') AS month,
    COUNT(*) AS orders,
    SUM(is_late) AS late_orders,
    ROUND(100.0 * SUM(is_late) / COUNT(*), 2) AS late_pct
FROM v_delivered_orders
GROUP BY TO_CHAR(order_purchase_timestamp, 'YYYY-MM')
ORDER BY month;

-- B11. Late delivery vs review score (business impact)
-- What: average review score for on-time vs late orders.
-- Why: proves late delivery hurts customer satisfaction, which is why the ML model matters.
-- Watch out: join to reviews is one-to-one because order_id is the key there.
SELECT
    d.is_late,
    COUNT(*) AS orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM v_delivered_orders d
JOIN order_reviews r ON d.order_id = r.order_id
GROUP BY d.is_late
ORDER BY d.is_late;

-- B12. Late rate by product category (top 10, at least 200 orders)
-- What: categories with the highest late %.
-- Why: some product types ship slower (large, fragile, special sellers).
-- Watch out: grain. We first make one row per (order, category) so an order is not counted twice.
WITH order_category AS (
    SELECT DISTINCT i.order_id, p.product_category_name_english AS category
    FROM order_items i
    JOIN products p ON i.product_id = p.product_id
)
SELECT
    oc.category,
    COUNT(*) AS orders,
    SUM(d.is_late) AS late_orders,
    ROUND(100.0 * SUM(d.is_late) / COUNT(*), 2) AS late_pct
FROM order_category oc
JOIN v_delivered_orders d ON oc.order_id = d.order_id
GROUP BY oc.category
HAVING COUNT(*) >= 200
ORDER BY late_pct DESC
LIMIT 10;

-- B13. Same-state vs different-state delivery (distance proxy)
-- What: compares late % when seller and customer are in the same state or not.
-- Why: gives an early idea of how much distance matters, before we calculate real distance.
-- Watch out: only orders with exactly one seller are used, so each order has one clear seller state.
WITH single_seller AS (
    SELECT i.order_id, MIN(s.seller_state) AS seller_state
    FROM order_items i
    JOIN sellers s ON i.seller_id = s.seller_id
    GROUP BY i.order_id
    HAVING COUNT(DISTINCT i.seller_id) = 1
)
SELECT
    CASE WHEN ss.seller_state = c.customer_state THEN 'same state' ELSE 'different state' END AS route,
    COUNT(*) AS orders,
    ROUND(AVG(d.delivery_days), 2) AS avg_delivery_days,
    ROUND(100.0 * SUM(d.is_late) / COUNT(*), 2) AS late_pct
FROM v_delivered_orders d
JOIN customers c ON d.customer_id = c.customer_id
JOIN single_seller ss ON d.order_id = ss.order_id
GROUP BY CASE WHEN ss.seller_state = c.customer_state THEN 'same state' ELSE 'different state' END
ORDER BY route;

-- B14. Freight cost by customer state
-- What: average freight and freight as % of item price per state.
-- Why: far states pay much more for shipping, which can also explain delays.
-- Watch out: freight % uses SUM / SUM, not the average of percentages.
SELECT
    c.customer_state,
    COUNT(*) AS items,
    ROUND(AVG(i.freight_value), 2) AS avg_freight,
    ROUND(100.0 * SUM(i.freight_value) / SUM(i.price), 2) AS freight_pct_of_price
FROM order_items i
JOIN orders o ON i.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY avg_freight DESC;


-- =====================================================================
-- PART C: ADVANCED ANALYSIS
-- =====================================================================

-- C1. Month-over-month revenue growth and running total (window functions)
-- What: revenue per month, previous month, growth % and cumulative revenue.
-- Why: LAG looks at the previous row and SUM() OVER gives a running total, without self-joins.
-- Watch out: the first month has no previous month, so its growth is NULL.
WITH monthly AS (
    SELECT
        TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM') AS month,
        SUM(i.price) AS revenue
    FROM orders o
    JOIN order_items i ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM')
)
SELECT
    month,
    ROUND(revenue, 2) AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY month), 2) AS previous_month,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month)) / LAG(revenue) OVER (ORDER BY month), 2) AS growth_pct,
    ROUND(SUM(revenue) OVER (ORDER BY month), 2) AS cumulative_revenue
FROM monthly
ORDER BY month;

-- C2. Top 10 sellers by revenue with RANK
-- What: ranks sellers by revenue and shows their orders.
-- Why: RANK() numbers rows by a value; ties get the same rank.
-- Watch out: RANK vs DENSE_RANK vs ROW_NUMBER is a common interview question.
WITH seller_stats AS (
    SELECT
        i.seller_id,
        COUNT(DISTINCT i.order_id) AS orders,
        SUM(i.price) AS revenue
    FROM order_items i
    JOIN orders o ON i.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY i.seller_id
)
SELECT
    RANK() OVER (ORDER BY revenue DESC) AS rank_by_revenue,
    seller_id,
    orders,
    ROUND(revenue, 2) AS revenue
FROM seller_stats
ORDER BY rank_by_revenue
LIMIT 10;

-- C3. Sellers with the highest late rate (at least 50 delivered orders)
-- What: finds sellers whose orders are late most often.
-- Why: seller behaviour is a likely ML feature and a business action list.
-- Watch out: HAVING filters groups (after GROUP BY), WHERE filters rows (before). Minimum 50 orders avoids lucky/unlucky tiny sellers.
WITH seller_orders AS (
    SELECT DISTINCT seller_id, order_id
    FROM order_items
)
SELECT
    so.seller_id,
    COUNT(*) AS orders,
    SUM(d.is_late) AS late_orders,
    ROUND(100.0 * SUM(d.is_late) / COUNT(*), 2) AS late_pct
FROM seller_orders so
JOIN v_delivered_orders d ON so.order_id = d.order_id
GROUP BY so.seller_id
HAVING COUNT(*) >= 50
ORDER BY late_pct DESC
LIMIT 10;

-- C4. Pareto check: how much revenue do the top 20% of sellers make (NTILE)
-- What: splits sellers into 5 equal groups by revenue and shows each group share.
-- Why: tests the 80/20 rule and shows how dependent the business is on few sellers.
-- Watch out: NTILE(5) makes 5 groups of (almost) equal number of sellers, bucket 1 = top sellers.
WITH seller_rev AS (
    SELECT i.seller_id, SUM(i.price) AS revenue
    FROM order_items i
    JOIN orders o ON i.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY i.seller_id
),
bucketed AS (
    SELECT seller_id, revenue, NTILE(5) OVER (ORDER BY revenue DESC) AS bucket
    FROM seller_rev
)
SELECT
    bucket,
    COUNT(*) AS sellers,
    ROUND(SUM(revenue), 2) AS revenue,
    ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS pct_of_revenue
FROM bucketed
GROUP BY bucket
ORDER BY bucket;

-- C5. Repeat customers (customer_unique_id vs customer_id)
-- What: how many real customers ordered more than once.
-- Why: customer_id is created per order, so only customer_unique_id identifies the person.
-- Watch out: using customer_id here would wrongly show 0% repeat customers.
WITH customer_orders AS (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS orders
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS customers,
    SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_pct
FROM customer_orders;

-- C6. Delay buckets vs review score (CASE)
-- What: groups orders by how early or late they arrived and shows the average review.
-- Why: shows exactly where customers get unhappy (a few days late vs a week late).
-- Watch out: delay_days is negative when the order arrived before the promised date.
SELECT
    CASE
        WHEN d.delay_days <= -7 THEN '1. 7+ days early'
        WHEN d.delay_days <= -1 THEN '2. 1-6 days early'
        WHEN d.delay_days = 0   THEN '3. on the promised date'
        WHEN d.delay_days <= 7  THEN '4. 1-7 days late'
        ELSE '5. 8+ days late'
    END AS delivery_bucket,
    COUNT(*) AS orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM v_delivered_orders d
JOIN order_reviews r ON d.order_id = r.order_id
GROUP BY 1
ORDER BY 1;

-- C7. Median vs average delivery days by state (PERCENTILE_CONT)
-- What: median and average delivery days per customer state.
-- Why: a few very slow orders pull the average up; the median shows the typical order.
-- Watch out: PERCENTILE_CONT is PostgreSQL syntax (it exists in PostgreSQL, not in every database).
SELECT
    c.customer_state,
    COUNT(*) AS orders,
    ROUND(CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(d.delivery_days AS DOUBLE PRECISION)) AS NUMERIC), 2) AS median_delivery_days,
    ROUND(AVG(d.delivery_days), 2) AS avg_delivery_days
FROM v_delivered_orders d
JOIN customers c ON d.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY median_delivery_days DESC;

-- C8. Order-level summary view (aggregate first, then join) + proof of no join explosion
-- What: builds one row per delivered order with items, price, freight, payment and review.
-- Why: items and payments are summed BEFORE joining, so orders are never duplicated. This view is the base of the ML table later.
-- Watch out: the check query must show the same number for COUNT(*) and COUNT(DISTINCT order_id).
CREATE OR REPLACE VIEW v_order_summary AS
WITH item_agg AS (
    SELECT
        order_id,
        COUNT(*) AS items,
        COUNT(DISTINCT seller_id) AS sellers,
        SUM(price) AS total_price,
        SUM(freight_value) AS total_freight
    FROM order_items
    GROUP BY order_id
),
pay_agg AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_paid,
        MAX(payment_installments) AS max_installments
    FROM order_payments
    GROUP BY order_id
)
SELECT
    d.order_id,
    c.customer_state,
    d.order_purchase_timestamp,
    d.delivery_days,
    d.estimated_days,
    d.delay_days,
    d.is_late,
    ia.items,
    ia.sellers,
    ia.total_price,
    ia.total_freight,
    pa.total_paid,
    pa.max_installments,
    r.review_score
FROM v_delivered_orders d
JOIN customers c ON d.customer_id = c.customer_id
LEFT JOIN item_agg ia ON d.order_id = ia.order_id
LEFT JOIN pay_agg pa ON d.order_id = pa.order_id
LEFT JOIN order_reviews r ON d.order_id = r.order_id;

SELECT
    COUNT(*) AS rows_in_view,
    COUNT(DISTINCT order_id) AS distinct_orders,
    ROUND(AVG(items), 2) AS avg_items_per_order,
    SUM(CASE WHEN sellers > 1 THEN 1 ELSE 0 END) AS multi_seller_orders,
    ROUND(AVG(total_price), 2) AS avg_price,
    ROUND(AVG(total_freight), 2) AS avg_freight
FROM v_order_summary;
