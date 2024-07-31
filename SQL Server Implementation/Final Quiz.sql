USE trading;

--Exploring Data type of each column
SELECT 
	'daily_btc' AS [table_name],
	COLUMN_NAME, 
	DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'daily_btc';


SELECT 
	'daily_eth' AS [table_name],
	COLUMN_NAME, 
	DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'daily_eth';



--1. What is the earliest and latest market_date values?
SELECT 
	MIN(market_date) AS earliest_date,
	MAX(market_date) AS latest_date
FROM daily_btc;

--2. What was the historic all-time high and low values for the close_price and their dates?
WITH max_cte AS 
(
SELECT 
	market_date,
	MAX(close_price) AS all_time_high
FROM daily_btc
WHERE close_price IS NOT NULL
GROUP BY market_date
),
min_cte AS
(
SELECT
	market_date,
	MIN(close_price) AS all_time_low
FROM daily_btc
WHERE close_price IS NOT NULL
GROUP BY market_date
)
SELECT TOP 1
	T1.market_date, T1.all_time_high,
	T2.market_date, T2.all_time_low
FROM  
	max_cte AS T1,
	min_cte AS T2
ORDER BY 2 DESC, 4 ASC;


--3. Which date had the most volume traded and what was the close_price for that day?
SELECT TOP 1
	market_date,
	MAX(volume) AS max_volume_observed,
	close_price
FROM daily_btc
WHERE volume IS NOT NULL
	AND close_price IS NOT NULL
GROUP BY 
	market_date, 
	close_price
ORDER BY 2 DESC;


--4. How many days had a low_price price which was 10% less than the open_price?
WITH price_difference_metric AS (
SELECT 
	market_date,
	CASE 
		WHEN low_price < 0.9 * open_price THEN 1
		ELSE 0
	END AS price_difference
FROM daily_btc
WHERE open_price IS NOT NULL
	AND low_price IS NOT NULL
)
SELECT 
	COUNT(*) AS low_price_bound_days,
	CONCAT(
			(CAST(CAST((COUNT(*)) AS DECIMAL(5, 3))*100/(SELECT COUNT(DISTINCT market_date) FROM daily_btc) AS INT)
		), 
	'% ') AS proportion_to_total_days
FROM price_difference_metric
WHERE price_difference = 1;


--5. What percentage of days have a higher close_price than open_price?
WITH high_close_price AS (
SELECT 
	SUM(
		CASE 
			WHEN close_price > open_price THEN 1
			ELSE 0
			END
	) AS [high_close_price_bound],
	COUNT(*) AS [total_days]
FROM daily_btc
WHERE 
	volume IS NOT NULL
)
SELECT 
	high_close_price_bound AS high_days,
	CEILING(CAST(high_close_price_bound AS FLOAT)*100/CAST(total_days AS FLOAT)) AS [proportion_of_total_days]
FROM high_close_price;


--6. What was the largest difference between high_price and low_price and which date did it occur?
WITH price_difference_metric AS (
SELECT 
	market_date,
	high_price,
	low_price,
	(high_price - low_price) AS price_difference
FROM daily_btc
WHERE high_price IS NOT NULL
	AND low_price IS NOT NULL
)
SELECT TOP 1
	market_date,
	MAX(price_difference) AS largest_difference
FROM price_difference_metric
GROUP BY market_date
ORDER BY 2 DESC;


--7. If you invested $10,000 on the 1st January 2016 - how much is your investment worth in 1st of February 2021? 
--Use the close_price for this calculation.
WITH start_dt AS (
SELECT 
	market_date AS start_date,
	close_price AS starting_price,
	10000/close_price AS btc_volume
FROM daily_btc
WHERE 
	market_date = '2016-01-01'
),
end_dt AS (
SELECT 
	market_date AS end_date,
	close_price AS ending_price
FROM daily_btc
WHERE 
	market_date = '2021-01-01'
)
SELECT 
	CAST((T2.ending_price * T1.btc_volume) AS DECIMAL(15, 6)) AS final_returns,
	CAST(((T2.ending_price - T1.starting_price)/T1.starting_price)*100 AS DECIMAL(15, 6)) AS rate_of_return
FROM 
	start_dt  [T1],
	end_dt [T2];