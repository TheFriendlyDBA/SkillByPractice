-- Enable snapshot isolation at database level
ALTER DATABASE CURRENT SET ALLOW_SNAPSHOT_ISOLATION ON;

-- Session 1: Start snapshot transaction
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;
SELECT * FROM Orders WHERE CustomerID = 300;

-- Session 2: Update the same data
UPDATE Orders SET TotalAmount = TotalAmount + 100 
WHERE CustomerID = 300;
-- This succeeds, versions stored in tempdb

-- Session 1: Still sees old data
SELECT * FROM Orders WHERE CustomerID = 300;
-- Sees pre-update version from tempdb

-- Monitor version store growth
SELECT 
    DB_NAME(database_id) as DatabaseName,
    reserved_page_count * 8/1024 as VersionStoreSizeMB
FROM sys.dm_tran_version_store_space_usage;