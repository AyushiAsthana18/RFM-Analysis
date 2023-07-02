/*
RFM Analysis | Value Segmentation | Customer Segmentation

Skills used: Joins, Unions, CTE's, Temp Tables,Views, Windows Functions, Aggregate Functions, CASE, Converting Data Types

--==> This means insights/inferences
*/

--Lets have a look at the data
Select top 10 * FROM PortfolioProjects..['Sales Orders Data'] 

--Get the range of dates for the order data
Select 
	MAX(OrderDate) AS MAX, 
	MIN(OrderDate) AS MIN  
FROM PortfolioProjects..['Sales Orders Data'] 

--==> Data is from May 2018 to Dec 2020

--Since its a bit out-dated data, so lets declare a today variable for better calculations
DECLARE @today_date AS DATE = '2021-01-31';

--Calculating the RFM
SELECT 
	_CustomerID AS CustomerID
	,Datediff(day,MAX(OrderDate),@today_date) AS Recency
	,Count(OrderNumber) AS Frequency
	,Sum([Unit Price] - ([Unit Price]*[Discount Applied] - [Unit Cost])) AS Monetary_Value
FROM PortfolioProjects..['Sales Orders Data'] 
GROUP BY _CustomerID

---------------------------------------------------------------------------------------------------------------------------------
---Lets understand the distribution of RFM Values by Five Number Summary

--Calculate RFM Values
DECLARE @today_date AS DATE = '2021-01-01';
WITH RFM_CALC AS (
	SELECT 
		_CustomerID AS CustomerID
		,Datediff(day,MAX(OrderDate),@today_date) AS Recency
		,Count(OrderNumber) AS Frequency
		,CAST(Sum([Unit Price] - ([Unit Price]*[Discount Applied] - [Unit Cost])) AS decimal(16,2)) AS Monetary_Value
	FROM PortfolioProjects..['Sales Orders Data'] 
	GROUP BY _CustomerID
),
--Minimum & Maximum Values
MinMax AS ( 
	Select 
		Min(Recency) AS Rmin,
		Max(Recency) AS Rmax,
		Min(Frequency) AS Fmin,
		Max(Frequency) AS Fmax,
		Min(Monetary_Value) AS Mmin,
		Max(Monetary_Value) AS Mmax
	FROM RFM_CALC 
)
--Fivenumber Summary for Monetary Value
SELECT DISTINCT
	'Monetary Value' AS RFM,
	M.Mmin AS Min,
	PERCENTILE_DISC(0.25) WITHIN GROUP (ORDER BY Monetary_Value) OVER () as Q1,
	PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY Monetary_Value) OVER () as Median,
	PERCENTILE_DISC(0.75) WITHIN GROUP (ORDER BY Monetary_Value) OVER () as Q3,
	M.Mmax AS Max
FROM MinMax M JOIN RFM_CALC ON 1=1
UNION
--Fivenumber Summary for Frequency
SELECT DISTINCT
	'Frequency' AS RFM,
	F.Fmin AS Min,
	PERCENTILE_DISC(0.25) WITHIN GROUP (ORDER BY Frequency) OVER () as Q1,
	PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY Frequency) OVER () as Median,
	PERCENTILE_DISC(0.75) WITHIN GROUP (ORDER BY Frequency) OVER () as Q3,
	F.Fmax AS Max
FROM MinMax F JOIN RFM_CALC ON 1=1
UNION
--Fivenumber Summary for Recency
SELECT DISTINCT
	'Recency' AS RFM,
	R.Rmin AS Min,
	PERCENTILE_DISC(0.25) WITHIN GROUP (ORDER BY Recency) OVER () as Q1,
	PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY Recency) OVER () as Median,
	PERCENTILE_DISC(0.75) WITHIN GROUP (ORDER BY Recency) OVER () as Q3,
	R.Rmax AS MAX
FROM MinMax R JOIN RFM_CALC ON 1=1

--==> Data is righly-skewed

---------------------------------------------------------------------------------------------------------------------------------
----lets partition RFM Values on the scale of 1 to 5 scores as the ranges of RFM are not very big

--Lets calculate RFM Values
DECLARE @today_date AS DATE = '2021-01-01';
WITH RFM_CALC AS (
	SELECT 
		_CustomerID AS CustomerID
		,Datediff(day,MAX(OrderDate), @today_date) AS Recency
		,Count(OrderNumber) AS Frequency
		,CAST(Sum([Unit Price] - ([Unit Price]*[Discount Applied] - [Unit Cost])) AS decimal(16,2)) AS Monetary_Value
	FROM PortfolioProjects..['Sales Orders Data'] 
	GROUP BY _CustomerID
)
-- Calculate RMF Scores
SELECT 
	CustomerID
	,Recency
	,Frequency
	,Monetary_Value
	,NTILE(5) OVER(ORDER BY Recency DESC) AS Recency_Score
	,NTILE(5) OVER(ORDER BY Frequency ASC) AS Frequency_Score
	,NTILE(5) OVER(ORDER BY Monetary_Value ASC) AS Monetary_Score
FROM 
	RFM_CALC
ORDER BY 
	CustomerID

---------------------------------------------------------------------------------------------------------------------------------
----Lets store the above result as a temporary table for further analytics

--Lets calculate RFM Values
WITH RFM_CALC AS (
	SELECT 
		_CustomerID AS CustomerID
		,Datediff(day,MAX(OrderDate),'2021-01-01') AS Recency
		,Count(OrderNumber) AS Frequency
		,CAST(Sum([Unit Price] - ([Unit Price]*[Discount Applied] - [Unit Cost])) AS decimal(16,2)) AS Monetary_Value
	FROM PortfolioProjects..['Sales Orders Data'] 
	GROUP BY _CustomerID
)
-- Calculate RMF Scores
SELECT 
	CustomerID
	,Recency
	,Frequency
	,Monetary_Value
	,NTILE(5) OVER(ORDER BY Recency DESC) AS Recency_Score
	,NTILE(5) OVER(ORDER BY Frequency ASC) AS Frequency_Score
	,NTILE(5) OVER(ORDER BY Monetary_Value ASC) AS Monetary_Score
INTO #RFM_Value_Score 
FROM 
	RFM_CALC

---------------------------------------------------------------------------------------------------------------------------------
----Lets check the Ranges of RFM by Scores using the temp table created above

WITH Recency_Range AS ( 
	Select 
		row_number() Over(Order by Recency_Score) AS I,
		Recency_Score,
		Min(Recency) AS Rmin,
		Max(Recency) AS Rmax
	FROM #RFM_Value_Score
	GROUP BY Recency_Score
),
Frequency_Range AS ( 
	Select
		row_number() Over(Order by Frequency_Score) AS I,
		Frequency_Score,
		Min(Frequency) AS Fmin,
		Max(Frequency) AS Fmax
	FROM #RFM_Value_Score
	GROUP BY Frequency_Score
),
Monetary_Range AS ( 
	Select
		row_number() Over(Order by Monetary_Score) AS I,
		Monetary_Score,
		Min(Monetary_Value) AS Mmin,
		Max(Monetary_Value) AS Mmax
	FROM #RFM_Value_Score
	GROUP BY Monetary_Score
)
Select 
	Recency_Score,Rmin,Rmax,
	Frequency_Score,Fmin,Fmax,
	Monetary_Score,Mmin,Mmax
FROM Recency_Range R
Join Frequency_Range F
On R.I = F.I
Join Monetary_Range M
On R.I = M.I
---------------------------------------------------------------------------------------------------------------------------------
----Create the Value Segments & Customer Segments based on RFM Score & Average RFM Score & store as a View for further Analytics & Visualization

--As we can't use the variable directly in the View, Lets create a Function to get the Recency``1
CREATE FUNCTION GetRecency(@today_date DATE, @orderDate DATE)
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(day, @orderDate, @today_date);
END;

--Create a View for RFM Values & RFM Scores
DROP VIEW IF EXISTS RFM_View;
CREATE VIEW RFM_View AS
--Calculate RFM Values
WITH RFM_CALC AS (
    SELECT 
        _CustomerID AS CustomerID,
        dbo.GetRecency('2021-01-01', MAX(OrderDate)) AS Recency,
        COUNT(OrderNumber) AS Frequency,
        CAST(SUM([Unit Price] - ([Unit Price]*[Discount Applied] - [Unit Cost])) AS decimal(16,2)) AS Monetary_Value
    FROM PortfolioProjects..['Sales Orders Data'] 
    GROUP BY _CustomerID
),
-- Calculate RMF Scores
RFM_SCORES AS (
SELECT 
	CustomerID
	,Recency
	,Frequency
	,Monetary_Value
	,NTILE(5) OVER(ORDER BY Recency DESC) AS Recency_Score
	,NTILE(5) OVER(ORDER BY Frequency ASC) AS Frequency_Score
	,NTILE(5) OVER(ORDER BY Monetary_Value ASC) AS Monetary_Score
FROM RFM_CALC
),
-- Calculate Avg RFM Score
RFM_AVG_SCORE AS (
	Select
		CustomerID
		,CONCAT_WS('-',Recency_Score,Frequency_Score,Monetary_Score) AS R_F_M
		,CAST((CAST(Recency_Score AS Float) + Frequency_Score + Monetary_Score)/3 AS DECIMAL(16,2)) AS Avg_RFM_Score
	FROM RFM_SCORES
)	 
Select 
	T1.CustomerID
	,Recency,Frequency,Monetary_Value
	,Recency_Score,Frequency_Score,Monetary_Score
	,R_F_M,Avg_RFM_Score
FROM RFM_SCORES T1
JOIN RFM_AVG_SCORE T2
ON T1.CustomerID = T2.CustomerID

SELECT * FROM RFM_View ORDER BY Avg_RFM_Score

----Create a View for the Customer Segments & Value Segments using the View "RFM_View" 
DROP VIEW IF EXISTS Customer_Segmentaion;

CREATE VIEW Customer_Segmentaion AS
Select *
	, CASE WHEN Avg_RFM_Score >= 4 THEN 'High Value'
			WHEN Avg_RFM_Score >= 2.5 AND Avg_RFM_Score < 4 THEN 'Mid Value'
			WHEN Avg_RFM_Score > 0 AND Avg_RFM_Score < 2.5 THEN 'Low Value'
	END AS Value_Seg --Value Segment
	, CASE WHEN Frequency_Score >= 4 and Recency_Score >= 4 and Monetary_Score >= 4 THEN 'VIP'
			WHEN Frequency_Score >= 3 and Monetary_Score < 4 THEN 'Regular'
			WHEN Recency_Score <= 3 and Recency_Score > 1 THEN 'Dormat'
			WHEN Recency_Score = 1 THEN 'Churned'
			WHEN Recency_Score >= 4 and Frequency_Score <= 4 THEN 'New Customer'
	END AS Cust_Seg --Customer Segment
FROM RFM_View 

---------------------------------------------------------------------------------------------------------------------------------
--*******************************************************************************************************************************
----Insights

--Distribution of Customers by Value Segment
SELECT 
	Value_Seg, 
	COUNT(CustomerID) AS Customer_Count
FROM Customer_Segmentaion 
GROUP BY Value_Seg 
ORDER BY Customer_Count

--==> We have highest Mid Value Customers (42%) 

--Distribution of Customers by Customer Segment
SELECT 
	Cust_Seg,
	COUNT(CustomerID) AS Customer_Count
FROM Customer_Segmentaion 
GROUP BY Cust_Seg 
ORDER BY Customer_Count

--==>Company have highest Dormat Customers (34%), 20% Regular Customers, 18% New Custoers, 16% Churned Customers & Lowest VIP Customers (12%)

--Distribution of customers across different RFM customer segments within each value segment
SELECT 
	Value_Seg,
	Cust_Seg,
	COUNT(CustomerID) AS Customer_Count
FROM Customer_Segmentaion 
GROUP BY Cust_Seg,Value_Seg
ORDER BY Value_Seg,Customer_Count DESC

--==>Churned Customers are equally distributed among mid value & low value customers.
--==>Domart Customes are distributed across all the value segments, low value segment have the maximum dormat customers.
--==>Regular Customers are also distributed across all the value segments but majorly the Mid Value segment.
--==>New Customers are als distrubted across all the value segments but majorly low value & mid value segment.
--==>55% of High Value segment customers are the VIP Customer

 




