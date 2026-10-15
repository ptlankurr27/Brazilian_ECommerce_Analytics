-- Business Analysis
-- ------------------------Revenue---------------------

-- Total Revenue
select round(sum(payment_value),2) as Total_Revenue
from payments;

-- Monthly Revenue - Growth trend
select o.order_year, o.order_month_name, round(sum(payment_value),2) as Total_monthly_revenue
from Payments p
left join orders o
on p.order_id = o.order_id
group by o.order_year,
o.order_month_name
order by o.order_year,
o.order_month_name;

-- Revenue Growth % - Is business improving?
with monthly_revenue as (
    select
        o.order_year,
        o.order_month,
        o.order_month_name,
        round(sum(p.payment_value), 2) as revenue
    from payments p
    join orders o
        on p.order_id = o.order_id
    group by
        o.order_year,
        o.order_month,
        o.order_month_name
)

select
    order_year,
    order_month,
    order_month_name,
    revenue,
    lag(revenue) over (
	order by order_year, order_month
    ) as previous_revenue,
    round((revenue -lag(revenue) 
    over ( order by order_year, order_month)
        ) /
        lag(revenue) over (
            order by order_year, order_month
        ) * 100,
        2
    ) as revenue_growth_pct
from monthly_revenue
order by
    order_year,
    order_month;
    
-- Revenue by Category - Which products make money?
select
    pd.product_category_name,
    round(sum(oi.price), 2) as revenue
from order_items oi
join products pd
    on oi.product_id = pd.product_id
group by pd.product_category_name
order by revenue desc;

-- Revenue by State

select
c.customer_state,
round(sum(oi.price), 2) as revenue
from order_items oi
join orders o
on oi.order_id = o.order_id
join customers c
on o.customer_id = c.customer_id
group by c.customer_state
order by revenue desc;


-- ------------------------order---------------------

-- Total Orders
select count(order_id) as Total_orders from orders;

-- Orders per Month

select order_year, order_month, count(order_id) as Tot_order
from orders
group by order_year, order_month
order by order_year, order_month;

-- Average Order Value
select
round(sum(payment_value) /count(distinct order_id),2 )
as avg_order_value
from payments;

-- Cancelled Orders %
select
    round(
        count(case
            when order_status = 'canceled'
            then 1
        end)
        * 100.0
        / count(*),
        2
    ) as cancelled_order_pct
from orders;

-- ---------------------------Customers-------------------

-- Total Customers
select count(customer_id) as Total_customer
from customers;

-- New Customers per Month

-- select order_year, order_month, count(*), lag(count(*)) over (
-- 	order by order_year, order_month) as nxt, 
--     (count(*) - lag(count(*)) over (
-- 	order by order_year, order_month)) as new_customers
--     from customers c
-- join orders o
-- on c.customer_id = o.customer_id
-- group by order_year, order_month
-- order by order_year, order_month;

select
    year(first_order_date) as order_year,
    month(first_order_date) as order_month,
    count(*) as new_customers
from (
    select
        customer_id,
        min(order_purchase_timestamp) as first_order_date
    from orders
    group by customer_id
) t
group by
    year(first_order_date),
    month(first_order_date)
order by
    order_year,
    order_month;

-- Repeat Customers

select
    customer_id,
    count(order_id) as total_orders
from orders
group by customer_id
having count(order_id) > 1;

-- Repeat Customer Rate
select
    round(
        count(*) * 100.0 /
        (
            select count(distinct customer_id)
            from orders
        ),
        2
    ) as repeat_customer_rate
from (
    select customer_id
    from orders
    group by customer_id
    having count(order_id) > 1
) t;

-- New Customers per Month

select
    year(first_order_date) as order_year,
    month(first_order_date) as order_month,
    count(*) as new_customers
from (
    select
        customer_id,
        min(order_purchase_timestamp) as first_order_date
    from orders
    group by customer_id
) t
group by
    year(first_order_date),
    month(first_order_date)
order by
    order_year,
    order_month;
    
-- -------------------------Products--------------------------------

-- Top Selling Products

select
    p.product_id,
    p.product_category_name,
    round(sum(o.price),2) as product_revenue
from products p
join order_items o
on p.product_id = o.product_id
group by
    p.product_id,
    p.product_category_name
order by product_revenue desc
limit 10;

-- Top Categories
select
    p.product_category_name,
    round(sum(o.price),2) as category_revenue
from products p
join order_items o
on p.product_id = o.product_id
group by p.product_category_name
order by category_revenue desc
limit 10;

-- Average Product Rating
select p.product_category_name, round(avg(r.review_score), 2) as avg_product_rating
from products p
join order_items o
on p.product_id = o.product_id
join reviews r
on o.order_id = r.order_id
group by p.product_category_name
order by avg_product_rating desc;

-- ---------------------------------Sellers--------------------------------

-- Number of Sellers

select count(distinct(seller_id)) 
as no_of_sellers from sellers;

-- Top Sellers by Revenue

select s.seller_id, round(sum(oi.price), 2) as seller_revenue
from sellers s
join order_items oi
on s.seller_id = oi.seller_id
group by s.seller_id
order by seller_revenue desc
limit 10;

-- ---------------------------------Delivery--------------------------------

-- Average Delivery Time

select
    round(avg(datediff(order_delivered_customer_date,
                       order_purchase_timestamp)), 2) as avg_delivery_days
from orders
where order_delivered_customer_date is not null;

-- Delayed Deliveries

select
    order_id,
    order_estimated_delivery_date,
    order_delivered_customer_date,
    datediff(order_delivered_customer_date,
             order_estimated_delivery_date) as delayed_by_days
from orders
where order_delivered_customer_date > order_estimated_delivery_date;

-- ----------------------------------Reviews---------------------------------

-- Average Rating

select avg(review_score) as avg_rating from reviews;

-- Rating Distribution

select
    review_score,
    count(*) as total_reviews
from reviews
group by review_score
order by review_score;

-- ---------------------------------Payments------------------------------------

-- Most Used Payment Method

select
payment_type,
count(*) as use_times
from payments
group by payment_type
order by use_times desc;

-- Installment Usage

select
payment_installments,
count(*) as total_payments
from payments
group by payment_installments
order by payment_installments;