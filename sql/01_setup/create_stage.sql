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
AZURE_SAS_TOKEN = 'your token here'
);

-- List all tables in your landing stage in ADLS
ls @LANDING_STAGE;

