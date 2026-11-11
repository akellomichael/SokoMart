-- ===================================================================================================================================================
-- 										Section A — CTEs and subqueries (20 marks)

-- *****************************************************************************************************************************************************
SET SEARCH_PATH TO sokomart;
/* Question 1 — Big spenders of 2025 *(4 marks · Medium)*
	**Scenario.** Marketing wants to invite 2025's above-average customers to a loyalty launch.
	**Task.** In a CTE, compute each customer's **2025 revenue** (completed orders placed in 2025).
	List the customers whose 2025 revenue is **above the average 2025 revenue of customers who
	bought in 2025**. Get the average with a subquery (or a second CTE) over the first CTE — not
	a hard-coded number. Order by `total_spent_2025` descending. Then, in a second query, give
	the number of customers who bought in 2025, the average, and the number of rows your main
	query returns.
	**Required concept.** CTE + scalar subquery over the CTE.
	**Expected output.** `customer_id, full_name, county, total_spent_2025, avg_spent_2025, amount_above_avg`
*/

WITH customer_revenue AS (                                 -- EACH customers' completed orders in 2025
	SELECT 
		c.customer_id, 
		c.first_name ||' ' || c.last_name AS full_name, 
		c.county,
		SUM(oi.line_total)                AS total_spent_2025
	FROM customers c
	JOIN orders o        USING(customer_id)
	JOIN order_items oi  USING(order_id)
	WHERE o.order_date >= '2025-01-01' 
		AND o.order_date < '2026-01-01'
		AND o.order_status = 'completed'
	GROUP BY c.customer_id, c.first_name ,c.last_name ,c.county
), 
avg_revenue AS (		                                   -- general average of revenue on orders completed in 2025
	SELECT AVG(total_spent_2025) AS avg_spent_2025
	FROM customer_revenue
)
SELECT 
	customer_id, 
	full_name, 
	county, 
	cr.total_spent_2025						            AS total_spent_2025, 
	ROUND(ar.avg_spent_2025,2)				            AS avg_spent_2025, 
	ROUND((cr.total_spent_2025 - ar.avg_spent_2025),2)  AS amount_above_avg
FROM customer_revenue cr
CROSS JOIN avg_revenue ar
WHERE cr.total_spent_2025 > ar.avg_spent_2025              -- check - revenue > average revenue
ORDER BY cr.total_spent_2025 DESC;


-- ***********************REVISIT
--- --  Then, in a second query, give
--the number of customers who bought in 2025, the average, and the number of rows your main query returns



/******************************************************************************************************************************************************
Question 2 — Premium-priced products *(4 marks · Medium)*

**Scenario.** The pricing team wants every **active** product that is priced above the average
price of **its own category**.
**Task.** Use a **correlated subquery** that computes the category average for each product's
category (average over all products in the category, any status). Show the gap. Order by
category, then `price_gap` descending. Add a second query counting the rows per category.
**Required concept.** Correlated subquery (in `WHERE` and in `SELECT`). No window functions.
**Expected output.** `product_id, product_name, category, unit_price, category_avg_price, price_gap`
*/
SELECT 
	p.product_id,
	p.product_name, 
	p.category, 
	p.unit_price, 
	ROUND((SELECT AVG(a.unit_price)
	 	   FROM products a 
	       WHERE a.category = p.category),2) AS category_avg_price,
	ROUND((p.unit_price - (SELECT AVG(a.unit_price)
	 				 	   FROM products a 
	 					   WHERE a.category = p.category)),2) AS price_gap
FROM products p
WHERE p.product_status = 'active'
	AND p.unit_price > 	(SELECT AVG(a.unit_price)
	 					 FROM products a 
						 WHERE a.category = p.category)
ORDER BY p.category, price_gap DESC;


-- Query 2 - counting the rows per category.
SELECT 	
	p.category,
	COUNT(*) AS rows_per_category
FROM products p
WHERE p.product_status = 'active'
	AND p.unit_price > 	(SELECT AVG(a.unit_price)
	 					 FROM products a 
						 WHERE a.category = p.category)
GROUP BY p.category;

	

/******************************************************************************************************************************************************
 Question 3 — 2026 monthly profit and loss *(4 marks · Medium)*

**Scenario.** Finance needs a monthly P&L for **January–October 2026**.
**Task.** Build it with **at least three chained CTEs**: (1) the completed order lines with
their month and line cost; (2) monthly revenue and cost; (3) gross profit. Final `SELECT` adds
the margin. One row per month, in month order.
**Required concept.** Multiple chained CTEs.
**Expected output.** `month, revenue, cost, gross_profit, margin_pct` (10 rows)
*/



/******************************************************************************************************************************************************
Question 4 — Cross-category shoppers in Nakuru *(4 marks · Medium)*

**Scenario.** The Nakuru regional manager wants customers who already shop across several
departments, for a bundle campaign.
**Task.** In a **derived table** (a subquery in `FROM`), compute for every customer the number of
distinct product categories in their completed orders and their total revenue. Join it to
`customers` and keep customers **living in Nakuru** with **3 or more** categories. Order by
`category_count` descending, then `total_spent` descending. Second query: how many Nakuru
customers qualify, and how many of them bought from **all five** categories.
**Required concept.** Derived table, `COUNT(DISTINCT …)`.
**Expected output.** `customer_id, full_name, county, category_count, total_spent`
*/


SELECT 
	customer_id, full_name, county, category_count, total_spent
FROM (
	SELECT 	
		c.customer_id,
		c.first_name ||' '||c.last_name AS full_name,
		COUNT(distinct p.category) category_count,
		SUM(oi.line_total) AS total_spent,
		c.county 
	FROM customers c
	JOIN orders o       USING(customer_id)
	JOIN order_items oi USING(order_id)
	JOIN products p     USING(product_id) 
	WHERE o.order_status = 'completed'
	GROUP BY c.customer_id 
) AS customer_details
WHERE category_count >= 3
	AND county = 'Nakuru'
ORDER BY category_count, total_spent DESC;

--Query 2. count(qualified from querry 1) | count(customers who bought from all 5 caegories)
-- Worked around q1 with a cte. couldnt solve it using a FROM subquery.
WITH customer_count AS (
    SELECT
        c.customer_id,
        COUNT(DISTINCT p.category) AS category_count
    FROM customers c
    JOIN orders o       USING(customer_id)
    JOIN order_items oi USING(order_id)
    JOIN products p     USING(product_id)
    WHERE o.order_status = 'completed'
      AND c.county = 'Nakuru'
    GROUP BY c.customer_id
)
SELECT
    COUNT(*) FILTER (WHERE category_count >= 3) AS qualified_customers,
    COUNT(*) FILTER (WHERE category_count = 5)  AS customers_all_5_categories
FROM customer_count;


/******************************************************************************************************************************************************
-- Question 5 — Products nobody has ordered *(4 marks · Easy)*

**Scenario.** The warehouse is reviewing shelf space: which products have **never appeared on
any order** (any status)?
**Task.** Use `NOT EXISTS` (or `LEFT JOIN … IS NULL`). **`NOT IN` is not allowed** — it returns
nothing at all if the subquery ever yields a NULL. Order by category, then product name.
**Required concept.** Anti-join with `NOT EXISTS`.
**Expected output.** `product_id, product_name, category, product_status, stock_quantity, created_at`
*/



SELECT
	p.product_id, p.product_name, p.category, p.product_status, p.stock_quantity, p.created_at, oi.order_id
FROM products p
LEFT JOIN order_items oi USING(product_id)
WHERE oi.order_id IS NULL;


















































