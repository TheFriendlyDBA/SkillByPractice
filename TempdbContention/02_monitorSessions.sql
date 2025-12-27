Exec [dbo].[sp_WhoIsActive] 
Exec [dbo].[sp_WhoIsActive] @get_task_info = 2

exec sp_BlitzWho

Exec [dbo].[sp_Sessions]

select 'Kill '+convert(varchar,session_id) , * from [dbo].[fn_GetSessionsActivity] (NULL)
where 1=1
and program_name = '.Net SqlClient Data Provider'

and program_name = 'SQLQueryStress'




/* TempDB Contention (Error 1101/1105)
Problem: "Could not allocate space for object in database 'tempdb'"
Root Cause: Insufficient tempdb space or PFS/SGAM contention

Check for:
	1. tempdb databases are configured properly
		a. Configure multiple tempdb files (1 per CPU core up to 8)
		b. tempdb files on dedicated drive
		c. drive is formated with 64K block size
	2. check for abnormal workload usage
		a. increase of workload / more connections then normal
		b. version store usage higher then normal
	3. check for allocation
		select name , is_mixed_page_allocation_on from sys.databases 
		ALTER DATABASE TempDBStress SET MIXED_PAGE_ALLOCATION OFF; 











Solution:
-- Configure multiple tempdb files (1 per CPU core up to 8)
USE master;
GO
ALTER DATABASE tempdb 
MODIFY FILE (NAME = tempdev, SIZE = 8192MB, FILEGROWTH = 512MB);
GO

-- Add additional files
ALTER DATABASE [tempdb] ADD FILE ( NAME = N'temp4', 
FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\temp4.ndf' 
, SIZE = 23535616KB , FILEGROWTH = 65536KB )
ALTER DATABASE [tempdb] ADD FILE ( NAME = N'temp5', 
FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\temp4.ndf' 
, SIZE = 23535616KB , FILEGROWTH = 65536KB )
ALTER DATABASE [tempdb] ADD FILE ( NAME = N'temp6', 
FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\temp4.ndf' 
, SIZE = 23535616KB , FILEGROWTH = 65536KB )

GO

-- Monitor tempdb usage
SELECT 
	SUM(user_object_reserved_page_count) AS user_object_pages,
	SUM(internal_object_reserved_page_count) AS internal_object_pages,
	SUM(version_store_reserved_page_count) AS version_store_pages,
	SUM(mixed_extent_page_count) AS mixed_pages
FROM sys.dm_db_file_space_usage;
*/

select name , is_mixed_page_allocation_on from sys.databases 
