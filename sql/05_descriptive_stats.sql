-- --##5 Descriptive Stats ## -- --

/* A few key considerations for this section:
 * 
 * 
 * I want the stats per ticker, per sector but every stock in the secto pooled as
 * 	one observation (what a random stock day within a sector looks like) and sector
 *  performance (avg return across all tickers in that sector for that day).
 * 
 * Skewness and Kurtosis will not use sample size bias correction because i found
 * 	that python's default behavior is to correct that. 
 * 
 * Will consider a 252 trading days/year. Seems to be the norm in the finance world.
 *  
 * 
 * Why keep both simple_return and log_return?
 * 	.simple_return represents the actual percentage change in price 
 * 	and is therefore the most intuitive measure for describing daily return 
 * 	distributions and communicating results. 
 * 	.log_return is retained because they are additive through time and can be 
 * 	useful for certain statistical and time-series analyses.
 */

-- 5.0 Overall excess kurtosis and skewness of the sp500 index:

WITH numerators AS (
	SELECT 
		avg(simple_return) as mean_return,
		STDDEV_POP(simple_return) as  pop_std_return
	FROM INDEX_FEATURES T 
	WHERE simple_return IS NOT NULL
)

SELECT 
	avg(POWER(simple_return-mean_return,3))/POWER(pop_std_return,3) as skewness,
	avg(POWER(simple_return-mean_return,4))/POWER(pop_std_return,4) -3 as excess_kurtosis
FROM INDEX_FEATURES, numerators
GROUP BY pop_std_return

/*
 * skewness                                   |excess_kurtosis                            |
-------------------------------------------+-------------------------------------------+
-0.5282979381346642894250377671805239788814|14.6043372901933269861313081157450389911811|
 */




SELECT AVG(POWER(simple_return - m, 3)) / POWER(sd, 3)     AS skewness,
       AVG(POWER(simple_return - m, 4)) / POWER(sd, 4) - 3 AS excess_kurtosis
FROM sql_track.index_features, s
WHERE simple_return IS NOT NULL;

		--skewness formula: 
		-- numerator: (1/n) x SUM(Xi-meanX)^3
		-- denominator: ((1/n) x SUM(Xi-meanX)^2)^3/2
		--	denominator is the standard deviation (sigma)
		--	note: power 3/2 is the same as SQR(x^3) 
			
		--kurtosis formula:
		-- numerator: (1/n) x SUM(Xi-meanX)^4
		-- denominator: ((1/n) x SUM(Xi-meanX)^2)^2
		AVG(POWER(simple_return - mean_return,3)) as skew_num,
		AVG(POWER(simple_return - mean_return,4)) as kurt_num



-- 5.1 Descriptive stats for all stocks:

DROP TABLE IF EXISTS stock_descriptive_stats

CREATE TABLE stock_descriptive_stats as 
WITH basic_stats as (
	SELECT 
		symbol,
		count(simple_return) as n_obs,
		avg(simple_return) as mean_return,
		PERCENTILE_CONT(0.5) WITHIN GROUP (order by simple_return ASC) as median_return,
		stddev(simple_return) as sample_std_return,
		stddev_pop(simple_return) as pop_std_return,
		min(SIMPLE_RETURN) as min_return,
		max(simple_return) as max_return
	FROM stock_features
	GROUP BY symbol
),

--get most of the numerators of skewness and kurtosis:
kurt_ske_nums as (
	SELECT
		sf.symbol,
		--skewness formula: 
		-- numerator: (1/n) x SUM(Xi-meanX)^3
		-- denominator: ((1/n) x SUM(Xi-meanX)^2)^3/2
		--	denominator is the standard deviation (sigma)
		--	note: power 3/2 is the same as SQR(x^3)

		--kurtosis formula:
		-- numerator: (1/n) x SUM(Xi-meanX)^4
		-- denominator: ((1/n) x SUM(Xi-meanX)^2)^2
		AVG(POWER(simple_return - mean_return,3)) as skew_num,
		AVG(POWER(simple_return - mean_return,4)) as kurt_num	
	FROM stock_features sf
	JOIN basic_stats bs
	ON sf.symbol=bs.symbol
	GROUP BY sf.symbol
),

final_cumulative as (
	SELECT
		Distinct ON (symbol) symbol,
		cumulative_return as final_cumulative_return
	FROM stock_features	
	ORDER BY symbol, date desc
),

drawdown_calc as (
	SELECT
		symbol,
		adj_close/(MAX(adj_close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))-1 as drawdown
	FROM stock_features
),

max_drawdown as (
	SELECT
		symbol,
		min(drawdown) as max_drawdown
	FROM drawdown_calc
	GROUP BY symbol
)

SELECT 
	bs.*,
	--all: symbol, n_obs, mean_return, median_return, sample_std_return, pop_std_ret,
		--min_return, max_return
	skew_num/POWER(pop_std_return,3) as skewness,
	kurt_num/POWER(pop_std_return,4)-3 as excess_kurtosis,
	
	bs.mean_return * 252 as annualized_mean_return, --simple arithmetic 

	bs.sample_std_return * SQRT(252) as annualized_volatility,
	
	(bs.mean_return*252)/(bs.sample_std_return * SQRT(252)) as sharpe_ratio_naive,
	--sharpe ratio: 		
		--why naive? because we excluded the risk free rate from the formula:
			-- sharpe_ratio=(return - risk free)/volatility

	
	final_cumulative_return,
	
	POWER(1+fc.final_cumulative_return,252.0/bs.n_obs)-1 as annualized_compound_return,
	max_drawdown
FROM basic_stats bs
JOIN kurt_ske_nums ksn
	ON bs.symbol=ksn.symbol
JOIN final_cumulative fc
	ON bs.symbol=fc.symbol
JOIN max_drawdown md
	ON bs.symbol=md.symbol

symbol|n_obs|mean_return            |median_return        |sample_std_return                         |pop_std_return                            |min_return             |max_return        |skewness                                   |excess_kurtosis                                  |annualized_mean_return |annualized_volatility|sharpe_ratio_naive |final_cumulative_return|annualized_compound_return|max_drawdown           |
------+-----+-----------------------+---------------------+------------------------------------------+------------------------------------------+-----------------------+------------------+-------------------------------------------+-------------------------------------------------+-----------------------+---------------------+-------------------+-----------------------+--------------------------+-----------------------+
A     | 3767| 0.00066753204711057932|   0.0008951916653229|0.0179857544284326615307428686929040891075|0.0179833669917156421821879558085926911523|-0.11013939030562993665|0.1176305886578621|-0.1962352277080660633588324162254324377770|     4.552870743803696344488158243691842981674465| 0.16821807587186598864|   0.2855150001570689| 0.5891742142420715|     5.7077142163888685|    0.13578241029352601442|-0.44085203490814675042|
AAPL  | 3767| 0.00113045907069189605|0.0010010374961459607|0.0175614875062529707311845855746237318265|0.0175591563869082283737829690744428262624|-0.12864689271025902724|0.1198080988562634|-0.0436451408854432034756642362488537039840|       5.1876424443600199066380960233457916209580| 0.28487568581435780460|   0.2787799715634794| 1.0218656821603498|    38.4716581759268271|    0.27875186213027201760|-0.43797144969217467874|
ABBV  | 3013| 0.00083429034195425875|0.0013055445819212946|0.0166076905732556010108690258525244366054|0.0166049343388040829332737571588022810974|-0.16252389369040227688|0.1376728453140941|-0.6762242511801969317159234724831487752586|      10.7705059286029623470179415652502221199207| 0.21024116617247320500|   0.2636389146476763| 0.7974587759680198|     7.1177398492193421|    0.19141467400998906023|-0.45089771332635010794|
ABNB  | 1013| 0.00040333301419711718|                  0.0|0.0309356280467276571408064304006776368684|0.0309203549635717481831100701675873292460|-0.13425033452497866225|0.1335318225655482| 0.1236718276419799595465996007940950859044|       2.1602974159926482597610564475716402037173| 0.10163991957767352936|  0.49108787077941735|0.20696890643289229|-0.07255890755890491654|   -0.01856407538388112790|-0.61958126149739641857|
(...)


--Overall stock summary stats:

-- Summary of the stock-level metrics across all stocks (one row per metric).
-- Each stock is one observation, so there is no GROUP BY.
-- STDDEV is the sample standard deviation and PERCENTILE_CONT interpolates,
-- the same as pandas' describe(), so the two tracks should match.
SELECT 'annualized_mean_return' AS metric,
       COUNT(annualized_mean_return) AS n,
       AVG(annualized_mean_return) AS mean,
       STDDEV(annualized_mean_return) AS std,
       MIN(annualized_mean_return) AS min,
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY annualized_mean_return) AS p25,
       PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY annualized_mean_return) AS median,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY annualized_mean_return) AS p75,
       MAX(annualized_mean_return) AS max
FROM sql_track.stock_descriptive_stats
UNION ALL
SELECT 'annualized_volatility',
       COUNT(annualized_volatility), AVG(annualized_volatility), STDDEV(annualized_volatility),
       MIN(annualized_volatility),
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY annualized_volatility),
       PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY annualized_volatility),
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY annualized_volatility),
       MAX(annualized_volatility)
FROM sql_track.stock_descriptive_stats
UNION ALL
SELECT 'sharpe_ratio_naive',
       COUNT(sharpe_ratio_naive), AVG(sharpe_ratio_naive), STDDEV(sharpe_ratio_naive),
       MIN(sharpe_ratio_naive),
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY sharpe_ratio_naive),
       PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY sharpe_ratio_naive),
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY sharpe_ratio_naive),
       MAX(sharpe_ratio_naive)
FROM sql_track.stock_descriptive_stats
UNION ALL
SELECT 'annualized_compound_return',
       COUNT(annualized_compound_return), AVG(annualized_compound_return), STDDEV(annualized_compound_return),
       MIN(annualized_compound_return),
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY annualized_compound_return),
       PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY annualized_compound_return),
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY annualized_compound_return),
       MAX(annualized_compound_return)
FROM sql_track.stock_descriptive_stats
UNION ALL
SELECT 'max_drawdown',
       COUNT(max_drawdown), AVG(max_drawdown), STDDEV(max_drawdown),
       MIN(max_drawdown),
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY max_drawdown),
       PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY max_drawdown),
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY max_drawdown),
       MAX(max_drawdown)
FROM sql_track.stock_descriptive_stats
UNION ALL
SELECT 'skewness',
       COUNT(skewness), AVG(skewness), STDDEV(skewness),
       MIN(skewness),
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY skewness),
       PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY skewness),
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY skewness),
       MAX(skewness)
FROM sql_track.stock_descriptive_stats
UNION ALL
SELECT 'excess_kurtosis',
       COUNT(excess_kurtosis), AVG(excess_kurtosis), STDDEV(excess_kurtosis),
       MIN(excess_kurtosis),
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY excess_kurtosis),
       PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY excess_kurtosis),
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY excess_kurtosis),
       MAX(excess_kurtosis)
FROM sql_track.stock_descriptive_stats;

-- this was just to mimic pandas' describe function.
	
	
-- 5.2 Every stock by sector
/*what does a random stock within a sector look like.
 * This will look at each stock inside each sector. It's not a sector performance, 
 * but a stock within sector performance.
*/


DROP TABLE IF EXISTS sector_stock_return_distribution

CREATE TABLE sector_stock_return_distribution as
WITH sector_returns as (
	SELECT
		sector,
		sf.symbol,
		simple_return
	FROM CLEAN_SP500_COMPANIES CSC 
	JOIN STOCK_FEATURES SF 
		ON csc.SYMBOL = sf.symbol
	WHERE simple_return IS NOT NULL
),

sector_basic_stats as (
	SELECT
		sector,
		count(distinct symbol) as n_symbols,
		count(*) as n_obs,
		avg(simple_return) as mean_return,
		PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY simple_return ASC) as median_return,
		STDDEV(simple_return) as sample_std_return,
		stddev_pop(simple_return) as pop_std_return,
		min(simple_return) as min_return,
		max(simple_return) as max_return
	FROM sector_returns
	GROUP BY sector
),

sector_kurt_skew_nums as (
	SELECT
		sr.sector,
		AVG(POWER(simple_return-mean_return,3)) as skew_num,
		AVG(POWER(simple_return-mean_return,4)) as kurt_num
	FROM sector_basic_stats sbs
	JOIN sector_returns sr
		ON sbs.sector=sr.sector
	GROUP BY sr.sector
)

SELECT 
	sbs.*,
	skew_num/power(pop_std_return,3) as skewness,
	kurt_num/power(pop_std_return,4)-3 as excess_kurtosis
FROM sector_basic_stats sbs
JOIN sector_kurt_skew_nums sksn
	ON sbs.sector=sksn.sector
ORDER BY sbs.sector

sector                |n_symbols|n_obs |mean_return           |median_return     |sample_std_return                         |pop_std_return                            |min_return             |max_return        |skewness                                   |excess_kurtosis                                   |
----------------------+---------+------+----------------------+------------------+------------------------------------------+------------------------------------------+-----------------------+------------------+-------------------------------------------+--------------------------------------------------+
Basic Materials       |       22| 78115|0.00057029651055377897|0.0005459837629778|0.0208273410507553728464943495392705284515|0.0208272077382820501468667172383981099785|-0.27507747207632201718|0.2968461067700693|-0.0587164588646246454113881879325802679633|        9.3277400722740323059410767100602581688765|
Communication Services|       22| 75911|0.00070163751189240337|0.0005896381863834|0.0207686327767341776829535207923464000466|0.0207684959803464660647899919502741769195|-0.36588368716742864175|0.4222351004273728| 0.1570411883150439370182093891835558932090|     19.678768826393833765271939468331300171712712|
Consumer Cyclical     |       55|196421|0.00081243262375806891|0.0006163861215081|0.0220855529971253204156518977178405904370|0.0220854967771154763408831787899694835850|-0.37505049430128593231|0.4415709574369838| 0.0840950029640575779840883980484707200851|   18.61955976295277264066054985373093776112924763|
Consumer Defensive    |       37|132912|0.00049991199532982647|0.0006360809894442|0.0148958796111451184575830636345141784410|0.0148958235744154418194392389785713124464|-0.32146316808645852046|0.3723340303544993|-0.1892282953957588262921867886627993737623|  26.454997443163677118718704014901275669605159119|
(...)







-- 5.3 Sector performance:

-- Sector PERFORMANCE: an equal-weighted **daily** sector portfolio (average
-- return across all tickers active in the sector that day), then the
-- same stat calcs on that single return series per sector. This
-- answers "how did a representative sector portfolio actually perform,"
-- which is a different (and for a diversification-focused project, more
-- relevant) question than the pooled distribution above.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS sector_daily_returns;

--creating this as a separate table because it can be useful later
CREATE TABLE sector_daily_returns as
SELECT
	date,
	sector,
	AVG(simple_return) as sector_return
FROM stock_features sf
JOIN clean_sp500_companies as c
ON sf.symbol=c.symbol
WHERE simple_return IS NOT NULL
GROUP BY date,sector
ORDER BY date,sector

date      |sector                |sector_return              |
----------+----------------------+---------------------------+
2010-01-05|Basic Materials       |     0.00082307911253063999|
2010-01-05|Communication Services|     0.00249980942504935652|
2010-01-05|Consumer Cyclical     |     0.01540831625857687672|
2010-01-05|Consumer Defensive    |     0.00153747527717045201|
(...)



DROP TABLE IF EXISTS sector_performance_stats;

CREATE TABLE sector_performance_stats as
WITH cum_index as (
	SELECT
		*,
		EXP(SUM(LN(1+sector_return)) OVER (PARTITION BY sector ORDER BY date)) as cum_index
	FROM sector_daily_returns
),

final_cum_index as (
	SELECT DISTINCT ON (sector)
		sector,
		cum_index as final_cum_index
	FROM cum_index
	ORDER BY sector, date DESC
),

sector_agg_basic_stats as (
	SELECT
		sector,
		count(*) as n_obs,
		AVG(sector_return) as mean_return,
		PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sector_return) as median_return,
		STDDEV(sector_return) as sample_std_return,
		STDDEV_POP(sector_return) as pop_std_return,
		MIN(sector_return) as min_return,
		MAX(sector_return) as max_return
	FROM sector_daily_returns
	GROUP BY sector
),


sector_kurt_skew_nums as (
	SELECT
		sabs.sector,
		AVG(POWER(sector_return-mean_return,3)) as skew_num,
		AVG(POWER(sector_return-mean_return,4)) as kurt_num
	FROM sector_agg_basic_stats sabs
	JOIN sector_daily_returns sdr
	ON sabs.sector=sdr.sector
	GROUP BY sabs.sector
),

drawdown_calc as (
	SELECT
		sector,
		(cum_index/MAX(cum_index) OVER (PARTITION BY sector ORDER BY date
			ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))-1 as drawdown
	FROM cum_index
),

max_drawdown as (
	SELECT
		sector,
		MIN(drawdown) as max_drawdown
	FROM drawdown_calc
	GROUP BY sector
)

SELECT
	sabs.sector,
	n_obs,
	mean_return,
	median_return,
	sample_std_return,
	pop_std_return,
	min_return,
	max_return,
	skew_num/POWER(pop_std_return,3) as skewness,
	kurt_num/POWER(pop_std_return,4)-3 as excess_kurtosis,
	mean_return*252 as annualized_mean_return,
	sample_std_return*SQRT(252) as annualized_volatility,
	(mean_return*252)/(sample_std_return*SQRT(252)) as sharpe_ratio_naive,
	(final_cum_index-1) as final_cumulative_return,
	POWER(final_cum_index,252.0/n_obs)-1 as annualized_compound_return,	
	max_drawdown
FROM sector_agg_basic_stats sabs
JOIN max_drawdown md
	ON sabs.sector=md.sector
JOIN final_cum_index fci
	ON sabs.sector=fci.sector
JOIN sector_kurt_skew_nums sksn
	ON sabs.sector=sksn.sector
ORDER BY sharpe_ratio_naive DESC
	

sector                |n_obs|mean_return               |median_return        |sample_std_return                                 |pop_std_return                                    |min_return             |max_return            |skewness                                           |excess_kurtosis                                    |annualized_mean_return    |annualized_volatility|sharpe_ratio_naive|final_cumulative_return    |annualized_compound_return|max_drawdown               |
----------------------+-----+--------------------------+---------------------+--------------------------------------------------+--------------------------------------------------+-----------------------+----------------------+---------------------------------------------------+---------------------------------------------------+--------------------------+---------------------+------------------+---------------------------+--------------------------+---------------------------+
Technology            | 3767|0.000913868535932981181682| 0.001323406551139968|0.014084555442481861477314829991011178121642372674|0.014082685852582806785636690877962419431867170493|-0.13280835346638072802|0.11394721288916576707|-0.308670254262664390850955136082636648963398671683| 6.706226227143653665097158624618589456216697296349|0.230294871055111257783864|  0.22358538616624982|1.0300086021001056|20.470217290646128249826312|0.227709196644808692389877|-0.343852079441359235985700|
Healthcare            | 3767|0.000688236917468075310555|   0.0009812735293408|0.010979018405365168034147544948915563863541855348|0.010977561045777495503257585266378032657126060685|-0.10351825757376131388|0.08160480469089222080|-0.372875205441179316604829291208984841135962756445| 6.831508011996513021712816722877447457116746381658|0.173435703201954978259860|    0.174286514041183|0.9951183208643041| 9.636370690425611740193744|0.171356603178306290662572|-0.294702865103055631933278|
Consumer Cyclical     | 3767|0.000820585303194768338917|0.0010930349871061697|0.013611705248075047886341181229371605106129963241|0.013609898424512555198966126839737808458080738118|-0.15306669935566133889|0.16105022342627808640|-0.315953417396943999667858153043071586594065427541|16.528645411495699955427782432729288902516480286893|0.206787496405081621407084|  0.21607912203551596|0.9569989661985616|14.485971177533901315963456|0.201165906126853861832615|-0.486566492364935368403428|
Industrials           | 3767|0.000767475553438301698682|0.0011510721851918215|0.012770321874693771560034334998105992014336396822|0.012768626736719264247383017541704922236069304367|-0.11649343558415897161|0.12645113813294407688|-0.308413548551201028594471360400107237086006745823| 9.266704862399067632274720849497277519353892767689|0.193403839466452028067864|   0.2027225750561272|0.9540320776455453|12.226817652719276942318352|0.188561619850564411154314|-0.405817434475767924727825|
(...)




-- 5.4 Snippets of the tables:


(SELECT symbol, n_obs, final_cumulative_return, annualized_compound_return, sharpe_ratio_naive, max_drawdown
 FROM stock_descriptive_stats
 ORDER BY final_cumulative_return DESC LIMIT 10)
UNION ALL
(SELECT symbol, n_obs, final_cumulative_return, annualized_compound_return, sharpe_ratio_naive, max_drawdown
 FROM stock_descriptive_stats
 ORDER BY final_cumulative_return ASC LIMIT 10);
--cumulative_return: who won on row performance.

symbol|n_obs|final_cumulative_return|annualized_compound_return|sharpe_ratio_naive  |max_drawdown           |
------+-----+-----------------------+--------------------------+--------------------+-----------------------+
AVGO  | 3767| 1743.41629872783391383|    0.64761527431538439477|   1.484695115545648|-0.48299968253644506167|
NVDA  | 3767|   316.7466546938823876|    0.47021567323407916052|  1.0735250079402974|-0.66335090736239454953|
TSLA  | 3645|   263.3741610099025696|    0.47048992996649643480|  0.9576703234188897|-0.73632217442191194254|
TPL   | 3767|   155.7547691857505045|    0.40233928731802237133|  1.0285607061625484|-0.63077087814080707467|
AXON  | 3767|   134.8473095668811059|    0.38897410726134732115|  0.9102356364250789|-0.58606906921819067258|
NFLX  | 3767|   117.9856025758194519|    0.37671422373908313393|   0.890599881538324|-0.81990426632908985333|
FICO  | 3767|    96.8441686198597101|    0.35881486257264444576|  1.0687880915052659|-0.50900921626903985416|
URI   | 3767|    72.5191776952923692|    0.33307968043093879639|  0.8637627563854969|-0.63585949756298143948|
DPZ   | 3767|    59.5563892800195325|    0.31589332228408741494|  1.0652902543449407|-0.47812896033643093595|
LRCX  | 3767|    55.6531080234541640|    0.31004116817482826100|  0.8849536917970353|-0.56845523739174692394|
APA   | 3767|-0.74389245796579612020|   -0.08709541553758724177| 0.08051465186453106|-0.96474382233641574416|
WBA   | 3767|-0.59174172675632295181|   -0.05816934585272964169|-0.03909278333990382|-0.87962975139962327373|
MOS   | 3767|-0.53135491687310084567|   -0.04943779446668224040| 0.08464705493522949|-0.90762166867332995090|
DVN   | 3767|-0.48807996039272431125|   -0.04380477179982831966|  0.1286436166143175|-0.93398225578078033541|
PCG   | 3767|-0.39889344064573466060|   -0.03347615057613576638| 0.17928293965470588|-0.94648037955018946223|
KHC   | 2383|-0.37344985196969774321|   -0.04823819662910566097|-0.04512567325621957|-0.76074992890455505465|
AMTM  |   62|-0.35038970086038810409|   -0.82680924822183995735| -1.4958080032803514|-0.43323354968985602266|
WBD   | 3767|-0.32515067389345871413|   -0.02596515436908650717|  0.1319920091946468|-0.91316163673278643172|
PARA  | 3767|-0.25192983526932561404|   -0.01923004365227817267|  0.1649624637625999|-0.90422563277443238409|
VTRS  | 3767|-0.22136594158802727975|   -0.01659919596735416782| 0.12711155666733093|-0.88241626344459591665|

/*These results do not allow us to say that AVGO was the best perfoming stock, 
 * because the starting dates of stocks are different. X only has two years of 
 * observations while AVGO has fifteen. What we can say is that AVGO had a greater
 * total return over its available dataset history than X.
 */


--Fairer cross-stock ranking with annualized_compound_return:
(SELECT symbol, n_obs, annualized_compound_return, final_cumulative_return, max_drawdown
 FROM stock_descriptive_stats
 ORDER BY annualized_compound_return DESC LIMIT 10)
UNION ALL
(SELECT symbol, n_obs, annualized_compound_return, final_cumulative_return, max_drawdown
 FROM stock_descriptive_stats
 ORDER BY annualized_compound_return ASC LIMIT 10);

symbol|n_obs|annualized_compound_return|final_cumulative_return|max_draw
------+-----+--------------------------+-----------------------+--------
GEV   |  184|        2.3444500851402361|     1.4145726149680591|-0.13603
CEG   |  735|    0.79969545458254539275|     4.5504791341496344|-0.27645
PLTR  | 1063|    0.65988233407241239960|     7.4789476896587168|-0.84615
AVGO  | 3767|    0.64761527431538439477| 1743.41629872783391383|-0.48299
TSLA  | 3645|    0.47048992996649643480|   263.3741610099025696|-0.73632
NVDA  | 3767|    0.47021567323407916052|   316.7466546938823876|-0.66335
CARR  | 1198|    0.44849015386175483259|     4.8208633510444073|-0.41297
TPL   | 3767|    0.40233928731802237133|   155.7547691857505045|-0.63077
CRWD  | 1392|    0.39327283369748483611|     5.2463794576710672|-0.67692
ANET  | 2654|    0.39301470518110528315|    31.8174538352272727|-0.52200
AMTM  |   62|   -0.82680924822183995735|-0.35038970086038810409|-0.43323
KVUE  |  411|   -0.12167279563226437232|-0.19070629120874638827|-0.35636
APA   | 3767|   -0.08709541553758724177|-0.74389245796579612020|-0.96474
WBA   | 3767|   -0.05816934585272964169|-0.59174172675632295181|-0.87962
MOS   | 3767|   -0.04943779446668224040|-0.53135491687310084567|-0.90762
KHC   | 2383|   -0.04823819662910566097|-0.37344985196969774321|-0.76074
SOLV  |  184|   -0.04471641870407780870|-0.03285089281031684784|-0.31458
DVN   | 3767|   -0.04380477179982831966|-0.48807996039272431125|-0.93398
PCG   | 3767|   -0.03347615057613576638|-0.39889344064573466060|-0.94648
WBD   | 3767|   -0.02596515436908650717|-0.32515067389345871413|-0.91316



(SELECT symbol, sharpe_ratio_naive, annualized_mean_return, annualized_volatility, max_drawdown
 FROM stock_descriptive_stats
 ORDER BY sharpe_ratio_naive DESC LIMIT 10)
UNION ALL
(SELECT symbol, sharpe_ratio_naive, annualized_mean_return, annualized_volatility, max_drawdown
 FROM stock_descriptive_stats
 ORDER BY sharpe_ratio_naive ASC LIMIT 10);
--sharpe_ratio: who won per unit of risk taken.

symbol|sharpe_ratio_naive  |annualized_mean_return     |annualized_volatility|max_drawdown           |
------+--------------------+---------------------------+---------------------+-----------------------+
GEV   |  2.7392083386766215|     1.32575321212263611892|  0.48399137568453077|-0.13603719010441557986|
CEG   |  1.5550217575103138|     0.68254603519495314852|  0.43893021554100414|-0.27645000831168471265|
AVGO  |   1.484695115545648|     0.57366916868238050556|  0.38638853369673026|-0.48299968253644506167|
CTAS  |  1.1881940315530195|     0.29819900410817347152|  0.25096827301717284|-0.48379696291654667412|
VLTO  |   1.164112300766488|     0.27132289700479881372|  0.23307278586967198|-0.13426517383618149676|
CARR  |  1.1608654886439034|     0.44173123171342742556|  0.38051887667833745|-0.41297029191966905710|
COST  |  1.1326175805866747|     0.22884996214049850468|  0.20205404371523042|-0.31402436218577808566|
NVDA  |  1.0735250079402974|     0.48798884165815281960|  0.45456681311451264|-0.66335090736239454953|
FICO  |  1.0687880915052659|     0.36382842015799128696|   0.3404121200916269|-0.50900921626903985416|
AJG   |  1.0658613085607018|     0.21693285283969159056|  0.20352821806866167|-0.37220269579838172742|
AMTM  | -1.4958080032803514|    -1.35070182438706361448|   0.9029914410304895|-0.43323354968985602266|
KVUE  | -0.3606618282562014|    -0.09537596701280093880|   0.2644470790655706|-0.35636360862038352727|
KHC   |-0.04512567325621957|-0.012187350331574222043792|   0.2700757562635249|-0.76074992890455505465|
WBA   |-0.03909278333990382|-0.012056431042245491442072|   0.3084055422049965|-0.87962975139962327373|
SOLV  |0.013172168982556175| 0.004179776331071262983544|   0.3173187602289734|-0.31458746601293014125|
APA   | 0.08051465186453106|     0.04035409220545736544|   0.5012018467564717|-0.96474382233641574416|
MOS   | 0.08464705493522949|     0.03487311591580637604|   0.4119826252961866|-0.90762166867332995090|
VTRS  | 0.12711155666733093|     0.04408928733760220628|   0.3468550656884028|-0.88241626344459591665|
DVN   |  0.1286436166143175|     0.05800142060015125032|  0.45086901415437924|-0.93398225578078033541|
WBD   |  0.1319920091946468|     0.05194070516266374456|  0.39351401254955903|-0.91316163673278643172|



SELECT sector, n_obs, annualized_mean_return, annualized_volatility, sharpe_ratio_naive, max_drawdown
FROM sector_performance_stats
ORDER BY sharpe_ratio_naive DESC;


sector                |n_obs|annualized_mean_return    |annualized_volatility|sharpe_ratio_naive|max_drawdown               |
----------------------+-----+--------------------------+---------------------+------------------+---------------------------+
Technology            | 3767|0.230294871055111257783864|  0.22358538616624982|1.0300086021001056|-0.343852079441359235985700|
Healthcare            | 3767|0.173435703201954978259860|    0.174286514041183|0.9951183208643041|-0.294702865103055631933278|
Consumer Cyclical     | 3767|0.206787496405081621407084|  0.21607912203551596|0.9569989661985616|-0.486566492364935368403428|
Industrials           | 3767|0.193403839466452028067864|   0.2027225750561272|0.9540320776455453|-0.405817434475767924727825|
Communication Services| 3767|0.180451766522961448946424|  0.19378793413309306| 0.931181641056288|-0.373539572706933423708195|
Consumer Defensive    | 3767|0.127590121837982782286784|  0.13744293111526876|0.9283134520099637|-0.242143754849366449191237|
Financial Services    | 3767|0.173064461063056253873532|  0.21686093449452445|0.7980435086957812|-0.435175258828523679286233|
Utilities             | 3767|0.131474140526941280380872|  0.17849288417046913|0.7365791703011381|-0.371000659855596866198465|
Real Estate           | 3767|0.140675627446893925396668|  0.20759713479511596|0.6776376156912333|-0.418172955240762358416126|
Basic Materials       | 3767|0.143451243906638800818924|  0.22742743871067236|0.6307560983841267|-0.415406847257848658565241|
Energy                | 3767|0.161239586919935431363092|  0.29951869006417003|0.5383289666677924|-0.715007912110437024427226|





-- 5.5 Sanity checks:

--one row per symbol:
SELECT COUNT(*) AS n_symbols FROM stock_descriptive_stats;

n_symbols|
---------+
      502|
      
      
-- confirming the number of sectors is the same as the og table:
SELECT COUNT(*) AS n_sectors 
FROM sector_performance_stats;
/*11*/


--confirm no positive max_drawdown:

(
SELECT
	'stock_descriptive_stats' as table_name,
	count(*) as positive_drawdowns
FROM STOCK_DESCRIPTIVE_STATS SDS 
WHERE SDS.MAX_DRAWDOWN > 0
)

UNION ALL

(
SELECT
	'sector_performance_stats',
	count(*) as positive_drawdowns
FROM sector_performance_stats
WHERE max_drawdown>0
)


-- standard deviations cannot be negative
SELECT COUNT(*)
FROM sql_track.stock_descriptive_stats
WHERE sample_std_return < 0
   OR pop_std_return < 0
   OR annualized_volatility < 0;
/*0*/



-- unexpected nulls in the final summary tables:
SELECT COUNT(*) as rows_with_any_null
FROM STOCK_DESCRIPTIVE_STATS SDS 
WHERE num_nulls(symbol,N_OBS,MEAN_RETURN,MEDIAN_RETURN,SAMPLE_STD_RETURN,
POP_STD_RETURN,MIN_RETURN,MAX_RETURN,SKEWNESS,EXCESS_KURTOSIS,ANNUALIZED_MEAN_RETURN ,
ANNUALIZED_VOLATILITY,SHARPE_RATIO_NAIVE,FINAL_CUMULATIVE_RETURN, ANNUALIZED_COMPOUND_RETURN,
MAX_DRAWDOWN)>0 


--How many symbols actually contribute to each sector:
SELECT sector, MIN(n) AS min_tickers_per_day, MAX(n) AS max_tickers_per_day, AVG(n) AS avg_tickers_per_day
FROM (
    SELECT c.sector, sf.date, COUNT(*) AS n
    FROM stock_features sf
    JOIN clean_sp500_companies c ON sf.symbol = c.symbol
    WHERE sf.simple_return IS NOT NULL
    GROUP BY c.sector, sf.date
) t
GROUP BY sector
ORDER BY (max(n) - min(n)) DESC;
