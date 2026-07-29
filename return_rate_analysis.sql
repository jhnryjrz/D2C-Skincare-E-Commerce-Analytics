--Return Rate & Financial Impact

CREATE VIEW return_rate_summary AS 
SELECT
	strftime('%Y-%m', o.order_date) AS month,
	oi.product_id,
	p.product_name,
	p.category,
	count(CASE WHEN o.order_status IN ('Returned') THEN 1 END) AS returned_orders,
	count(CASE WHEN o.order_status IN ('Delivered', 'Returned') THEN 1 END) AS eligible_orders,
	sum(CASE WHEN o.order_status IN ('Returned') THEN oi.item_total END) AS returned_revenue,
	sum(CASE WHEN o.order_status IN ('Delivered', 'Returned') THEN oi.item_total END) AS eligible_revenue
FROM Orders AS o INNER JOIN Order_Items AS oi ON o.order_id = oi.order_id INNER JOIN Products AS p ON oi.product_id = p.product_id
GROUP BY month, oi.product_id, p.product_name, p.category;


--Overall summary

WITH order_summary AS (
	SELECT 
		COUNT(CASE WHEN o.order_status IN ('Returned') THEN 1 END) AS returned_orders,
		COUNT(CASE WHEN o.order_status IN ('Delivered', 'Returned') THEN 1 END) AS eligible_orders,
		SUM(CASE WHEN o.order_status IN ('Returned') THEN o.gross_amount END) AS returned_revenue,
		sum(CASE WHEN o.order_status IN ('Delivered', 'Returned') THEN o.gross_amount END) AS eligible_revenue
	FROM Orders AS o
)
SELECT returned_orders, eligible_orders, 
	ROUND(returned_orders * 100.0 / NULLIF(eligible_orders, 0), 2) AS returned_orders_pct, 
	returned_revenue, 
	eligible_revenue,
	ROUND(returned_revenue * 100.0 / NULLIF(eligible_revenue, 0), 2) AS revenue_loss_pct 
FROM order_summary;

--By product

SELECT
	product_id,
	product_name,
	category,
	sum(returned_orders) AS returned_orders,
	sum(eligible_orders) AS eligible_orders,
	round(sum(returned_orders) * 100.0 / nullif(sum(eligible_orders), 0), 2) AS returned_orders_pct,
	sum(returned_revenue) AS returned_revenue,
	sum(eligible_revenue) AS eligible_revenue,
	round(sum(returned_revenue) * 100.0 / nullif(sum(eligible_revenue), 0), 2) AS revenue_loss_pct
FROM return_rate_summary
GROUP BY product_id, product_name, category;

--Top 10 products by return-driven revenue loss
SELECT
	product_name,
	category,
	sum(returned_revenue) AS returned_revenue,
	sum(eligible_revenue) AS eligible_revenue,
	round(sum(returned_revenue) * 100.0 / nullif(sum(eligible_revenue),0),2) AS revenue_loss_pct,
	RANK() OVER (ORDER BY sum(returned_revenue) DESC) AS revenue_loss_rank
FROM return_rate_summary
GROUP BY product_name, category
ORDER BY revenue_loss_rank
LIMIT 10;

--By category

SELECT
	category,
	sum(returned_orders) AS returned_orders,
	sum(eligible_orders) AS eligible_orders,
	round(sum(returned_orders) * 100.0 / nullif(sum(eligible_orders), 0), 2) AS returned_orders_pct,
	sum(returned_revenue) AS returned_revenue,
	sum(eligible_revenue) AS eligible_revenue,
	round(sum(returned_revenue) * 100.0 / nullif(sum(eligible_revenue), 0), 2) AS revenue_loss_pct
FROM return_rate_summary
GROUP BY category
ORDER BY revenue_loss_pct DESC;

--Category contribution to total lost (how many percent a category contributed to the overall loss)

SELECT
	category,
	sum(returned_revenue) AS returned_revenue,
	round(sum(returned_revenue) * 100.0 / nullif(SUM(sum(returned_revenue)) OVER (), 0),2) AS pct_of_total_loss
FROM return_rate_summary
GROUP BY category
ORDER BY pct_of_total_loss DESC;

--Monthly
SELECT
	month,
	sum(returned_orders) AS returned_orders,
	sum(eligible_orders) AS eligible_orders,
	round(sum(returned_orders) * 100.0 / nullif(sum(eligible_orders),0), 2) AS returned_orders_pct,
	sum(returned_revenue) AS returned_revenue,
	sum(eligible_revenue) AS eligible_revenue,
	round(sum(returned_revenue) * 100.0 / nullif(sum(eligible_revenue), 0), 2) AS revenue_loss_pct
FROM return_rate_summary
GROUP BY month;

--Month-over-month trend
SELECT
	month,
	sum(returned_revenue) AS returned_revenue,
	sum(eligible_revenue) AS eligible_revenue,
	round(sum(returned_revenue) * 100.0 / nullif(sum(eligible_revenue), 0), 2) AS revenue_loss_pct,
	round(
		sum(returned_revenue) * 100.0 / nullif(sum(eligible_revenue), 0) 
		- lag(round(sum(returned_revenue) * 100.0 / nullif(sum(eligible_revenue), 0), 2)) OVER (ORDER BY month),2) AS pct_point_change 
FROM return_rate_summary
GROUP BY month
ORDER BY month;	

--Yearly
SELECT
	substr(month, 1, 4) AS year,
	sum(returned_orders) AS returned_orders,
	sum(eligible_orders) AS eligible_orders,
	round(sum(returned_orders) * 100.0 / nullif(sum(eligible_orders),0), 2) AS returned_orders_pct,
	sum(returned_revenue) AS returned_revenue,
	sum(eligible_revenue) AS eligible_revenue,
	round(sum(returned_revenue) * 100.0 / nullif(sum(eligible_revenue), 0), 2) AS revenue_loss_pct
FROM return_rate_summary
GROUP BY substr(month, 1, 4)
ORDER BY year;


