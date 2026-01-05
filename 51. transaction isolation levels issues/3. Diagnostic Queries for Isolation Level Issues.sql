/*
-- after Problem Creation Script for:
1) Quickly identify MAXDOP throttling 
	- by resource governor or 
	- user using query hint for Maxdop

2) identify blocking caused by different Transaction isolation level

3) how to identify nested long running procedures, which part is currently running and overall session time etc.

*/

-- https://github.com/TheFriendlyDBA/SkillByPractice/tree/main/sp_sessions
exec sp_Sessions 
--exec sp_WhoIsActive 
--exec sp_BlitzWho

select * from dbo.fn_GetSessionsActivity(null)
select * from dbo.fn_GetLockInfo(null, null)

-- direct DMV queries
-- Check current blocking
SELECT 
    blocking.session_id as blocking_session,
    blocked.session_id as blocked_session,
    blocking_text.text as blocking_query,
    blocked_text.text as blocked_query,
    blocking.transaction_isolation_level as blocking_iso,
    blocked.transaction_isolation_level as blocked_iso
FROM sys.dm_exec_requests blocked
JOIN sys.dm_exec_requests blocking 
    ON blocked.blocking_session_id = blocking.session_id
CROSS APPLY sys.dm_exec_sql_text(blocking.sql_handle) blocking_text
CROSS APPLY sys.dm_exec_sql_text(blocked.sql_handle) blocked_text
WHERE blocked.blocking_session_id > 0;

-- Check lock waits by isolation level
SELECT 
    t.isolation_level,
    COUNT(*) as waiting_requests,
    AVG(wait_time_ms) as avg_wait_ms
FROM sys.dm_exec_requests r
JOIN sys.dm_tran_session_transactions st ON r.session_id = st.session_id
JOIN sys.dm_tran_active_transactions t ON st.transaction_id = t.transaction_id
WHERE r.wait_time > 0
GROUP BY t.isolation_level;

-- Find transactions holding locks
SELECT 
    dt.transaction_id,
    CASE dt.transaction_isolation_level 
        WHEN 0 THEN 'Unspecified'
        WHEN 1 THEN 'ReadUncommitted'
        WHEN 2 THEN 'ReadCommitted'
        WHEN 3 THEN 'Repeatable'
        WHEN 4 THEN 'Serializable'
        WHEN 5 THEN 'Snapshot'
    END as isolation_level,
    dt.transaction_begin_time,
    DATEDIFF(SECOND, dt.transaction_begin_time, GETDATE()) as transaction_age_seconds
FROM sys.dm_tran_active_transactions dt
WHERE dt.transaction_type = 1; -- Read/Write transaction