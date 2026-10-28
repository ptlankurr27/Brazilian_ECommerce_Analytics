-- 1. customers
-- What: one row per customer_id. Why: PRIMARY KEY stops duplicate rows.
-- Watch out: customer_id is created per ORDER; customer_unique_id is the real person.
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id              VARCHAR(50) PRIMARY KEY,
    customer_unique_id       VARCHAR(50) NOT NULL,
    customer_zip_code_prefix INTEGER,
    customer_city            VARCHAR(100),
    customer_state           CHAR(2)
);

-- ---------------------------------------------------------------------
-- 2. sellers
-- What: one row per seller. Why: seller_id is the key used by order_items.
-- ---------------------------------------------------------------------
CREATE TABLE sellers (
    seller_id              VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix INTEGER,
    seller_city            VARCHAR(100),
    seller_state           CHAR(2)
);

-- ---------------------------------------------------------------------
-- 3. geolocation
-- What: one row per zip prefix (we made this in Phase 1).
-- Why: PRIMARY KEY on the zip proves the one-row-per-zip rule is true.
-- Watch out: no foreign key from customers/sellers, because ~287 customer zips
-- and ~7 seller zips are not in this table (we handle that in the ML phase).
-- ---------------------------------------------------------------------
CREATE TABLE geolocation (
    geolocation_zip_code_prefix INTEGER PRIMARY KEY,
    geolocation_lat             DOUBLE PRECISION,
    geolocation_lng             DOUBLE PRECISION,
    geolocation_city            VARCHAR(100),
    geolocation_state           CHAR(2)
);

-- ---------------------------------------------------------------------
-- 4. products
-- What: one row per product, with the English category from Phase 1.
-- Watch out: the numeric columns are NUMERIC (not INTEGER) because the CSV
-- stores them like 40.0, and INTEGER would reject that during import.
-- ---------------------------------------------------------------------
CREATE TABLE products (
    product_id                    VARCHAR(50) PRIMARY KEY,
    product_category_name         VARCHAR(100),
    product_name_length           NUMERIC,
    product_description_length    NUMERIC,
    product_photos_qty            NUMERIC,
    product_weight_g              NUMERIC,
    product_length_cm             NUMERIC,
    product_height_cm             NUMERIC,
    product_width_cm              NUMERIC,
    product_category_name_english VARCHAR(100)
);

-- ---------------------------------------------------------------------
-- 5. orders
-- What: one row per order, the main table of the project.
-- Why: the delivery date columns are allowed to be NULL (canceled/undelivered orders).
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    order_id                      VARCHAR(50) PRIMARY KEY,
    customer_id                   VARCHAR(50) NOT NULL REFERENCES customers (customer_id),
    order_status                  VARCHAR(20),
    order_purchase_timestamp      TIMESTAMP NOT NULL,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 6. order_items
-- What: one row per item in an order. Why: composite PRIMARY KEY (order + item number).
-- Watch out: one order can have several items, so this table is bigger than orders.
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    order_id            VARCHAR(50) NOT NULL REFERENCES orders (order_id),
    order_item_id       INTEGER NOT NULL,
    product_id          VARCHAR(50) NOT NULL REFERENCES products (product_id),
    seller_id           VARCHAR(50) NOT NULL REFERENCES sellers (seller_id),
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(10, 2),
    freight_value       NUMERIC(10, 2),
    PRIMARY KEY (order_id, order_item_id)
);

-- ---------------------------------------------------------------------
-- 7. order_payments
-- What: one row per payment of an order. Why: composite PRIMARY KEY (order + payment number).
-- Watch out: one order can have several payments (for example voucher + card).
-- ---------------------------------------------------------------------
CREATE TABLE order_payments (
    order_id             VARCHAR(50) NOT NULL REFERENCES orders (order_id),
    payment_sequential   INTEGER NOT NULL,
    payment_type         VARCHAR(20),
    payment_installments INTEGER,
    payment_value        NUMERIC(10, 2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- ---------------------------------------------------------------------
-- 8. order_reviews
-- What: one review per order (we kept the latest one in Phase 1).
-- Watch out: order_id is the PRIMARY KEY here, NOT review_id, because the same
-- review_id appears on more than one order in the raw data.
-- ---------------------------------------------------------------------
CREATE TABLE order_reviews (
    review_id               VARCHAR(50),
    order_id                VARCHAR(50) PRIMARY KEY REFERENCES orders (order_id),
    review_score            INTEGER,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- =====================================================================
-- IMPORT ORDER (important, because of the foreign keys):
--   1. customers_clean.csv       -> customers
--   2. sellers_clean.csv         -> sellers
--   3. geolocation_clean.csv     -> geolocation
--   4. products_clean.csv        -> products
--   5. orders_clean.csv          -> orders
--   6. order_items_clean.csv     -> order_items
--   7. order_payments_clean.csv  -> order_payments
--   8. order_reviews_clean.csv   -> order_reviews
-- Parent tables first, child tables after. If you import a child table early,
-- PostgreSQL will refuse the rows (that is the foreign key doing its job).
-- =====================================================================
