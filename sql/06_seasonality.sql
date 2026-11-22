-- --##6 Seasonality Analysis ## -- --

/*Intro:
 * 
 * Ill be focussing only on a market level (SP500 index). Ill not include a
 *  per-sector or per-stock analysis.
 * The index is clean and a single real time series, and is the actual market.
 */


-- -- #6.1 Day of week summary -- --


CREATE TABLE market_dow_stats as 
SELECT
	day_of_week,
	max(day_name) as day_name, --max is just a trick to avoid having to group
	COUNT(*) as n_obs,
	AVG(simple_return) as mean_return,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY simple_return) as median_return,
	stddev(simple_return) as stddev_return,
	AVG(simple_return*simple_return) as mean_sq_return,
	min(simple_return) as min_return,
	max(simple_return) as max_return
FROM INDEX_FEATURES
WHERE simple_return IS NOT NULL
GROUP BY day_of_week,day_name
ORDER BY day_of_week




-- -- #6.2 Month summary -- --

CREATE TABLE market_month_stats as 
SELECT
	month,
	max(TRIM(TO_CHAR(date,'Month'))) as month_name,
	--or: trim(to_char(to_date(month::text,'MM'),'Month'))
	-- month_number::text converts the number to text.
	-- to_date(..., 'MM') interpret this text as a month number, using the MM format.
	-- to_char(..., 'Month') take that date and extracts/formats its month name
	COUNT(*) as n_obs,
	AVG(simple_return) as mean_return,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY simple_return) as median_return,
	stddev(simple_return) as stddev_return,
	AVG(simple_return*simple_return) as mean_sq_return,
	min(simple_return) as min_return,
	max(simple_return) as max_return
FROM INDEX_FEATURES
WHERE simple_return IS NOT NULL
GROUP BY month
ORDER BY month




-- -- #6.3 Sanity checks -- --

/*Same amount of records: */
--DOW
SELECT
(SELECT sum(n_obs) from MARKET_DOW_STATS) as sum_by_dow,
(SELECT count(*) from INDEX_FEATURES WHERE simple_return is not null) as total_non_null_returns

--Month:
SELECT
(SELECT sum(n_obs) from MARKET_MONTH_STATS) as sum_by_month,
(SELECT count(*) from INDEX_FEATURES WHERE simple_return is not null) as total_non_null_returns


--No weekend days should appear:
SELECT day_of_week, day_name, n_obs
FROM MARKET_DOW_STATS
WHERE day_of_week IN (5, 6);


--Only 5 distinct days of week and 12 distinct months:
SELECT 
(SELECT COUNT(distinct day_of_week) FROM MARKET_DOW_STATS) as n_dows,
(SELECT COUNT(distinct month) FROM MARKET_MONTH_STATS) as n_months


--No negative sttdev and impossible min > max:
SELECT
(SELECT COUNT(*) FROM market_dow_stats WHERE stddev_return < 0 OR min_return > max_return) AS bad_dow_rows,
(SELECT COUNT(*) FROM market_month_stats WHERE stddev_return < 0 OR min_return > max_return) AS bad_month_rows

