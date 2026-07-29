CREATE VIEW year_month_revenue_summary AS 
SELECT strftime('%Y-%m', order_date) AS month, count(order_id) AS total_orders, sum(gross_amount) AS realized_revenue FROM Orders WHERE order_status = 'Delivered' GROUP BY month;

CREATE VIEW product_category_revenue_summary AS 
SELECT strftime('%Y-%m', o.order_date) AS month, oi.product_id, p.product_name, p.category, count(oi.product_id) AS item_counts, sum(oi.item_total) AS realized_revenue FROM Order_Items AS oi INNER JOIN Products AS p ON oi.product_id = p.product_id INNER JOIN Orders AS o ON oi.order_id = o.order_id WHERE o.order_status = 'Delivered' GROUP BY month, oi.product_id, p.product_name, p.category;

CREATE VIEW customer_revenue_summary AS 
SELECT strftime('%Y-%m', o.order_date) AS month, o.customer_id, c.customer_name, c.city, c.state, c.gender, c.age_group, count(o.order_id) AS total_orders, sum(o.gross_amount) AS realized_revenue FROM Orders AS o INNER JOIN Customers AS c ON o.customer_id = c.customer_id WHERE o.order_status = 'Delivered' GROUP BY month, o.customer_id, c.customer_name, c.city, c.state, c.gender, c.age_group;

CREATE VIEW overall_revenue_view AS 
SELECT sum(gross_amount) AS overall_revenue, count(order_id) AS overall_orders FROM Orders WHERE order_status = 'Delivered';

--Total realized revenue
SELECT overall_revenue, overall_orders FROM overall_revenue_view;

--Yearly realized revenue
SELECT substr(month, 1, 4) AS year, sum(total_orders) AS total_orders, sum(realized_revenue) AS realized_revenue FROM year_month_revenue_summary GROUP BY year;

--Monthly realized revenue
SELECT month, total_orders, realized_revenue FROM year_month_revenue_summary;

--Running cumulative revenue
SELECT month, realized_revenue,
	sum(realized_revenue) OVER (ORDER BY month) AS cumulative_revenue
FROM year_month_revenue_summary;

--Products realized revenue
WITH product_revenue AS (
SELECT product_id, product_name, sum(item_counts) AS total_items_ordered, sum(realized_revenue) AS realized_revenue FROM product_category_revenue_summary GROUP BY product_id, product_name)
SELECT product_name, total_items_ordered, realized_revenue, 
CASE 
	WHEN realized_revenue >= (0.10 * v.overall_revenue) THEN 'Hero Product'
	WHEN realized_revenue >= (0.02 * v.overall_revenue) AND realized_revenue < (0.10 * v.overall_revenue) THEN 'Core Performer'
	WHEN realized_revenue >= (0.005 * v.overall_revenue) AND realized_revenue < (0.02 * v.overall_revenue) THEN'Niche'
	ELSE 'Slow Mover'
END AS perfomance_tier
 FROM product_revenue CROSS JOIN overall_revenue_view AS v ORDER BY realized_revenue DESC;

--Top 10 products via realized revenue
WITH product_revenue AS (
SELECT product_id, product_name, sum(realized_revenue) AS realized_revenue FROM product_category_revenue_summary GROUP BY product_id, product_name)
SELECT product_name, realized_revenue FROM product_revenue ORDER BY realized_revenue DESC LIMIT 10;

--Best-selling product by year
WITH products_rev AS (
SELECT substr(month, 1, 4) AS year, product_id, product_name, sum(realized_revenue) AS realized_revenue FROM product_category_revenue_summary GROUP BY year, product_id, product_name),
products_ranking AS (
SELECT year, product_name, realized_revenue, row_number() OVER (PARTITION BY year ORDER BY realized_revenue DESC) AS row_num FROM products_rev)
SELECT year, product_name, realized_revenue FROM products_ranking WHERE row_num = 1;

--Best-selling product by month
WITH products_rev AS (
SELECT month, product_id, product_name, sum(realized_revenue) AS realized_revenue FROM product_category_revenue_summary GROUP BY month, product_id, product_name),
products_ranking AS (
SELECT month, product_name, row_number() OVER (PARTITION BY month ORDER BY realized_revenue DESC) AS row_num FROM products_rev)
SELECT month, product_name FROM products_ranking WHERE  row_num = 1 ORDER BY month;

--Month-over-month Growth Rate
SELECT month, realized_revenue,
	LAG(realized_revenue) OVER (ORDER BY month) AS prev_month_revenue,
	ROUND((realized_revenue - LAG(realized_revenue) OVER (ORDER BY month)) * 100.0 / nullif(LAG(realized_revenue) OVER (ORDER BY month), 0), 2) AS mom_growth_pct
FROM year_month_revenue_summary;

--Category-based realized revenue
SELECT category, sum(item_counts) AS total_items, sum(realized_revenue) AS realized_revenue
FROM product_category_revenue_summary GROUP BY category ORDER BY realized_revenue DESC;

--Top 5 category
SELECT category, sum(item_counts) AS total_items, sum(realized_revenue) AS realized_revenue
FROM product_category_revenue_summary GROUP BY category ORDER BY realized_revenue DESC LIMIT 5;

--Best-selling category by year
WITH category_rev AS (
SELECT substr(month, 1,4) AS year, category, sum(item_counts) AS total_items, sum(realized_revenue) AS realized_revenue 
FROM product_category_revenue_summary GROUP BY year, category),
category_ranking AS (
SELECT year, category, total_items, realized_revenue, row_number() OVER (PARTITION BY year ORDER BY realized_revenue DESC) AS row_num FROM category_rev)
SELECT year, category, total_items, realized_revenue FROM category_ranking WHERE row_num = 1;

--Best-selling category by month
WITH category_rev AS (
SELECT month, category, sum(item_counts) AS total_items, sum(realized_revenue) AS realized_revenue 
FROM product_category_revenue_summary GROUP BY month, category),
category_ranking AS (
SELECT month, category, total_items, realized_revenue, row_number() OVER (PARTITION BY month ORDER BY realized_revenue DESC) AS row_num FROM category_rev)
SELECT month, category, total_items, realized_revenue FROM category_ranking WHERE row_num = 1;

--Revenue share by category
WITH category_revenue AS (
SELECT category, sum(realized_revenue) AS realized_revenue FROM product_category_revenue_summary GROUP BY category)
SELECT category, realized_revenue, round(realized_revenue * 100.0 / sum(realized_revenue) OVER (), 2) AS revenue_share_pct FROM category_revenue ORDER BY revenue_share_pct DESC;

--Customer revenue contribution
WITH customers_revenue AS (
SELECT customer_id, customer_name, sum(total_orders) AS total_orders, sum(realized_revenue) AS realized_revenue FROM customer_revenue_summary GROUP BY customer_id, customer_name)
SELECT customer_name AS full_name, total_orders, realized_revenue, 
CASE 
	WHEN realized_revenue >= (0.01 * v.overall_revenue) THEN 'VIP'
	WHEN realized_revenue >= (0.003 * v.overall_revenue) AND realized_revenue < (0.01 * v.overall_revenue) THEN 'High Value'
	WHEN realized_revenue >= (0.001 * v.overall_revenue) AND realized_revenue < (0.003 * v.overall_revenue) THEN 'Regular'
	ELSE 'Low Value'
END AS performance_tier
FROM customers_revenue CROSS JOIN overall_revenue_view AS v
ORDER BY realized_revenue DESC;

--Top 10 customers via realized revenue
SELECT customer_id, customer_name, sum(total_orders) AS total_orders, sum(realized_revenue) AS realized_revenue FROM customer_revenue_summary GROUP BY customer_id, customer_name ORDER BY realized_revenue DESC LIMIT 10;

--Top customer by year
WITH customer_rev_contri AS (
SELECT substr(month, 1, 4) AS year, customer_id, customer_name, sum(total_orders) AS total_orders, sum(realized_revenue) AS realized_revenue FROM customer_revenue_summary GROUP BY year, customer_id, customer_name),
customer_ranking AS (
SELECT year, customer_name, total_orders, realized_revenue, row_number() OVER (PARTITION BY year ORDER BY realized_revenue DESC) AS row_num FROM customer_rev_contri)
SELECT year, customer_name, total_orders, realized_revenue FROM customer_ranking WHERE row_num = 1;

--Top customer by month
WITH customer_rev_contribution AS (
SELECT month, customer_id, customer_name, sum(realized_revenue) AS realized_revenue FROM customer_revenue_summary GROUP BY month, customer_id, customer_name),
customer_ranking AS (
SELECT month, customer_name, row_number() OVER (PARTITION BY month ORDER BY realized_revenue DESC) AS row_num FROM customer_rev_contribution)
SELECT month, customer_name FROM customer_ranking WHERE row_num = 1;

--Gender-based realized revenue 
SELECT gender, sum(total_orders) AS total_orders , sum(realized_revenue) AS realized_revenue FROM customer_revenue_summary GROUP BY gender ORDER BY realized_revenue DESC;

--Age-group-based realized revenue 
SELECT age_group, sum(total_orders) AS order_count, sum(realized_revenue) AS realized_revenue FROM customer_revenue_summary GROUP BY age_group ORDER BY realized_revenue DESC;

--Average Order Value(AOV)
--Yearly AOV
SELECT substr(month, 1, 4) AS year, round(sum(realized_revenue) * 1.0/ sum(total_orders), 2) AS avg_order_val, sum(total_orders) AS total_orders FROM year_month_revenue_summary GROUP BY year;
--Monthly AOV
SELECT month, round(sum(realized_revenue) * 1.0 / sum(total_orders), 2) AS avg_order_val, sum(total_orders) AS total_orders FROM year_month_revenue_summary GROUP BY month;
--Product avg item value
SELECT product_id, product_name, round(sum(realized_revenue) * 1.0 / sum(item_counts), 2) AS avg_item_value, sum(item_counts) AS total_items
FROM product_category_revenue_summary GROUP BY product_id, product_name;
--Category avg item value
SELECT category, round(sum(realized_revenue) * 1.0 / sum(item_counts), 2) AS avg_item_value, sum(item_counts) AS total_items
FROM product_category_revenue_summary GROUP BY category;
--Customer AOV
SELECT customer_id, customer_name, round(sum(realized_revenue) * 1.0 / sum(total_orders), 2) AS avg_order_val, sum(total_orders) AS total_orders FROM customer_revenue_summary GROUP BY customer_id, customer_name;
--Gender-based AOV
SELECT gender, round(sum(realized_revenue) * 1.0 / sum(total_orders), 2) AS avg_order_val, sum(total_orders) AS total_orders FROM customer_revenue_summary GROUP BY gender;
--Age-group-based AOV 
SELECT age_group, round(sum(realized_revenue) * 1.0 / sum(total_orders), 2) AS avg_order_val, sum(total_orders) As total_orders FROM customer_revenue_summary GROUP BY age_group;