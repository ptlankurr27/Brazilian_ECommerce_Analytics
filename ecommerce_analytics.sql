create database ecommerce_analytics;
use ecommerce_analytics;

-- So, what we try to do is designing tables for which we have to 
-- 1. Database Design
-- Primary Keys
-- Foreign Keys
-- Relationships (ER Diagram)

-- Example:
-- customers ─── orders ─── order_items ─── products
--                       │
--                       ├── payments
--                       └── reviews
-- Check table have duplicate ids or not

select count(*), 
count(distinct(customer_id)) as unique_customer
from customers;

select count(*), 
count(distinct(order_id)) as unique_order
from orders;

select count(*), 
count(distinct(product_id)) as unique_product
from products;

select count(*), 
count(distinct(seller_id)) as unique_seller
from sellers;

-- checking weather review_id can be a primary key or not
select count(*),
count(distinct(review_id)) as unique_review 
from reviews;

select review_id, count(*) as cnt
from reviews
group by review_id
having cnt > 1
limit 10;

select count(*), count(distinct(geolocation_zip_code_prefix))
from geolocation;

-- checking if primary keys have null or not

select count(*) from customers where customer_id is null;
select count(*) from orders where order_id is null;
select count(*) from products where product_id is null;
select count(*) from sellers where seller_id is null;

-- check datatype of ids

describe customers;
describe orders;
describe sellers;
describe products;

-- Modify ids to varchar

alter table customers
modify customer_id varchar(32);

alter table orders
modify order_id varchar(32);

alter table products
modify product_id varchar(32);

alter table sellers
modify seller_id varchar(32);

-- Adding primary keys

alter table customers
add primary key(customer_id);

alter table orders
add primary key(order_id);

alter table sellers
add primary key(seller_id);

alter table products
add primary key(product_id);

alter table customers
modify customer_id varchar(32),
modify customer_unique_id varchar(32);

alter table orders
modify order_id varchar(32),
modify customer_id varchar(32);

alter table products
modify product_id varchar(32);

alter table sellers
modify seller_id varchar(32);

alter table order_items
modify order_id varchar(32),
modify product_id varchar(32),
modify seller_id varchar(32);

alter table payments
modify order_id varchar(32);

alter table reviews
modify review_id varchar(32),
modify order_id varchar(32);

show keys from customers;
show keys from orders;
show keys from products;


-- Foreign Keys 🔗

-- customers (1) ────< orders (Many)
-- orders (1) ────< order_items (Many)
-- products (1) ────< order_items (Many)
-- sellers (1) ────< order_items (Many)
-- orders (1) ────< payments (Many)
-- orders (1) ────< reviews (Many)

-- To check if any customer_id from orders is not in customers table

select count(*) from 
orders o 
left join customers c 
on o.customer_id = c.customer_id
where c.customer_id is null;

select count(*) from 
order_items ot
left join orders o 
on ot.order_id = o.order_id
where o.order_id is null;

select count(*) from 
order_items ot
left join products p 
on ot.product_id = p.product_id
where p.product_id is null;

select count(*) from 
order_items ot
left join sellers s 
on ot.seller_id = s.seller_id
where s.seller_id is null;

select count(*) from reviews r 
left join orders o
on r.order_id = o.order_id
where o.order_id is null;

select count(*) from payments pt
left join orders o
on pt.order_id = o.order_id
where o.order_id is null;

-- Adding Foreign key

alter table orders
add constraint fk_orders_customers
foreign key (customer_id)
references customers(customer_id);

alter table order_items
add constraint fk_order_items_orders
foreign key (order_id)
references orders(order_id);

alter table order_items
add constraint fk_order_items_products
foreign key (product_id)
references products(product_id);

alter table order_items
add constraint fk_order_items_sellers
foreign key (seller_id)
references sellers(seller_id);

alter table order_items
add constraint fk_order_items_sellers
foreign key (seller_id)
references sellers(seller_id);

alter table payments
add constraint fk_payments_orders
foreign key (order_id)
references orders(order_id);

alter table reviews
add constraint fk_reviews_orders
foreign key (order_id)
references orders(order_id);

describe payments;
