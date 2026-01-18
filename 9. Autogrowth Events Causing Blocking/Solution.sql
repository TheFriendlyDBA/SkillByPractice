/*
Symptoms: 
1. Slower inserts/update 
2. Blocking chains appear unexpectedly
3. One session becomes the lead blocker and No table or row locks involved
4. Wait types like PAGELATCH_UP and PREEMPTIVE_OS_WRITEFILEGATHER , WRITELOG

Solution:
1. Pre-size data and log files
2. Avoid small autogrowth increments
3. Use fixed growth sizes such as 512MB or 1GB
4. Enable instant file initialization (reduce file growth time) 
5. Monitor autogrowth via error log or default trace
6. Treat frequent autogrowth as a configuration issue
*/

-- 1. Check autogrowth events

exec sp_sessions
exec sp_WhoIsActive @find_block_leaders = 1
exec sp_BlitzWho


-- Autogrowth events in trace
SELECT
    te.name AS event_name,
    t.DatabaseName,
    t.Filename,
    t.Duration / 1000000.0 AS duration_seconds,
    t.StartTime 
	,t.LoginName
	,t.SPID
	,t.ApplicationName 
	,t.HostName
FROM sys.fn_trace_gettable(
        (SELECT path FROM sys.traces WHERE is_default = 1),
        DEFAULT
     ) t
JOIN sys.trace_events te ON t.EventClass = te.trace_event_id
WHERE te.name = 'Data File Auto Grow'
ORDER BY t.StartTime DESC;




-- 2. Configure proper file sizes
ALTER DATABASE AutogrowthDemo 
MODIFY FILE (
    NAME = AutogrowthDemo,
    SIZE = 1024MB,  -- Start with 1GB
    FILEGROWTH = 256MB);  -- Grow by 256MB

ALTER DATABASE AutogrowthDemo 
MODIFY FILE (
    NAME = AutogrowthDemo_log,
    SIZE = 512MB,  -- Start with 512MB
    FILEGROWTH = 128MB);  -- Grow by 128MB

-- 3. Enable instant file initialization (reduces data file growth time)
-- Run this at OS level:
-- secpol.msc -> Local Policies -> User Rights Assignment
-- Add SQL Server service account to "Perform volume maintenance tasks"

-- 4. Monitor file size and free space
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    name AS FileName,
    type_desc AS FileType,
    size/128.0 AS SizeMB,
    FILEPROPERTY(name, 'SpaceUsed')/128.0 AS UsedMB,
    size/128.0 - FILEPROPERTY(name, 'SpaceUsed')/128.0 AS FreeMB,
    growth/128.0 AS GrowthMB,
    CASE WHEN max_size = -1 THEN 'UNLIMITED' 
         ELSE CAST(max_size/128.0 AS VARCHAR) + ' MB' END AS MaxSize
FROM sys.master_files
WHERE database_id = DB_ID('AutogrowthDemo');

-- 5. SQL Server 2016 and lower Set trace flag 1117 for uniform file growth
DBCC TRACEON(1117, -1);
-- AUTOGROW_SINGLE_FILE and AUTOGROW_ALL_FILES option

