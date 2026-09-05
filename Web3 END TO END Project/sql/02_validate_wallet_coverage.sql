-- 02_validate_wallet_coverage.sql
-- Purpose:
--   Validate whether labelled wallets can be found in Ethereum activity data
--   before the project cutoff.
--
-- Sources checked:
--   1. Top-level Ethereum transactions
--   2. ERC token transfers
--   3. EVM traces / internal actions
--
-- Project cutoff currently used:
--   2020-07-15
--
-- Notes:
--   - Only syntactically valid Ethereum addresses are included in the coverage audit.
--   - This query does NOT create the modelling population. It is a diagnostic step.

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

coverage AS (
    SELECT
        l.address,
        l.fraud_flag,
        IF(t.address IS NOT NULL, 1, 0) AS found_transactions,
        IF(tok.address IS NOT NULL, 1, 0) AS found_tokens,
        IF(tr.address IS NOT NULL, 1, 0) AS found_traces
    FROM valid_labels l

    LEFT JOIN transaction_wallets t
        ON l.address = t.address

    LEFT JOIN token_wallets tok
        ON l.address = tok.address

    LEFT JOIN trace_wallets tr
        ON l.address = tr.address
)

SELECT
    fraud_flag,
    COUNT(*) AS total_wallets,
    COUNTIF(found_transactions = 1) AS found_transactions,
    COUNTIF(found_tokens = 1) AS found_token_transfers,
    COUNTIF(found_traces = 1) AS found_traces,

    COUNTIF(
        found_transactions = 1
        OR found_tokens = 1
        OR found_traces = 1
    ) AS found_anywhere,

    COUNTIF(
        found_transactions = 0
        AND found_tokens = 0
        AND found_traces = 0
    ) AS completely_unmatched

FROM coverage
GROUP BY fraud_flag
ORDER BY fraud_flag;


-- Optional validation: count malformed wallet addresses excluded above
SELECT
    fraud_flag,
    COUNT(*) AS malformed_addresses
FROM
    `ethereum-fraud-analysis.web3_fraud_us.wallet_labels`
WHERE
    NOT REGEXP_CONTAINS(address, r'^0x[0-9a-f]{40}$')
GROUP BY fraud_flag
ORDER BY fraud_flag;
