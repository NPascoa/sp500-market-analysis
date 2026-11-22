-- -- ## 4 Transformation -- --


/*Why use adj_close: it best reflects the value of the stock. 
 *Let's imagine a stock that on Day 1 has a Close 100$.
 *Then on Day 2 has a close of 50$. 
 *It is known that this was due to a stock split.
 *So by analyzing the close value alone, someone could be led to believe there was a 50% loss.
 *Adj_close already reflects that split. The values of all the previous days would already reflect that split to smooth out the transtion.
*/

/*Why use both simple and log returns:
 * Simple returns, also known as arithmetic returns, are the most straightforward way to calculate returns. ((Vt+1)/Vt)-1
 * They are computed as the percentage change in the asset’s price over a specified period, ignoring the compounding effect.
 * The compounding effect is just taking into account the initial stock's value. 
 * 
 * Log returns, also known as continuously compounded returns, take into account the compounding effect by calculating the 
 * natural logarithm of the ratio of the asset’s final price to its initial price. ln((Vt+1)/Vt)
 * 
 * Example:
 * 
 * Consider the following monthly stock prices for Company Z over three months:

	Month 1: $100
	Month 2: $50
	Month 3: $90

	Simple Returns: [-0.5, 0.8]
	
	-With simple returns, we calculate the percentage change between consecutive months:

	Simple Return for Month 2 = (50–100) / 100 = -0.5 or -50% 
	Simple Return for Month 3 = (90–50) / 50 = 0.8 or 80%

	The False Analysis: Using simple returns alone, we might conclude that the stock experienced a significant decline 
	in Month 2 (-50%) followed by a substantial increase in Month 3 (80%). However, this analysis overlooks the compounding 
	effect of returns over time and fails to capture the overall performance of the stock.
	If we take the mean of the returns we get 15%, but actually the price has decreased by 10% (from 100$ to 90$).
		
	-With log returns, we calculate the natural logarithm of the price ratios between consecutive months:

	Log Return for Month 2 = ln(50 / 100) ≈ -0.6931 or -69.31% 
	Log Return for Month 3 = ln(90 / 50) ≈ 0.5878 or 58.78%

	If we take the sum of log returns that is (69.31 + 58.78) = -10.53

	By using log returns, we now have a more accurate representation of the stock’s performance. We see that the stock experienced a 
	significant decline in Month 2 (-69.31%) and a partial recovery in Month 3 (58.78%), providing a clearer insight into the 
	overall volatility and trend of the stock.
		 
*/

-- STOCK level feature Table:

DROP TABLE IF EXISTS stock_features;

CREATE TABLE stock_features AS
WITH returns_calc as (
	SELECT	
		*,
		ROW_NUMBER() OVER (PARTITION BY symbol ORDER BY date ASC) as rn,
		
		--daily returns (simple and log) based on prior trading day's adj_close:
		(adj_close/LAG(adj_close) OVER (PARTITION BY symbol ORDER BY date ASC)) - 1 as simple_return,
		/*simple return (novo valor/valor anterior)-1. Só não convertemos em % */
				
		LN(adj_close/LAG(adj_close) OVER (PARTITION BY symbol ORDER BY date)) as log_return,
		
		--cumulative return since first data for that ticker:
		(adj_close/FIRST_VALUE(adj_close) OVER (PARTITION BY symbol ORDER BY date))-1 as cumulative_return,
		
		--moving averages:
		AVG(adj_close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as sma_20,
		AVG(adj_close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) as sma_50

	FROM CLEAN_SP500_STOCKS CSS
),

volatility as (
	SELECT
		*,
		STDDEV(log_return) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 20 PRECEDING AND CURRENT ROW) as rolling_vol_21
		--Note: in finance trading, the number of trading days in a month typically ranges from 19 to 23. On average, the U.S. market has about 21 trading days in a month, but this can vary based on public holidays and weekends
		
	FROM returns_calc
)

SELECT 
		date,
		symbol,
		adj_close,
		close,
		high,
		low,
		open,
		volume,
		no_trading,
		simple_return,
		log_return,
		cumulative_return,
		rolling_vol_21,
		--to force nulls in columns sma_20 and sma_50 whenever not in the actual range
		CASE WHEN rn >= 20 THEN sma_20 ELSE NULL END as sma_20,
		CASE WHEN rn >=50 THEN sma_50 ELSE NULL END as sma_50,
		
		CASE WHEN rn >=22 THEN rolling_vol_21 ELSE NULL END as rolling_vol_21,		
		--to force null in rolling_vol_21 before row 22. The first row of every ticker is null because log_return is also null for that row. 
		
		--build our calendar (syncing with Python because in Pandas 0=Monday whereas in SQL it's Sunday)
		(EXTRACT(ISODOW FROM date)-1)::INT as day_of_week,
		--we subtract 1 to make sure that the first week day (0) is Monday, like in Pandas
		TRIM(TO_CHAR(date,'Day')) as day_name,
		EXTRACT(MONTH FROM date)::INT as month,
		EXTRACT(QUARTER FROM date)::INT as quarter,
		EXTRACT(YEAR FROM date)::INT as year
	FROM volatility	 
	ORDER BY symbol, date
	
	

--CREATING AN INDEX FOR THIS TABLE:
	
CREATE INDEX idx_stock_features ON stock_features(symbol);




--CREATING THE SAME METRICS AND CALENDAR FEATURES BUT FOR THE INDEX TABLE AS A NEW TABLE:

DROP TABLE IF EXISTS index_features;

CREATE TABLE index_features AS
SELECT
	date,
	sp500_close,
	
	--simple return:
	(sp500_close/LAG(sp500_close) OVER (ORDER BY date))-1 as simple_return,
	--log return:
	LN(sp500_close/LAG(sp500_close) OVER (ORDER BY date)) as log_return,
	
	--calendar features:
	(EXTRACT(ISODOW FROM date)-1)::INT as day_of_week,
	TRIM(TO_CHAR(date,'Day')) as day_name,
	EXTRACT(MONTH FROM date) as month,
	EXTRACT(QUARTER FROM date) as quarter,
	EXTRACT(YEAR FROM date) as year
FROM clean_sp500_index
	



--CONFIRM INTEGRITY OF THE NEWLY CREATED TABLES.


--1. Number of rows of the newly created tables = og tables.
/*i did not filter any data, so the number of rows of the new tables should be equal
 * to the og tables'*/

SELECT 
	(SELECT COUNT(*) FROM clean_sp500_stocks) as clean_row_count,
	(SELECT COUNT(*) FROM stock_features) as features_row_count
	
	clean_row_count|features_row_count|
---------------+------------------+
        1791061|           1791061|
        
        

--2. First row per ticker should have NULL returns (nothing to compare) and 
   --cumulative_return=0 (by definition, cause its the starting point)
SELECT 
	COUNT(*)
FROM (	
	SELECT 
		symbol,
		date,
		SF.SIMPLE_RETURN,
		log_return,
		cumulative_return,
		ROW_NUMBER() OVER (PARTITION BY symbol ORDER BY date) as rn
	FROM STOCK_FEATURES SF 
	) t
WHERE rn>1
AND (t.SIMPLE_RETURN IS NULL OR log_return IS NULL OR cumulative_return IS NULL)
--No results.



--3. Confirm that i have the full window for each range (sma_20 i should have 20 values,
-- for sm_50 i should have 50 values, etc)

WITH numbered as ( 
	SELECT
		symbol,
		date,
		sma_20,
		sma_50,
		rolling_vol_21,
		row_number() OVER (PARTITION BY symbol ORDER BY date) as rn
	FROM STOCK_FEATURES SF 
)

SELECT 
	MIN(rn) FILTER (WHERE sma_20 IS NOT NULL) as first_row_with_sma_20,
	MIN(rn) FILTER (WHERE sma_50 IS NOT NULL) as first_row_with_sma_50,
	MIN(rn) FILTER (WHERE rolling_vol_21 IS NOT NULL) as first_row_with_vol_21
FROM numbered

first_row_with_sma_20|first_row_with_sma_50|first_row_with_vol_21|
---------------------+---------------------+---------------------+
                   20|                   50|                   22|

                   
--4. NULL counts per new column
                   
SELECT
    COUNT(*) FILTER (WHERE simple_return IS NULL) as null_simple_returns,
    COUNT(*) FILTER (WHERE log_return IS NULL) as null_log_returns,
    COUNT(*) FILTER (WHERE cumulative_return IS NULL) as null_cumulative_returns,
    COUNT(*) FILTER (WHERE sma_20 IS NULL) as null_sma_20,
    COUNT(*) FILTER (WHERE sma_50 IS NULL) as null_sma_50,
    COUNT(*) FILTER (WHERE rolling_vol_21 IS NULL) as null_rolling_vol_21
FROM sql_track.stock_features;

null_simple_returns|null_log_returns|null_cumulative_returns|null_sma_20|null_sma_50|null_rolling_vol_21|
-------------------+----------------+-----------------------+-----------+-----------+-------------------+
                502|             502|                      0|       9538|      24598|              10542|

/*
 * .for simple and log returns i should expect one null row per symbol (the first row of each symbol). The data has 502 symbols, so 502 nulls.

   .null_cumulative_returns 0 nulls. Even for the first row where there's no previous value, so cumulative is 0.

   .sma_20 and 50 also correct. 19 nulls and 49 nulls per symbol (x502).
   
   .for rolling_vol_21 there are 21 null rows (the case) per symbol (x502).
*/   

                
SELECT
    ROUND(MIN(simple_return)::NUMERIC, 4) AS min_return,
    ROUND(MAX(simple_return)::NUMERIC, 4) AS max_return,
    ROUND(AVG(simple_return)::NUMERIC, 6) AS avg_return,
    ROUND(STDDEV(simple_return)::NUMERIC, 4) AS stddev_return
FROM sql_track.stock_features;
                
                