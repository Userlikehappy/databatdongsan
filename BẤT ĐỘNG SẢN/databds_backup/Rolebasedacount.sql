-- Đối với tài khoản Admin 
	-- Tạo tài khoản người dùng cho Admin 
	CREATE LOGIN AD WITH PASSWORD = 'Matkhaumanh123'; 

	-- Gắn tài khoản vào cơ sở dữ liệu
	USE [batdongsandatabase] ;
	CREATE USER AD FOR LOGIN AD; 

	-- Tạo các vai trò của Admin 
	CREATE ROLE Role_Admin;

	-- Toàn quyền cho Admin
	GRANT CONTROL ON DATABASE::[batdongsandatabase] TO [Role_Admin];

	-- Gắn vai trò cho tài khoản Admin 
	EXEC sp_addrolemember 'Role_Admin', 'AD'; -- Thay 'AD' thành 'Admin'
	--Kiểm tra phân quyền của Admin 
	USE [batdongsandatabase];
	SELECT 
		dp.name AS [User Name],
		dp.type_desc AS [Principal Type],
		p.permission_name AS [Permission],
		p.state_desc AS [State]
	FROM sys.database_permissions p
	JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
	WHERE dp.name = 'AD';

	-- -Kiểm tra phân quyền  của tài khoản Role_Admin 
	USE [batdongsandatabase];
	SELECT 
		dp.name AS [Role Name],
		p.permission_name AS [Permission],
		p.state_desc AS [State]
	FROM sys.database_permissions p
	JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
	WHERE dp.name = 'Role_Admin';

-- Đối với Data Engineer 
	-- Tạo tài khoản người dùng cho Data Engineer  
	CREATE LOGIN DE WITH PASSWORD = 'Matkhaumanh123';

	-- Gắn tài khoản vào cơ sở dữ liệu
	USE [batdongsandatabase] ;
	CREATE USER DE FOR LOGIN DE;

	-- Tạo các vai trò của Data Engineer 
	CREATE ROLE Role_DE;

	-- Quyền cho Data Engineer
		-- Thao tác trên bảng
		GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO Role_DE; 
		-- Thao tác trên thủ tục và hàm
		GRANT EXECUTE ON SCHEMA::dbo TO Role_DE; 
		-- Tạo thủ tục, hàm
		GRANT CREATE PROCEDURE, CREATE FUNCTION TO Role_DE; 

	-- Gắn vai trò cho tài khoản Data Engineer  
	EXEC sp_addrolemember 'Role_DE', 'DE';

	-- Kiểm tra phân quyền của  Data Engineer  
	USE [batdongsandatabase]
	SELECT 
	dp1.name AS [Role Name], 
	dp2.name AS [Member Name]
	FROM sys.database_role_members drm
	JOIN sys.database_principals dp1 
		ON drm.role_principal_id = dp1.principal_id
	JOIN sys.database_principals dp2 
		ON drm.member_principal_id = dp2.principal_id
	WHERE dp1.name = 'Role_DE';

		-- Kiểm tra vai trò của Role_DE
	SELECT 
		dp.name AS PrincipalName,            
		ISNULL(o.name, 'Database-wide') AS ObjectName,
		p.permission_name AS Permission,    -- Tên quyền (SELECT, INSERT, EXECUTE, ...)
		p.state_desc AS PermissionState     -- Trạng thái quyền (GRANT, DENY, REVOKE)
	FROM sys.database_permissions p
	LEFT JOIN sys.objects o 
		ON p.major_id = o.object_id         -- Ghép nối với các đối tượng trong cơ sở dữ liệu
	JOIN sys.database_principals dp 
		ON p.grantee_principal_id = dp.principal_id  -- Ghép nối với vai trò hoặc tài khoản được cấp quyền
	WHERE dp.name = 'Role_DE';              --

-- Đối với Data Analysis
	-- Tạo tài khoản người dùng cho Data Analysis  
	CREATE LOGIN DA WITH PASSWORD = 'Matkhaumanh123';

	-- Gắn tài khoản vào cơ sở dữ liệu
	USE [batdongsandatabase] ;
	CREATE USER DA FOR LOGIN DA;

	-- Tạo các vai trò của Data Analysis  
	CREATE ROLE Role_DA;

	-- Quyền cho DA
	GRANT SELECT ON SCHEMA::dbo TO Role_DA; -- Chỉ quyền truy vấn
	-- Gắn vai trò cho tài khoản Data Analysis 
	EXEC sp_addrolemember 'Role_DA', 'DA';

	-- Kiểm tra phân quyền của  Data Analysis  
	USE [batdongsandatabase]
	SELECT 
	dp1.name AS [Role Name], 
	dp2.name AS [Member Name]
	FROM sys.database_role_members drm
	JOIN sys.database_principals dp1 
		ON drm.role_principal_id = dp1.principal_id
	JOIN sys.database_principals dp2 
		ON drm.member_principal_id = dp2.principal_id
	WHERE dp1.name = 'Role_DA';

		-- Kiểm tra vai trò của Role_DA
	SELECT 
		dp.name AS PrincipalName,            
		ISNULL(o.name, 'Database-wide') AS ObjectName,
		p.permission_name AS Permission,    -- Tên quyền (SELECT, INSERT, EXECUTE, ...)
		p.state_desc AS PermissionState     -- Trạng thái quyền (GRANT, DENY, REVOKE)
	FROM sys.database_permissions p
	LEFT JOIN sys.objects o 
		ON p.major_id = o.object_id         -- Ghép nối với các đối tượng trong cơ sở dữ liệu
	JOIN sys.database_principals dp 
		ON p.grantee_principal_id = dp.principal_id  -- Ghép nối với vai trò hoặc tài khoản được cấp quyền
	WHERE dp.name = 'Role_DA';  

-- Kiểm tra vai trò của từng thành viên một lần nữa: 
SELECT 
    dp.name AS PrincipalName,
    p.permission_name AS Permission,
    p.state_desc AS PermissionState
FROM sys.database_permissions p
LEFT JOIN sys.objects o ON p.major_id = o.object_id
JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
WHERE dp.name IN ('Role_Admin', 'Role_DE', 'Role_DA');
