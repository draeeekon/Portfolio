CREATE OR REPLACE TABLE
    `ethereum-fraud-analysis.web3_fraud_us.transaction_features`
AS

WITH wallets AS (
    SELECT
        address,
        fraud_flag
    FROM
        `ethereum-fraud-analysis.web3_fraud_us.modelling_wallets`
),

-- Outgoing transactions
outgoing AS (
    SELECT
        t.from_address AS address,
        t.transaction_hash,
        t.block_timestamp,
        t.to_address,
        SAFE_CAST(t.value AS BIGNUMERIC) AS value_wei,
        SAFE_CAST(t.gas AS BIGNUMERIC) AS gas,
        SAFE_CAST(t.gas_price AS BIGNUMERIC) AS gas_price

    FROM
        `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.transactions_by_from_address` t

    INNER JOIN wallets w
        ON t.from_address = w.address

    WHERE
        t.block_timestamp < TIMESTAMP('2020-07-15')
),

outgoing_agg AS (
    SELECT
        address,

        COUNT(*) AS transactions_sent,
        COUNT(DISTINCT to_address) AS unique_receivers,

        SUM(value_wei) / 1e18 AS total_eth_sent,
        AVG(value_wei) / 1e18 AS avg_eth_sent,
        MAX(value_wei) / 1e18 AS max_eth_sent,

        AVG(gas) AS avg_gas_limit,
        AVG(gas_price) AS avg_gas_price,

        MIN(block_timestamp) AS first_sent_transaction,
        MAX(block_timestamp) AS last_sent_transaction

    FROM outgoing
    GROUP BY address
),

-- Incoming transactions
incoming AS (
    SELECT
        t.to_address AS address,
        t.transaction_hash,
        t.block_timestamp,
        t.from_address,
        SAFE_CAST(t.value AS BIGNUMERIC) AS value_wei

    FROM
        `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.transactions_by_to_address` t

    INNER JOIN wallets w
        ON t.to_address = w.address

    WHERE
        t.block_timestamp < TIMESTAMP('2020-07-15')
),

incoming_agg AS (
    SELECT
        address,

        COUNT(*) AS transactions_received,
        COUNT(DISTINCT from_address) AS unique_senders,

        SUM(value_wei) / 1e18 AS total_eth_received,
        AVG(value_wei) / 1e18 AS avg_eth_received,
        MAX(value_wei) / 1e18 AS max_eth_received,

        MIN(block_timestamp) AS first_received_transaction,
        MAX(block_timestamp) AS last_received_transaction

    FROM incoming
    GROUP BY address
),

-- Combine both directions to calculate overall activity
activity AS (
    SELECT
        address,
        transaction_hash,
        block_timestamp
    FROM outgoing

    UNION DISTINCT

    SELECT
        address,
        transaction_hash,
        block_timestamp
    FROM incoming
),

activity_agg AS (
    SELECT
        address,

        COUNT(DISTINCT transaction_hash) AS total_transactions,
        COUNT(DISTINCT DATE(block_timestamp)) AS active_days,

        MIN(block_timestamp) AS first_transaction,
        MAX(block_timestamp) AS last_transaction

    FROM activity
    GROUP BY address
)

SELECT
    w.address,
    w.fraud_flag,

    COALESCE(o.transactions_sent, 0) AS transactions_sent,
    COALESCE(i.transactions_received, 0) AS transactions_received,
    COALESCE(a.total_transactions, 0) AS total_transactions,

    COALESCE(o.unique_receivers, 0) AS unique_receivers,
    COALESCE(i.unique_senders, 0) AS unique_senders,

    COALESCE(o.total_eth_sent, 0) AS total_eth_sent,
    COALESCE(i.total_eth_received, 0) AS total_eth_received,

    COALESCE(o.avg_eth_sent, 0) AS avg_eth_sent,
    COALESCE(i.avg_eth_received, 0) AS avg_eth_received,

    COALESCE(o.max_eth_sent, 0) AS max_eth_sent,
    COALESCE(i.max_eth_received, 0) AS max_eth_received,

    COALESCE(o.avg_gas_limit, 0) AS avg_gas_limit,
    COALESCE(o.avg_gas_price, 0) AS avg_gas_price,

    COALESCE(a.active_days, 0) AS active_days,

    a.first_transaction,
    a.last_transaction,

    CASE
        WHEN a.first_transaction IS NOT NULL
             AND a.last_transaction IS NOT NULL
        THEN DATE_DIFF(
            DATE(a.last_transaction),
            DATE(a.first_transaction),
            DAY
        ) + 1
        ELSE 0
    END AS wallet_lifetime_days,

    SAFE_DIVIDE(
        a.total_transactions,
        a.active_days
    ) AS transactions_per_active_day

FROM wallets w

LEFT JOIN outgoing_agg o
    ON w.address = o.address

LEFT JOIN incoming_agg i
    ON w.address = i.address

LEFT JOIN activity_agg a
    ON w.address = a.address;

-- Validation Check
SELECT
    COUNT(*) AS total_wallets,
    COUNT(DISTINCT address) AS unique_wallets,

    COUNTIF(total_transactions = 0) AS no_top_level_transactions,

    COUNTIF(transactions_sent = 0) AS never_sent,
    COUNTIF(transactions_received = 0) AS never_received

FROM
    `ethereum-fraud-analysis.web3_fraud_us.transaction_features`;

SELECT
    fraud_flag,
    COUNT(*) AS wallets,
    COUNTIF(total_transactions = 0) AS no_top_level_transactions,
    COUNTIF(transactions_sent = 0) AS never_sent,
    COUNTIF(transactions_received = 0) AS never_received
FROM
    `ethereum-fraud-analysis.web3_fraud_us.transaction_features`
GROUP BY fraud_flag
ORDER BY fraud_flag;  