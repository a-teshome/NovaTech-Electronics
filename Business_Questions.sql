/*
---------------------------------------------------
NovaTech Analysis - Targeted Business Questions
---------------------------------------------------
*/

-- 1) a) What were the order counts, sales, and AOV for Macbooks sold in North America for each quarter across all years? 

SELECT
  DATE_TRUNC(orders.purchase_ts, quarter) AS purchase_quarter,
  COUNT(DISTINCT orders.id) AS order_count,
  ROUND(SUM(orders.usd_price), 2) AS total_sales,
  ROUND(AVG(orders.usd_price), 2) AS aov
FROM core.orders
LEFT JOIN core.customers 
  ON orders.customer_id = customers.id
LEFT JOIN core.geo_lookup 
  ON customers.country_code = geo_lookup.country_code
WHERE LOWER(orders.product_name) LIKE '%macbook%' 
  AND geo_lookup.region = 'NA' 
GROUP BY 1
ORDER BY 1 DESC;


-- b) What is the average quarterly order count and total sales for Macbooks sold in North America? (i.e. “For North America Macbooks, average of X units sold per quarter and Y in dollar sales per quarter”)

WITH quarterly_metrics AS (
    SELECT
    DATE_TRUNC(orders.purchase_ts, quarter) AS purchase_quarter,
    COUNT(DISTINCT orders.id) AS order_count,
    ROUND(SUM(orders.usd_price), 2) AS total_sales,
    ROUND(AVG(orders.usd_price), 2) AS aov
  FROM core.orders
  LEFT JOIN core.customers 
    ON orders.customer_id = customers.id
  LEFT JOIN core.geo_lookup 
    ON customers.country_code = geo_lookup.country_code
  WHERE LOWER(orders.product_name) LIKE '%macbook%' 
    AND geo_lookup.region = 'NA' 
  GROUP BY 1
  ORDER BY 1 DESC)

SELECT 
  AVG(order_count) AS avg_quarter_orders,
  AVG(total_sales) AS avg_quarter_sales,
FROM quarterly_metrics;


-- 2) For products purchased in 2022 on the website or products purchased on mobile in any year, which region has the average highest time to deliver in days? 

SELECT geo_lookup.region,
  ROUND(AVG(DATE_DIFF(order_status.delivery_ts, order_status.purchase_ts, day)), 2) AS avg_days_to_deliver
FROM core.order_status 
LEFT JOIN core.orders
  ON order_status.order_id = orders.id
LEFT JOIN core.customers 
    ON orders.customer_id = customers.id
LEFT JOIN  core.geo_lookup
  ON customers.country_code = geo_lookup.country_code
WHERE (orders.purchase_platform = 'website' 
  AND EXTRACT(year FROM orders.purchase_ts) = 2022) 
  OR purchase_platform = 'mobile app'
GROUP BY 1
ORDER BY 2 DESC;

3) Rewrite this query for website purchases made in 2022 or Samsung purchases made in 2021, expressing time to deliver in weeks instead of days.

SELECT
  geo_lookup.region,
  ROUND(AVG(DATE_DIFF(order_status.delivery_ts, order_status.purchase_ts, week)), 2) AS avg_weeks_to_deliver
FROM core.order_status
LEFT JOIN core.orders
  ON order_status.order_id = orders.id
LEFT JOIN core.customers
  ON orders.customer_id = customers.id
LEFT JOIN core.geo_lookup 
  ON customers.country_code = geo_lookup.country_code
WHERE (orders.purchase_platform = 'website'
  AND EXTRACT(year FROM orders.purchase_ts) = 2022)
  OR (LOWER(orders.product_name) LIKE '%samsung%'
  AND EXTRACT(year FROM orders.purchase_ts) = 2021)
GROUP BY 1
ORDER BY 1;

-- 3) a) What was the refund rate and refund count for each product overall? 

SELECT 
  CASE WHEN product_name = '27in"" 4k gaming monitor' THEN '27in 4K gaming monitor' ELSE product_name END AS cleaned_product_name,
  ROUND(AVG(CASE WHEN order_status.refund_ts IS NOT NULL THEN 1 ELSE 0  END), 3) AS refund_rate,
  SUM(CASE WHEN order_status.refund_ts IS NOT NULL THEN 1 ELSE 0 END) AS refund_count
FROM core.order_status
LEFT JOIN core.orders
  ON order_status.order_id = orders.id
GROUP BY 1
ORDER BY 3 DESC;

-- b) What was the refund rate and refund count for each product per year?

SELECT 
  EXTRACT(year FROM orders.purchase_ts) AS purchase_year,
  CASE WHEN product_name = '27in"" 4k gaming monitor' THEN '27in 4K gaming monitor' ELSE product_name END AS cleaned_product_name,
  ROUND(AVG(CASE WHEN order_status.refund_ts IS NOT NULL THEN 1 ELSE 0  END), 2) AS refund_rate,
  SUM(CASE WHEN order_status.refund_ts IS NOT NULL THEN 1 ELSE 0 END) AS refund_count
FROM core.order_status
LEFT JOIN core.orders
  ON order_status.order_id = orders.id
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- 4) Within each region, what is the most popular product? 

WITH order_count_cte AS (
  SELECT
    geo_lookup.region, 
    CASE WHEN orders.product_name = '27in"" 4k gaming monitor' THEN '27in 4K gaming monitor' ELSE orders.product_name END AS cleaned_product_name,
    COUNT(DISTINCT orders.id) AS order_count
  FROM core.orders
  LEFT JOIN core.customers
    ON orders.customer_id = customers.id
  LEFT JOIN core.geo_lookup 
    ON customers.country_code = geo_lookup.country_code
  GROUP BY 1, 2
  ORDER BY 3 DESC)

, ranking_cte AS (
    SELECT *,
      ROW_NUMBER() OVER (PARTITION BY region ORDER BY order_count DESC) AS ranking
    FROM order_count_cte)

  SELECT *
  FROM ranking_cte
  WHERE ranking = 1;

-- OR

WITH order_count_cte AS (
  SELECT
    geo_lookup.region, 
    CASE WHEN orders.product_name = '27in"" 4k gaming monitor' THEN '27in 4K gaming monitor' ELSE orders.product_name END AS cleaned_product_name,
    COUNT(DISTINCT orders.id) AS order_count
  FROM core.orders
  LEFT JOIN core.customers
    ON orders.customer_id = customers.id
  LEFT JOIN core.geo_lookup 
    ON customers.country_code = geo_lookup.country_code
  GROUP BY 1, 2
  ORDER BY 3 DESC)

  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY region ORDER BY order_count DESC) AS ranking
  FROM order_count_cte
  QUALIFY ROW_NUMBER() OVER (PARTITION BY region ORDER BY order_count DESC) = 1;

-- 5) a) How does the time to make a purchase differ between loyalty customers vs. non-loyalty customers? 

SELECT 
  customers.loyalty_program,
  ROUND(AVG(DATE_DIFF(orders.purchase_ts, customers.created_on, day)), 2) AS avg_days_to_purchase,
  ROUND(AVG(DATE_DIFF(orders.purchase_ts, customers.created_on, month)), 2) AS avg_months_to_purchase
FROM core.customers
LEFT JOIN core.orders
  ON orders.customer_id = customers.id
GROUP BY 1;

-- b) Update this query to split the time to purchase per loyalty program, per purchase platform. Return the number of records to benchmark the severity of nulls.

SELECT 
  orders.purchase_platform,
  customers.loyalty_program,
  ROUND(AVG(DATE_DIFF(orders.purchase_ts, customers.created_on, day)), 0) AS avg_days_to_purchase,
  ROUND(AVG(DATE_DIFF(orders.purchase_ts, customers.created_on, month)), 0) AS avg_months_to_purchase,
  COUNT(*) AS row_count
FROM core.customers
LEFT JOIN core.orders
  ON orders.customer_id = customers.id
GROUP BY 1, 2;
