-- Session 1: Long-running report (common issue)
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRANSACTION;

-- Complex report query
SELECT 
    o.CustomerID,
    COUNT(*) as OrderCount,
    SUM(o.TotalAmount) as TotalSpent,
    AVG(od.Quantity) as AvgQuantity
FROM Orders o WITH (NOLOCK)  -- Mixed isolation levels!
JOIN OrderDetails od ON o.OrderID = od.OrderID
WHERE o.OrderDate >= '2023-01-01'
GROUP BY o.CustomerID
HAVING COUNT(*) > 5
ORDER BY TotalSpent DESC;
-- Keeps transaction open for user to scroll results

-- Session 2: OLTP operation - BLOCKED
UPDATE Orders SET Status = 'Shipped' 
WHERE OrderID = 5000;
-- Blocked by report's transaction

-- Session 3: Another blocked operation
DELETE FROM OrderDetails 
WHERE OrderDetailID = 10000;
-- Also blocked

rollback