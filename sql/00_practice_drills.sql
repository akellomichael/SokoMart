
--===================================================================================================================================================
--									 SokoMart Kenya — Advanced SQL Practical Project
--													Practice Drills
--													===============
SET SEARCH_PATH TO sokomart;


/*******************************************************************************************************************
| D1 | List the products whose `unit_price` is above the average `unit_price` of **all** products.
 Show the 10 most expensive, then on a second query the count. | Scalar subquery in `WHERE` and `SELECT` |.
 `product_id, product_name, category, unit_price, overall_avg_price`; then one number 
*/
SELECT 
	product_id, product_name, category, unit_price, 
	ROUND((SELECT AVG(unit_price) FROM products),2) AS overall_avg_price
FROM products
WHERE unit_price > (SELECT AVG(unit_price) FROM products)
ORDER BY unit_price DESC 
LIMIT 10;

-- part 2
SELECT 	
	COUNT(product_id)
FROM products
WHERE unit_price > (SELECT AVG(unit_price) FROM products);



/********************************************************************************************************************
 | D2 | List customers living in **Mombasa** who placed at least one order (any status) in **December 2025**. 
      | `IN (subquery)` | `customer_id, first_name, last_name, email`; then the count |
*/
SELECT 
	customer_id, 
	first_name||' '||last_name AS customer_name,
	email
FROM customers 
WHERE customer_id IN (SELECT customer_id FROM orders WHERE order_date BETWEEN '2025-12-01' AND '2025-12-31')
	AND county = 'Mombasa';



/**********************************************************************************************************************
| D3 | How many customers living in **Kisumu** have at least one payment with `payment_status = 'failed'`? |
`    EXISTS` correlated subquery | `kisumu_customers_with_failed_payment` (one number) |
*/

SELECT 
	COUNT(DISTINCT o.customer_id)
FROM orders o
JOIN customers c USING(customer_id)
WHERE c.county = 'Kisumu'
	AND order_id IN (SELECT order_id FROM payments WHERE payment_status = 'failed');



--*********************************************************************************************************************
-- | D4 | For each `order_status`, show the number of orders, the average number of lines per order and the average 
-- number of units per order. Compute the per-order figures in a subquery in `FROM`. | Derived table |
-- `order_status, orders, avg_lines_per_order, avg_units_per_order` |

SELECT 
	order_status, orders, avg_lines_per_order, avg_units_per_order
	FROM (
		SELECT 
			o.order_status,
			COUNT(oi.order_id) AS orders,
			ROUND(AVG(oi.line_total), 2)  AS avg_lines_per_order,
			ROUND(AVG(oi.quantity),2) AS avg_units_per_order
		FROM order_items oi
		JOIN orders o USING(order_id)
		GROUP BY o.order_status
	);


-- *******************************************************************************************************************
-- | D5 | Top 5 **shipping counties** by number of completed orders in 2026. Put the filtered orders in a CTE. 
-- | Single CTE | `shipping_county, completed_orders` |

WITH shippings AS (
	SELECT 
		shipping_county,
		COUNT(*) AS count
	FROM orders
	WHERE order_date BETWEEN '2026-01-01' AND '2026-12-31'
		AND order_status = 'completed'
	GROUP BY shipping_county
	ORDER BY count DESC
	LIMIT 5
)
SELECT shipping_county
FROM shippings;


--*******************************************************************************************************************
-- | D6 | For 2025: completed orders per month, the 2025 monthly average, and whether each month is `above average` or
-- `at/below average`. Use two CTEs (monthly counts, then the stats).
-- | Chained CTEs | `month, completed_orders, avg_per_month, vs_average` (12 rows) |

WITH monthly_count AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        COUNT(order_id) AS completed_orders
    FROM orders
    WHERE order_date >= '2025-01-01'
      AND order_date <  '2026-01-01'
      AND order_status = 'completed'
    GROUP BY DATE_TRUNC('month', order_date) -- 2025: completed orders per month
),
stats AS (
    SELECT
        month,
        completed_orders,
        AVG(completed_orders) OVER () AS avg_per_month
    FROM monthly_count
)
SELECT
    TO_CHAR(month, 'YYYY-MM') AS month,
    completed_orders,
    ROUND(avg_per_month, 2) AS avg_per_month,
    CASE
        WHEN completed_orders > avg_per_month THEN 'above average'
        ELSE 'at/below average'
    END AS vs_average
FROM stats
ORDER BY month;


--*******************************************************************************************************************
-- | D7 | Write `sokomart.fn_order_count(p_customer_id INTEGER) RETURNS INTEGER` — the number of orders (any status) a customer has. 
--		Call it for customer **177** and for a customer that does not exist (`-1`). | SQL function | two numbers |
--REVISIT (functions)

CREATE OR REPLACE FUNCTION sokomart.fn_order_count(p_customer_id INTEGER)
RETURNS INTEGER
LANGUAGE sql
AS $$
	SELECT count(order_id)
		FROM orders
	GROUP BY customer_id;
$$;

SELECT sokomart.fn_order_count(117);
SELECT sokomart.fn_order_count(-1);


-- *******************************************************************************************************************
-- | D8 | Write `sokomart.sp_set_customer_status(p_customer_id INTEGER, p_status VARCHAR)`. It raises an exception for a status other than
--`active / inactive / suspended`, and for a customer that does not exist. Inside `BEGIN … ROLLBACK`, set customer **177** to `suspended`, 
-- show it, roll back, show it is `active` again. Then show the exception for status `'vip'`. | Stored procedure, `RAISE EXCEPTION`, `CALL` | 
-- the three status checks + the error message |


CREATE OR REPLACE PROCEDURE sokomart.sp_set_customer_status(p_customer_id INTEGER,p_status VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_status IS NULL OR p_status NOT IN ('active', 'inactive', 'suspended') THEN
        RAISE EXCEPTION 'Incorrect status: %', p_status;
    END IF;

    IF p_customer_id IS NULL OR p_customer_id NOT BETWEEN 1 AND 5000 THEN
        RAISE EXCEPTION 'Customer : % does not exist', p_customer_id;
    END IF;

    UPDATE customers
    SET customer_status = p_status
    WHERE customer_id = p_customer_id;

    IF NOT FOUND THEN
        ROLLBACK;
        RAISE EXCEPTION 'Customer does not exist: %', p_customer_id;
    END IF;

    COMMIT;
    RAISE NOTICE 'Status set to % for customer % successfully', p_status, p_customer_id;
END;
$$;


CALL sokomart.sp_set_customer_status(177, 'active');
CALL sokomart.sp_set_customer_status(177, 'vip');
/*
SQL Error [P0001]: ERROR: Incorrect status: vip
  Where: PL/pgSQL function sp_set_customer_status(integer,character varying) line 4 at RAISE
*/



-- *******************************************************************************************************************
-- | D9 | Beauty products whose `stock_quantity` is below the **average Beauty stock**. Put the Beauty products in a CTE and compare with a scalar 
-- subquery on that CTE. | CTE + scalar subquery | `product_id, product_name, stock_quantity, beauty_avg_stock` |

WITH beauty_products AS (
    SELECT product_id, product_name, stock_quantity
    FROM products
    WHERE category = 'Beauty'
)
SELECT
    product_id,
    product_name,
    stock_quantity,
    ROUND((SELECT AVG(stock_quantity) FROM beauty_products),2) AS beauty_avg_stock
FROM beauty_products
WHERE stock_quantity < (SELECT AVG(stock_quantity) FROM beauty_products)
ORDER BY stock_quantity;


-- *******************************************************************************************************************
-- | D10 | Write `sokomart.sp_county_summary(IN p_county VARCHAR, OUT p_customers INTEGER, OUT p_revenue NUMERIC)` returning the number of customers
-- living in the county and their completed revenue. `CALL sokomart.sp_county_summary('Nakuru', NULL, NULL);` | Procedure with `OUT` parameters | 
-- M`p_customers, p_revenue` (one row) |

