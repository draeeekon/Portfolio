-- 03_create_modelling_population.sql
-- Purpose:
--   Create the final wallet population used for feature engineering and ML.
--
-- Inclusion criteria:
--   1. Wallet address has a valid Ethereum format.
--   2. Wallet has at least one observable activity record before 2020-07-15
--      in transactions, token transfers, or traces.
--
-- Why:
--   Completely unmatched wallets are excluded rather than being assigned
--   zero activity, because missing blockchain coverage is concentrated in
--   the fraud class and could otherwise become a misleading model signal.
--
-- Output:
--   ethereum-fraud-analysis.web3_fraud_us.modelling_wallets

CREATE OR REPLACE TABLE
    `ethereum-fraud-analysis.web3_fraud_us.modelling_wallets`
AS

WITH valid_labels AS (
    SELECT
        address,
        fraud_flag
    FROM
        `ethereum-fraud-analysis.web3_fraud_us.wallet_labels`
    WHERE
        REGEXP_CONTAINS(address, r'^0x[0-9a-f]{40}$')
),

transaction_wallets AS (

    SELECT DISTINCT
        t.from_address AS address
    FROM
        `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.transactions_by_from_address` t
    INNER JOIN valid_labels l
        ON t.from_address = l.address
    WHERE
        t.block_timestamp < TIMESTAMP('2020-07-15')

    UNION DISTINCT

    SELECT DISTINCT
        t.to_address AS address
    FROM
        `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.transactions_by_to_address` t
    INNER JOIN valid_labels l
        ON t.to_address = l.address
    WHERE
        t.block_timestamp < TIMESTAMP('2020-07-15')
),

token_wallets AS (

    SELECT DISTINCT
        t.from_address AS address
    FROM
        `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.token_transfers` t
    INNER JOIN valid_labels l
        ON t.from_address = l.address
    WHERE
        t.block_timestamp < TIMESTAMP('2020-07-15')

    UNION DISTINCT

    SELECT DISTINCT
        t.to_address AS address
    FROM
        `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.token_transfers` t
    INNER JOIN valid_labels l
        ON t.to_address = l.address
    WHERE
        t.block_timestamp < TIMESTAMP('2020-07-15')
),

trace_wallets AS (

    SELECT DISTINCT
        tr.action.from_address AS address
    FROM
        `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.traces` tr
    INNER JOIN valid_labels l
        ON tr.action.from_address = l.address
    WHERE
        tr.block_timestamp < TIMESTAMP('2020-07-15')

    UNION DISTINCT

    SELECT DISTINCT
        tr.action.to_address AS address
    FROM
        `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.traces` tr
    INNER JOIN valid_labels l
        ON tr.action.to_address = l.address
    WHERE
        tr.block_timestamp < TIMESTAMP('2020-07-15')
),

active_wallets AS (
    SELECT address FROM transaction_wallets

    UNION DISTINCT

    SELECT address FROM token_wallets

    UNION DISTINCT

    SELECT address FROM trace_wallets
)

SELECT
    l.address,
    l.fraud_flag
FROM
    valid_labels l
INNER JOIN
    active_wallets a
    ON l.address = a.address;


-- Validation: final class counts
SELECT
    fraud_flag,
    COUNT(*) AS wallet_count
FROM
    `ethereum-fraud-analysis.web3_fraud_us.modelling_wallets`
GROUP BY fraud_flag
ORDER BY fraud_flag;


-- Validation: total modelling population
SELECT
    COUNT(*) AS total_modelling_wallets,
    COUNT(DISTINCT address) AS unique_modelling_wallets
FROM
    `ethereum-fraud-analysis.web3_fraud_us.modelling_wallets`;
