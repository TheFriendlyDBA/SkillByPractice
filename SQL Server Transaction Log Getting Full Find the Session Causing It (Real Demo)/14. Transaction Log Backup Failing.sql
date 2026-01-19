use master
/* Database Setup Log Backup Issues */
IF DB_ID('LogBackupIssues') IS NOT NULL
BEGIN
    ALTER DATABASE LogBackupIssues SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LogBackupIssues;
END
GO
CREATE DATABASE LogBackupIssues;
GO
ALTER DATABASE LogBackupIssues SET RECOVERY FULL;
GO
USE LogBackupIssues;
GO

-- Create table and generate log activity
DROP TABLE IF EXISTS LogIntensive 
CREATE TABLE LogIntensive (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Data VARCHAR(8000),
    CreatedDate DATETIME DEFAULT GETDATE()
);

-- Take initial full backup
BACKUP DATABASE LogBackupIssues 
TO DISK = 'C:\Backup\LogBackupIssues_Full.bak'
WITH INIT, COMPRESSION;

-- Generate lots of transactions
DECLARE @i INT = 1;
WHILE @i <= 1000
BEGIN
    INSERT INTO LogIntensive (Data)
    VALUES (REPLICATE('X', 8000));
    
    -- Simulate some deletes and updates
    DELETE FROM LogIntensive 
    WHERE ID = (SELECT TOP 1 ID FROM LogIntensive ORDER BY NEWID());
    
    SET @i = @i + 1;
END;

-- Fill log file by starting huge transaction
BEGIN TRANSACTION;
DECLARE @j INT = 1;
WHILE @j <= 10000
BEGIN
    INSERT INTO LogIntensive (Data)
    VALUES (REPLICATE('Y', 8000));
    SET @j = @j + 1;
END;
-- DON'T COMMIT - Leave transaction open

-- Rollback 