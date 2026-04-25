USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    PRINT '==============================';
    PRINT 'Loading Bronze Layer';
    PRINT '==============================';

    PRINT 'Truncating Tables...';
    TRUNCATE TABLE bronze.crm_cust_info;
    TRUNCATE TABLE bronze.crm_prd_info;
    TRUNCATE TABLE bronze.crm_sales_details;
    TRUNCATE TABLE bronze.erp_cust_az12;
    TRUNCATE TABLE bronze.erp_loc_a101;
    TRUNCATE TABLE bronze.erp_px_cat_g1v2;

    PRINT 'Loading CRM Tables...';
    BULK INSERT bronze.crm_cust_info
    FROM 'C:\Users\Aayush\Desktop\sql-data-warehouse-project-main\datasets\source_crm\cust_info.csv'
    WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);

    BULK INSERT bronze.crm_prd_info
    FROM 'C:\Users\Aayush\Desktop\sql-data-warehouse-project-main\datasets\source_crm\prd_info.csv'
    WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);

    BULK INSERT bronze.crm_sales_details
    FROM 'C:\Users\Aayush\Desktop\sql-data-warehouse-project-main\datasets\source_crm\sales_details.csv'
    WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);

    PRINT 'Loading ERP Tables...';
    BULK INSERT bronze.erp_cust_az12
    FROM 'C:\Users\Aayush\Desktop\sql-data-warehouse-project-main\datasets\source_erp\CUST_AZ12.csv'
    WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);

    BULK INSERT bronze.erp_loc_a101
    FROM 'C:\Users\Aayush\Desktop\sql-data-warehouse-project-main\datasets\source_erp\LOC_A101.csv'
    WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);

    BULK INSERT bronze.erp_px_cat_g1v2
    FROM 'C:\Users\Aayush\Desktop\sql-data-warehouse-project-main\datasets\source_erp\PX_CAT_G1V2.csv'
    WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);

    PRINT 'Bronze Layer Loaded Successfully!';
END;
GO