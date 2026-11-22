-- --##7 Correlation CAPM ## -- --

/*

In this section, i intend to move on from "What happened?" (previous section) to 
 understanding the relationships between sectors, estimating an asset's expected return 
 based on how sensitive each stock is to the market.
 
Phase 7 moves beyond descriptive statistics. I use correlation to study 
 diversification, regression to measure each stock’s exposure to the market, 
 and inferential statistics to test whether differences between sectors are 
 statistically meaningful rather than just random variation.


CAPM - >  E(Ri) = Rf + Betai(E(Rm) - Rf)
	E(Ri) is expected return of asset i 
	Rf is the risk-free rate
	E(Rm)-Rf is the equity market risk premium.
	Bi is the beta, measuring sensitivity to the overall market
		Bi=Cov(Ri,Rm)/Var(Rm)

	Primary Purpose: Estimating Expected Return

	CAPM answers: Given that sensitivity (Beta), what return should investors require?


7.1 Sector correlation - How much do sectors move together?
7.2 CAPM beta per stock - how sensitive is each stock to the market?
7.3 Sector beta summary - do sectors differ in market sensitivity?

Hypothesis testing (assess if sector differences are real or noise) will be done using 
 Python's scipy.

The main metric used throughout this section will be the returns, never prices. Prices 
 are cumulative whilst Returns measure the percentage move over a single step. Prices 
 are non-stationary, as their mean changes constantly as prices trend up or down,
 whereas Returns fluctuate around a stable baseline mean, allowing more reliable 
 estimates.

*/

-- -- #7.1 Sector correlation matrix -- --

/*Using sector_daily_returns from phase 5 (equal-weighted daily sector returns).
 * I'll self join on date to put every pair of sectors side by side on the same day 
 * and then compute Pearson's correlation.
 * 
 * Pearson uses the actual size of the returns. It asks whether two series move up 
 *  and down together in a straight-line way. Measures linear co-movement using the 
 * 	actual numeric return values.
 * The one real objection to Pearson is that a few extreme days can pull it around. 
 * 
 * Spearman first turns each day into a rank (the best day is 1, the second best 
 *  is 2, and so on. Ties are averaged and ranked the same). It asks whether the 
 * two series rise and fall in the same order, ignoring how big the moves were.
*/

DROP TABLE IF EXISTS sector_correlation;

CREATE TABLE sector_correlation AS
SELECT
	a.sector as sector_a,
	b.sector as sector_b,
	COUNT(*) as n_obs,
	CORR(a.sector_return, b.sector_return) as pearson_corr
FROM SECTOR_DAILY_RETURNS a
JOIN SECTOR_DAILY_RETURNS b
	ON a.date=b.date
GROUP BY a.sector, b.sector
ORDER BY a.sector, b.sector

/*
sector_a              |sector_b              |n_obs|pearson_corr       |
----------------------+----------------------+-----+-------------------+
Basic Materials       |Basic Materials       | 3767|                1.0|
Basic Materials       |Communication Services| 3767| 0.7642330329440397|
Basic Materials       |Consumer Cyclical     | 3767| 0.8346603804019509|
(...)
*/




-- -- #7.2 CAMP per stock -- --

/*CAPM:
 * 	stock_return(y) = alpha + beta * (market_return(x)-risk free) + error
 * 	
 * 	beta -> REGR_SLOPE(y,x) -> how many % the stock tends to move when the market moves
 * 							1%. So it measure how much the stock moves relative to 
 * 							the market. Math:
 * 							
 * 							cov(y,x)/var(x)=SUM(xt-xmean).(yt-ymean)/SUM(xt-xmean)^2
 * 							y->stock
 * 							x->market
 * 
 * 	alpha -> REGR_INTERCEPT(y,x) -> avg daily return NOT explained by the market 
 * 								(daily, not annualized). So, it is the baselne daily
 * 								return of the stock when the market return (x) is 
 * 								equal to zero. Once beta is calculated, alpha is 
 * 								found using the means of both series (y and x):
 * 
 * 								alpha= ymean - beta.xmean
 * 
 * 	r2 (r squared)-> REGR_R2(y,x) -> share of the stock's daily variance (drama) 
 * 								   explained by the market.
 * 									 how strongly does the market model explain the 
 * 								   the stocks in this sector?
 * 								  R=1.0 (or 100%) means the stock returns lie 
 * 								   perfectly on the fitted regression line.
 * 								  R=0.5 About 50% of the variation in that stock's
 * 								   daily returns is explained by its linear 
 * 								   relationship with market returns in this model.
 * 								  R=0.0 (0), means the market return explains 
 * 								   essentially none of the stock-return variation 
 * 								   through this fitted linear relationship.
 * 								  R^2=(pearson correlation)^2
 * 								  R^2=variance explained by market/total stock's variance

Least squares:

Scatter plot with one dot per day. The x-axis is the market’s return 
 and the y-axis is the stock’s return. Regression draws the best straight line 
 through that cloud of dots.
Many lines could pass through the cloud, so you need a rule for “best”.
The rule is to measure how far each dot sits above or below the line, square 
 those distances, and add them up (SSE sum of squared errors or residuals). 
 The best line is the one with the smallest total. That’s “least squares”.

What i need:
	
	For each sotck, i want a regression of: 
		stock_return= alpha + Beta(market_return) + error
	
	For that, i need the stock return and the market (sp500) return. Therefore, i
	 need to join the stock_features and index_features by date. Most important and
	 fundamental join. This will allow to draw the x (market) and y (stock) points
	 on the plot. Inner join because i want only matching results (same dates).
	
	SQL's REGR_SLOPE use REGR_SLOPE(y,x) (not x,y)
	
	Group by symbol to get a regression for every stock. Without this, it would 
	 consider all stocks together and calc one meaningless regression for the entire
	 pile.
	 
	Join companies to get the sector.
	
	Remove null results for simple_returns. Regression requires pairs.
	 
*/


--to plot this, i just need the stock returns (y), the market returns (x) that will
-- be used to get all the correlation's parameters.
CREATE TABLE stock_capm as
SELECT
	s.symbol,
	sector,
	REGR_COUNT(s.simple_return, i.simple_return) as n_obs, 
	--counts the number of valid (y,x) pairs used in that stock's regression.
	REGR_SLOPE(s.simple_return, i.simple_return) as beta,
	--REGR_SLOPE(y,x) and means regress stock returns on market returns.
	REGR_INTERCEPT(s.simple_return, i.simple_return) as alpha_daily,
	REGR_R2(s.simple_return, i.simple_return) as r_squared 
FROM STOCK_FEATURES S 
JOIN INDEX_FEATURES I
	ON s.date=i.date 
JOIN CLEAN_SP500_COMPANIES C
	ON s.SYMBOL=c.SYMBOL 
WHERE s.SIMPLE_RETURN IS NOT NULL 
	AND i.SIMPLE_RETURN IS NOT NULL
GROUP BY s.SYMBOL, sector
ORDER BY s.SYMBOL 

/*
symbol|sector                |n_obs|beta               |alpha_daily          |r_squared          |
------+----------------------+-----+-------------------+---------------------+-------------------+
A     |Healthcare            | 2516| 1.0207653740992497|   0.0001471867676915| 0.4686121006193782|
AAPL  |Technology            | 2516| 1.1930810424154596|   0.0005082500966899| 0.5576435768470569|
ABBV  |Healthcare            | 2516| 0.6790152067633727|   0.0003644493954909| 0.2053535904694727|
(...)
*/




-- -- #7.3 Sector summary of beta -- --

/*In here, i applied a minimum threshold filter of at least 252 daily observations 
 * per stock. This is approximately one trading year. The goal is to avoid "short
 * lived" stocks distorting the sector averages. Purely practical and not statistical
 * rule.
*/

CREATE TABLE sector_capm_stats AS
SELECT
	sector,
	COUNT(*) as n_stocks,
	AVG(beta) as mean_beta,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY beta) as median_beta,
	STDDEV(beta) as stddev_beta,
	MIN(beta) as min_beta,
	MAX(beta) as max_beta,
	AVG(r_squared) as mean_r_squared,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY r_squared) as median_r_squared, 
	AVG(alpha_daily) as mean_alpha_daily	
FROM STOCK_CAPM SC 
WHERE N_OBS >= 252
GROUP BY SECTOR
ORDER BY SECTOR 

/*
sector                |n_stocks|mean_beta         |median_beta       |stddev_beta        |min_beta           |max_beta          |mean_r_squared     |median_r_squared   |mean_alpha_daily  |
----------------------+--------+------------------+------------------+-------------------+-------------------+------------------+-------------------+-------------------+------------------+
Basic Materials       |      22|1.0581278060129413|1.0531951645170576| 0.2299759470484132| 0.3841438385000907|1.6495867012060994|0.34540640546729257|0.35227886746878667|0.0000128396011712|
Communication Services|      22|0.9550759573922527|1.0048492019554023|0.20908302889500788|0.45876621160692294|1.2738223618578821|0.30068230528037926| 0.2768627167958201|  0.00010707162381|
Consumer Cyclical     |      54|1.1035896024618548|1.1000002416971966|0.27642682623550585| 0.6133017587617907|1.8446942278086733|0.31697287482995845| 0.3107504981238298|0.0001512320527447|
Consumer Defensive    |      37|0.5952111024781517|0.5696889042956772|  0.180283216013613| 0.3131706452388161|1.0382090353447828| 0.1956276663168687|0.19317784266423363|0.0000588051104909|
(...)
**/




-- -- #7.4 Sanity checks -- --


-- 7.4.1 check if there are any self correlations different from 1 (impossible):
	-- corr(a,a)=1, corr(b,b)=1, etc.

SELECT
	count(*) as impossible_correlations
FROM SECTOR_CORRELATION SC
WHERE sector_a=sector_b
AND (
	PEARSON_CORR IS NULL 
	OR 
	ABS(PEARSON_CORR - 1)>1e-9
	--The 1e-9 instead of = because floating-point calcs can introduce tiny rounding
	-- differences.
	)

-- result: 0

	
-- 7.4.2 check correlation matrix symmetry:
	-- corr(A,B)=corr(B,A), corr(A,C)=corr(C,A), etc.
	
SELECT COUNT(*) as bad_pairs
FROM sector_correlation x
LEFT JOIN sector_correlation y
   ON x.sector_a = y.sector_b
   AND x.sector_b = y.sector_a
WHERE y.sector_a IS NULL
   OR x.pearson_corr IS NULL
   OR y.pearson_corr IS NULL
   OR ABS(x.pearson_corr - y.pearson_corr) > 1e-9;

bad_pairs|
---------+
        0|


-- 7.4.3 correlation range, observation counts and matrix completeness:

SELECT
    MIN(pearson_corr ) as min_corr,
    MAX(pearson_corr ) as max_corr,
    COUNT(*) FILTER (WHERE pearson_corr  IS NULL
    				 OR pearson_corr  < -1 - 1e-9
    				 OR pearson_corr  >  1 + 1e-9
    				) AS bad_correlations,
    COUNT(DISTINCT n_obs) as distinct_n_obs,
    COUNT(*) FILTER (WHERE n_obs IS NULL OR n_obs < 2) as bad_observation_counts,
    COUNT(*) AS n_pairs,
    COUNT(DISTINCT (sector_a, sector_b)) as unique_pairs,
    (SELECT 
    	COUNT(DISTINCT sector)
     FROM sql_track.sector_daily_returns) as n_sectors
FROM sql_track.sector_correlation;


min_corr          |max_corr|bad_correlations|distinct_n_obs|bad_observation_counts|n_pairs|unique_pairs|n_sectors|
------------------+--------+----------------+--------------+----------------------+-------+------------+---------+
0.4402252204814803|     1.0|               0|             1|                     0|    121|         121|       11|




-- 7.4.4 CAPM stock coverage and observation window:
/* Trying to verify 3 things:
 * 	. every elegible stock appears exactly once in the CAPM results.
 * 	. the regression uses the intended 2014-2024 window.
 * 	. no stock has more observation than the market index.
 */

SELECT
	COUNT(*) as n_capm_rows,
	COUNT(DISTINCT symbol) as n_unique_stocks,
	MIN(n_obs) as min_obs,
	MAX(n_obs) as max_obs,
	COUNT(*) FILTER (WHERE n_obs > ( 
							SELECT COUNT(*)
							FROM INDEX_FEATURES
							WHERE simple_return IS NOT NULL
								AND date >= (SELECT min(date) from INDEX_FEATURES)
								AND date <= (SELECT MAX(date) from INDEX_FEATURES)
								) 
					) as stocks_exceeding_index_obs
FROM STOCK_CAPM SC	
    
n_capm_rows|n_unique_stocks|min_obs|max_obs|stocks_exceeding_index_obs|
-----------+---------------+-------+-------+--------------------------+
        502|            502|     62|   2516|                         0|
        
        

-- 7.4.5 Check if there are dates where stocks have valid returns, but the index 
-- does not have a valid return:"        
        
SELECT
    sf.date,
    COUNT(DISTINCT sf.symbol) as affected_stocks
FROM stock_features sf
WHERE sf.simple_return IS NOT NULL
  -- Only check dates within the valid index return window
  AND sf.date BETWEEN
      (SELECT MIN(date)
       FROM index_features
       WHERE simple_return IS NOT NULL)
       AND
      (SELECT MAX(date)
       FROM index_features
       WHERE simple_return IS NOT NULL)
  -- Find dates without a valid index return
  AND NOT EXISTS (
      SELECT 1
      FROM index_features ix
      WHERE ix.date = sf.date
        AND ix.simple_return IS NOT NULL
  )
GROUP BY sf.date
ORDER BY sf.date;   

date|affected_stocks|
----+---------------+



        

-- 7.4.6 Check for missing Betas and that all r_squares are between [0,1]

SELECT
	COUNT(*) FILTER (WHERE beta IS NULL OR alpha_daily IS NULL OR r_squared IS NULL) as null_rows,
	COUNT(*) FILTER (WHERE r_squared < -1e-9 OR r_squared > 1+1e-9) as bad_r2_rows
	--WHERE r_squared NOT BETWEEN -1e-9 (-0.00000001) AND 1+1e-9 (1.00000001)
FROM STOCK_CAPM

null_rows|bad_r2_rows|
---------+-----------+
        0|          0|
        
        



-- 7.4.7 Check if my capm_stats only has stocks that have more than 252 obs:

SELECT
    (SELECT SUM(n_stocks)
     FROM sql_track.sector_capm_stats)
        AS stocks_in_summary,

    (SELECT COUNT(*)
     FROM sql_track.stock_capm
     WHERE n_obs >= 252)
        AS stocks_with_enough_obs;
    
stocks_in_summary|stocks_with_enough_obs|
-----------------+----------------------+
              498|                   498|



-- 7.4.8 CAPM overall stats:
SELECT 
	AVG(beta) as mean_beta,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY beta) as median_beta,
	MIN(beta) as min_beta,
	MAX(beta) as max_beta
FROM stock_capm 
WHERE n_obs >= 252;

mean_beta         |median_beta       |min_beta          |max_beta         |
------------------+------------------+------------------+-----------------+
0.9911649402533101|0.9917643656490924|0.3131706452388161|1.927918761193255|




-- 7.5 Quick top and bottom betas:

(SELECT symbol, sector, beta, r_squared FROM stock_capm
 WHERE n_obs >= 252 ORDER BY beta DESC LIMIT 5)
UNION ALL
(SELECT symbol, sector, beta, r_squared FROM stock_capm
 WHERE n_obs >= 252 ORDER BY beta ASC LIMIT 5);

symbol|sector            |beta               |r_squared           |
------+------------------+-------------------+--------------------+
PLTR  |Technology        |  1.927918761193255| 0.19624030252718647|
CZR   |Consumer Cyclical | 1.8446942278086733|  0.3045916142173116|
NVDA  |Technology        | 1.7356195421979714| 0.40514756173126054|
ON    |Technology        | 1.7280979166655293|  0.4085160172897267|
NCLH  |Consumer Cyclical | 1.7233149793758438|  0.2637534291237381|
CPB   |Consumer Defensive| 0.3131706452388161|0.053574568890828345|
CLX   |Consumer Defensive|0.33736352344986387| 0.06796344971363097|
K     |Consumer Defensive|0.34747967569155624| 0.08136651617308077|
SJM   |Consumer Defensive| 0.3523186597395104| 0.07479364294631229|
GIS   |Consumer Defensive| 0.3628420154277658| 0.09492012193367244|