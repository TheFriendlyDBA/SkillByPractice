-- Session 1: Long-running update
BEGIN TRANSACTION;
UPDATE Orders SET TotalAmount = TotalAmount * 1.1 
WHERE CustomerID = 500;
-- Don't commit yet (keep transaction open)

-- Session 2: READ UNCOMMITTED sees uncommitted data
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT * FROM Orders WHERE CustomerID = 500;
-- May see temporary, uncommitted values