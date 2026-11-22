-- -- 3 CLEANING -- --


/*From the exploration phase and after assessing our data inconsistencies, there are
a few things worth doing in the Stocks table:

	1. Exclude rows where all 6 value columns (adj_close, high, open, low, close and
	volume) are null. This represents approx. 5.3% of the Stocks table rows. It was 
	verified that all of those full NULL rows sit outside of each symbol's observed
	valid price window (date). Possibly pre-listing periods.

	2. Retain all data with volume = 0 and flat values (adj_close=high=open=low=close)
	These will be flagged via a new "suspect" column for easier dinstinction. It will
	make deletion easier if required for any later analysis.

Companies and Index tables do not need any changes, as no duplicates or integrity
issues were found. Only a few missing values were found but in minor or unremarkable
columns.
*/

-- COMPANIES CLEAN TABLE:
DROP TABLE IF EXISTS clean_sp500_companies;

CREATE TABLE clean_sp500_companies AS
SELECT * FROM raw_sp500_companies;

ALTER TABLE CLEAN_SP500_COMPANIES ADD PRIMARY KEY (symbol)


-- INDEX CLEAN TABLE:
DROP TABLE IF EXISTS clean_sp500_index;

CREATE TABLE clean_sp500_index AS
SELECT * FROM raw_sp500_index;

ALTER TABLE CLEAN_SP500_INDEX ADD PRIMARY KEY (date);


-- STOCKS CLEAN TABLE:
DROP TABLE IF EXISTS clean_sp500_stocks;

CREATE TABLE clean_sp500_stocks AS
SELECT
	*,
	(volume=0 AND open=high AND high=low AND low=close) as no_trading
FROM raw_sp500_stocks
WHERE NOT (adj_close IS NULL AND close IS NULL AND high IS NULL AND low IS NULL AND open IS NULL and volume IS NULL);
	--saw that there are no partial nulls so a simple adj_close is null would be 
	--enough

ALTER TABLE CLEAN_SP500_STOCKS ADD PRIMARY KEY (date, symbol);

CREATE INDEX idx_clean_stocks_symbol ON clean_sp500_stocks(symbol);



-- Verification:

SELECT 
	(SELECT count(*) from raw_SP500_STOCKS CSS) as raw_row_count,
	(SELECT count(*) from CLEAN_SP500_STOCKS CSS) as clean_row_count,
	(SELECT count(*) from raw_SP500_STOCKS CSS) 
		- 
	(SELECT count(*) from raw_sp500_stocks where adj_close IS NULL) as raw_minus_nulls

raw_row_count|clean_row_count|raw_minus_nulls|
-------------+---------------+---------------+
      1891536|        1791061|        1791061|
      
      

SELECT 
	(SELECT COUNT(*) as no_trading FROM CLEAN_SP500_STOCKS CSS WHERE CSS.NO_TRADING) as clean_no_trading_number,
	(SELECT COUNT(*) FROM raw_SP500_STOCKS WHERE volume = 0 AND open = high AND high = low AND low = close) as raw_no_trading_number

clean_no_trading_number|raw_no_trading_number|
-----------------------+---------------------+
                   1406|                 1406|
	
	

