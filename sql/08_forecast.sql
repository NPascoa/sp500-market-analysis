-- --##8 Forecast ## -- --

/*This section will only be about building the tables (data) necessary for 
the forecast models. All forecasting will be done using Python, so this section
is not an 100% equivalent of what was done in Python*/



-- 1. Get yesterday's return

SELECT
	date,
	--TO_CHAR(date,'Day'), this was just to check
	SIMPLE_RETURN,
	lag(simple_return,1) over (order by date) as lag_1_return
FROM INDEX_FEATURES
ORDER BY date

/*This is usefull for the naive forecasting and for the AR(1) model.*/


-- 2. Get 21 day rolling volatility (trailing)

WITH filtering AS (
	SELECT 
		date,
		simple_return,
		stddev(simple_return) OVER (ORDER BY date ROWS BETWEEN 20 
			PRECEDING AND CURRENT ROW) as trailing_21d_vol,
		ROW_NUMBER() OVER (ORDER BY date) as rn
	FROM INDEX_FEATURES
)

SELECT
	date,
	simple_return,
	CASE
		WHEN rn<21 then null
		ELSE trailing_21d_vol
	--so that only values are shown after i have 21 records.
	END as trailing_21d_vol	
FROM filtering
ORDER BY date


-- 3. Get 21 day rolling volatility (forward)

WITH filtering AS (
	SELECT 
		date,
		simple_return,
		stddev(simple_return) OVER (ORDER BY date ROWS BETWEEN 1 FOLLOWING 
			AND 21 FOLLOWING) as following_21d_vol,
		COUNT(simple_return) OVER (ORDER BY date ROWS BETWEEN 1 FOLLOWING 
			AND 21 FOLLOWING) as future_n_days
	FROM INDEX_FEATURES
	WHERE simple_return IS NOT NULL
)

SELECT
	date,
	simple_return,
	CASE
		WHEN future_n_days < 21 then null
		ELSE following_21d_vol
	END as following_21d_vol	
FROM filtering
ORDER BY date



-- 4. Both together:


WITH filtering AS ( 
	SELECT
		date,
		simple_return,
		
		ROW_NUMBER() OVER (ORDER BY date) as rn,
		
		STDDEV(simple_return) OVER (ORDER BY date ROWS BETWEEN 20 PRECEDING
			AND CURRENT ROW) as trailing_21d_vol,
		
		STDDEV(simple_return) OVER (ORDER BY date ROWS BETWEEN 1 FOLLOWING
			AND 21 FOLLOWING) as following_21d_vol,
		COUNT(simple_return) OVER (ORDER BY date ROWS BETWEEN 1 FOLLOWING
			AND 21 FOLLOWING) as future_n_days
	FROM INDEX_FEATURES
	WHERE simple_return IS NOT NULL
)

SELECT 
	date,
	simple_return,
	
	CASE
		WHEN rn<21 THEN NULL
		ELSE trailing_21d_vol
	END as trailing_21d_vol,
	
	CASE
		WHEN future_n_days < 21 THEN NULL
		ELSE following_21d_vol
	END
FROM filtering
ORDER BY date



-- 5. Regressions:

/*The main difficulty here would be to recreate the ever expanding loop:
 * Forecast date 1:
 * 	Fit the model to the historical rows
 * 	 Predict
 * 
 * Forecast date 2:
 * 	Fit the model to the historical rows expanded with date 1 (becomes known)
 *   Predict.
 * 
 * Etc.
 * 
 * That is easily done in Python using a for loop with a train data condition.
 */

/* 5.1 AR(1) 
 * 
 * AR(1) model goes like this:
 * 
 * Rt = c + phi.Rt-1 + Et
 * 
 * c is the intercept (constant)
 * phi is the slope
 * 
 * I can get those in SQL using the respective REGR_functions(y,x).
 */


WITH returns_with_lag as ( 
	SELECT
		date,
		simple_return,
		LAG(simple_return,1) OVER (ORDER BY date) as lag_1_return
	FROM INDEX_FEATURES
)

SELECT 
	REGR_COUNT(simple_return,lag_1_return) as n_obs,
	
	REGR_SLOPE(simple_return,lag_1_return) as phi,
	
	REGR_INTERCEPT(simple_return,lag_1_return) as c,
	
	REGR_R2(simple_return,lag_1_return) as r_squared

FROM returns_with_lag
WHERE simple_return IS NOT NULL 
	AND lag_1_return IS NOT NULL

/*
n_obs|phi                 |c                 |r_squared         |
-----+--------------------+------------------+------------------+
 2515|-0.13751310172501346|0.0005450014252494|0.0189035030952919|
 */

	
/* 5.2 Vol Regression 
*/

WITH filtering AS ( 
	SELECT
		date,
		simple_return,
		
		ROW_NUMBER() OVER (ORDER BY date) as rn,
		
		STDDEV(simple_return) OVER (ORDER BY date ROWS BETWEEN 20 PRECEDING
			AND CURRENT ROW) as trailing_21d_vol,
		
		STDDEV(simple_return) OVER (ORDER BY date ROWS BETWEEN 1 FOLLOWING
			AND 21 FOLLOWING) as following_21d_vol,
		COUNT(simple_return) OVER (ORDER BY date ROWS BETWEEN 1 FOLLOWING
			AND 21 FOLLOWING) as future_n_days
	FROM INDEX_FEATURES
	WHERE simple_return IS NOT NULL
)

SELECT 
	REGR_COUNT(following_21d_vol, trailing_21d_vol) as n_obs,
	
	REGR_SLOPE(following_21d_vol, trailing_21d_vol) as phi,
	
	REGR_INTERCEPT(following_21d_vol,trailing_21d_vol) as c,
	
	REGR_R2(following_21d_vol,trailing_21d_vol) as r_squared
	
FROM filtering
WHERE following_21d_vol IS NOT NULL 
	AND trailing_21d_vol IS NOT NULL
	
/*
n_obs|phi               |c                   |r_squared          |
-----+------------------+--------------------+-------------------+
 2513|0.5108614279515061|0.004606781730232529|0.26096695347178095|
/*