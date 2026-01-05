-- Step 1: Create the first supporting stored procedure
CREATE OR ALTER PROCEDURE dbo.LongRunningQuery1
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Starting LongRunningQuery1 at: ' + CONVERT(VARCHAR, GETDATE(), 120);
    
    -- Complex query with multiple joins and calculations that takes 5-10 minutes
    WITH SalesAnalysis AS (
        SELECT 
            YEAR(soh.OrderDate) AS OrderYear,
            MONTH(soh.OrderDate) AS OrderMonth,
            c.CustomerID,
            c.AccountNumber,
            c.PersonID,
            p.FirstName,
            p.LastName,
            sod.ProductID,
            p2.Name AS ProductName,
            psc.Name AS SubCategoryName,
            pc.Name AS CategoryName,
            sod.OrderQty,
            sod.UnitPrice,
            sod.LineTotal,
            soh.TotalDue,
            soh.Freight,
            soh.TaxAmt,
            soh.SubTotal,
            sp.Name AS TerritoryName,
            --cr.Name AS CurrencyName,
            ROW_NUMBER() OVER (PARTITION BY YEAR(soh.OrderDate), MONTH(soh.OrderDate) 
                               ORDER BY soh.TotalDue DESC) AS SalesRank
        FROM Sales.SalesOrderHeader soh
        INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
        INNER JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
        LEFT JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
        INNER JOIN Production.Product p2 ON sod.ProductID = p2.ProductID
        INNER JOIN Production.ProductSubcategory psc ON p2.ProductSubcategoryID = psc.ProductSubcategoryID
        INNER JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
        INNER JOIN Sales.SalesTerritory sp ON soh.TerritoryID = sp.TerritoryID
        INNER JOIN Sales.CurrencyRate cr ON soh.CurrencyRateID = cr.CurrencyRateID
        WHERE soh.OrderDate BETWEEN '2011-01-01' AND '2014-12-31'
    ),
    MonthlyAggregates AS (
        SELECT 
            OrderYear,
            OrderMonth,
            COUNT(DISTINCT CustomerID) AS UniqueCustomers,
            COUNT(DISTINCT ProductID) AS UniqueProducts,
            SUM(OrderQty) AS TotalQuantity,
            SUM(LineTotal) AS TotalSales,
            AVG(LineTotal) AS AvgOrderValue,
            MAX(LineTotal) AS MaxOrderValue,
            SUM(Freight) AS TotalFreight,
            SUM(TaxAmt) AS TotalTax
        FROM SalesAnalysis
        GROUP BY OrderYear, OrderMonth
    ),
    CustomerLifetimeValue AS (
        SELECT 
            c.CustomerID,
            c.AccountNumber,
            FirstName,
            LastName,
            COUNT(DISTINCT Year(OrderDate) * 100 + Month(Orderdate)) AS ActiveMonths,
            SUM(TotalDue) AS LifetimeValue,
            AVG(TotalDue) AS AvgOrderValue,
            MAX(TotalDue) AS MaxOrderValue,
            MIN(soh.OrderDate) AS FirstOrderDate,
            MAX(soh.OrderDate) AS LastOrderDate,
            DATEDIFF(DAY, MIN(soh.OrderDate), MAX(soh.OrderDate)) AS CustomerLifespanDays
        FROM Sales.SalesOrderHeader soh
        INNER JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
        LEFT JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
        GROUP BY c.CustomerID, c.AccountNumber, FirstName, LastName
    )
    SELECT 
        sa.OrderYear,
        sa.OrderMonth,
        sa.TerritoryName,
        sa.CategoryName,
        sa.SubCategoryName,
        ma.UniqueCustomers,
        ma.UniqueProducts,
        ma.TotalQuantity,
        ma.TotalSales,
        ma.AvgOrderValue,
        ma.MaxOrderValue,
        ma.TotalFreight,
        ma.TotalTax,
        clv.LifetimeValue,
        clv.AvgOrderValue AS CustomerAvgOrderValue,
        clv.CustomerLifespanDays,
        RANK() OVER (PARTITION BY sa.OrderYear, sa.OrderMonth ORDER BY ma.TotalSales DESC) AS TerritoryRank
    FROM SalesAnalysis sa
    INNER JOIN MonthlyAggregates ma ON sa.OrderYear = ma.OrderYear AND sa.OrderMonth = ma.OrderMonth
    INNER JOIN CustomerLifetimeValue clv ON sa.CustomerID = clv.CustomerID
    WHERE sa.SalesRank <= 100
    ORDER BY sa.OrderYear, sa.OrderMonth, ma.TotalSales DESC
    OPTION (MAXDOP 1, LOOP JOIN, MERGE JOIN, HASH JOIN);
    
    PRINT 'Completed LongRunningQuery1 at: ' + CONVERT(VARCHAR, GETDATE(), 120);
END;
GO

-- Step 2: Create the second supporting stored procedure
CREATE OR ALTER PROCEDURE dbo.LongRunningQuery2
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Starting LongRunningQuery2 at: ' + CONVERT(VARCHAR, GETDATE(), 120);
    
    -- Another complex query with cross joins and recursive CTE
    DECLARE @StartDate DATE = '2011-01-01';
    DECLARE @EndDate DATE = '2014-12-31';
    
    -- Create a numbers table on the fly
    WITH Numbers AS (
        SELECT TOP 1000000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_columns a 
        CROSS JOIN sys.all_columns b
    ),
    DateSeries AS (
        SELECT 
            DATEADD(DAY, n-1, @StartDate) AS Date,
            YEAR(DATEADD(DAY, n-1, @StartDate)) AS Year,
            MONTH(DATEADD(DAY, n-1, @StartDate)) AS Month,
            DATEPART(QUARTER, DATEADD(DAY, n-1, @StartDate)) AS Quarter,
            DATEPART(WEEK, DATEADD(DAY, n-1, @StartDate)) AS WeekNumber,
            DATEPART(WEEKDAY, DATEADD(DAY, n-1, @StartDate)) AS Weekday
        FROM Numbers
        WHERE DATEADD(DAY, n-1, @StartDate) <= @EndDate
    ),
    ProductSalesTrend AS (
        SELECT 
            p.ProductID,
            p.Name AS ProductName,
            pc.Name AS CategoryName,
            psc.Name AS SubCategoryName,
            ds.Year,
            ds.Quarter,
            ds.Month,
            COUNT(DISTINCT soh.SalesOrderID) AS OrderCount,
            SUM(sod.OrderQty) AS TotalQuantity,
            SUM(sod.LineTotal) AS TotalSales,
            AVG(sod.UnitPrice) AS AvgUnitPrice,
            SUM(sod.LineTotal - (sod.OrderQty * p.StandardCost)) AS EstimatedProfit,
            SUM(soh.TaxAmt) AS TotalTax,
            SUM(soh.Freight) AS TotalFreight,
            COUNT(DISTINCT soh.CustomerID) AS UniqueCustomers,
            COUNT(DISTINCT soh.SalesPersonID) AS UniqueSalesPeople
        FROM DateSeries ds
        CROSS JOIN Production.Product p
        LEFT JOIN Sales.SalesOrderDetail sod ON p.ProductID = sod.ProductID
        LEFT JOIN Sales.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID 
            AND YEAR(soh.OrderDate) = ds.Year 
            AND MONTH(soh.OrderDate) = ds.Month
            AND soh.OrderDate BETWEEN @StartDate AND @EndDate
        LEFT JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
        LEFT JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
        WHERE p.ProductID BETWEEN 1 AND 1000  -- Limit to first 1000 products for demonstration
        GROUP BY 
            p.ProductID,
            p.Name,
            pc.Name,
            psc.Name,
            ds.Year,
            ds.Quarter,
            ds.Month
    ),
    MovingAverages AS (
        SELECT *,
            AVG(TotalSales) OVER (
                PARTITION BY ProductID 
                ORDER BY Year, Month 
                ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
            ) AS SalesMovingAvg4Month,
            AVG(TotalQuantity) OVER (
                PARTITION BY ProductID 
                ORDER BY Year, Month 
                ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
            ) AS QuantityMovingAvg7Month,
            SUM(TotalSales) OVER (
                PARTITION BY ProductID, Year 
                ORDER BY Month
            ) AS YTDSales,
            LAG(TotalSales, 1) OVER (
                PARTITION BY ProductID 
                ORDER BY Year, Month
            ) AS PreviousMonthSales,
            LAG(TotalSales, 12) OVER (
                PARTITION BY ProductID 
                ORDER BY Year, Month
            ) AS PreviousYearSales
        FROM ProductSalesTrend
    ),
    YearOverYearGrowth AS (
        SELECT 
            ProductID,
            ProductName,
            CategoryName,
            SubCategoryName,
            Year,
            Month,
            OrderCount,
            TotalQuantity,
            TotalSales,
            AvgUnitPrice,
            EstimatedProfit,
            TotalTax,
            TotalFreight,
            UniqueCustomers,
            UniqueSalesPeople,
            SalesMovingAvg4Month,
            QuantityMovingAvg7Month,
            YTDSales,
            PreviousMonthSales,
            PreviousYearSales,
            CASE 
                WHEN PreviousMonthSales > 0 
                THEN ((TotalSales - PreviousMonthSales) / PreviousMonthSales) * 100 
                ELSE NULL 
            END AS MonthOverMonthGrowth,
            CASE 
                WHEN PreviousYearSales > 0 
                THEN ((TotalSales - PreviousYearSales) / PreviousYearSales) * 100 
                ELSE NULL 
            END AS YearOverYearGrowth,
            RANK() OVER (PARTITION BY Year, Month ORDER BY TotalSales DESC) AS SalesRank,
            NTILE(4) OVER (PARTITION BY Year, Month ORDER BY TotalSales DESC) AS SalesQuartile
        FROM MovingAverages
    )
    SELECT 
        yoy.*,
        CASE 
            WHEN yoy.YearOverYearGrowth > 20 THEN 'High Growth'
            WHEN yoy.YearOverYearGrowth BETWEEN 10 AND 20 THEN 'Moderate Growth'
            WHEN yoy.YearOverYearGrowth BETWEEN 0 AND 10 THEN 'Slow Growth'
            WHEN yoy.YearOverYearGrowth < 0 THEN 'Declining'
            ELSE 'No Previous Data'
        END AS GrowthCategory,
        CASE 
            WHEN yoy.SalesQuartile = 1 THEN 'Top 25%'
            WHEN yoy.SalesQuartile = 2 THEN '25-50%'
            WHEN yoy.SalesQuartile = 3 THEN '50-75%'
            WHEN yoy.SalesQuartile = 4 THEN 'Bottom 25%'
        END AS PerformanceQuartile,
        AVG(yoy.TotalSales) OVER (PARTITION BY yoy.CategoryName, yoy.Year, yoy.Month) AS CategoryAvgSales,
        SUM(yoy.TotalSales) OVER (PARTITION BY yoy.CategoryName, yoy.Year) AS CategoryYTDSales
    FROM YearOverYearGrowth yoy
    WHERE yoy.TotalSales IS NOT NULL
    ORDER BY yoy.Year DESC, yoy.Month DESC, yoy.TotalSales DESC
    OPTION (MAXDOP 1, FORCE ORDER, LOOP JOIN, MERGE JOIN, HASH JOIN);
    
    PRINT 'Completed LongRunningQuery2 at: ' + CONVERT(VARCHAR, GETDATE(), 120);
END;
GO

-- Step 3: Create the main stored procedure that waits and calls the other two
CREATE OR ALTER PROCEDURE dbo.MasterLongRunningProcedure
    @WaitSeconds INT = 5,
    @RunQuery1 BIT = 1,
    @RunQuery2 BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @EndTime DATETIME;
    DECLARE @Message NVARCHAR(MAX);
    
    PRINT '========================================';
    PRINT 'Starting MasterLongRunningProcedure at: ' + CONVERT(VARCHAR, @StartTime, 120);
    PRINT 'Parameters:';
    PRINT '  WaitSeconds: ' + CAST(@WaitSeconds AS VARCHAR(10));
    PRINT '  RunQuery1: ' + CAST(@RunQuery1 AS VARCHAR(10));
    PRINT '  RunQuery2: ' + CAST(@RunQuery2 AS VARCHAR(10));
    PRINT '========================================';
    
    -- Phase 1: Initial wait
    SET @Message = 'Phase 1: Waiting for ' + CAST(@WaitSeconds AS VARCHAR(10)) + ' seconds...';
    PRINT @Message;
    
    WAITFOR DELAY @WaitSeconds;
    
    -- Phase 2: Run first stored procedure if requested
    IF @RunQuery1 = 1
    BEGIN
        PRINT 'Phase 2: Executing LongRunningQuery1...';
        PRINT '----------------------------------------';
        
        EXEC dbo.LongRunningQuery1;
        
        SET @EndTime = GETDATE();
        SET @Message = 'LongRunningQuery1 completed. Duration: ' 
            + CAST(DATEDIFF(SECOND, @StartTime, @EndTime) AS VARCHAR(10)) 
            + ' seconds';
        PRINT @Message;
    END
    ELSE
    BEGIN
        PRINT 'Phase 2: Skipping LongRunningQuery1 as requested.';
    END
    
    -- Phase 3: Run second stored procedure if requested
    IF @RunQuery2 = 1
    BEGIN
        PRINT '';
        PRINT 'Phase 3: Executing LongRunningQuery2...';
        PRINT '----------------------------------------';
        
        DECLARE @Query2StartTime DATETIME = GETDATE();
        
        EXEC dbo.LongRunningQuery2;
        
        SET @EndTime = GETDATE();
        SET @Message = 'LongRunningQuery2 completed. Duration: ' 
            + CAST(DATEDIFF(SECOND, @Query2StartTime, @EndTime) AS VARCHAR(10)) 
            + ' seconds';
        PRINT @Message;
    END
    ELSE
    BEGIN
        PRINT 'Phase 3: Skipping LongRunningQuery2 as requested.';
    END
    
    -- Final summary
    SET @EndTime = GETDATE();
    PRINT '';
    PRINT '========================================';
    PRINT 'MasterLongRunningProcedure completed at: ' + CONVERT(VARCHAR, @EndTime, 120);
    PRINT 'Total duration: ' + CAST(DATEDIFF(SECOND, @StartTime, @EndTime) AS VARCHAR(10)) + ' seconds';
    PRINT '========================================';
END;
GO

-- Step 4: Create a wrapper procedure for testing with shorter duration
CREATE OR ALTER PROCEDURE dbo.TestLongRunningProcedure
    @TestMode BIT = 1  -- Set to 1 for testing (shorter queries), 0 for full run
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @TestMode = 1
    BEGIN
        PRINT 'Running in TEST MODE with shorter queries...';
        
        -- Create a simple version of the first query for testing
        PRINT 'Running simplified LongRunningQuery1...';
        SELECT TOP 1000 
            soh.SalesOrderID,
            soh.OrderDate,
            soh.TotalDue,
            c.CustomerID,
            COUNT(*) OVER(PARTITION BY soh.CustomerID) AS CustomerOrderCount
        FROM Sales.SalesOrderHeader soh
        INNER JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
        WHERE soh.OrderDate BETWEEN '2013-01-01' AND '2013-12-31'
        ORDER BY soh.TotalDue DESC;
        
        WAITFOR DELAY '00:00:05';
        
        PRINT 'Running simplified LongRunningQuery2...';
        SELECT TOP 1000 
            p.ProductID,
            p.Name,
            pc.Name AS CategoryName,
            COUNT(DISTINCT sod.SalesOrderID) AS OrderCount,
            SUM(sod.OrderQty) AS TotalQuantity
        FROM Production.Product p
        LEFT JOIN Sales.SalesOrderDetail sod ON p.ProductID = sod.ProductID
        LEFT JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
        LEFT JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
        GROUP BY p.ProductID, p.Name, pc.Name
        ORDER BY TotalQuantity DESC;
    END
    ELSE
    BEGIN
        PRINT 'Running in FULL MODE with long-running queries...';
        EXEC dbo.MasterLongRunningProcedure 
            @WaitSeconds = 5,
            @RunQuery1 = 1,
            @RunQuery2 = 1;
    END
END;
GO

-- Usage examples:
PRINT 'To run the complete long-running procedure (5-10+ minutes):';
PRINT 'EXEC dbo.MasterLongRunningProcedure @WaitSeconds = 5, @RunQuery1 = 1, @RunQuery2 = 1;';
PRINT '';
PRINT 'To run in test mode (quick execution):';
PRINT 'EXEC dbo.TestLongRunningProcedure @TestMode = 1;';
PRINT '';
PRINT 'To run individual procedures:';
PRINT 'EXEC dbo.LongRunningQuery1;';
PRINT 'EXEC dbo.LongRunningQuery2;';