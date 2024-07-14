SELECT TOP (1000) [CustomerID]
      ,[FirstName]
      ,[LastName]
      ,[DateOfBirth]
      ,[Contact_Email]
      ,[Contact_Phone]
      ,[Account_Type]
      ,[Account_Open_Date]
      ,[Account_Number]
      ,[Employment_Status]
  FROM [NovaTrust Bank].[dbo].[Customers]

-- EDA
-- Total Number of Customers
SELECT FORMAT(COUNT(Account_Number), 'N0') as Total_Customers
FROM dbo.Customers;

-- Check for Null Values
select *
from [dbo].[Customers] c
where c.Account_Number is null
or c.Account_Open_Date is null
or c.Account_Type is null
or c.Contact_Email is null
or c.Contact_Phone is null
or c.CustomerID is null
or c.DateOfBirth is null
or c.Employment_Status is null
or c.FirstName is null
or c.LastName is null

--Check for duplicate
select Account_Number, CustomerID, Contact_Email, COUNT(*) as Counts
from [dbo].[Customers]
group by Account_Number, CustomerID, Contact_Email
having count(*) > 1

-- Check employment status
select distinct employment_status
from dbo.Customers

select employment_status, count (*)
from dbo.Customers
group by Employment_Status

-- Explore Transaction Table
select top 10 *
from [dbo].[Transaction]

--Check for most recent transaction date
select MAX(transactiondate) MaxDate
from dbo.[Transaction]

--Check for oldest transaction date
select min(transactiondate) MinDate
from dbo.[Transaction]

-- Check for Max & Min Transaction Amount
SELECT 
    FORMAT(MIN(Transaction_Amount), 'N0') AS MinTransaction, 
    FORMAT(MAX(Transaction_Amount), 'N0') AS MaxTransaction
FROM dbo.[Transaction];


-- Distribution of Debit and Credit 
SELECT 
    transactiontype, 
    FORMAT(COUNT(*), 'N0')
FROM dbo.[Transaction]
GROUP BY transactiontype;

--DATA EXTRACTION
CREATE PROCEDURE sp_GetCustomerSegments
	@EmploymentStatus NVARCHAR(50),
	@DateCriteria DATE,
	@TransDescription NVARCHAR(50)
AS
BEGIN
-- Extract student customers with salaries
WITH Salaries AS(
select c.Account_Number,
			t.TransactionID,
			t.TransactionDate,
			t.Transaction_Amount,
			t.TransDescription
from dbo.[Customers] as c
inner join dbo.[Transaction] as t
on c.Account_Number = t.AccountNumber
where c.Employment_Status = @EmploymentStatus
AND lower(t.TransDescription) like '%' + @TransDescription + '%'
AND t.TransactionDate >= DATEADD(MONTH, -12, @DateCriteria)
AND t.TransactionType = 'Credit'
),

--RFM Modeling (Recency, Frequency and Monetary Value)

--Calculate the RFM Values
RFM AS(
SELECT Account_Number,
		MAX(TransactionDate) AS LastTransactionDate,
		DATEDIFF(MONTH, MAX(TransactionDate), @DateCriteria) as Recency,
		COUNT(TransactionID) AS Frequency,
		AVG(Transaction_Amount) AS Monetary_Value
FROM Salaries
group by Account_Number
having AVG(Transaction_Amount) >= 200000
),
-- select MIN(Monetary_Value) AS MinSalary,
--	   AVG(Monetary_Value) AS AvgSalary,
--	   MAX(Monetary_Value) AS MaxSalary
--from RFM
--Assign RFM Scores to each customer
RFM_Scores AS(
SELECT Account_Number,
	   LastTransactionDate,
	   Recency,
	   Frequency,
	   Monetary_Value,
	   CASE
			 WHEN Recency = 0 THEN 10
			 WHEN Recency < 3 THEN 7
			 WHEN Recency < 5 THEN 4
			 ELSE 1
		END AS R_Score,
		CASE
			 WHEN Frequency = 12 THEN 10
			 WHEN Frequency >= 9 THEN 7
			 WHEN Frequency >= 6 THEN 4
			 ELSE 1
		END AS F_Score,
		CASE
			 WHEN Monetary_Value > 600000 THEN 10
			 WHEN Monetary_Value > 400000 THEN 7
			 WHEN Monetary_Value BETWEEN 300000 AND 400000 THEN 4
			 ELSE 1
		END AS M_Score
FROM RFM
),
-- Segment each customers based on their RFM
Segment as(
select Account_Number,
	 LastTransactionDate,
	 Recency,
	 Frequency,
	 Monetary_Value,
	 cast((R_Score + F_Score + M_Score) as float)/30 AS RFM_Segment, --Calculate RFM Scores``
	 CASE  -- group salaries based on Monetary values
			 WHEN Monetary_Value > 600000 THEN 'Above 600k'
			 WHEN Monetary_Value between 400000 and 600000 THEN '400k-600k'
			 WHEN Monetary_Value BETWEEN 300000 AND 400000 THEN '300k-400k'
			 ELSE '200k-300k'
		END AS SalaryRange,
		-- Customer Segmentation
	    case
			when cast((R_Score + F_Score + M_Score) as float)/30 > 0.8 then 'Tier 1 Customers'
			when cast((R_Score + F_Score + M_Score) as float)/30 >= 0.6 then 'Tier 2 Customers'
			when cast((R_Score + F_Score + M_Score) as float)/30 >= 0.5 then 'Tier 3 Customers'
			else 'Tier 4 Customers'
		END AS Segments

from RFM_Scores)

-- Retrieve final values 
select S.Account_Number,
	   C.Contact_Email,
	   LastTransactionDate,
	   Recency AS MonthlySinceLastSalary,
	   Frequency AS SalariesReceived,
	   Monetary_Value AS AverageSalary,
	   SalaryRange,
	   Segments
from Segment S
LEFT JOIN dbo.Customers C
ON S.Account_Number = C.Account_Number

END;

--To call the stored procedure, use the following SQL statement:
EXEC dbo.sp_GetCustomerSegments
	@EmploymentStatus = 'Student',
	@DateCriteria = '2023-08-31',
	@TransDescription = 'Salary';

 
