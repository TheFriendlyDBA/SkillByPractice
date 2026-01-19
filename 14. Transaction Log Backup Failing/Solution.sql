/*
Symptoms: 
	• Transaction log keeps growing
	• DBCC SQLPERF(LOGSPACE) shows log near 100%
	• Log backups do NOT reduce log usage
	• New transactions start failing
Root Cause
	• Active or long-running transaction
	• SQL Server must keep log records
	• Log backups cannot truncate active log records
	• Often caused by ETL jobs or uncommitted sessions
Solution:
	  https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-log-architecture-and-management-guide?view=sql-server-ver17
	• Identify open transaction (DBCC OPENTRAN)
	• Commit or rollback the transaction
	• Take a log backup
	• Monitor log usage proactively
*/
USE master
-- 1. Check log space usage
DBCC SQLPERF(LOGSPACE);

-- take log backup
BACKUP LOG LogBackupIssues 
TO DISK = 'C:\Backup\LogBackupIssues_log.trn' WITH NOFORMAT, NOINIT;


-- 2. why the log backup space not getting released by T-log job
use master;
select name , log_reuse_wait_desc from sys.databases 

-- 3. Find oldest active transaction
exec sp_sessions 72
Select * from master.dbo.fn_GetSessionsActivity(null)
where [database] = 'LogBackupIssues'

exec master.dbo.sp_WhoIsActive
exec sp_BlitzWho @ShowSleepingSPIDs = 1

exec xp_readerrorlog 



-- 4.to check oldest active transaction
-- Identify active transactions that may be preventing log truncation. DBCC OPENTRAN displays information about the oldest active transaction 
USE LogBackupIssues
DBCC OPENTRAN


dbcc loginfo
select * from sys.dm_db_log_info(null)

-- find out Active log and free log size
;WITH cte_vlf AS (
SELECT ROW_NUMBER() OVER(ORDER BY vlf_begin_offset) AS vlfid, DB_NAME(database_id) AS [Database Name], vlf_sequence_number, vlf_active, vlf_begin_offset, vlf_size_mb
    FROM sys.dm_db_log_info(DEFAULT)),
cte_vlf_cnt AS (SELECT [Database Name], COUNT(vlf_sequence_number) AS vlf_count,
    (SELECT COUNT(vlf_sequence_number) FROM cte_vlf WHERE vlf_active = 0) AS vlf_count_inactive,
    (SELECT COUNT(vlf_sequence_number) FROM cte_vlf WHERE vlf_active = 1) AS vlf_count_active,
    (SELECT MIN(vlfid) FROM cte_vlf WHERE vlf_active = 1) AS ordinal_min_vlf_active,
    (SELECT MIN(vlf_sequence_number) FROM cte_vlf WHERE vlf_active = 1) AS min_vlf_active,
    (SELECT MAX(vlfid) FROM cte_vlf WHERE vlf_active = 1) AS ordinal_max_vlf_active,
    (SELECT MAX(vlf_sequence_number) FROM cte_vlf WHERE vlf_active = 1) AS max_vlf_active
    FROM cte_vlf
    GROUP BY [Database Name])
SELECT [Database Name], vlf_count, min_vlf_active, ordinal_min_vlf_active, max_vlf_active, ordinal_max_vlf_active,
((ordinal_min_vlf_active-1)*100.00/vlf_count) AS free_log_pct_before_active_log,
((ordinal_max_vlf_active-(ordinal_min_vlf_active-1))*100.00/vlf_count) AS active_log_pct,
((vlf_count-ordinal_max_vlf_active)*100.00/vlf_count) AS free_log_pct_after_active_log
FROM cte_vlf_cnt;
GO



-- 5. Kill blocking transaction (if necessary)
-- First identify session
SELECT 
    s.session_id,
    t.transaction_id,
    s.login_name,
    s.host_name,
    s.program_name,
    s.last_request_start_time,
    s.last_request_end_time
FROM sys.dm_tran_session_transactions t
INNER JOIN sys.dm_exec_sessions s ON t.session_id = s.session_id
ORDER BY s.last_request_start_time;

-- Rollback / Kill if safe to release and take normal backup
KILL <session_id>;


-- 6. take log backup
BACKUP LOG LogBackupIssues 
TO DISK = 'C:\Backup\LogBackupIssues_log.trn' WITH NOFORMAT, NOINIT;

-- 7. Emergency when log backup 100% full then attempt OR change database recovery mode to simple.
-- both will break T-log backup chain which mean take FULL after the issue resolves.
BACKUP LOG LogBackupIssues 
TO DISK = 'NUL:' WITH NOFORMAT, NOINIT;


-- 8. Monitor log growth
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    (total_log_size_in_bytes/1048576.0) AS TotalLogSizeMB,
    (used_log_space_in_bytes/1048576.0) AS UsedLogSpaceMB
    ,*
FROM sys.dm_db_log_space_usage;

-- 9. shrink database log file
USE [LogBackupIssues]
GO
DBCC SHRINKFILE (N'LogBackupIssues_log' , 0, TRUNCATEONLY)
GO
