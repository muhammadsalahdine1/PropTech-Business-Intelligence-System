-- Create schema for application tables

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'nawy')
BEGIN
    EXEC('CREATE SCHEMA nawy AUTHORIZATION dbo;');
END
GO