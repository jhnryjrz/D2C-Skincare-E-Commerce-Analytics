# D2C-Skincare-E-Commerce-Analytics

##Overview
An SQL-based analytics portfolio that explores customer behaviour, revenue, product profitability, and return rate for a D2C Skincare E-commerce dataset from kaggle. Built entirely in SQLite using DB Browser for SQLite.

##Schema
'Customers' - This is the table for customer's demographics (customer name, region, gender, age-group, etc)
'Order_items' - This is the table for the breakdown of a single order (products, unit price, quantity, etc)
'Orders' - This is the table for individual ordes and their informations (order date, gross amount, order status, etc)
'Products' - This is the table for products (product name, cost price, category, key ingredient, etc)
'Returns' - This is the table for returned items (products, return reason, etc)
'Reviews' - This is the table for reviewed items (products, ratings, etc)


##Modules
| File | Covers |
|---|---|
| `revenue_analysis.sql` | Monthly/yearly revenue, MoM growth, AOV, top products/categories |
| `products_profitability_analysis.sql` | Margin analysis, profit concentration, underperformers |
| `return_rate_analysis.sql` | Return rate & revenue loss by product/category/month |
| `customer_segmentation.sql` | RFM scoring, CLV, churn risk, cohort retention |

## Key Findings
- Cohort retention drops to single digits by month 3, indicating weak repeat-purchase behavior.
- Repeat customers contribute more gross revenue than one-time customers and loyal customers.
- The top 54% of customers drive 80% of total gross revenue (Pareto concentration).
- Serum is the top revenue-driving product, contributing 45% of total realized revenue.
- Lip Care accounts for 10% of revenue loss on just 10% of order volume — proportional, not a red flag.

## Technical Notes
- **Grain discipline**: joining `Order_Items` to `Orders` and summing an
  order-level column caused revenue double-counting — fixed by aggregating
  at the correct grain before joining.
- **Return rate denominator**: only `Delivered` + `Returned` orders count
  as "eligible," excluding `In Transit`, since those haven't had a chance
  to be returned yet.
- **Retention metrics**: built two versions — "exact-month" (activity in
  a specific month) vs. "retained-to-date" (monotonic, based on last order
  date) — to show the tradeoff between measuring engagement vs. churn.

## How to Run
1. Open the `.db` file in DB Browser for SQLite
2. Run each `.sql` file's `CREATE VIEW` statements first
3. Execute individual queries under the `Execute SQL` tab
