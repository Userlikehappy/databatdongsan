-- FULL Backup
--Tạo thủ tục sao lưu
CREATE PROCEDURE BackupFull_QUANLYBDS
    @BackupPath NVARCHAR(500)
AS
BEGIN
    BEGIN TRY
        -- Tạo tên file backup động với timestamp
        DECLARE @BackupFile NVARCHAR(500)
        DECLARE @BackupPath NVARCHAR(500)

        -- Kiểm tra @BackupPath có hợp lệ không
        IF @BackupPath IS NULL OR LTRIM(RTRIM(@BackupPath)) = ''
        BEGIN
            PRINT 'Backup path is invalid.';
            RETURN;
        END

        SET @BackupFile = @BackupPath + N'QUANLYBDS' + 
                          REPLACE(CONVERT(VARCHAR(20), GETDATE(), 120), ':', '-') + '.bak'

        -- Thực hiện backup đầy đủ
        BACKUP DATABASE batdongsandatabase 
        TO DISK = @BackupFile
        WITH FORMAT, INIT, NAME = 'Full Backup of QUANLYBDS',
             STATS = 10;

        -- In thông báo thành công
        PRINT 'Full backup completed successfully. Backup file: ' + @BackupFile
    END TRY
    BEGIN CATCH
        -- Xử lý lỗi nếu xảy ra
        PRINT 'An error occurred during the full backup.';
        THROW;
    END CATCH
END;
GO

-- Gọi thủ tục với đường dẫn backup hợp lệ
EXEC BackupFull_QUANLYBDS @BackupPath = 'D:\QTCSDL-BDS\Backup\';

------------------------------------------------------------------------------------------------------
-- Tạo Job tự động chạy sao lưu hàng tuần
USE msdb;
GO

BEGIN TRANSACTION
    DECLARE @JobID UNIQUEIDENTIFIER; -- Dùng UNIQUEIDENTIFIER thay cho NVARCHAR(36)
    DECLARE @ScheduleID INT;

    -- Xóa job cũ nếu tồn tại
    IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = N'Weekly_QUANLYBDS_Backup')
    BEGIN
        EXEC msdb.dbo.sp_delete_job 
            @job_name = N'Weekly_QUANLYBDS_Backup', 
            @delete_unused_schedule = 1;
    END

    -- Tạo job mới
    EXEC msdb.dbo.sp_add_job
        @job_name = N'Weekly_QUANLYBDS_Backup', -- Tên job
        @enabled = 1, -- Kích hoạt job
        @description = N'Sao lưu hàng tuần cho cơ sở dữ liệu QUANLYBDS', -- Mô tả job
        @start_step_id = 1, -- Bước khởi đầu
        @job_id = @JobID OUTPUT;

    -- Thêm bước thực thi cho job
    EXEC msdb.dbo.sp_add_jobstep
        @job_id = @JobID, -- ID của job
        @step_name = N'Thực hiện sao lưu đầy đủ', -- Tên bước
        @subsystem = N'TSQL', -- Subsystem là T-SQL
        @command = N'
            BACKUP DATABASE [QUANLYBDS]
            TO DISK = ''C:\Users\DELL\Năm 3\Quản trị cơ sở dữ liệu\Backup\QUANLYBDS_Full.bak''
            WITH FORMAT, INIT, SKIP, NOREWIND, NOUNLOAD, STATS = 10;', -- Lệnh backup
        @on_success_action = 1, -- Tiếp tục thực thi bước kế tiếp (nếu có)
        @on_fail_action = 2, -- Dừng job nếu thất bại
        @retry_attempts = 3, -- Số lần thử lại nếu thất bại
        @retry_interval = 5, -- Thời gian chờ giữa các lần thử lại (phút)
        @database_name = N'master'; -- Thực thi trên cơ sở dữ liệu master

    -- Tạo lịch biểu mới
	DECLARE @ActiveStartDate INT;

-- Tính toán ngày hiện tại dưới dạng số nguyên YYYYMMDD
	SET @ActiveStartDate = YEAR(GETDATE()) * 10000 + MONTH(GETDATE()) * 100 + DAY(GETDATE());

	EXEC msdb.dbo.sp_add_schedule
		@schedule_name = N'WeeklyBackupSchedule', -- Tên lịch biểu
		@enabled = 1, -- Kích hoạt lịch biểu
		@freq_type = 8, -- Loại lịch: hàng tuần
		@freq_interval = 1, -- Ngày thực thi: Chủ nhật
		@freq_recurrence_factor = 1, -- Thực thi mỗi 1 tuần
		@active_start_date = @ActiveStartDate, -- Bắt đầu từ ngày hiện tại
		@active_start_time = 120000, -- Thời gian bắt đầu: 12:00:00
		@schedule_id = @ScheduleID OUTPUT;

    -- Gắn lịch biểu vào job
    EXEC msdb.dbo.sp_attach_schedule
        @job_id = @JobID, -- ID của job
        @schedule_id = @ScheduleID; -- ID của lịch biểu

    -- Gắn job vào SQL Server Agent
    EXEC msdb.dbo.sp_add_jobserver
        @job_id = @JobID; -- ID của job

COMMIT TRANSACTION;
GO

--------------------------------------------------------------------------------------------------------------------
----Kiểm tra lịch sử backup (quản lý)
IF OBJECT_ID('dbo.ManageBackupHistory', 'TF') IS NOT NULL
    DROP FUNCTION dbo.ManageBackupHistory;
GO
-- Xóa hàm nếu đã tồn tại
IF OBJECT_ID('dbo.ManageBackupHistory', 'TF') IS NOT NULL
    DROP FUNCTION dbo.ManageBackupHistory;
GO

-- Tạo hàm trả về lịch sử backup
CREATE FUNCTION dbo.ManageBackupHistory(@DatabaseName NVARCHAR(128))
RETURNS TABLE
AS
RETURN
(
    SELECT 
        bs.database_name AS DatabaseName,
        bs.backup_start_date AS BackupStartTime,
        bs.backup_finish_date AS BackupFinishTime,
        CASE bs.type
            WHEN 'D' THEN 'Full'           -- Full Backup
            WHEN 'I' THEN 'Differential'   -- Differential Backup
            WHEN 'L' THEN 'Log'            -- Transaction Log Backup
        END AS BackupType,
        bmf.physical_device_name AS BackupLocation,
        CAST(bs.backup_size / 1024.0 / 1024.0 AS DECIMAL(10, 2)) AS BackupSizeMB -- Backup Size in MB
    FROM msdb.dbo.backupset bs
    INNER JOIN msdb.dbo.backupmediafamily bmf
        ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name = @DatabaseName
);
GO

-- Sử dụng hàm để lấy lịch sử backup của cơ sở dữ liệu
SELECT *
FROM dbo.ManageBackupHistory('QUANLYBDS')
ORDER BY BackupStartTime DESC;



--------------------------------------------------------------------------------------------------------------------
--Xem qua lịch sử của các job
SELECT * 
FROM sys.objects
WHERE type = 'P' AND name = 'GetJobHistory';

DROP PROCEDURE GetJobHistory
CREATE PROCEDURE GetJobHistory
AS
BEGIN
    SELECT 
        j.name AS JobName,
        h.run_date AS RunDate,
        h.run_time AS RunTime,
        h.run_duration AS RunDuration,
        CASE h.run_status
            WHEN 1 THEN 'Succeeded'
            WHEN 0 THEN 'Failed'
            ELSE 'Unknown'
        END AS Status,
        h.message AS Message
    FROM msdb.dbo.sysjobs AS j
    LEFT JOIN msdb.dbo.sysjobhistory AS h
        ON j.job_id = h.job_id
    ORDER BY h.run_date DESC, h.run_time DESC
END

EXEC GetJobHistory


--------Chạy job ngay lập tức
EXEC msdb.dbo.sp_start_job @job_name = N'Weekly_QUANLYBDS_Backup';
GO


