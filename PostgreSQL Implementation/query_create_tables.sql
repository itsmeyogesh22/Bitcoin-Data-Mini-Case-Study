DROP TABLE IF EXISTS daily_btc;
CREATE TABLE daily_btc 
	(
	market_date DATE, 
	open_price NUMERIC, 
	high_price NUMERIC, 
	low_price NUMERIC, 
	close_price NUMERIC, 
	adjusted_close_price NUMERIC, 
	volume NUMERIC
	);

DROP TABLE IF EXISTS daily_eth;
CREATE TABLE daily_eth 
	(
	market_date DATE, 
	open_price NUMERIC, 
	high_price NUMERIC, 
	low_price NUMERIC, 
	close_price NUMERIC, 
	adjusted_close_price NUMERIC, 
	volume NUMERIC
	);