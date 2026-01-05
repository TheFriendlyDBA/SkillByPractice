-- Session 1: Serializable transaction
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
SELECT COUNT(*) FROM Orders 
WHERE CustomerID BETWEEN 100 AND 200;
-- Acquires range locks

-- Session 2: Another transaction with overlapping range
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
SELECT * FROM Orders 
WHERE CustomerID BETWEEN 150 AND 250;
-- Also acquires range locks

-- Session 3: This insert can cause deadlock
INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, Status)
VALUES (175, GETDATE(), 200.00, 'Pending');
-- May cause deadlock with either session