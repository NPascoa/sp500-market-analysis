--SCHEMA CREATION:
CREATE SCHEMA IF NOT EXISTS sql_track;




--CREATING THE TABLES

DROP TABLE IF EXISTS sql_track.raw_sp500_companies;

CREATE TABLE sql_track.raw_sp500_companies(
	exchange TEXT,
	symbol TEXT PRIMARY KEY,
	short_name TEXT,
	long_name TEXT,
    sector TEXT,
    industry TEXT,
    current_price NUMERIC,
    market_cap NUMERIC,
    ebitda NUMERIC,
    revenue_growth NUMERIC,
    city TEXT,
    state TEXT,
    country TEXT,
    fulltime_employees NUMERIC,
    long_business_summary TEXT,
    weight NUMERIC
);




DROP TABLE IF EXISTS sql_track.raw_sp500_index;

/*CREATE TABLE sql_track.raw_sp500_index(
	date DATE PRIMARY KEY,
	sp500_close NUMERIC
);
*/ -- explained below in the copy process

CREATE TABLE sql_track.raw_sp500_index(
	date DATE,
	sp55_close NUMERIC
);



DROP TABLE IF EXISTS sql_track.raw_sp500_stocks;

CREATE TABLE sql_track.raw_sp500_stocks(
	date DATE,
	symbol TEXT,
	adj_close NUMERIC,
	close NUMERIC,
	high NUMERIC,
	low NUMERIC,
	open NUMERIC,
	volume NUMERIC,
	PRIMARY KEY (date,symbol)
);


/*This table has date and symbol as a combo PK, so an index of that combo starting with date.
 * But I expect to use the symbol column as join and filter conditions, so i'll create an index based on that alone.
 */

CREATE INDEX idx_stocks_symbol ON raw_sp500_stocks(symbol)





--COPYING THE VALUES FROM CSV FILES TO THESE TABLES


COPY sql_track.raw_sp500_companies (
	exchange, symbol, short_name, long_name, sector, industry, current_price, market_cap, ebitda, revenue_growth,
	city, state, country, fulltime_employees, long_business_summary, weight)
FROM '/csv_raw/sp500_companies.csv'
WITH (FORMAT csv, HEADER true);



COPY sql_track.raw_sp500_index (
	date, sp500_close)
FROM '/csv_raw/sp500_index.csv'
WITH (FORMAT csv, HEADER true);





COPY sql_track.raw_sp500_stocks (
	date, symbol, adj_close, close, high, low, open, volume)
FROM '/csv_raw/sp500_stocks.csv'
WITH (FORMAT csv, HEADER true);






--CHECK HOW MANY ROWS OF DATA:

SELECT 
	'raw_sp500_companies' as table_name,
	COUNT(*) as row_count
FROM RAW_SP500_COMPANIES

UNION ALL

SELECT 
	'raw_sp500_index',
	COUNT(*)
FROM RAW_SP500_INDEX

UNION ALL

SELECT 
	'raw_sp500_stocks',
	COUNT(*)
FROM RAW_SP500_STOCKS

table_name         |row_count|
-------------------+---------+
raw_sp500_companies|      502|
raw_sp500_index    |     2517|
raw_sp500_stocks   |  1891536|



