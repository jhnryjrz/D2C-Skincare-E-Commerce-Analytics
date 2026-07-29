--Customer Segmentation

CREATE VIEW customer_metrics AS
SELECT c.customer_name, cast(julianday((SELECT max(order_date) FROM Orders WHERE order_status IN ('Delivered', 'In Transit'))) - julianday(max(o.order_date)) AS INT) AS recency_date, count(o.order_id) AS total_orders, sum(o.gross_amount) AS total_revenue FROM Customers AS c INNER JOIN Orders AS o ON c.customer_id = o.customer_id WHERE o.order_status IN ('Delivered', 'In Transit') GROUP BY c.customer_id, c.customer_name ORDER BY total_revenue DESC;
--Customer Lifetime Value (CLV)

SELECT customer_name, total_orders, total_revenue, round(total_revenue / total_orders, 2) AS avg_order_value FROM customer_metrics;

--RFM Segment (Recency, Frequency, and Monetary
WITH rfm_scores AS (
SELECT rs.customer_name, ntile(5) OVER (ORDER BY rs.recency_date DESC) AS r_score, ntile(5) OVER (ORDER BY rs.total_orders) AS f_score, ntile(5) OVER (ORDER BY rs.total_revenue) AS m_score FROM customer_metrics AS rs)
SELECT customer_name, CASE
    WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
    WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
    WHEN r_score >= 4 AND f_score <= 2 THEN 'New/Promising'
    ELSE 'Needs Attention'
  END AS rfm_segment 
FROM rfm_scores;

--Churn Risk (Slipping away)
SELECT customer_name, recency_date, total_orders, total_revenue FROM customer_metrics WHERE recency_date > 90;

--Cohort Sizing
WITH first_orders AS (
	SELECT 
		customer_id,
		min(order_date) AS first_order_date
	FROM Orders
	WHERE order_status IN ('Delivered', 'In Transit')
	GROUP BY customer_id)
SELECT strftime('%Y-%m', first_order_date) AS cohort_month, count(DISTINCT customer_id) AS cohort_size FROM first_orders GROUP BY cohort_month ORDER BY cohort_month;

--Customer Retention
--Exact-month Retention
WITH first_orders AS (
    SELECT customer_id, min(order_date) AS first_order_date
    FROM Orders
    WHERE order_status IN ('Delivered', 'In Transit')
    GROUP BY customer_id
),
cohort_activity AS (
    SELECT
        fo.customer_id,
        strftime('%Y-%m', fo.first_order_date) AS cohort_month,
        -- how many months after their first order did this order happen?
        (CAST(strftime('%Y', o.order_date) AS INT) - CAST(strftime('%Y', fo.first_order_date) AS INT)) * 12
        + (CAST(strftime('%m', o.order_date) AS INT) - CAST(strftime('%m', fo.first_order_date) AS INT)) AS months_since_first
    FROM Orders AS o
    INNER JOIN first_orders AS fo ON o.customer_id = fo.customer_id
    WHERE o.order_status IN ('Delivered', 'In Transit')
),
cohort_sizes AS (
    SELECT cohort_month, count(DISTINCT customer_id) AS cohort_size
    FROM cohort_activity
    WHERE months_since_first = 0
    GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    cs.cohort_size,
    ca.months_since_first,
    count(DISTINCT ca.customer_id) AS active_customers,
    round(count(DISTINCT ca.customer_id) * 100.0 / cs.cohort_size, 2) AS retention_pct
FROM cohort_activity AS ca
INNER JOIN cohort_sizes AS cs ON ca.cohort_month = cs.cohort_month
GROUP BY ca.cohort_month, ca.months_since_first
ORDER BY ca.cohort_month, ca.months_since_first;

--Retained-to-date Retention
WITH first_orders AS (
    SELECT customer_id, min(order_date) AS first_order_date
    FROM Orders
    WHERE order_status IN ('Delivered', 'In Transit')
    GROUP BY customer_id
),
cohort_activity AS (
    SELECT
        fo.customer_id,
        strftime('%Y-%m', fo.first_order_date) AS cohort_month,
        (CAST(strftime('%Y', o.order_date) AS INT) - CAST(strftime('%Y', fo.first_order_date) AS INT)) * 12
        + (CAST(strftime('%m', o.order_date) AS INT) - CAST(strftime('%m', fo.first_order_date) AS INT)) AS months_since_first
    FROM Orders AS o
    INNER JOIN first_orders AS fo ON o.customer_id = fo.customer_id
    WHERE o.order_status IN ('Delivered', 'In Transit')
),
customer_max_gap AS (
    -- the LATEST month gap each customer was ever active in
    SELECT customer_id, cohort_month, max(months_since_first) AS max_gap
    FROM cohort_activity
    GROUP BY customer_id, cohort_month
),
cohort_sizes AS (
    SELECT cohort_month, count(DISTINCT customer_id) AS cohort_size
    FROM cohort_activity
    WHERE months_since_first = 0
    GROUP BY cohort_month
),
month_range AS (
    SELECT DISTINCT months_since_first AS n FROM cohort_activity
)
SELECT
    cs.cohort_month,
    cs.cohort_size,
    mr.n AS months_since_first,
    count(DISTINCT cmg.customer_id) AS retained_customers,
    round(count(DISTINCT cmg.customer_id) * 100.0 / cs.cohort_size, 2) AS retention_pct
FROM cohort_sizes AS cs
CROSS JOIN month_range AS mr
LEFT JOIN customer_max_gap AS cmg
    ON cmg.cohort_month = cs.cohort_month AND cmg.max_gap >= mr.n
GROUP BY cs.cohort_month, cs.cohort_size, mr.n
ORDER BY cs.cohort_month, mr.n;


--Top spenders
WITH avg_gross_amount_table AS (
SELECT avg(total_revenue) AS avg_gross_amount FROM customer_metrics)
SELECT customer_name, total_orders, total_revenue FROM customer_metrics WHERE total_revenue > (SELECT avg_gross_amount FROM avg_gross_amount_table) ORDER BY total_revenue DESC;

--One-time buyer VS. Repeat Customers
SELECT 
CASE 
	WHEN total_orders = 1 THEN 'One-Time Buyer'
	WHEN total_orders BETWEEN 2 AND 5 THEN 'Repeat Customer'
	ELSE 'Loyal Customer'
END AS customer_segment,
count(customer_name) AS customer_count,
sum(total_revenue) AS segment_revenue
FROM customer_metrics
GROUP BY customer_segment
ORDER BY customer_count DESC;

--New Vs. Returning 

SELECT 
	strftime('%Y-%m', o.order_date) AS order_month,
	CASE 
		WHEN o.order_date = fo.first_order_date THEN 'New'
		ELSE 'Returning'
	END customer_type,
	sum(o.gross_amount) AS total_revenue
FROM Orders AS o 
JOIN (SELECT customer_id, min(order_date) AS first_order_date FROM Orders GROUP BY customer_id) AS fo 
ON o.customer_id = fo.customer_id 
WHERE o.order_status IN ('Delivered', 'In Transit')
GROUP BY order_month, customer_type 
ORDER BY order_month;

--Customer Concentration (Pareto / 80-20)
WITH ranking AS (
SELECT customer_name, total_revenue,
	sum(total_revenue) OVER (ORDER BY total_revenue DESC) * 1.0 / sum(total_revenue) OVER() AS cumulative_pct
FROM customer_metrics), 
summary AS (
	SELECT count(*) AS customers_needed FROM ranking WHERE cumulative_pct <= 0.80)
SELECT customers_needed, (SELECT count(*) FROM customer_metrics) AS total_num_customers, round(customers_needed * 100.0 / (SELECT count(*) FROM customer_metrics), 2) AS pct_of_customers FROM summary;

--Customer category preference
WITH customer_category_preference AS (
SELECT c.customer_name, p.category, count(oi.order_id) AS total_orders, row_number() OVER (PARTITION BY c.customer_name ORDER BY count(oi.order_id) DESC, p.category ASC) AS row_num  FROM Customers AS c INNER JOIN Orders AS o ON c.customer_id = o.customer_id INNER JOIN Order_Items AS oi ON o.order_id = oi.order_id INNER JOIN Products AS p ON oi.product_id = p.product_id WHERE o.order_status IN ('Delivered', 'In Transit') GROUP BY c.customer_id, c.customer_name, p.category)
SELECT ccp.customer_name, ccp.category AS category_preference FROM customer_category_preference AS ccp WHERE ccp.row_num = 1;
