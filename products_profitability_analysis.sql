--Products Profitability Analysis

CREATE VIEW monetary_metrics AS
SELECT 
strftime('%Y-%m', o.order_date) AS month,
oi.product_id, 
p.product_name, p.category, 
sum(oi.item_total) AS total_revenue, 
sum(oi.quantity * p.cost_price) AS total_cost, 
sum(oi.item_total) - sum(oi.quantity * p.cost_price) AS gross_profit,
round(((sum(oi.item_total) - sum(oi.quantity * p.cost_price)) / sum(oi.item_total)) * 100, 2) AS margin_pct
FROM Order_Items AS oi 
INNER JOIN Products AS p ON oi.product_id = p.product_id 
INNER JOIN Orders AS o ON oi.order_id = o.order_id 
WHERE o.order_status IN ('Delivered', 'In Transit')
GROUP BY month, oi.product_id, p.product_name, p.category
ORDER BY gross_profit DESC;

--Base product margins

SELECT
product_id,
product_name,
category,
sum(total_revenue) AS total_revenue,
sum(gross_profit) AS gross_profit,
round((sum(gross_profit) / sum(total_revenue)) * 100, 2) AS margin_pct
FROM monetary_metrics
GROUP BY product_id, product_name, category;

--Profit Trend Over time
SELECT 
month, 
sum(total_revenue) AS total_revenue, 
sum(gross_profit) AS gross_profit, 
round((sum(gross_profit) / sum(total_revenue)) *100, 2) AS margin_pct 
FROM monetary_metrics 
GROUP BY month 
ORDER BY month;

--Profit Concentration
WITH re_aggregated AS (
SELECT product_id, product_name, sum(gross_profit) AS gross_profit FROM monetary_metrics GROUP BY product_id, product_name),
ranked AS (
SELECT ra.product_name, ra.gross_profit,
sum(ra.gross_profit) OVER () AS total_profit,
sum(ra.gross_profit) OVER (ORDER BY gross_profit DESC) AS running_profit
FROM re_aggregated AS ra)
SELECT r.product_name, r.gross_profit,
round((running_profit / total_profit) * 100, 2) AS cumulative_profit_pct
FROM ranked AS r ORDER BY r.gross_profit DESC;

--Category Margin Ranking
SELECT 
category, 
sum(total_revenue) AS total_revenue,
sum(gross_profit) AS gross_profit,
round((sum(gross_profit) / sum(total_revenue)) * 100, 2) AS margin_pct
FROM monetary_metrics GROUP BY category ORDER BY margin_pct DESC;

--Products with high revenue but has almost zero profit
SELECT 
product_id, 
product_name, 
sum(total_revenue) AS total_revenue, 
sum(gross_profit) AS gross_profit, 
round((sum(gross_profit) / sum(total_revenue)) * 100, 2) AS margin_pct 
FROM monetary_metrics 
GROUP BY product_id, product_name
HAVING sum(total_revenue) > 10000 AND round((sum(gross_profit) / sum(total_revenue)) * 100, 2) < 15.00;

--Category with high revenue but has almost zero profit
SELECT 
category, 
sum(total_revenue) AS total_revenue, 
sum(gross_profit) AS gross_profit, 
round((sum(gross_profit) / sum(total_revenue)) * 100, 2) AS margin_pct 
FROM monetary_metrics 
GROUP BY category 
HAVING sum(total_revenue) > 10000 AND round((sum(gross_profit) / sum(total_revenue)) * 100, 2) < 15.00	;

--Underperformers - High cost, low income
SELECT 
product_id, 
product_name, 
sum(total_revenue) AS total_revenue, 
sum(total_cost) AS total_cost, 
sum(gross_profit) AS gross_profit, 
round((sum(gross_profit) / sum(total_revenue)) * 100, 2) AS margin_pct 
FROM monetary_metrics 
GROUP BY product_id, product_name 
HAVING sum(gross_profit) < 0 OR round((sum(gross_profit) / sum(total_revenue)) * 100, 2) < 5.00;

--The profit killer
SELECT p.product_name,
sum(CASE WHEN o.order_status IN ('Delivered', 'In Transit', 'Returned') THEN oi.quantity ELSE 0 END) AS total_units_ordered,
sum(CASE WHEN o.order_status = 'Returned' THEN oi.quantity ELSE 0 END) AS total_units_returned,
round(
	cast(sum(CASE WHEN o.order_status = 'Returned' THEN oi.quantity ELSE 0 END) AS REAL) /
	sum(CASE WHEN o.order_status IN ('Delivered', 'In Transit', 'Returned') THEN oi.quantity ELSE 0 END) * 100, 2) AS return_rate_pct,
sum(CASE WHEN o.order_status IN ('Delivered', 'In Transit') THEN (oi.unit_price - p.cost_price) * oi.quantity ELSE 0 END) AS net_realized_profit
FROM Products AS p INNER JOIN Order_Items AS oi ON p.product_id = oi.product_id INNER JOIN Orders AS o ON oi.order_id = o.order_id GROUP BY p.product_id ORDER BY return_rate_pct DESC;
