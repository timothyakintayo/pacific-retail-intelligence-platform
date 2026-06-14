-- See if database was created successfully
SHOW DATABASES;

-- See if schema was created successfully
SHOW SCHEMAS IN PACIFICRETAIL_DB;

-- Use created database
USE DATABASE PACIFICRETAIL_DB;

-- Use database and schema
USE pacificretail_db.bronze;

-- Create Stage and connect via Azure SAS token to ADLS Gen 2
CREATE OR REPLACE STAGE landing_stage
URL = 'azure://pacificretailstorageact.blob.core.windows.net/landing/'
CREDENTIALS = (
AZURE_SAS_TOKEN = 'sv=2024-11-04&ss=bfqt&srt=sco&sp=rwdlacupyx&se=2026-03-08T00:45:24Z&st=2026-03-07T16:30:24Z&spr=https&sig=SdVMjz5%2F%2BAAT4IdZJ2TCrHKzZ5Dy%2B%2BnhduXNePMpPy0%3D'
);

-- List all tables in your landing stage in ADLS
ls @LANDING_STAGE;

