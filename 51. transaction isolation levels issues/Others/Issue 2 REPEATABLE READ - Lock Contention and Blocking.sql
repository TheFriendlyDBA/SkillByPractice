-- Session 1: Reads data and holds locks
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRANSACTION;
SELECT * FROM Orders WHERE CustomerID = 100;
-- Locks are held on rows with CustomerID = 100

-- Session 2: Blocked trying to update same rows
UPDATE Orders SET Status = 'Processing' 
WHERE CustomerID = 100;
-- This will be BLOCKED until Session 1 commits

-- Session 3: Also blocked trying to insert new order for same customer
INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, Status)
VALUES (100, GETDATE(), 150.00, 'Pending');
-- BLOCKED due to range locks