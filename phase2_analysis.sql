-- ============================================================
-- PHASE 2: SQL BUSINESS ANALYSIS
-- Dataset: Olist E-Commerce (olist_ecommerce database)
-- ============================================================
-- This file contains 5 queries that answer core business questions:
--   1. Revenue and order trends over time
--   2. Best-selling products within each category
--   3. Month-over-month growth
--   4. Revenue and orders by customer state (geography)
--   5. Late delivery rate by customer state (logistics performance)
--
-- All queries exclude 'canceled' and 'unavailable' orders unless
-- otherwise noted, since those didn't generate real revenue.
-- ============================================================


-- ------------------------------------------------------------
-- QUERY 1: Total revenue and order count, by month
-- ------------------------------------------------------------
-- WHAT IT DOES:
--   Groups all order items by the month the order was placed,
--   then sums up revenue (price only, not shipping) and counts
--   the number of distinct orders per month.
--
-- WHY price ONLY (not price + freight_value):
--   freight_value is the shipping fee, which mostly passes through
--   to logistics/sellers rather than being "revenue" for the
--   business in the way product price is.
--
-- WHY COUNT(DISTINCT o.order_id) instead of COUNT(*):
--   One order can contain multiple products (multiple rows in
--   order_items). COUNT(*) would count an order with 3 products
--   as 3 orders. COUNT(DISTINCT order_id) counts it correctly, once.
--
-- FINDING:
--   Data is very sparse in late 2016 (Olist's early pilot phase),
--   ramps up steadily through 2017, spikes hard in Nov 2017
--   (Black Friday), plateaus through mid-2018, then drops off in
--   Sept 2018 because that's simply where the dataset's data
--   collection ends (not a real business decline).
-- ------------------------------------------------------------

SELECT 
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
    SUM(oi.price) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY order_month
ORDER BY order_month;


-- ------------------------------------------------------------
-- QUERY 2: Top 3 best-selling products within each category
-- ------------------------------------------------------------
-- WHAT IT DOES:
--   For every product category, ranks products by total revenue
--   and keeps only the top 3 in each category.
--
-- HOW THE RANKING WORKS (RANK() OVER (PARTITION BY ...)):
--   PARTITION BY product_category_name tells SQL to "restart" the
--   ranking for every category, instead of ranking all products
--   in the whole dataset together. ORDER BY SUM(price) DESC ranks
--   from highest revenue to lowest within each category.
--   This is called a "window function" and it's one of the most
--   common patterns asked about in data analyst interviews.
--
-- WHY SOME ROWS SHOW A BLANK CATEGORY:
--   A small number of products in the raw Olist data have no
--   category assigned (NULL). This is a known data quality issue,
--   not a mistake in the query -- worth mentioning in your README.
-- ------------------------------------------------------------

SELECT *
FROM (
    SELECT 
        p.product_category_name,
        oi.product_id,
        SUM(oi.price) AS product_revenue,
        RANK() OVER (PARTITION BY p.product_category_name ORDER BY SUM(oi.price) DESC) AS category_rank
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY p.product_category_name, oi.product_id
) ranked
WHERE category_rank <= 3
ORDER BY product_category_name, category_rank;


-- ------------------------------------------------------------
-- QUERY 3: Month-over-month revenue growth
-- ------------------------------------------------------------
-- WHAT IT DOES:
--   Takes the monthly revenue totals from Query 1 and compares
--   each month to the month before it, calculating a percent
--   growth (or decline).
--
-- HOW LAG() WORKS:
--   LAG(total_revenue) OVER (ORDER BY order_month) grabs the
--   PREVIOUS row's revenue value and lines it up next to the
--   CURRENT row. This lets you compare "this month vs last month"
--   without writing a manual self-join.
--
-- WHY THE FIRST ROW SHOWS NULL:
--   There's no month before the very first month in the data,
--   so LAG() has nothing to pull -- that's expected, not a bug.
--
-- FINDING:
--   Early months (2016) show extreme, meaningless percentages
--   (e.g. +1,101,718%) because the starting revenue was nearly
--   zero -- any small increase looks huge as a percentage.
--   From 2017 onward, growth settles into a believable range,
--   with a clear +52% spike in November 2017 (Black Friday).
-- ------------------------------------------------------------

SELECT 
    order_month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY order_month) AS prev_month_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY order_month)) 
        / LAG(total_revenue) OVER (ORDER BY order_month) * 100, 
    2) AS pct_growth
FROM (
    SELECT 
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        SUM(oi.price) AS total_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY order_month
) monthly
ORDER BY order_month;


-- ------------------------------------------------------------
-- QUERY 4: Revenue, order count, and average order value by state
-- ------------------------------------------------------------
-- WHAT IT DOES:
--   Groups all orders by the customer's state and calculates
--   total orders, total revenue, and average revenue per order
--   for each state.
--
-- FINDING:
--   Sao Paulo (SP) alone accounts for roughly 38% of total
--   revenue -- unsurprising since it's Brazil's largest and most
--   developed state, and Olist is a Brazilian marketplace.
--   Rio de Janeiro (RJ) and Minas Gerais (MG) are a distant
--   second and third. Smaller/farther states (AP, RR, AC) have
--   very few orders but a HIGHER average order value -- likely
--   fewer, larger purchases rather than frequent small ones.
-- ------------------------------------------------------------

SELECT 
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.price) AS total_revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_state
ORDER BY total_revenue DESC;


-- ------------------------------------------------------------
-- QUERY 5: Late delivery rate by customer state
-- ------------------------------------------------------------
-- WHAT IT DOES:
--   For every order that was actually delivered, checks whether
--   the real delivery date came AFTER the estimated delivery
--   date (i.e. it was late), then calculates what percentage of
--   each state's deliveries were late.
--
-- WHY WE FILTER TO order_delivered_customer_date IS NOT NULL:
--   You can't measure "late" for an order that never arrived, so
--   orders with no delivery date (canceled, lost, etc.) are
--   excluded from this specific analysis.
--
-- HOW THE CASE STATEMENT WORKS:
--   CASE WHEN ... THEN 1 ELSE 0 END turns a true/false comparison
--   into a 1 or 0, which lets SUM() count how many orders in each
--   state met the "late" condition.
--
-- FINDING (the most interesting one in this whole analysis):
--   Contrary to the initial assumption that remote northern
--   states (AP, AM, AC) would have the worst delivery
--   performance, it's actually NORTHEAST states (AL, MA, PI, CE,
--   SE, BA) with the highest late-delivery rates (15-24%).
--   The remote North states actually have some of the LOWEST
--   late rates -- likely because Olist sets longer, more
--   conservative delivery estimates for those far-flung areas,
--   making the estimate easier to beat. SP and MG, despite having
--   the highest order volume, have among the lowest late rates,
--   consistent with denser logistics infrastructure near Brazil's
--   economic center.
--   LESSON: the data corrected the original hypothesis rather
--   than confirming it -- a stronger, more honest finding than a
--   guess that just happened to be right.
-- ------------------------------------------------------------

SELECT 
    c.customer_state,
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_orders,
    ROUND(
        SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) 
        / COUNT(*) * 100, 
    2) AS pct_late
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY pct_late DESC;