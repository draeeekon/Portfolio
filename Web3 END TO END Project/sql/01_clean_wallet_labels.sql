-- 01_clean_wallet_labels.sql
-- Purpose:
--   Clean the raw Kaggle fraud-label table and create one row per wallet.
--
-- Cleaning decisions:
--   1. Trim whitespace from wallet addresses.
--   2. Convert addresses to lowercase to match Google's Ethereum tables.
--   3. Cast FLAG to INT64.
--   4. Remove rows with NULL address/label.
--   5. Deduplicate repeated wallet addresses.
--   6. Exclude wallets that have conflicting fraud labels.
--
-- Output:
--   ethereum-fraud-analysis.web3_fraud_us.wallet_labels

CREATE OR REPLACE TABLE
    `ethereum-fraud-analysis.web3_fraud_us.wallet_labels`
AS

WITH cleaned AS (
    SELECT
        LOWER(TRIM(Address)) AS address,
        CAST(FLAG AS INT64) AS fraud_flag
    FROM
        `ethereum-fraud-analysis.web3_fraud_us.fraud_labels`
    WHERE
        Address IS NOT NULL
        AND FLAG IS NOT NULL
),

wallet_check AS (
    SELECT
        address,
        COUNT(*) AS row_count,
        COUNT(DISTINCT fraud_flag) AS unique_labels,
        MAX(fraud_flag) AS fraud_flag
    FROM cleaned
    GROUP BY address
)

SELECT
    address,
    fraud_flag
FROM wallet_check
WHERE unique_labels = 1;


-- Validation: class distribution after cleaning/deduplication
SELECT
    fraud_flag,
    COUNT(*) AS wallet_count
FROM
    `ethereum-fraud-analysis.web3_fraud_us.wallet_labels`
GROUP BY fraud_flag
ORDER BY fraud_flag;


-- Validation: confirm one row per wallet
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT address) AS unique_wallets
FROM
    `ethereum-fraud-analysis.web3_fraud_us.wallet_labels`;
