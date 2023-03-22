USE [master]
-- Declare variables
DECLARE @BackupPath NVARCHAR(500) = 'E:\DBBackup\SQL2\'; -- The path of the folder containing .bak files
DECLARE @DataPath NVARCHAR(500) = 'E:\SQL_2019_DB\DATA\'; -- The path of the SQL Server data directory
DECLARE @BackupFile NVARCHAR(500); -- The name of the backup file
DECLARE @DatabaseName NVARCHAR(500); -- The name of the database to be restored
DECLARE @SQL NVARCHAR(MAX); -- The dynamic SQL statement
DECLARE @dbname NVARCHAR(255);
DECLARE @LogicalNameSQL NVARCHAR(255);
DECLARE @LogicalName NVARCHAR(255);

-- Create a temporary table to store the backup file names
CREATE TABLE #BackupFiles (FileName NVARCHAR(500));
-- Insert the backup file names into the temporary table using xp_cmdshell command
INSERT INTO #BackupFiles (FileName)
EXEC xp_cmdshell 'dir /b E:\DBBackup\SQL2\*.bak';

-- Delete any NULL values from the temporary table
DELETE FROM #BackupFiles WHERE FileName IS NULL;

-- Loop through each backup file name in the temporary table
WHILE EXISTS (SELECT * FROM #BackupFiles)
BEGIN

    -- Select the first backup file name and assign it to a variable
    SELECT TOP 1 @BackupFile = FileName FROM #BackupFiles;

    -- Extract the database name from the backup file name by removing the .bak extension
    SET @DatabaseName = REPLACE(@BackupFile, '.bak', '');
	SET @dbname = SUBSTRING(@BackupFile,1,LEN(@BackupFile)-37);
	
	CREATE TABLE #fileListTable(
    [LogicalName]           NVARCHAR(128),
    [PhysicalName]          NVARCHAR(260),
    [Type]                  CHAR(1),
    [FileGroupName]         NVARCHAR(128),
    [Size]                  NUMERIC(20,0),
    [MaxSize]               NUMERIC(20,0),
    [FileID]                BIGINT,
    [CreateLSN]             NUMERIC(25,0),
    [DropLSN]               NUMERIC(25,0),
    [UniqueID]              UNIQUEIDENTIFIER,
    [ReadOnlyLSN]           NUMERIC(25,0),
    [ReadWriteLSN]          NUMERIC(25,0),
    [BackupSizeInBytes]     BIGINT,
    [SourceBlockSize]       INT,
    [FileGroupID]           INT,
    [LogGroupGUID]          UNIQUEIDENTIFIER,
    [DifferentialBaseLSN]   NUMERIC(25,0),
    [DifferentialBaseGUID]  UNIQUEIDENTIFIER,
    [IsReadOnly]            BIT,
    [IsPresent]             BIT,
    [TDEThumbprint]         VARBINARY(32)
)


	SET @LogicalNameSQL = 'RESTORE FILELISTONLY FROM Disk ='''+@BackupPath+@BackupFile+'''';
	PRINT 'LogicalNameSQL = '+@LogicalNameSQL;
	INSERT INTO #fileListTable EXEC(@LogicalNameSQL);
	DECLARE @logicalData NVARCHAR(255)
	DECLARE @logicalLog NVARCHAR(255)
	SELECT @logicalData = LogicalName FROM #fileListTable WHERE Type = 'D' AND FileGroupName = 'PRIMARY';
	SELECT @logicalLog = LogicalName FROM #fileListTable WHERE Type = 'L';
    -- Build a dynamic SQL statement to restore the database from the backup file with MOVE option
    SET @SQL = 'RESTORE DATABASE ' + QUOTENAME(@dbname) +
               ' FROM DISK = ''' + @BackupPath + @BackupFile + '''' +
               ' WITH FILE=1,PARTIAL,REPLACE, MOVE ''' + @logicalData + ''' TO ''' + @DataPath + @dbname + '_DATA.mdf''' +
               ', MOVE ''' + @logicalLog + ''' TO ''' + @DataPath + @dbname + '_LOG.ldf'',NOUNLOAD,STATS=5';

    -- Print and execute the dynamic SQL statement
    
	PRINT 'fileName = '+@BackupFile;
	PRINT 'databaseName = '+@DatabaseName;
	PRINT 'dbname = '+@dbname;
	PRINT 'LogicalNameData = '+@logicalData;
	PRINT 'LogicalNameLog = '+@logicalLog;
	PRINT 'SQLcmd = '+@SQL;
    EXEC sp_executesql @SQL;
	DROP TABLE #filelistTable;
    -- Delete the backup file name from the temporary table
    DELETE FROM #BackupFiles WHERE FileName = @BackupFile;

END

-- Drop the temporary table
DROP TABLE #BackupFiles;
