--Tabel [Căn Hộ]
CREATE PROCEDURE ConvertTextToNumeric
AS
BEGIN
    -- Convert area to numeric
    UPDATE [dbo].[Căn Hộ]
    SET [Diện tích] = TRY_CAST(REPLACE([Diện tích], ' m²', '') AS DECIMAL(10, 2))
    WHERE ISNUMERIC(REPLACE([Diện tích], ' m²', '')) = 1;

    -- Convert frontage to numeric
    UPDATE [dbo].[Căn Hộ]
    SET [Mặt tiền] = TRY_CAST(REPLACE([Mặt tiền], 'm', '') AS DECIMAL(10, 2))
    WHERE ISNUMERIC(REPLACE([Mặt tiền], 'm', '')) = 1;

    -- Convert road width to numeric
    UPDATE [dbo].[Căn Hộ]
    SET [Đường vào] = TRY_CAST(REPLACE([Đường vào], 'm', '') AS DECIMAL(10, 2))
    WHERE ISNUMERIC(REPLACE([Đường vào], 'm', '')) = 1;
END;
GO

EXEC ConvertTextToNumeric;

CREATE PROCEDURE RemoveDuplicates
AS
BEGIN
    -- Remove duplicates based on title

    WITH CTE AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY [Tiêu đề] ORDER BY (SELECT NULL)) AS RowNum
        FROM [dbo].[Căn Hộ]
    )
    DELETE FROM [dbo].[Căn Hộ]
    WHERE [Mã Căn Hộ] IN (
        SELECT [Mã Căn Hộ]
        FROM CTE
        WHERE RowNum > 1
    );
END;
GO

EXEC RemoveDuplicates;

CREATE PROCEDURE NormalizeValuesPrice
AS
BEGIN
    -- Normalize price values
    UPDATE [dbo].[Căn Hộ]
    SET [Mức giá] = CASE 
        WHEN [Mức giá] LIKE N'% ty' THEN CAST(REPLACE(LEFT([Mức giá], CHARINDEX(' ', [Mức giá]) - 1), ',', '.') AS DECIMAL(10, 2)) * 1
        WHEN [Mức giá] LIKE N'% trieu' THEN CAST(REPLACE(LEFT([Mức giá], CHARINDEX(' ', [Mức giá]) - 1), ',', '.') AS DECIMAL(10, 2)) * 0.001
        WHEN [Mức giá] LIKE '% trieu/m²' AND ISNUMERIC(REPLACE(REPLACE(TRIM([Mức giá]), ' trieu/m²', ''), ',', '')) = 1 THEN CAST(REPLACE(REPLACE(TRIM([Mức giá]), ' trieu/m²', ''), ',', '') AS FLOAT) * [Diện tích] * 0.001
    END;
END;
GO

EXEC NormalizeValuesPrice;


CREATE PROCEDURE HandleNullValuesRoom
AS
BEGIN
	-- Handle NULL values in multiple columns
	-- Replace null values ​​in comlumn [Số toilet] & [Số phòng ngủ]
	UPDATE [dbo].[Căn Hộ]
	SET [Số toilet] = [Số phòng ngủ]
	WHERE [Số toilet] IS NULL AND [Số phòng ngủ] IS NOT NULL;

	-- Replace null values ​​in comlumn [Số tầng]
	UPDATE [dbo].[Căn Hộ]
	SET [Số tầng] = CASE
	-- Conditions for an area larger than 100m² and more than 6 bedrooms
		WHEN TRY_CAST([Diện tích] AS FLOAT) > 100 AND TRY_CAST([Số phòng ngủ] AS INT) > 6 THEN 5
    
	-- Area conditions from 70 to 100m² or 3 to 4 bedrooms
		WHEN TRY_CAST([Diện tích] AS FLOAT) BETWEEN 70 AND 100 OR TRY_CAST([Số phòng ngủ] AS INT) BETWEEN 3 AND 4 THEN 4
    
	-- Area conditions range from 50 to 70m² and have 1 to 2 bedrooms
		WHEN TRY_CAST([Diện tích] AS FLOAT) BETWEEN 50 AND 70 AND TRY_CAST([Số phòng ngủ] AS INT) <= 2 THEN 3
    
	-- Area conditions from 30 to 50m² or 1 to 2 bedrooms (other cases)
		WHEN TRY_CAST([Diện tích] AS FLOAT) BETWEEN 30 AND 50 OR TRY_CAST([Số phòng ngủ] AS INT) <= 2 THEN 2
    
	-- Area conditions under 30m²
		WHEN TRY_CAST([Diện tích] AS FLOAT) < 30 THEN 1
	END
	WHERE [Số tầng] IS NULL;
END;
GO

EXEC HandleNullValuesRoom

--Remove unnecessary null values ​​from columns
CREATE PROCEDURE NullvaluesColumns
AS
BEGIN
	DELETE FROM [dbo].[Căn Hộ]
	WHERE [Diện tích] IS NULL
		OR [Mức giá] IS NULL
		OR [Mức giá] = N'%Thỏa Thuận%'
		OR ([Số phòng ngủ] IS NULL AND [Số toilet] IS NULL);
END;
GO

EXEC NullvaluesColumns

 -- Conditional frontage assignment
    UPDATE [dbo].[Căn Hộ]
    SET [Mặt tiền] = CASE
        WHEN [Tiêu đề] LIKE N'%biệt thự%' AND TRY_CAST([Diện tích] AS FLOAT) >= 100 THEN 8
        WHEN [Tiêu đề] LIKE N'%biệt thự%' AND (TRY_CAST([Diện tích] AS FLOAT) >= 70 AND TRY_CAST([Diện tích] AS FLOAT) < 100) THEN 7
        WHEN [Tiêu đề] IN (N'%nhà%', N'%căn hộ%', N'%căn%') THEN 
            CASE 
                WHEN TRY_CAST([Diện tích] AS FLOAT) >= 100 THEN 5
                WHEN TRY_CAST([Diện tích] AS FLOAT) >= 50 AND TRY_CAST([Diện tích] AS FLOAT) < 100 THEN 6
                WHEN TRY_CAST([Diện tích] AS FLOAT) < 50 THEN 2.5
            END
	END
	WHERE [Mặt tiền] IS NULL;

CREATE PROCEDURE HandleNullValuesFacade
AS
BEGIN
-- Replace null values ​​in comlumn [Mặt tiền]
    -- KNN to replace NULL frontage
    WITH KNN_Distances AS (
        SELECT 
            A.[Mặt tiền], 
            CAST(A.[Diện tích] AS FLOAT) AS Diện_tích_A, 
            CAST(A.[Mức giá] AS FLOAT) AS Mức_giá_A,
            CAST(B.[Diện tích] AS FLOAT) AS Diện_tích_B,
            CAST(B.[Mức giá] AS FLOAT) AS Mức_giá_B,
            POWER(CAST(A.[Diện tích] AS FLOAT) - CAST(B.[Diện tích] AS FLOAT), 2) + 
            POWER(CAST(A.[Mức giá] AS FLOAT) - CAST(B.[Mức giá] AS FLOAT), 2) + 1e-10 AS Euclidean_Distance,
            ROW_NUMBER() OVER (PARTITION BY A.[Mặt tiền] ORDER BY 
                POWER(CAST(A.[Diện tích] AS FLOAT) - CAST(B.[Diện tích] AS FLOAT), 2) + 
                POWER(CAST(A.[Mức giá] AS FLOAT) - CAST(B.[Mức giá] AS FLOAT), 2)) AS Rank
        FROM [dbo].[Căn Hộ] A, [dbo].[Căn Hộ] B
        WHERE A.[Mặt tiền] IS NULL AND B.[Mặt tiền] IS NOT NULL
    )
    UPDATE [dbo].[Căn Hộ]
    SET [Mặt tiền] = (SELECT TOP 1 [Mặt tiền] 
                      FROM KNN_Distances 
                      WHERE [dbo].[Căn Hộ].[Mặt tiền] IS NULL AND Rank = 1)
    WHERE [Mặt tiền] IS NULL;

END;
GO

EXEC HandleNullValuesFacade;

-- Set default frontage if NULL
UPDATE [dbo].[Căn Hộ]
SET [Mặt tiền] = '0'
WHERE [Mặt tiền] IS NULL;


CREATE PROCEDURE HandleNullValuesRoad 
AS
BEGIN
-- Replace null values ​​in comlumn [Đường vào]
		WITH KNN_Distances AS (
			SELECT 
				A.[Đường vào], 
				CAST(A.[Diện tích] AS FLOAT) AS Diện_tích_A, 
				CAST(A.[Mức giá] AS FLOAT) AS Mức_giá_A,
				CAST(B.[Diện tích] AS FLOAT) AS Diện_tích_B, 
				CAST(B.[Mức giá] AS FLOAT) AS Mức_giá_B,
				POWER(CAST(A.[Diện tích] AS FLOAT) - CAST(B.[Diện tích] AS FLOAT), 2) + 
				POWER(CAST(A.[Mức giá] AS FLOAT) - CAST(B.[Mức giá] AS FLOAT), 2) + 1e-10 AS Euclidean_Distance,
				ROW_NUMBER() OVER (PARTITION BY A.[Đường vào] ORDER BY 
				POWER(CAST(A.[Diện tích] AS FLOAT) - CAST(B.[Diện tích] AS FLOAT), 2) + 
				POWER(CAST(A.[Mức giá] AS FLOAT) - CAST(B.[Mức giá] AS FLOAT), 2)) AS Rank
			FROM [dbo].[Căn Hộ] A, [dbo].[Căn Hộ] B
			WHERE A.[Đường vào] IS NULL AND B.[Đường vào] IS NOT NULL
			)
		UPDATE [dbo].[Căn Hộ] 
		SET [Đường vào] = (SELECT TOP 1 [Đường vào] 
						   FROM KNN_Distances 
						   WHERE [dbo].[Căn Hộ].[Đường vào] IS NULL AND Rank = 1)
		WHERE [Đường vào] IS NULL;
END;
GO

EXEC HandleNullValuesRoad;

-- If Entrance is null then There is no entry
		UPDATE [dbo].[Căn Hộ]
		SET [Đường vào] = '0'
		WHERE [Đường vào] IS NULL;

--  Handle additional blank values ​​in the Furniture column
CREATE PROCEDURE HandleValuesFurniture
AS
BEGIN
UPDATE [dbo].[Căn Hộ]
	SET [Nội thất] = CASE
		WHEN [Nội thất] LIKE N'%bàn giao%' OR [Nội thất] LIKE  N'%Đầy đủ%' OR [Nội thất] LIKE N'%Cao cấp%'  THEN N'Đầy đủ'
		WHEN [Nội thất] LIKE N'%Cơ bản%' THEN N'Cơ bản'
		WHEN [Nội thất] LIKE  N'%không%' OR [Nội thất] LIKE N'%thô%' OR [Nội thất] is null THEN N'Chưa có nội thất'
	END;
END;
GO

EXEC HandleValuesFurniture

-- Remove unnecessary NULL values
CREATE PROCEDURE Nullvalues
AS
BEGIN
	DELETE FROM [dbo].[Căn Hộ] 
	WHERE [Số tầng]    IS NULL
	OR [Đường vào] = '0' and [Mặt tiền] = '0.0'
	OR [Đường vào] = '0' and [Mặt tiền] = '0'
	OR [Nội thất] IS NULL
END;
GO

EXEC Nullvalues

--Returns the final result to the table
CREATE PROCEDURE GetFinalResultForHouse
AS
BEGIN
   SELECT * FROM [dbo].[Căn Hộ] ;
END;
GO

  EXEC GetFinalResultForHouse;

--Tabel [Pháp Lý]

CREATE PROCEDURE CleanLegal
AS
BEGIN
    -- 1. Remove NULL values in `Tình Trạng Pháp Lý`
    DELETE FROM [dbo].[Pháp Lý]
    WHERE [Tình Trạng Pháp Lý] IS NULL;


    -- 2. Normalize `Tình Trạng Pháp Lý`
    UPDATE [dbo].[Pháp Lý]
    SET [Tình Trạng Pháp Lý] = CASE
        WHEN ([Tình Trạng Pháp Lý] LIKE N'%đỏ%' OR [Tình Trạng Pháp Lý] LIKE N'%sđcc%' OR [Tình Trạng Pháp Lý] LIKE N'%Sổ đỏ%') AND [Tình Trạng Pháp Lý] NOT LIKE N'%/%' THEN N'Sổ đỏ'
		WHEN [Tình Trạng Pháp Lý] LIKE N'%hồng%'  OR [Tình Trạng Pháp Lý] LIKE N'%có sổ%'  OR [Tình Trạng Pháp Lý] LIKE N'%/%' Or [Tình Trạng Pháp lý] LIKE N'%Sổ riêng%' Or [Tình Trạng Pháp Lý] LIKE N'%Đầy đủ%'Or [Tình Trạng Pháp Lý] LIKE N'%Sẵn sổ%'Or [Tình Trạng Pháp Lý] LIKE N'%Sổ sẵn%' Or [Tình Trạng Pháp Lý] LIKE N'%Sổ đẹp%' Or [Tình Trạng Pháp Lý] LIKE N'%SHR%' Or [Tình Trạng Pháp Lý] LIKE N'%Sổ chính chủ%' THEN N'Sổ hồng'
		WHEN ([Tình Trạng Pháp Lý] LIKE N'%Pháp lý%' OR [Tình Trạng Pháp Lý] LIKE N'%Giấy phép%' OR [Tình Trạng Pháp Lý] LIKE N'%Chờ sổ%' OR [Tình Trạng Pháp Lý] LIKE N'%Chưa sổ%') THEN N'Pháp lý và giấy tờ bổ sung'
		WHEN [Tình Trạng Pháp Lý] LIKE N'%Sổ chung' OR [Tình Trạng Pháp Lý] LIKE N'%Đồng sở hữu%' OR [Tình Trạng Pháp Lý] LIKE N'%Sổ chung%' OR [Tình Trạng Pháp Lý] LIKE N'%S? chung%' THEN 'Sổ chung'
        WHEN ([Tình Trạng Pháp Lý] LIKE N'%HĐMB%' OR [Tình Trạng Pháp Lý] LIKE N'%HDMB%' OR [Tình Trạng Pháp Lý] LIKE N'%Hình thức%'  OR [Tình Trạng Pháp Lý] LIKE N'%Hợp đồng%' OR [Tình Trạng Pháp Lý] LIKE N'%Https%') AND [Tình Trạng Pháp Lý] NOT LIKE N'%/%' THEN N'Hợp đồng mua bán'
		WHEN [Tình Trạng Pháp Lý] LIKE N'%VBCN%' OR  [Tình Trạng Pháp Lý] LIKE N'%vi bằng%'THEN N'Vi bằng '
	END;
END;
GO

EXEC CleanLegal;
	--3. Normalize `Tình Trạng Pháp Lý` bar number
	    UPDATE [dbo].[Pháp Lý]
    SET [Tình trạng pháp lý] = CASE
			WHEN [Tình trạng pháp lý] = N'Sổ đỏ' THEN 1 
            WHEN [Tình trạng pháp lý] = N'Sổ hồng' THEN 2
			WHEN [Tình trạng pháp lý] = N'Pháp lý và giấy tờ bổ sung' THEN 3
            WHEN [Tình trạng pháp lý] = N'Sổ chung' THEN 4
			WHEN [Tình trạng pháp lý] = N'Hợp đồng mua bán' THEN 5
            WHEN [Tình trạng pháp lý] =  N'Vi bằng' THEN 6
            ELSE 0
        END;

CREATE PROCEDURE GetFinalResultForLegal
AS
BEGIN
    SELECT * FROM [dbo].[Pháp Lý];
END;
GO

EXEC GetFinalResultForLegal;

--Tabel [Địa chỉ]

CREATE PROCEDURE CleanAddress
AS
BEGIN
    -- Remove rows with NULL values in `Phường/Xã/Thị trấn`
	DELETE FROM [dbo].[Pháp Lý]
	WHERE [Mã Địa Chỉ] IN (
    SELECT [Mã Địa Chỉ]
    FROM [dbo].[Địa chỉ]
    WHERE [Phường/Xã/Thị trấn] IS NULL
);

DELETE FROM [dbo].[Hướng Nhà]
WHERE [Mã Căn Hộ] IN (
    SELECT [Mã Căn Hộ]
    FROM [dbo].[Căn Hộ]
    WHERE [Mã Địa Chỉ] IN (
        SELECT [Mã Địa Chỉ]
        FROM [dbo].[Địa chỉ]
        WHERE [Phường/Xã/Thị trấn] IS NULL
    )
);

	DELETE FROM [dbo].[Căn Hộ]
	WHERE [Mã Địa Chỉ] IN (
    SELECT [Mã Địa Chỉ]
    FROM [dbo].[Địa chỉ]
    WHERE [Phường/Xã/Thị trấn] IS NULL
);

	DELETE FROM [dbo].[Địa chỉ]
	WHERE [Phường/Xã/Thị trấn] IS NULL 
END;
GO

EXEC CleanAddress;

CREATE PROCEDURE GetFinalResultForCleanAddress
AS
BEGIN
    SELECT * FROM [dbo].[Địa chỉ];
END;
GO

EXEC GetFinalResultForCleanAddress;

CREATE PROCEDURE CleanHouseDirection
AS
BEGIN
    -- 1. Remove rows with NULL values in `Hướng nhà`
    DELETE FROM [dbo].[Hướng Nhà]
    WHERE [Hướng nhà] IS NULL;

	--2 Normalize `Hướng nhà` bar number
	UPDATE [Hướng Nhà]
    SET [Hướng nhà] = 
        CASE 
            WHEN [Hướng nhà] = N'Đông' THEN 1
            WHEN [Hướng nhà] = N'Tây' THEN 2
            WHEN [Hướng nhà] = N'Nam' THEN 3
            WHEN [Hướng nhà] = N'Bắc' THEN 4
            WHEN [Hướng nhà] = N'Đông - Bắc' THEN 5
            WHEN [Hướng nhà] = N'Tây - Bắc' THEN 6
            WHEN [Hướng nhà] = N'Đông - Nam' THEN 7
            WHEN [Hướng nhà] = N'Tây - Nam' THEN 8
            ELSE 0
        END;
END;
GO

EXEC CleanHouseDirection;

CREATE PROCEDURE GetFinalResultForHouseDirection
AS
BEGIN
    SELECT * FROM [dbo].[Hướng Nhà];
END;
GO

EXEC GetFinalResultForHouseDirection;
