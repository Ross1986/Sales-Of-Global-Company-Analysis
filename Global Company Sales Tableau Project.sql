---Sales Of Global Company dataset exploration and RFM Analysts

----INSPECTING THE DATA----

SELECT *
FROM sales_data_sample;

----INSPECTING DISTINCT VALUES---

SELECT DISTINCT COUNTRY FROM sales_data_sample
SELECT DISTINCT CITY FROM sales_data_sample
SELECT DISTINCT TERRITORY FROM sales_data_sample;

SELECT DISTINCT YEAR_ID FROM sales_data_sample
SELECT DISTINCT MONTH_ID FROM sales_data_sample
SELECT DISTINCT QTR_ID FROM sales_data_sample;

SELECT DISTINCT PRODUCTLINE
FROM sales_data_sample;

SELECT DISTINCT PRODUCTCODE, PRODUCTLINE
FROM sales_data_sample;

SELECT DISTINCT DEALSIZE FROM sales_data_sample;


SELECT DISTINCT PRICEPERUNIT, PRODUCTLINE
FROM sales_data_sample
ORDER BY 1 DESC;

---ANALYSIS--

SELECT PRODUCTLINE, AVG(cast(PRICEPERUNIT as decimal)) AvgSalePrice
FROM sales_data_sample
GROUP BY PRODUCTLINE
order by 2 desc;


SELECT productline, SUM(cast(sales as decimal)) Revenue
FROM sales_data_sample
GROUP BY productline
order by 2 desc;

----Total revenue by country---

SELECT country, SUM(cast(sales as decimal)) TotalRevenue
FROM sales_data_sample
GROUP BY country
order by 2 desc;

----Total revenue by city---

SELECT CITY, SUM(cast(SALES as decimal)) TotalRevenue
FROM sales_data_sample
GROUP BY CITY
order by 2 desc;

----Total revenue per year---

SELECT YEAR_ID, SUM(cast(sales as decimal)) TotalRevenue
FROM sales_data_sample
GROUP BY YEAR_ID
order by 2 desc;

----Sales within the year 2005---

SELECT MONTH_ID, YEAR_ID, SALES
FROM sales_data_sample
WHERE YEAR_ID like '%2005%'
ORDER by 1 desc;

SELECT MAX(ORDERDATE)
FROM sales_data_sample
where YEAR_ID = 2005;

/*
We only have sales data for the first 5 months
of sales in 2005.
Data only collected untill 5/31/2005 
*/

----Revenue from each deal size---

SELECT DEALSIZE, SUM(cast(sales as decimal)) Revenue
FROM sales_data_sample
GROUP BY DEALSIZE
order by 2 desc;

----Looking at order status--

SELECT DISTINCT STATUS
FROM sales_data_sample

SELECT DEALSIZE, SUM(cast(sales as decimal)) Revenue
FROM sales_data_sample
WHERE STATUS = 'SHIPPED'
GROUP BY DEALSIZE
order by 2 desc;

/* Considering the status of the order, the revenues above maybe
incorrect */

----sales with Cancelled status---

SELECT *
FROM sales_data_sample
where status = 'Cancelled'

SELECT DEALSIZE, SUM(cast(sales as decimal)) Revenue
FROM sales_data_sample
WHERE STATUS = 'Cancelled'
GROUP BY DEALSIZE
order by 2 desc;


----looking at sales with resolved status---

SELECT *
FROM sales_data_sample
WHERE status = 'resolved'

SELECT *
FROM sales_data_sample
WHERE ORDERNUMBER = '10327'

/* Sales with resolved status do not show as shipped or cancelled*/

SELECT *
FROM sales_data_sample
where status = 'in process'

SELECT *
FROM sales_data_sample
WHERE ORDERNUMBER = '10424'

/* all the oreders with the "in process" status are in the last 3 days of may 2005
and may 2005 is where are data stops, therefor I will assume the order was shipped*/

/*Going forward I will only consider orders which do not have the status cancelled, 
below is an example using total revenue per year */

SELECT YEAR_ID, SUM(cast(sales as decimal)) TotalRevenue
FROM sales_data_sample
WHERE STATUS != 'Cancelled'
GROUP BY YEAR_ID
order by 2 desc;

----Looking at revenue per months---

SELECT MONTH_ID, SUM(cast(sales as decimal)) Revenue, COUNT(ORDERNUMBER) Frequency
FROM sales_data_sample
WHERE YEAR_ID = 2003
AND STATUS != 'Cancelled'
GROUP BY MONTH_ID
order by 2 desc;

SELECT MONTH_ID, SUM(cast(sales as decimal)) Revenue, COUNT(ORDERNUMBER) Frequency
FROM sales_data_sample
WHERE YEAR_ID = 2004
AND STATUS != 'Cancelled'
GROUP BY MONTH_ID
order by 2 desc;

----November was the best month of sales in 2003 and 2004---

SELECT MONTH_ID, PRODUCTLINE, SUM(cast(sales as decimal)) Revenue, COUNT(ORDERNUMBER) Frequency
FROM sales_data_sample
WHERE STATUS != 'Cancelled'
AND MONTH_ID = 11
GROUP BY MONTH_ID, PRODUCTLINE
order by 3 desc;

---Classic cars were the best selling product in november---


----Revanue for each ProductLine---

SELECT PRODUCTLINE, SUM(cast(sales as decimal)) Revenue
FROM sales_data_sample
WHERE STATUS != 'cancelled'
GROUP BY PRODUCTLINE;

----Running total of sales per country---

SELECT COUNTRY, ORDERDATE, SALES,   
SUM(CONVERT(INT,SALES)) OVER (PARTITION BY COUNTRY ORDER BY ORDERDATE 
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rolling_revenue
FROM sales_data_sample
WHERE STATUS != 'cancelled'

----Running total of sales per city---

SELECT CITY, ORDERDATE, SALES,   
SUM(CONVERT(INT,SALES)) OVER (PARTITION BY CITY ORDER BY ORDERDATE 
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rolling_revenue
FROM sales_data_sample
WHERE STATUS != 'cancelled'

----Sales of product line per year---

SELECT YEAR_ID, PRODUCTLINE, SUM(cast(sales as decimal)) Revenue
FROM sales_data_sample
WHERE STATUS != 'cancelled'
GROUP BY YEAR_ID, PRODUCTLINE
ORDER BY YEAR_ID;

-----Deal size distribution---

SELECT DEALSIZE, YEAR_ID, SUM(cast(sales as decimal)) Revenue
FROM sales_data_sample
WHERE STATUS != 'cancelled'
GROUP BY DEALSIZE, YEAR_ID
ORDER BY YEAR_ID;

---RFM analysts (Recency,Frequency,Monetary)---

DROP TABLE IF EXISTS #rfm
;with rfm as
(
Select 
	CUSTOMERNAME, 
	SUM(sales) MonetaryValue, 
	AVG(sales) AvgMonetaryValue, 
	COUNT(ORDERNUMBER) Frequency,
	MAX(ORDERDATE) LastOrderDate, 
	DATEDIFF(DD, MAX(ORDERDATE), '2005/5/31') Recency
FROM sales_data_sample
WHERE STATUS != 'cancelled'
GROUP BY CUSTOMERNAME
),
-- Define another CTE named rfm_calc and Divide customers into 4 groups based on recency, frequency and monetary value
rfm_calc as
(
SELECT R.*,
	NTILE(4) OVER (order by Recency desc) rfm_recency,
	NTILE(4) OVER (order by Frequency) rfm_Frequency,
	NTILE(4) OVER (order by MonetaryValue) rfm_monetary
FROM rfm R
)
-- Calculate the RFM cell for each customer and Storing results in #rfm table
select 
	c.*, rfm_recency+ rfm_frequency+ rfm_monetary as rfm_cell,
	cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary  as varchar)rfm_cell_string
into #rfm
from rfm_calc c

-- Assign a segment name to each RFM cell, to easily identify customer type
select CUSTOMERNAME , rfm_recency, rfm_frequency, rfm_monetary,
	case 
		when rfm_cell_string in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141) then 'lost customer'
		
		when rfm_cell_string in (311, 411, 331) then 'new customers'
		when rfm_cell_string in (222, 223, 233, 322) then 'infrequent customers'
		when rfm_cell_string in (323, 333,321, 422, 332, 432) then 'frequent customers'
		when rfm_cell_string in (433, 434, 443, 444) then 'frequent big spenders'
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144) then 'big spenders with no recent activity'
	end rfm_segment

from #rfm
