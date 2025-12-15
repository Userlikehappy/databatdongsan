-- Đối với bảng Căn hộ 
	-- 1. Chuyển đổi vùng từ văn bản sang số, xóa 'm²' và xử lý mọi dấu phẩy
	UPDATE [dbo].[Căn Hộ] 
	SET [Diện tích] = TRY_CAST(REPLACE([Diện tích], ' m²', '') AS DECIMAL(10, 2))
	WHERE ISNUMERIC(REPLACE([Diện tích], ' m²', '')) = 1;

	-- 2. Chuyển đổi vùng từ văn bản sang số, xóa 'm' và xử lý mọi dấu phẩy
	UPDATE [dbo].[Căn Hộ] 
	SET [Mặt tiền] = TRY_CAST(REPLACE([Mặt tiền], 'm', '') AS DECIMAL(10, 2))
	WHERE ISNUMERIC(REPLACE([Mặt tiền], 'm', '')) = 1;

	UPDATE [dbo].[Căn Hộ] 
	SET [Đường vào] = TRY_CAST(REPLACE([Đường vào], 'm', '') AS DECIMAL(10, 2))
	WHERE ISNUMERIC(REPLACE([Đường vào], 'm', '')) = 1;

	-- 3. Loại bỏ các mục trùng lặp dựa trên sự kết hợp giữa tiêu đề và địa chỉ
		WITH CTE AS (
		SELECT *, ROW_NUMBER() OVER (PARTITION BY [Tiêu đề] ORDER BY (SELECT NULL)) AS RowNum
		FROM [dbo].[Căn Hộ]
	)
	DELETE HN
	FROM [dbo].[Hướng Nhà] HN
	INNER JOIN CTE
		ON HN.[Mã Căn Hộ] = CTE.[Mã Căn Hộ]
	WHERE CTE.RowNum > 1;

	WITH CTE AS (
		SELECT *, ROW_NUMBER() OVER (PARTITION BY [Tiêu đề] ORDER BY (SELECT NULL)) AS RowNum
		FROM [dbo].[Căn Hộ]
	)
	DELETE PL
	FROM [dbo].[Pháp Lý] PL
	INNER JOIN CTE
		ON PL.[Mã Địa Chỉ] = CTE.[Mã Căn Hộ]
	WHERE CTE.RowNum > 1;

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



	--4. Chuyển đổi giá từ văn bản sang số bằng cách xử lý các trường hợp khác nhau (ty, trieu)
	UPDATE [dbo].[Căn Hộ] 
	SET [Mức giá] = CASE 
			WHEN [Mức giá] LIKE N'% ty' THEN CAST(REPLACE(LEFT([Mức giá], CHARINDEX(' ', [Mức giá]) - 1), ',', '.') AS DECIMAL(10, 2)) * 1
			WHEN [Mức giá] LIKE N'% trieu' THEN CAST(REPLACE(LEFT([Mức giá], CHARINDEX(' ', [Mức giá]) - 1), ',', '.') AS DECIMAL(10, 2)) * 0.001
			WHEN [Mức giá] LIKE '% trieu/m²' AND ISNUMERIC(REPLACE(REPLACE(TRIM([Mức giá]), ' trieu/m²', ''), ',', '')) = 1 THEN CAST(REPLACE(REPLACE(TRIM([Mức giá]), ' trieu/m²', ''), ',', '') AS FLOAT) * [Diện tích] * 0.001
	END;

	--5. Thay thế giá trị null trong bảng Căn hộ 
		-- 5.1. Nếu "Số phòng" hoặc "Số toilet" là NULL, thì thay thế bằng giá trị còn lại
		UPDATE [dbo].[Căn Hộ]
		SET [Số toilet] = [Số phòng ngủ]
		WHERE [Số toilet] IS NULL AND [Số phòng ngủ] IS NOT NULL;


		-- 5.2. Nếu diện tích lớn hơn 100m2 và mức giá trên 10 tỷ thì số tầng tối thiểu là 3,số phòng lớn hơn 4 thì số tầng tối thiểu là 2.
		UPDATE [dbo].[Căn Hộ]
		SET [Số tầng] = CASE
				-- Điều kiện diện tích lớn hơn 100m² và có hơn 6 phòng ngủ
				WHEN TRY_CAST([Diện tích] AS FLOAT) > 100 AND TRY_CAST([Số phòng ngủ] AS INT) > 6 THEN 5
    
			-- Điều kiện diện tích từ 70 đến 100m² hoặc có từ 3 đến 4 phòng ngủ
			WHEN TRY_CAST([Diện tích] AS FLOAT) BETWEEN 70 AND 100 OR TRY_CAST([Số phòng ngủ] AS INT) BETWEEN 3 AND 4 THEN 4
    
			-- Điều kiện diện tích từ 50 đến 70m² và có từ 1 đến 2 phòng ngủ
			WHEN TRY_CAST([Diện tích] AS FLOAT) BETWEEN 50 AND 70 AND TRY_CAST([Số phòng ngủ] AS INT) <= 2 THEN 3
    
			-- Điều kiện diện tích từ 30 đến 50m² hoặc có từ 1 đến 2 phòng ngủ (các trường hợp còn lại)
			WHEN TRY_CAST([Diện tích] AS FLOAT) BETWEEN 30 AND 50 OR TRY_CAST([Số phòng ngủ] AS INT) <= 2 THEN 2
    
			-- Điều kiện diện tích dưới 30m²
			WHEN TRY_CAST([Diện tích] AS FLOAT) < 30 THEN 1
		END
		WHERE [Số tầng] IS NULL;
		-- 5.3.1 Sử dụng thuật toán KNN để thay thế giá trị cột [ Mặt tiền] từ [Mức giá] và [Diện tích] có giá trị Mặt tiền gần với giá trị đó nhất 
		-- Đếm giá trị Null mặt tiền trước khi xử lí 
			SELECT COUNT(*) AS NullRows FROM [dbo].[Căn Hộ]
		WHERE [Mặt tiền] IS NULL;
		--------------------------
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
			WHERE [Mặt tiền] IS Null;
					-- Đếm giá trị null mặt tiền sau khi xử lí 
			SELECT COUNT(*) AS NullRows FROM [dbo].[Căn Hộ]
		WHERE [Mặt tiền] IS NULL;

		-- 5.3.2  Nếu Tiêu đề là 'biệt thự' và diện tích lớn hơn hoặc bằng 100, gán giá trị Mặt tiền là 8.
		--		  Nếu Tiêu đề là một trong các giá trị 'nhà', 'căn hộ', hoặc 'căn':
		--	   	Nếu diện tích lớn hơn hoặc bằng 100, gán giá trị Mặt tiền là 5, từ 50 đến dưới 100, gán giá trị Mặt tiền là 6. nhỏ hơn 50, gán giá trị Mặt tiền là 2.5
		--		Nếu không thỏa mãn bất kỳ điều kiện nào trên (ví dụ Tiêu đề không khớp), giá trị Mặt tiền sẽ được gán NULL.
			UPDATE [dbo].[Căn Hộ]
			SET [Mặt tiền] = CASE
				WHEN [Tiêu đề] LIKE N'%biệt thự%' AND TRY_CAST([Diện tích] AS FLOAT) >= 100 THEN 8
				WHEN [Tiêu đề] LIKE N'%biệt thự%' AND (TRY_CAST([Diện tích] AS FLOAT) >= 70 AND TRY_CAST([Diện tích] AS FLOAT) < 100) THEN 7
				WHEN [Tiêu đề] IN (N'%nhà%',N'%căn hộ%', N'%căn%') THEN 
					CASE 
						WHEN TRY_CAST([Diện tích] AS FLOAT) >= 100 THEN 5
						WHEN TRY_CAST([Diện tích] AS FLOAT) >= 50 AND TRY_CAST([Diện tích] AS FLOAT) < 100 THEN 6
						WHEN TRY_CAST([Diện tích] AS FLOAT) < 50 THEN 2.5
					END
				WHEN   [Mặt tiền] IS NULL THEN 0 
			END
			WHERE [Mặt tiền] IS NULL;

		--5.5 Xóa giá trị null không cần thiết từ các cột
				DELETE FROM [dbo].[Pháp Lý]
				WHERE [Mã Địa Chỉ] IN (
					SELECT [Mã Địa Chỉ]
					FROM [dbo].[Căn Hộ]
					WHERE [Diện tích] IS NULL
					   OR [Mức giá] IS NULL
					   OR [Mức giá] = N'%Thỏa Thuận%'
					   OR ([Số phòng ngủ] IS NULL AND [Số toilet] IS NULL)
				);

				DELETE FROM [dbo].[Hướng Nhà]
				WHERE [Mã Căn Hộ] IN (
					SELECT [Mã Căn Hộ]
					FROM [dbo].[Căn Hộ]
					WHERE [Diện tích] IS NULL
					   OR [Mức giá] IS NULL
					   OR [Mức giá] = N'%Thỏa Thuận%'
					   OR ([Số phòng ngủ] IS NULL AND [Số toilet] IS NULL)
				);

				DELETE FROM [dbo].[Căn Hộ]
				WHERE [Diện tích] IS NULL
				   OR [Mức giá] IS NULL
				   OR [Mức giá] = N'%Thỏa Thuận%'
				   OR ([Số phòng ngủ] IS NULL AND [Số toilet] IS NULL);

		-- 5.4. Sử dụng thuật toán KNN để thay thế giá trị cột [Đường vào] từ [Mức giá] và [Diện tích]
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

			-- Nếu Đường vào null thì Không có đường vào 
			UPDATE [dbo].[Căn Hộ]
			SET [Đường vào] = '0'
			WHERE [Đường vào] IS NULL;


		-- 5.6: Xử lý các giá trị trống bổ sung trong cột Nội thất 
				UPDATE [dbo].[Căn Hộ]
				SET [Nội thất] = CASE
					WHEN [Nội thất] LIKE N'%bàn giao%' OR [Nội thất] LIKE  N'%Đầy đủ%' OR [Nội thất] LIKE N'%Cao cấp%'  THEN N'Đầy đủ'
					When [Nội thất] LIKE N'%Cơ bản%' THEN N'Cơ bản'
					WHEN [Nội thất] LIKE  N'%không%' OR [Nội thất] LIKE N'%thô%' OR [Nội thất] is null THEN N'Chưa có nội thất'
				END; 

		--5.7 Xóa giá trị null không cần thiết từ các cột 
			DELETE FROM [dbo].[Pháp Lý]
			WHERE [Mã Địa Chỉ] IN (
				SELECT [Mã Địa Chỉ]
				FROM [dbo].[Căn Hộ]
				WHERE [Số tầng] IS NULL
				   OR ([Đường vào] = '0' AND [Mặt tiền] = '0.0')

			);
			DELETE FROM [dbo].[Hướng Nhà]
			WHERE [Mã Căn Hộ] IN (
				SELECT [Mã Căn Hộ]
				FROM [dbo].[Căn Hộ]
				WHERE [Số tầng] IS NULL
				   OR ([Đường vào] = '0' AND [Mặt tiền] = '0.0')
				   OR [Nội thất] IS NULL

			);
			DELETE FROM [dbo].[Pháp Lý]
			WHERE [Mã Địa Chỉ] IN (
				SELECT [Mã Địa Chỉ] FROM [dbo].[Căn Hộ]
				WHERE [Số tầng] IS NULL
				OR [Đường vào] = '0' AND [Mặt tiền] = '0.0'
				OR [Nội thất] IS NULL
)


			DELETE FROM [dbo].[Căn Hộ] 
			WHERE [Số tầng]    IS NULL
			OR [Đường vào] = '0' and [Mặt tiền] = '0.0'
			OR [Nội thất] IS NULL;

		--5.8 Trả kết quả cuối cùng cho bảng 
			SELECT * FROM [dbo].[Căn Hộ]

-- Đối với bảng Pháp Lý 
	--1 Xóa các giá trị null trong cột Tình trạng pháp lý 
	DELETE FROM [dbo].[Pháp Lý] 
	WHERE [Tình Trạng Pháp Lý] IS NULL;

	--2 
	UPDATE [dbo].[Pháp Lý]
	SET [Tình Trạng Pháp Lý] = CASE
        WHEN ([Tình Trạng Pháp Lý] LIKE N'%đỏ%' OR [Tình Trạng Pháp Lý] LIKE N'%sđcc%' OR [Tình Trạng Pháp Lý] LIKE N'%Sổ đỏ%') AND [Tình Trạng Pháp Lý] NOT LIKE N'%/%' THEN N'Sổ đỏ'
		WHEN [Tình Trạng Pháp Lý] LIKE N'%hồng%'  OR [Tình Trạng Pháp Lý] LIKE N'%có sổ%'  OR [Tình Trạng Pháp Lý] LIKE N'%/%' Or [Tình Trạng Pháp lý] LIKE N'%Sổ riêng%' Or [Tình Trạng Pháp Lý] LIKE N'%Đầy đủ%'Or [Tình Trạng Pháp Lý] LIKE N'%Sẵn sổ%'Or [Tình Trạng Pháp Lý] LIKE N'%Sổ sẵn%' Or [Tình Trạng Pháp Lý] LIKE N'%Sổ đẹp%' Or [Tình Trạng Pháp Lý] LIKE N'%SHR%' Or [Tình Trạng Pháp Lý] LIKE N'%Sổ chính chủ%' THEN N'Sổ hồng'
		WHEN ([Tình Trạng Pháp Lý] LIKE N'%Pháp lý%' OR [Tình Trạng Pháp Lý] LIKE N'%Giấy phép%' OR [Tình Trạng Pháp Lý] LIKE N'%Chờ sổ%' OR [Tình Trạng Pháp Lý] LIKE N'%Chưa sổ%') THEN N'Pháp lý và giấy tờ bổ sung'
		When [Tình Trạng Pháp Lý] LIKE N'%Sổ chung' OR [Tình Trạng Pháp Lý] LIKE N'%Đồng sở hữu%' OR [Tình Trạng Pháp Lý] LIKE N'%Sổ chung%' OR [Tình Trạng Pháp Lý] LIKE N'%S? chung%' THEN 'Sổ chung'
        WHEN ([Tình Trạng Pháp Lý] LIKE N'%HĐMB%' OR [Tình Trạng Pháp Lý] LIKE N'%HDMB%' OR [Tình Trạng Pháp Lý] LIKE N'%Hình thức%'  OR [Tình Trạng Pháp Lý] LIKE N'%Hợp đồng%' OR [Tình Trạng Pháp Lý] LIKE N'%Https%') AND [Tình Trạng Pháp Lý] NOT LIKE N'%/%' THEN N'Hợp đồng mua bán'
		WHEN [Tình Trạng Pháp Lý] LIKE N'%VBCN%' OR  [Tình Trạng Pháp Lý] LIKE N'%vi bằng%'THEN N'Vi bằng '
	END;

	--3 Trả kết quả cuối cùng cho bảng 
	SELECT *  FROM [dbo].[Pháp Lý]


-- Đối với bảng Địa chỉ
	--1. Xóa dữ liệu null  
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

	--2  Trả kết quả cuối cùng cho bảng 
	SELECT * FROM [dbo].[Địa chỉ]


-- Đối với bảng Hướng nhà
--1. Xóa dữ liệu null  
	DELETE FROM [dbo].[Hướng Nhà] 
	WHERE [Hướng nhà] IS NULL 

--2  Trả kết quả cuối cùng cho bảng 
	SELECT * FROM [dbo].[Hướng Nhà] 

-- Thêm cột Thông tin nhà ở vào bảng căn hộ và phân loại nhà ở theo tiêu đê 
  SELECT 
    CASE
        WHEN [Tiêu đề] LIKE N'%nhà%'Or  [Tiêu đề] LIKE N'%house' Or [Tiêu đề] LIKE N'%mặt tiền%'THEN N'Nhà'
        WHEN [Tiêu đề]  LIKE N'%Căn%' Or [Tiêu đề] Like N'%Khu'  THEN N'Căn hộ' 
        WHEN [Tiêu đề] LIKE N'%biệt thự%' Or [Tiêu đề] Like N'%BT' Or [Tiêu đề] LIKE N'%siêu phẩm %' THEN N'Biệt thự' 
		WHEN [Tiêu đề]  LIKE N'%Chung cư%' Then N'Chung cư'
		WHEN [Tiêu đề]  LIKE N'%Trọ%' Then N'Trọ '
		WHEN [Tiêu đề] Like N'%Đất%' then N'Đất trống'
    END AS [Thông tin nhà ở ]
FROM [dbo].[Căn Hộ];
