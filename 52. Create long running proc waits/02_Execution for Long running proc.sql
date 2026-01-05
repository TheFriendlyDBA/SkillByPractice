/* Key Features:
Main Procedure (MasterLongRunningProcedure):
	Waits for specified seconds (default: 5)
	Calls two long-running stored procedures sequentially
	Provides detailed progress messages and timing information

Long-Running Queries:
LongRunningQuery1: Complex sales analysis with multiple CTEs, window functions, and joins across 8+ tables
LongRunningQuery2: Product sales trend analysis with recursive CTEs, moving averages, and year-over-year growth calculations
Both queries use query hints (MAXDOP 1, LOOP JOIN, etc.) to intentionally slow down execution

Test Mode (TestLongRunningProcedure):
	Simplified versions of queries for testing
	Runs in seconds instead of minutes

Performance Characteristics:
	The long-running queries are designed to:
	Process 4+ years of sales data (2011-2014)
	Use multiple Common Table Expressions (CTEs)
	Employ complex window functions and analytics
	Include cross joins and recursive operations
	Use query hints to prevent parallel execution and force specific join types
	Process millions of rows across multiple tables

*/


-- For full long-running execution (5-10+ minutes):
EXEC dbo.MasterLongRunningProcedure @WaitSeconds = 5, @RunQuery1 = 1, @RunQuery2 = 1;

-- For testing (quick execution):
EXEC dbo.TestLongRunningProcedure @TestMode = 1;

-- Run individual long queries:
EXEC dbo.LongRunningQuery1;  -- ~1 minutes
EXEC dbo.LongRunningQuery2;  -- ~5-10 minutes

/*
Note: Actual execution time depends on your server hardware, AdventureWorks database size, and SQL Server configuration. The queries are intentionally complex to achieve the desired 5-10 minute runtime.
*/