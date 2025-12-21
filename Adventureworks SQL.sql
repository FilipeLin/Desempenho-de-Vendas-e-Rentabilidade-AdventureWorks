--Data Panel 
SELECT 
    d.SalesOrderID, 
    p.ProductID, 
    d.UnitPrice, 
    p.[Name] AS ProductName, 
    d.UnitPriceDiscount, 
    d.OrderQty, 
    h.OrderDate, 
    p.StandardCost, 
    d.LineTotal, 
    (d.UnitPrice * (1.0 - d.UnitPriceDiscount) - p.StandardCost) AS UnitProfit, 
    h.CustomerID, 
    h.ModifiedDate, 
    sp.[Name] AS StateProvince, 
    cr.[Name] AS Country, 
    cr.CountryRegionCode, 
    a.StateProvinceID, 
    a.City, 
    pct.[Name] AS CategoryName, 
    psc.[Name] AS SubCategoryName, 
    pct.ProductCategoryID, 
    psc.ProductSubcategoryID 
INTO #panel_Project 
FROM Sales.SalesOrderDetail AS d 
    JOIN Sales.SalesOrderHeader  AS h    
    ON h.SalesOrderID = d.SalesOrderID 
    JOIN Production.Product AS p    
    ON p.ProductID = d.ProductID 
    JOIN Person.Address AS a    
    ON a.AddressID = h.ShipToAddressID   
    JOIN Person.StateProvince  AS sp   
    ON sp.StateProvinceID = a.StateProvinceID 
    JOIN Person.CountryRegion  AS cr   
    ON cr.CountryRegionCode = sp.CountryRegionCode 
    LEFT JOIN Production.ProductSubcategory AS psc  
    ON p.ProductSubcategoryID = psc.ProductSubcategoryID 
    LEFT JOIN Production.ProductCategory  AS pct  
    ON psc.ProductCategoryID  = pct.ProductCategoryID 

--Data Check 
--Numero de colunas 
SELECT COUNT(*) AS TotalRows FROM #panel_Project 

--Contagem de NULL's por coluna 
SELECT  
    SUM(CASE WHEN SalesOrderID IS NULL THEN 1 ELSE 0 END) AS Null_SalesOrderID, 
    SUM(CASE WHEN ProductID IS NULL THEN 1 ELSE 0 END) AS Null_ProductID, 
    SUM(CASE WHEN UnitPrice IS NULL THEN 1 ELSE 0 END) AS Null_UnitPrice, 
    SUM(CASE WHEN ProductName IS NULL THEN 1 ELSE 0 END) AS Null_ProductName, 
    SUM(CASE WHEN UnitPriceDiscount IS NULL THEN 1 ELSE 0 END) AS Null_UnitPriceDiscount, 
    SUM(CASE WHEN OrderQty IS NULL THEN 1 ELSE 0 END) AS Null_OrderQty, 
    SUM(CASE WHEN OrderDate IS NULL THEN 1 ELSE 0 END) AS Null_OrderDate, 
    SUM(CASE WHEN StandardCost IS NULL THEN 1 ELSE 0 END) AS Null_StandardCost, 
    SUM(CASE WHEN LineTotal IS NULL THEN 1 ELSE 0 END) AS Null_LineTotal, 
    SUM(CASE WHEN UnitProfit IS NULL THEN 1 ELSE 0 END) AS Null_UnitProfit, 
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS Null_CustomerID, 
    SUM(CASE WHEN Country IS NULL THEN 1 ELSE 0 END) AS Null_Country, 
    SUM(CASE WHEN CountryRegionCode IS NULL THEN 1 ELSE 0 END) AS Null_CountryRegionCode, 
    SUM(CASE WHEN CategoryName IS NULL THEN 1 ELSE 0 END) AS Null_CategoryName, 
    SUM(CASE WHEN SubCategoryName IS NULL THEN 1 ELSE 0 END) AS Null_SubCategoryName 
FROM #panel_Project 

--Contagem de duplicados no Data Panel 
SELECT  
    SalesOrderID, ProductID, COUNT(*) AS DuplicateCount 
FROM #panel_Project 
GROUP BY SalesOrderID, ProductID 
HAVING COUNT(*) > 1 

--Quantidades iguais a zero ou negativas 
SELECT *  
FROM #panel_Project 
WHERE OrderQty <= 0 

--Preços iguais a 0 ou negativos  
SELECT *  
FROM #panel_Project 
WHERE UnitPrice <= 0 OR StandardCost < 0 

--Lucros Negativos(UnitProfit) 
SELECT *  
FROM #panel_Project 
WHERE UnitProfit < 0 
ORDER BY UnitProfit ASC 

--Consistência da data 
SELECT  
    MIN(OrderDate) AS MinDate,  
    MAX(OrderDate) AS MaxDate 
FROM #panel_Project 

--Check se algum produto tem categoria mas não tem subcategoria 
SELECT * 
FROM #panel_Project 
WHERE SubCategoryName IS NULL AND CategoryName IS NOT NULL 

--Check se alguma subcategoria pertence a mais do que uma categoria 
SELECT SubCategoryName, COUNT(DISTINCT CategoryName) AS DifferentCategories 
FROM #panel_Project 
GROUP BY SubCategoryName 
HAVING COUNT(DISTINCT CategoryName) > 1 

--Análise de Vendas 
--Análise da Sazonalidade 
--Receita e lucro da empresa ao longo dos meses: 
SELECT 
YEAR(OrderDate) AS Year, 
MONTH(OrderDate) AS Month, 
SUM(LineTotal) AS Revenue, 
SUM(LineTotal - StandardCost * OrderQty) AS Profit 
FROM #panel_Project 
GROUP BY Year(OrderDate), Month(OrderDate) 
ORDER BY Year, Month 

--Índice mensal de receita e lucro da empresa (100 = média global): 
WITH MonthlyData AS  
(SELECT YEAR (OrderDate) AS Year, 
 MONTH(OrderDate) AS Month, 
 SUM(LineTotal) AS Revenue, 
 SUM(LineTotal - (StandardCost * OrderQty)) AS Profit 
 FROM #panel_Project 
GROUP BY YEAR(OrderDate), Month(OrderDate)) 
Select Year, 
    Month, 
    Revenue, 
    Profit, 
    CAST(Revenue * 100/Avg(Revenue) over() as Decimal(10,2)) as PercRevenueFromAvg, 
    CAST(Profit * 100/Avg(Profit) over() as Decimal(10,2)) as PercProfitFromAvg 
FROM MonthlyData 
ORDER BY Year, Month 

--Tendência dos dados da empresa 
--Receita, lucro e margem de lucro da empresa ao longo dos trimestres: 
WITH Q AS ( 
  SELECT 
    YEAR(OrderDate) AS Year, 
    DATEPART(QUARTER, OrderDate) AS Quarter, 
    SUM(LineTotal) AS Revenue, 
    SUM(LineTotal - StandardCost * OrderQty) AS Profit 
  FROM #panel_Project 
  GROUP BY YEAR(OrderDate), DATEPART(QUARTER, OrderDate) 
) 
SELECT 
  Year, 
  Quarter, 
  Revenue, 
  Profit, 
  Profit / Revenue AS ProfitMargin 
FROM Q 
ORDER BY Year, Quarter 

--Evolução mensal de novos clientes 
WITH FirstPurchase AS ( 
  SELECT 
      CustomerID, 
      MIN(CAST(OrderDate AS date)) AS FirstDate 
  FROM #panel_Project 
  GROUP BY CustomerID 
) 
SELECT 
    YEAR(FirstDate)  AS FirstYear, 
    MONTH(FirstDate) AS FirstMonth, 
    COUNT(*)         AS NewClients 
FROM FirstPurchase 
GROUP BY YEAR(FirstDate), MONTH(FirstDate) 
ORDER BY FirstYear, FirstMonth 

--Análise de cada região 
--Receita e Lucro de cada País ao logo dos meses: 
SELECT 
    YEAR(OrderDate)  AS Year, 
    MONTH(OrderDate) AS Month, 
    Country, 
    SUM(LineTotal) AS Revenue, 
    SUM(LineTotal – StandardCost * OrderQty) AS Profit 
FROM #panel_Project 
GROUP BY YEAR(OrderDate), MONTH(OrderDate), Country 
ORDER BY Country, Year, Month 

--Vendas mensais em novas regiões: 
SELECT 
    YEAR(FirstMonth)  AS Year, 
    MONTH(FirstMonth) AS Month, 
    StateProvince     AS StateName, 
    Country           AS CountryName 
FROM ( 
    SELECT 
        StateProvinceID, 
        StateProvince, 
        Country, 
        DATEFROMPARTS(YEAR(MIN(OrderDate)), MONTH(MIN(OrderDate)), 1) AS FirstMonth 
    FROM #panel_Project 
    WHERE StateProvinceID IS NOT NULL 
    GROUP BY StateProvinceID, StateProvince, Country 
) s 
ORDER BY Year, Month, CountryName, StateName 

--Número de estados com vendas por país (Trimestral): 
WITH T AS ( 
  SELECT 
      YEAR(OrderDate) AS [Year], 
      DATEPART(QUARTER, OrderDate) AS [Quarter], 
      Country, 
      COUNT(DISTINCT StateProvinceID) AS StatesInQuarter 
  FROM #panel_Project 
  WHERE StateProvinceID IS NOT NULL 
  GROUP BY YEAR(OrderDate), DATEPART(QUARTER, OrderDate), Country 
) 
SELECT 
    [Year], [Quarter], 
    SUM(CASE WHEN Country = 'Australia'       THEN StatesInQuarter ELSE 0 END) AS Australia, 
    SUM(CASE WHEN Country = 'Canada'          THEN StatesInQuarter ELSE 0 END) AS Canada, 
    SUM(CASE WHEN Country = 'France'          THEN StatesInQuarter ELSE 0 END) AS France, 
    SUM(CASE WHEN Country = 'Germany'         THEN StatesInQuarter ELSE 0 END) AS Germany, 
    SUM(CASE WHEN Country = 'United Kingdom'  THEN StatesInQuarter ELSE 0 END) AS [United Kingdom], 
    SUM(CASE WHEN Country = 'United States'   THEN StatesInQuarter ELSE 0 END) AS [United States] 
FROM T 
GROUP BY [Year], [Quarter] 
ORDER BY [Year], [Quarter] 

--Top 10 estados com maioreslucros: 
SELECT TOP (10) 
    StateProvince, 
    Country, 
    SUM(LineTotal) AS Revenue, 
    SUM(UnitProfit * OrderQty)  AS Profit, 
    SUM(UnitProfit * OrderQty) /(SUM(LineTotal)) AS ProfitMargin 
FROM #panel_Project 
WHERE StateProvinceID IS NOT NULL 
GROUP BY StateProvince, Country 
ORDER BY Profit DESC 

--Receita e lucro total de cada país durante o período 2011-2014: 
SELECT 
    Country, 
    SUM(LineTotal) AS Revenue, 
    SUM(UnitProfit * OrderQty) AS Profit, 
    SUM(UnitProfit * OrderQty)/ SUM(LineTotal) AS ProfitMargin 
FROM #panel_Project 
GROUP BY Country 
ORDER BY Profit desc 

--Análise por categoria 
--Categorias mais lucrativas: 
SELECT 
    CategoryName, 
    SubCategoryName, 
    SUM(LineTotal - (OrderQty * StandardCost)) AS TotalProfit 
FROM #panel_Project 
GROUP BY CategoryName, SubCategoryName 
ORDER BY TotalProfit DESC 

--Top 5 das subcategories mais lucrativas: 
SELECT  top 5 
    CategoryName, 
    SubCategoryName, 
    SUM(LineTotal - (OrderQty * StandardCost)) AS TotalProfit 
FROM #panel_Project 
GROUP BY CategoryName, SubCategoryName 
ORDER BY TotalProfit DESC 

--Top 5 das subcategorias mais vendidas: 
SELECT top 5 
    CategoryName, 
    SubCategoryName, 
    SUM(OrderQty) AS TotalUnitsSold 
FROM #panel_Project 
GROUP BY CategoryName, SubCategoryName 

ORDER BY TotalUnitsSold DESC 

