-- Solution 1: Use READ COMMITTED SNAPSHOT for read-heavy workloads
ALTER DATABASE CURRENT SET READ_COMMITTED_SNAPSHOT ON;

-- Solution 2: Keep transactions short
BEGIN TRANSACTION;
-- Do work immediately
UPDATE Orders SET Status = 'Processed' WHERE OrderID = @OrderID;
COMMIT TRANSACTION; -- Commit ASAP

-- Solution 3: Use appropriate isolation level for the task
SET TRANSACTION ISOLATION LEVEL READ COMMITTED; -- Default, usually best

-- Solution 4: Use NOLOCK hint cautiously (only for reporting)
SELECT * FROM Orders WITH (NOLOCK) 
WHERE OrderDate >= DATEADD(DAY, -1, GETDATE());

-- Solution 5: Implement retry logic for deadlocks
DECLARE @retryCount INT = 0, @maxRetries INT = 3;

WHILE @retryCount < @maxRetries
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Your transaction logic here
        COMMIT TRANSACTION;
        BREAK;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 1205 -- Deadlock victim
        BEGIN
            ROLLBACK TRANSACTION;
            SET @retryCount = @retryCount + 1;
            WAITFOR DELAY '00:00:00.100'; -- Exponential backoff
        END
        ELSE
        BEGIN
            THROW;
        END
    END CATCH
END

/*
Key Takeaways:
READ UNCOMMITTED: Fastest but risks dirty reads and inconsistent data

READ COMMITTED: Balanced default, but can have non-repeatable reads

REPEATABLE READ: Prevents non-repeatable reads but causes more blocking

SERIALIZABLE: Highest isolation, but severe performance impact

SNAPSHOT: Good for read consistency but tempdb overhead

READ COMMITTED SNAPSHOT: Best balance for most scenarios

Always:

Choose the lowest isolation level needed

Keep transactions as short as possible

Monitor blocking and deadlocks

Test isolation level changes in non-production first
*/