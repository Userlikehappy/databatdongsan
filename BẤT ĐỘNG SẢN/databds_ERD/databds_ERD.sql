-- THEM COT  [STT] 
Alter Table [dbo].[database$]
Add STT Int Identity(1, 1)

-- THEM COT CO [Mã địa chỉ] 
ALTER TABLE [dbo].[database$]
ADD [Mã Địa Chỉ] NVARCHAR(100);

WITH RowNumberCTE AS (
    SELECT 
        [STT],
        CONCAT('diachi_', ROW_NUMBER() OVER (ORDER BY [STT])) AS [Mã địa chỉ],
        -- Chọn thêm các cột khác nếu cần
        ROW_NUMBER() OVER (ORDER BY [STT]) AS RowNum
    FROM [dbo].[database$]
)
UPDATE [dbo].[database$]
SET [Mã Địa Chỉ] = RowNumberCTE.[Mã Địa Chỉ]
FROM RowNumberCTE
WHERE [dbo].[database$].[STT] = RowNumberCTE.[STT];

-- THEM COT CO [Mã Căn Hộ] 
ALTER TABLE [dbo].[database$]
ADD [Mã Căn Hộ] NVARCHAR(100);

WITH RowNumberCTE AS (
    SELECT 
        [STT],
        CONCAT('canho_', ROW_NUMBER() OVER (ORDER BY [STT])) AS [Mã Căn Hộ],
        -- Chọn thêm các cột khác nếu cần
        ROW_NUMBER() OVER (ORDER BY [STT]) AS RowNum
    FROM [dbo].[database$]
)
UPDATE [dbo].[database$]
SET [Mã Căn Hộ] = RowNumberCTE.[Mã Căn Hộ]
FROM RowNumberCTE
WHERE [dbo].[database$].[STT] = RowNumberCTE.[STT];

-- THU TUC TACH COT 

CREATE TABLE [Địa chỉ] (
     [Mã Địa Chỉ] NVARCHAR(100) PRIMARY KEY, -- Cột tự động tăng
     [Tỉnh/Thành] NVARCHAR(100) ,
     [Quận/Huyện] NVARCHAR(100),
     [Phường/Xã/Thị trấn] NVARCHAR(100)
    );

CREATE TABLE [Căn Hộ] (
    [Mã Căn Hộ]  NVARCHAR(100) PRIMARY KEY,
    [Mã Địa Chỉ]  NVARCHAR(100) UNIQUE,
	[Tiêu đề] NVARCHAR(255),
	[Mức giá] NVARCHAR(25 ),
	[Mặt tiền] NVARCHAR(25 ),
	[Đường vào] NVARCHAR(25 ),
    [Diện Tích] NVARCHAR(25 ),
	[Số Tầng] NVARCHAR(255),
    [Số Phòng Ngủ] NVARCHAR(255),
    [Số Toilet] NVARCHAR(255),
    [Nội Thất] NVARCHAR(255),
    FOREIGN KEY ([Mã Địa Chỉ]) REFERENCES [Địa chỉ]([Mã Địa Chỉ]) ON DELETE CASCADE
);


CREATE TABLE [Hướng Nhà] (
    [Mã hướng nhà] NVARCHAR(255) PRIMARY KEY,
    [Mã Căn Hộ] NVARCHAR(100),
    [Hướng Nhà] NVARCHAR(255),
    FOREIGN KEY ([Mã Căn Hộ]) REFERENCES [Căn Hộ]([Mã Căn Hộ]) ON DELETE CASCADE
);

CREATE TABLE [Pháp Lý] (
    [Mã Pháp lý] NVARCHAR(255) PRIMARY KEY,
    [Mã Địa Chỉ]  NVARCHAR(100),
    [Tình trạng pháp lý] NVARCHAR(255),
    FOREIGN KEY ([Mã Địa Chỉ]) REFERENCES [Căn Hộ]([Mã Địa Chỉ]) ON DELETE CASCADE
);
-- TẠO HÀM NHẬP DỮ LIỆU
			-- INSERT DỮ LIỆU VÀO BẢNG [Địa chỉ] 
		INSERT INTO [Địa chỉ] ([Mã Địa Chỉ], [Tỉnh/Thành], [Quận/Huyện], [Phường/Xã/Thị trấn])
		SELECT 
			[Mã Địa Chỉ],
			[Tỉnh/Thành], 
			[Quận/Huyện], 
			[Phường/Xã/Thị trấn]
		FROM [dbo].[database$];

			-- INSERT DỮ LIỆU VÀO BẢNG [Căn Hộ] 
		INSERT INTO [Căn Hộ] ([Mã Căn Hộ],[Mã Địa Chỉ], [Tiêu đề], [Mức giá], [Mặt tiền],[Đường vào], [Diện Tích], [Số Tầng], [Số Phòng Ngủ], [Số Toilet], [Nội Thất])
		SELECT 
			[Mã Căn Hộ],
			[Mã Địa Chỉ],
			[Tiêu đề],
			[Mức giá] ,
			[Mặt tiền],
			[Đường vào],
			[Diện Tích],
			[Số Tầng],
			[Số Phòng Ngủ],
			[Số Toilet],
			[Nội Thất]
		FROM [database$];

			-- INSERT DỮ LIỆU VÀO BẢNG [Hướng Nhà] 
		INSERT INTO [Hướng Nhà] ([Mã hướng nhà], [Mã Căn Hộ], [Hướng Nhà])
		SELECT 
			CONCAT('huongnha_', ROW_NUMBER() OVER (ORDER BY [STT])) AS [Mã hướng nhà],
			[Mã Căn Hộ], 
			[Hướng Nhà]
		FROM [database$];

			 -- INSERT DỮ LIỆU VÀO BẢNG [Pháp Lý] 
		INSERT INTO [Pháp Lý] ([Mã Pháp lý], [Mã Địa Chỉ], [Tình trạng pháp lý])
		SELECT 
			CONCAT('phaply_', ROW_NUMBER() OVER (ORDER BY [STT] ASC)) AS [Mã Pháp lý],
			[Mã Địa Chỉ],
			[Tình trạng pháp lý]
		FROM [dbo].[database$];

