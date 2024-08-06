--1) What is the average daily volume of Bitcoin for the last 7 days?
--2) Create a 1/0 flag if a specific day is higher than the last 7 days volume average. 
WITH window_calculations AS (
SELECT 
	market_date,
	volume,
	 AVG(volume)
		OVER (
			ORDER BY market_date 
			RANGE BETWEEN '7 DAYS' PRECEDING AND '1 DAY' PRECEDING
		) AS past_weekly_avg_volume
FROM daily_btc
)
SELECT 
	market_date,
	volume,
	CASE 
		WHEN volume > past_weekly_avg_volume THEN 1 ELSE 0
		END AS volume_flag
FROM window_calculations
ORDER BY market_date DESC
LIMIT 10;



--3) What is the percentage of weeks (starting on a Monday) where there are 4 or more days with increased volume?
--4) How many high volume weeks are there broken down by year for the weeks with 5-7 days above the 7 day volume 
--average excluding 2021?
WITH window_calculations AS (
SELECT 
	market_date,
	volume,
	 AVG(volume)
		OVER (
			ORDER BY market_date 
			RANGE BETWEEN '7 DAYS' PRECEDING AND '1 DAY' PRECEDING
		) AS past_weekly_avg_volume
FROM daily_btc
),
date_calculations AS (
SELECT 
	market_date,
	DATE_TRUNC('week', market_date)::DATE AS start_of_week,
	volume,
	past_weekly_avg_volume,
	CASE 
		WHEN volume > past_weekly_avg_volume THEN 1 ELSE 0
		END AS volume_flag
FROM window_calculations
),
aggregated_weeks AS (
SELECT 
	start_of_week,
	SUM(volume_flag) AS weekly_high_volume_days
FROM date_calculations
GROUP BY start_of_week
)
SELECT 
	EXTRACT(YEAR FROM start_of_week) AS market_year,
	COUNT(*) AS high_volume_weeks,
	ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (), 2) AS percentage_of_total
FROM aggregated_weeks
WHERE weekly_high_volume_days >= 5
AND start_of_week < '2021-01-01'
GROUP BY 1
ORDER BY 1;



--Moving Metrics for close_price
/*
	For the following time windows: 14, 28, 60, 150 days - calculate the following metrics for the close_price column:

	1) Moving average
	2) Moving standard deviation
	3) The maximum and minimum values
*/
DROP TABLE IF EXISTS base_table;
CREATE TEMP TABLE base_table AS 
SELECT 
	market_date,
	close_price,
	ROUND(AVG(close_price) OVER w_14, 2) AS avg_14,
	ROUND(AVG(close_price) OVER w_28, 2) AS avg_28,
	ROUND(AVG(close_price) OVER w_60, 2) AS avg_60,
	ROUND(AVG(close_price) OVER w_150, 2) AS avg_150,
	ROUND(STDDEV(close_price) OVER w_14, 2) AS std_14,
	ROUND(STDDEV(close_price) OVER w_28, 2) AS std_28,
	ROUND(STDDEV(close_price) OVER w_60, 2) AS std_60,
	ROUND(STDDEV(close_price) OVER w_150, 2) AS std_150,
	ROUND(MAX(close_price) OVER w_14, 2) AS max_14,
	ROUND(MAX(close_price) OVER w_28, 2) AS max_28,
	ROUND(MAX(close_price) OVER w_60, 2) AS max_60,
	ROUND(MAX(close_price) OVER w_150, 2) AS max_150,
	ROUND(MIN(close_price) OVER w_14, 2) AS min_14,
	ROUND(MIN(close_price) OVER w_28, 2) AS min_28,
	ROUND(MIN(close_price) OVER w_60, 2) AS min_60,
	ROUND(MIN(close_price) OVER w_150, 2) AS min_150
FROM daily_btc
WINDOW 
	w_14 AS (ORDER BY market_date ASC RANGE BETWEEN '14 DAYS' PRECEDING AND '1 DAY' PRECEDING),
	w_28 AS (ORDER BY market_date ASC RANGE BETWEEN '28 DAYS' PRECEDING AND '1 DAY' PRECEDING),
	w_60 AS (ORDER BY market_date ASC RANGE BETWEEN '60 DAYS' PRECEDING AND '1 DAY' PRECEDING),
	w_150 AS (ORDER BY market_date ASC RANGE BETWEEN '150 DAYS' PRECEDING AND '1 DAY' PRECEDING)
ORDER BY market_date DESC;


--Weighted Moving Averages
SELECT 
	market_date,
	close_price,
	0.5 * avg_14 +
	0.3 * avg_28 +
	0.15 * avg_60 +
	0.05 * avg_150 AS custom_moving_avg
FROM base_table
ORDER BY market_date DESC;


--Weighted Moving Averages (1-14 Days)
SELECT 
	market_date,
	ROUND(close_price, 2) AS close_price,
	ROUND(avg_14) AS simple_moving_average_SMA,
	ROW_NUMBER()
		OVER (
			ORDER BY market_date
		)
FROM base_table
LIMIT 15;

--Exponential Weighted Average
DROP TABLE IF EXISTS EWMA;
CREATE TEMP TABLE EWMA AS 
SELECT 
	market_date,
	ROUND(close_price, 2) AS close_price,
	ROUND(avg_14) AS simple_moving_average_SMA,
	ROW_NUMBER()
		OVER (
			ORDER BY market_date
		) AS rn
FROM base_table;


DROP TABLE IF EXISTS EWMA_FINAL;
CREATE TEMP TABLE EWMA_FINAL AS
WITH RECURSIVE OUTPUT_EWMA
	(
	market_date, 
	close_price, 
	simple_moving_average_SMA, 
	exponential_weighted_moving_average_EWMA
	)
AS (
	SELECT 
		market_date,
		close_price,
		simple_moving_average_SMA,
		simple_moving_average_SMA AS exponential_weighted_moving_average_EWMA,
		rn
	FROM EWMA
	WHERE rn = 15

	UNION ALL

	SELECT 
		T1.market_date,
		T1.close_price,
		T1.simple_moving_average_SMA,
		ROUND(
			(0.13*T1.simple_moving_average_SMA + (1 - 0.13) * T2.exponential_weighted_moving_average_EWMA), 
		2) AS exponential_weighted_moving_average_EWMA,
		T1.rn
	FROM OUTPUT_EWMA AS T2
	INNER JOIN EWMA AS T1
	ON 
		T2.rn + 1 = T1.rn
		AND 
		T1.rn > 15
)
SELECT * FROM OUTPUT_EWMA;



SELECT * FROM EWMA_FINAL LIMIT 10;



--Pivoting the results
SELECT 
	market_date,
	'SMA' AS measure_name,
	simple_moving_average_SMA AS measure_value
FROM EWMA_FINAL
UNION
SELECT 
	market_date,
	'EWMA' AS measure_name,
	exponential_weighted_moving_average_EWMA AS measure_value
FROM EWMA_FINAL
ORDER BY 1, 2
LIMIT 10;