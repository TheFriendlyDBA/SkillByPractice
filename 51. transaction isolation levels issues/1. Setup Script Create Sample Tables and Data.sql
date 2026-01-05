USE BlockingDemo
-- Create sample tables
DROP TABLE IF EXISTS Orders
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY IDENTITY(1,1),
    CustomerID INT,
    OrderDate DATETIME,
    TotalAmount DECIMAL(10,2),
    Status VARCHAR(20)
);

DROP TABLE IF EXISTS OrderDetails
CREATE TABLE OrderDetails (
    OrderDetailID INT PRIMARY KEY IDENTITY(1,1),
    OrderID INT FOREIGN KEY REFERENCES Orders(OrderID),
    ProductID INT,
    Quantity INT,
    Price DECIMAL(10,2)
);

CREATE INDEX IX_Orders_CustomerID ON Orders(CustomerID);
CREATE INDEX IX_Orders_Status ON Orders(Status);
CREATE INDEX IX_OrderDetails_OrderID ON OrderDetails(OrderID);

-- Insert sample data
INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, Status)
SELECT TOP 100000
    ABS(CHECKSUM(NEWID())) % 1000 + 1,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE()),
    ABS(CHECKSUM(NEWID())) % 1000 + 50.00,
    CASE WHEN ABS(CHECKSUM(NEWID())) % 10 = 0 THEN 'Pending' 
         WHEN ABS(CHECKSUM(NEWID())) % 10 = 1 THEN 'Processing'
         ELSE 'Completed' END
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

INSERT INTO OrderDetails (OrderID, ProductID, Quantity, Price)
SELECT 
    o.OrderID,
    ABS(CHECKSUM(NEWID())) % 100 + 1,
    ABS(CHECKSUM(NEWID())) % 10 + 1,
    ABS(CHECKSUM(NEWID())) % 100 + 10.00
FROM Orders o;