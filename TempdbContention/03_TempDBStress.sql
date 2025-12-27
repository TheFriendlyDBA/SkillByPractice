-- Create scenario causing tempdb contention
USE master;
GO

-- Simulate heavy tempdb usage
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE NAME = 'TempDBStress')
CREATE DATABASE TempDBStress;
GO

USE TempDBStress;
GO

-- Create large table
DROP TABLE IF EXISTS LargeTable
CREATE TABLE LargeTable (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Col1 VARCHAR(1000),
    Col2 VARCHAR(1000),
    Col3 VARCHAR(1000),
    CreatedDate DATETIME DEFAULT GETDATE()
);

-- Create indexes to increase tempdb usage during sorts
CREATE INDEX IX_LargeTable_Col1 ON LargeTable(Col1);
CREATE INDEX IX_LargeTable_Col2 ON LargeTable(Col2);
CREATE INDEX IX_LargeTable_CreatedDate ON LargeTable(CreatedDate);
GO

-- Fill with initial data (fewer rows for faster setup)
INSERT INTO LargeTable (Col1, Col2, Col3, CreatedDate)
SELECT TOP 500000  -- Reduced for faster setup
    REPLICATE('A', 1000),
    REPLICATE('B', 1000),
    REPLICATE('C', 1000),
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE())
FROM sys.objects s1
CROSS JOIN sys.objects s2
CROSS JOIN sys.objects s3;


-- Insert more varied data
INSERT INTO LargeTable (Col1, Col2, Col3,CreatedDate)
SELECT TOP 500000
    REPLICATE(CONVERT(VARCHAR(1000), NEWID()), 25),
    REPLICATE(CONVERT(VARCHAR(1000), NEWID()), 25),
    REPLICATE(CONVERT(VARCHAR(1000), NEWID()), 25)
	,DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE())
FROM sys.objects s1
CROSS JOIN sys.objects s2

GO

-- Update statistics
UPDATE STATISTICS LargeTable WITH FULLSCAN;
GO
USE TempDBStress;

drop table if exists #TempTable
-- Create temporary table with sorting operation
SELECT * INTO #TempTable
FROM LargeTable
ORDER BY NEWID();  -- Random ordering for more contention

drop table if exists #TempJoin
-- Create additional temp objects
SELECT TOP 50000 
    ID, 
    Col1, 
    Col2, 
    Col3,
    CHECKSUM(NEWID()) as HashValue
INTO #TempJoin
FROM LargeTable
ORDER BY Col1, Col2, Col3;


drop table if exists #TempAgg
-- Complex query with multiple tempdb operations
;WITH CTE AS (
    SELECT 
        ID,
        Col1,
        ROW_NUMBER() OVER (ORDER BY Col1) as RowNum
    FROM LargeTable
    WHERE ID % 2 = 0
)
SELECT 
    a.*,
    b.Col2,
    RANK() OVER (ORDER BY a.RowNum) as RankNum
INTO #TempAgg
FROM CTE a
JOIN LargeTable b ON a.ID = b.ID;