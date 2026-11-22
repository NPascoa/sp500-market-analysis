-- --## 1- CHECK DATA COVERAGE:##-- --



-- 1.1 earliest and latest dates, number of rows and tickers:
SELECT
	min(date) as earliest_date,
	max(date) as latest_date,
	count(*) as n_rows,
	count(Distinct symbol) as n_tickers
FROM RAW_SP500_STOCKS

earliest_date|latest_date|n_rows |n_tickers|
-------------+-----------+-------+---------+
   2010-01-04| 2024-12-20|1891536|      502|

   
   

-- 1.2 How many companies and sectors:   
SELECT 
	count(*) as n_companies,
	count(Distinct SECTOR) sectors
FROM RAW_SP500_COMPANIES

n_companies|sectors|
-----------+-------+
        502|     11|
        
/*This is the sp500 and we see here that we have 502 tickers.
 * THis could be due to different classes of the same shares of certain companies.
 * Confirming with:*/
        
        SELECT
        	RSC.LONG_NAME,
        	COUNT(distinct RSC.SYMBOL) as n_symbols,
        	string_agg(RSC.SYMBOL, ', ') as symbols
        FROM RAW_SP500_COMPANIES RSC
        GROUP BY LONG_NAME 
        HAVING COUNT(distinct RSC.SYMBOL)>1
        
        long_name       |n_symbols|symbols    |
		----------------+---------+-----------+
		Alphabet Inc.   |        2|GOOG, GOOGL|
		Fox Corporation |        2|FOX, FOXA  |
		News Corporation|        2|NWS, NWSA  |
		
		
		
		
		

-- 1.3 CHECK HOW MANY TICKERS:
SELECT
	symbol,
	count(distinct date) as n_days
FROM RAW_SP500_STOCKS
GROUP BY symbol
ORDER BY n_days ASC
/*All ticker have 3768 days*/




-- 1.4 see how many groups of n_days this dataset has:
with days as (
	SELECT
	symbol,
	count(distinct date) as n_days
	FROM RAW_SP500_STOCKS
	GROUP BY symbol
)
SELECT 
	n_days,
	count(symbol) as n_symbols
from days
group by N_DAYS 
order by n_days asc


n_days|n_symbols|
------+---------+
  3768|      502|




  
  

-- -- 2 DUPLICATES:-- --

/*INDEX table:
 * This table should only have one day per row because this reflects the 
 * daily value of the sp500
 */
SELECT 
	date,
	count(*)
FROM RAW_SP500_INDEX
GROUP BY date
HAVING count(*)>1
/*no results*/


/*STOCKS table:
 * this table gives us the daily information of each stock. 
 * So there should only be one daily record per date+symbol
 */
SELECT 
	date,
	symbol,
	count(*)
FROM RAW_SP500_STOCKS
GROUP BY date,symbol
HAVING count(*)>1
/*No results*/



/*COMPANIES table:
 * this table gives information about each stock, so there 
 * shouldn't be any repeating symbols.
 */
SELECT
	symbol,
	count(*)
FROM RAW_SP500_COMPANIES
GROUP BY symbol
HAVING count(*)>1
/*No results*/







-- -- 3 MISSING VALUES-- --

/* 3.1 COMPANIES table missing values:*/
SELECT
	count(*) FILTER (WHERE exchange IS NULL) as null_exchange,
	count(*) FILTER (WHERE symbol IS NULL) as null_symbol,
	count(*) FILTER (WHERE short_name IS NULL) as null_short_name,
	count(*) FILTER (WHERE long_name IS NULL) as null_long_name,
	count(*) FILTER (WHERE sector IS NULL) as null_sector,
	count(*) FILTER (WHERE industry IS NULL) as null_industry,
	count(*) FILTER (WHERE current_price IS NULL) as null_current_price,
	count(*) FILTER (WHERE market_cap IS NULL) as null_market_cap,
	count(*) FILTER (WHERE ebitda IS NULL) as null_ebitda,
	count(*) FILTER (WHERE revenue_growth IS NULL) as null_revenue_growth,
	count(*) FILTER (WHERE city IS NULL) as null_city,
	count(*) FILTER (WHERE state IS NULL) as null_state,
	count(*) FILTER (WHERE country IS NULL) as null_country,
	-- the long business summary isn't really relevant. excluded.
	count(*) FILTER (WHERE fulltime_employees IS NULL) as null_fulltime_employees,
	count(*) FILTER (WHERE weight IS NULL) as null_weight
FROM raw_sp500_companies
	
null_exchange|null_symbol|null_short_name|null_long_name|null_sector|null_industry|null_current_price|null_market_cap|null_ebitda|null_revenue_growth|null_city|null_state|null_country|null_fulltime_employees|null_weight|
-------------+-----------+---------------+--------------+-----------+-------------+------------------+---------------+-----------+-------------------+---------+----------+------------+-----------------------+-----------+
            0|          0|              0|             0|          0|            0|                 0|              0|         29|                  3|        0|        20|           0|                      9|          0|
            
        
            

/* 3.2 STOCKS table missing values:*/
SELECT
	count(*) as n_rows,
	count(*) FILTER (WHERE date IS NULL) as null_date,
	count(*) FILTER (WHERE symbol IS NULL) as null_symbol,
	count(*) FILTER (WHERE adj_close IS NULL) as null_adj_close,
	count(*) FILTER (WHERE close IS NULL) as null_close,
	count(*) FILTER (WHERE high IS NULL) as null_high,
	count(*) FILTER (WHERE low IS NULL) as null_low,
	count(*) FILTER (WHERE open IS NULL) as null_open,
	count(*) FILTER (WHERE volume IS NULL) as null_volume
FROM RAW_SP500_STOCKS
	
n_rows |null_date|null_symbol|null_adj_close|null_close|null_high|null_low|null_open|null_volume|
-------+---------+-----------+--------------+----------+---------+--------+---------+-----------+
1891536|        0|          0|        100475|    100475|   100475|  100475|   100475|     100475|

/*This dataset has quite a few nulls, even though it is just a 5% rate. 
 * Further exploration will be needed.
 * Possible explanation for the amount of nulls is that the index is not static 
 * so many of these companies werent probably present during the whole period range.
 * This needs to be checked bcause a decision must be made on how to deal with these.
 * One way is to check 
 * */
       -- 3.2.1. per ticker summary: dataset span vs valid price span:
        SELECT
        	RSS.SYMBOL,
        	min(date) as first_dataset_date,
        	max(date) as last_dataset_date,
        	min(date) FILTER (WHERE adj_close IS NOT NULL) as first_valid_price_date,
        	max(date) FILTER (WHERE adj_close IS NOT NULL) as last_valid_price_date,
        	count(*) FILTER (WHERE adj_close IS NOT NULL) as valid_price_rows,
        	count(*) FILTER (WHERE adj_close IS NULL) as null_price_rows
        FROM RAW_SP500_STOCKS RSS
        GROUP BY RSS.SYMBOL
        
       -- 3.2.2. nulls before, between and after real dates (price first appeared):
	    with boundaries as (    
        	SELECT
	        	RSS.SYMBOL,
	        	min(date) FILTER (WHERE adj_close IS NOT NULL) as first_real_date,
	        	max(date) FILTER (WHERE adj_close IS NOT NULL) as last_real_date
	        FROM RAW_SP500_STOCKS RSS
	        GROUP BY RSS.SYMBOL
	        )
	        
	    Select
	    	s.symbol,
	    	first_real_date,
	    	last_real_date,
	    	count(*) FILTER (WHERE s.adj_close IS NULL AND s.date<first_real_date) as nulls_before,
	    	count(*) FILTER (WHERE s.adj_close IS NULL AND s.date BETWEEN first_real_date and last_real_date) as nulls_between,
	    	count(*) FILTER (WHERE s.adj_close IS NULL AND s.date>last_real_date) as nulls_after
	    FROM RAW_SP500_STOCKS s
	    JOIN boundaries b
	    	on s.symbol=b.symbol
	    GROUP BY s.symbol, first_real_date, last_real_date
	    ORDER BY nulls_between DESC
	    /*no nulls between nor after real dates*/
	    
	    
	    -- 3.2.3. Checking if there are any symbols with only null adj_close:	    
	    SELECT symbol, count(*) FILTER (WHERE adj_close IS NOT NULL)
		FROM sql_track.raw_sp500_stocks
		GROUP BY symbol
		HAVING COUNT(*) FILTER (WHERE adj_close IS NOT NULL) = 0;
	    /*No results.*/
        
        
	    -- 3.2.4. all price columns null vs partial nulls:
	    SELECT
	    	count(*) FILTER (WHERE adj_close IS NULL AND close IS NULL AND high IS NULL
	    		AND low IS NULL AND open IS NULL AND volume IS NULL) as all_prices_null,
			count(*) FILTER (
			WHERE NOT(adj_close IS NULL AND close IS NULL AND high IS NULL
           		AND low IS NULL AND open IS NULL AND volume IS NULL)
           	AND
           		(adj_close IS NULL OR close IS NULL OR high IS NULL
       			OR low IS NULL OR open IS NULL OR volume IS NULL)) as partial_null    
	    FROM RAW_SP500_STOCKS RSS 
	    
		all_prices_null|partial_null|
		---------------+------------+
		         100475|           0|
        
	    
	    -- 4. comfirm particular stocks that i know when their ipo was:
        SELECT 
        	symbol, 
        	MIN(date) FILTER (WHERE adj_close IS NOT NULL) as first_real_date
		FROM raw_sp500_stocks
		WHERE symbol IN ('UBER', 'ABNB')
		GROUP BY symbol;
        
        
        
/* 3.3 INDEX table missing values:*/
SELECT
	count(*) FILTER (WHERE date IS NULL) as null_date,
	count(*) FILTER (WHERE sp500_close IS NULL) as null_sp500_close
FROM RAW_SP500_INDEX

null_date|null_sp500_close|
---------+----------------+
        0|               0|



        
        
        
-- -- 4 CHECK FOR STRANGE VALUES-- --


/* 4.1. COMPANIES table:
 * the integrity of this table isnt too relevant.
 */

        
        
        
/*4.2. STOCKS table:
 * in this table there are a couple of situations that, if present, wouldnt make sense. Such as:
 * -Prices should never be negative nor zero. 
 * -As for volume, it should never be negative and it would be unusual if it were zero but still possible. 
 */

	-- 4.2.1. STOCKS table Negative values:
	SELECT 
		count(*) as bad_rows
	FROM RAW_SP500_STOCKS
	WHERE adj_close<=0 OR close<=0 OR high<=0 OR low<=0 OR open<=0
	OR VOLUME<0
	
	bad_rows|
	--------+
	       0|
       
	/* 4.2.2. STOCKS table Other important checks:
	 * - high should never be lower than low, or below close and open prices.
	 * - the inverse goes for low, so low can never be higher than close nor open.
	 */
	SELECT 
		count(*) as bad_rows
	FROM RAW_SP500_STOCKS
	WHERE high<low OR high<close OR high<open OR low>close OR low>open
	
	bad_rows|
	--------+
	       1|
 
       
       
	/* 4.2.3. STOCKS table Spread of the values data:*/
	
	SELECT
		ROUND(min(ADJ_CLOSE),2) as min_adj_close,
		ROUND(max(ADJ_CLOSE),2) as max_adj_close,
		ROUND(avg(adj_close),2) as avg_adj_close,
		ROUND(min(VOLUME),2) as min_volume,
		ROUND(max(volume),2) as max_volume,
		ROUND(avg(volume),2) as avg_volume
	FROM RAW_SP500_STOCKS
	
	min_adj_close|max_adj_close|avg_adj_close|min_volume|max_volume   |avg_volume|
	-------------+-------------+-------------+----------+-------------+----------+
	         0.11|      9924.40|        98.09|      0.00|3692928000.00|7022542.83|
         
	/*Some of these values, though not impossible, are strange and require further analysis:*/
         
	         
         -- 4.2.3.1 STOCKS table with adj.close low value:
         SELECT *
         FROM RAW_SP500_STOCKS RSS
         ORDER BY adj_close ASC 
         LIMIT 5
         
         -- 4.2.3.2 STOCKS table with volume value of 0:
         SELECT *
         FROM RAW_SP500_STOCKS RSS
         ORDER BY volume ASC 
         LIMIT 5
		         
         /*some of the stocks with 0 volume had the same values for all other columns
          * Need to check that:
          */
         		-- number of stocks with volum 0 and all values the same:
         		SELECT COUNT(*) AS flat_zero_volume_rows
				FROM raw_sp500_stocks
				WHERE volume = 0 AND open = high AND high = low AND low = close
				
				flat_zero_volume_rows|
				---------------------+
                 1406|
                 
					-- which are the 1406 stocks:
					SELECT symbol, date, adj_close, close, high, low, open, volume
					FROM raw_sp500_stocks
					WHERE volume = 0 AND open = high AND high = low AND low = close
					ORDER BY symbol, date
				
					
				-- Are these 0 volume rows near a symbol's first/last real date or
				-- scattered?
				CREATE TEMP TABLE bounds AS --reason for this temp table below
				SELECT
				    symbol,
				    MIN(date) FILTER (WHERE adj_close IS NOT NULL) AS first_real_date,
				    MAX(date) FILTER (WHERE adj_close IS NOT NULL) AS last_real_date
				FROM sql_track.raw_sp500_stocks
				GROUP BY symbol;
				
				SELECT
					CASE
				        WHEN s.date <= b.first_real_date THEN 'near_start'
				        WHEN s.date >= b.last_real_date THEN 'near_end'
				        ELSE 'mid_series'
				    END AS position,
				    COUNT(*) AS n_rows
				FROM sql_track.raw_sp500_stocks s
				JOIN bounds b ON s.symbol = b.symbol
				WHERE s.volume = 0
				  AND s.open = s.high
				  AND s.high = s.low
				  AND s.low = s.close
				GROUP BY position;
				/* why the temp table: this query was taking a long time (more than 30s!) to execute. AI advised me to create a temp table instead of a cte like i initially did.
				 */
				
				position  |n_rows|
				----------+------+
				mid_series|  1404|
				near_start|     2|

				/*mostly in the middle of tickers' trading history*/
				
					--Are these in specific dates or spread out?
					SELECT 
						date,
						count(*) as n_affected_tickers
					FROM RAW_SP500_STOCKS RSS 
					WHERE volume=0 AND open = high AND high = low AND low = close
					GROUP BY date ORDER BY n_affected_tickers DESC LIMIT 15;
					
					--Which tickers are these?
					SELECT 
						symbol,
						count(*) as n_flat_rows
					FROM RAW_SP500_STOCKS RSS 
					WHERE volume=0 AND open = high AND high = low AND low = close
					GROUP BY symbol
					ORDER BY n_flat_rows DESC
					
					symbol|n_flat_rows|
					------+-----------+
					AMCR  |       1371|
					CHTR  |         18|
					PFG   |          2|
					BKR   |          1|
					CCI   |          1|
					CHD   |          1|
					...   |        ...|
					
					/*Heavily concentrated in one ticker - AMCR (1371 out of 1406 - 97.5%)*/




         
-- -- 5 CROSS TABLE CHECK:-- --
/*check if are there any tickers in stocks that never appear in companies table.
 * And check if are there any tickers that never appear in stocks table.
*/
         
SELECT 
	s.SYMBOL 
FROM RAW_SP500_STOCKS s 
LEFT JOIN RAW_SP500_COMPANIES c
	on s.SYMBOL=c.SYMBOL 
WHERE c.SYMBOL IS NULL
/*no results. all stocks have company metadata.*/


SELECT 
	c.SYMBOL  
FROM RAW_SP500_STOCKS s 
RIGHT JOIN RAW_SP500_COMPANIES c
	on s.SYMBOL=c.SYMBOL 
WHERE s.SYMBOL IS NULL
/*no results. all companies have stock data.*/

/*The tickers exist in both tables*/


	