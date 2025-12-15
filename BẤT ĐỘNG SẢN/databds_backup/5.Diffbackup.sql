--Tạo thủ tục cho Differential Backup

CREATE PROCEDURE BackupDifferential_QUANLYBDS
    @BackupPath NVARCHAR(500)
AS
BEGIN
    BEGIN TRY
        -- Tạo tên file backup động với timestamp
        DECLARE @BackupFile NVARCHAR(500)

        -- Kiểm tra @BackupPath có hợp lệ không
        IF @BackupPath IS NULL OR LTRIM(RTRIM(@BackupPath)) = ''
        BEGIN
            PRINT 'Backup path is invalid.';
            RETURN;
        END

        SET @BackupFile = @BackupPath + N'QUANLYBDS_DIFF_' + 
                          REPLACE(CONVERT(VARCHAR(20), GETDATE(), 120), ':', '-') + '.bak'

        -- Thực hiện backup khác biệt
        BACKUP DATABASE batdongsandatabase 
        TO DISK = @BackupFile
        WITH DIFFERENTIAL, INIT, NAME = 'Differential Backup of QUANLYBDS',
             STATS = 10;

        -- In thông báo thành công
        PRINT 'Differential backup completed successfully. Backup file: ' + @BackupFile
    END TRY
    BEGIN CATCH
        -- Xử lý lỗi nếu xảy ra
        PRINT 'An error occurred during the differential backup.';
        THROW;
    END CATCH
END;
GO

USE msdb;
GO

--Tạo Job tự động chạy Differential Backup hàng ngày
BEGIN TRANSACTION
    DECLARE @JobID UNIQUEIDENTIFIER; -- Dùng UNIQUEIDENTIFIER thay cho NVARCHAR(36)
    DECLARE @ScheduleID INT;

    -- Xóa job cũ nếu tồn tại
    IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = N'Daily_QUANLYBDS_DiffBackup')
    BEGIN
        EXEC msdb.dbo.sp_delete_job 
            @job_name = N'Daily_QUANLYBDS_DiffBackup', 
            @delete_unused_schedule = 1;
    END

    -- Tạo job mới
    EXEC msdb.dbo.sp_add_job
        @job_name = N'Daily_QUANLYBDS_DiffBackup', -- Tên job
        @enabled = 1, -- Kích hoạt job
        @description = N'Sao lưu khác biệt hàng ngày cho cơ sở dữ liệu QUANLYBDS', -- Mô tả job
        @start_step_id = 1, -- Bước khởi đầu
        @job_id = @JobID OUTPUT;

    -- Thêm bước thực thi cho job
    EXEC msdb.dbo.sp_add_jobstep
        @job_id = @JobID, -- ID của job
        @step_name = N'Thực hiện sao lưu khác biệt', -- Tên bước
        @subsystem = N'TSQL', -- Subsystem là T-SQL
        @command = N'
            BACKUP DATABASE [QUANLYBDS]
            TO DISK = ''C:\Users\DELL\Năm 3\Quản trị cơ sở dữ liệu\Backup\QUANLYBDS_DIFF.bak''
            WITH DIFFERENTIAL, INIT, SKIP, NOREWIND, NOUNLOAD, STATS = 10;', -- Lệnh backup
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
		@schedule_name = N'DailyDiffBackupSchedule', -- Tên lịch biểu
		@enabled = 1, -- Kích hoạt lịch biểu
		@freq_type = 4, -- Loại lịch: hàng ngày
		@freq_interval = 1, -- Thực thi mỗi 1 ngày
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

--Chạy Job ngay lập tức
EXEC msdb.dbo.sp_start_job @job_name = N'Daily_QUANLYBDS_DiffBackup';
GO

--------------------------------------------------
--Thực hiện Full Backup trước:
BACKUP DATABASE batdongsandatabase
TO DISK = 'D:\QTCSDL-BDS\Backup\batdongsandatabase_FULL.bak'
WITH INIT, -- Ghi đè file backup nếu đã tồn tại
     FORMAT, -- Tạo file backup mới
     SKIP, 
     NOREWIND, 
     NOUNLOAD, 
     STATS = 10; -- Hiển thị trạng thái tiến trình mỗi 10%

--Thực hiện Differential Backup:
BACKUP DATABASE batdongsandatabase
TO DISK = 'D:\QTCSDL-BDS\Backup\batdongsandatabase_DIFF.bak'
WITH DIFFERENTIAL, 
     INIT, -- Ghi đè file backup nếu đã tồn tại
     SKIP, 
     NOREWIND, 
     NOUNLOAD, 
     STATS = 10; -- Hiển thị trạng thái tiến trình mỗi 10%

--Kiem tra ket qua 
SELECT 
    database_name AS DatabaseName,
    backup_start_date AS BackupStartTime,
    backup_finish_date AS BackupFinishTime,
    CASE type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Transaction Log'
    END AS BackupType,
    physical_device_name AS BackupLocation,
    CAST(backup_size / 1024.0 / 1024.0 AS DECIMAL(10, 2)) AS BackupSizeMB
FROM msdb.dbo.backupset bs
INNER JOIN msdb.dbo.backupmediafamily bmf
    ON bs.media_set_id = bmf.media_set_id
WHERE database_name = 'batdongsandatabase'
ORDER BY backup_start_date DESC;
