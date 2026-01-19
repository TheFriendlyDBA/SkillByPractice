USE master;
GO
/* Database Setup (Guaranteed Autogrowth Pressure) */
IF DB_ID('AutogrowthDemo') IS NOT NULL
BEGIN
    ALTER DATABASE AutogrowthDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE AutogrowthDemo;
END
GO

CREATE DATABASE AutogrowthDemo;
GO

ALTER DATABASE AutogrowthDemo SET RECOVERY SIMPLE;
GO

USE AutogrowthDemo;
GO

-- Configure very small data & log files with tiny growth
ALTER DATABASE AutogrowthDemo 
MODIFY FILE (
    NAME = AutogrowthDemo,
    SIZE = 10MB,
    FILEGROWTH = 1MB);   -- Forces frequent autogrowth

ALTER DATABASE AutogrowthDemo 
MODIFY FILE (
    NAME = AutogrowthDemo_log,
    SIZE = 10MB,
    FILEGROWTH = 1MB);
GO

EXEC sp_helpdb AutogrowthDemo;
GO

-- Autogrowth is synchronous. While one session grows the file, all other sessions wait, causing blocking.
-- Table Designed to Consume Space Fast
DROP TABLE IF EXISTS dbo.GrowingTable1
CREATE TABLE dbo.GrowingTable1
(
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Padding CHAR(8000) NOT NULL DEFAULT REPLICATE('X',8000),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME()
);
DROP TABLE IF EXISTS dbo.GrowingTable2
CREATE TABLE dbo.GrowingTable2
(
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Padding CHAR(8000) NOT NULL DEFAULT REPLICATE('X',8000),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME()
);
DROP TABLE IF EXISTS dbo.GrowingTable3
CREATE TABLE dbo.GrowingTable3
(
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Padding CHAR(8000) NOT NULL DEFAULT REPLICATE('X',8000),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME()
);
GO

GO

-- Window 1
USE AutogrowthDemo;
GO

SET NOCOUNT ON;

WHILE 1 = 1
BEGIN
    INSERT INTO dbo.GrowingTable1 DEFAULT VALUES;
	--select * from dbo.GrowingTable1
END;
GO

-- Window 2
USE AutogrowthDemo;
GO

SET NOCOUNT ON;

WHILE 1 = 1
BEGIN
    INSERT INTO dbo.GrowingTable2 DEFAULT VALUES;
END;
GO

-- Window 3
USE AutogrowthDemo;
GO

SET NOCOUNT ON;

WHILE 1 = 1
BEGIN
    INSERT INTO dbo.GrowingTable3 DEFAULT VALUES;
END;
GO
