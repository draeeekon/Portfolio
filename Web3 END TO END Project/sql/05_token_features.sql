CREATE OR REPLACE TABLE
    `ethereum-fraud-analysis.web3_fraud_us.token_features`
AS

WITH wallets AS (
    SELECT
        address,
        fraud_flag
    FROM
        `ethereum-fraud-analysis.web3_fraud_us.modelling_wallets`
),

-- Token transfers sent by each wallet
token_sent AS (
    SELECT
        t.from_address AS address,
        t.address AS token_address,
        t.to_address AS counterparty,
        t.block_timestamp
    FROM
        `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.token_transfers` t

    INNER JOIN wallets w
        ON t.from_address = w.address

    WHERE
        t.block_timestamp < TIMESTAMP('2020-07-15')
),

token_sent_agg AS (
    SELECT
        address,

        COUNT(*) AS token_transfers_sent,
        COUNT(DISTINCT token_address) AS unique_tokens_sent,
        COUNT(DISTINCT counterparty) AS unique_token_receivers,

        COUNT(DISTINCT DATE(block_timestamp))
            AS token_sent_active_days,

        MIN(block_timestamp)
            AS first_token_sent,

        MAX(block_timestamp)
            AS last_token_sent

    FROM token_sent
    GROUP BY address
),

-- Token transfers received by each wallet
token_received AS (
    SELECT
        t.to_address AS address,
        t.address AS token_address,
        t.from_address AS counterparty,
        t.block_timestamp
    FROM
        `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.token_transfers` t

    INNER JOIN wallets w
        ON t.to_address = w.address

    WHERE
        t.block_timestamp < TIMESTAMP('2020-07-15')
),

token_received_agg AS (
    SELECT
        address,

        COUNT(*) AS token_transfers_received,
        COUNT(DISTINCT token_address) AS unique_tokens_received,
        COUNT(DISTINCT counterparty) AS unique_token_senders,

        COUNT(DISTINCT DATE(block_timestamp))
            AS token_received_active_days,

        MIN(block_timestamp)
            AS first_token_received,

        MAX(block_timestamp)
            AS last_token_received

    FROM token_received
    GROUP BY address
),

-- Combine both directions for general token activity
token_activity AS (

    SELECT
        address,
        token_address,
        block_timestamp
    FROM token_sent

    UNION ALL

    SELECT
        address,
        token_address,
        block_timestamp
    FROM token_received
),

token_activity_agg AS (
    SELECT
        address,

        COUNT(DISTINCT token_address)
            AS unique_tokens_interacted,

        COUNT(DISTINCT DATE(block_timestamp))
            AS token_active_days,

        MIN(block_timestamp)
            AS first_token_transfer,

        MAX(block_timestamp)
            AS last_token_transfer

    FROM token_activity
    GROUP BY address
)

SELECT
    w.address,
    w.fraud_flag,

    COALESCE(s.token_transfers_sent, 0)
        AS token_transfers_sent,

    COALESCE(r.token_transfers_received, 0)
        AS token_transfers_received,

    COALESCE(s.token_transfers_sent, 0)
        + COALESCE(r.token_transfers_received, 0)
        AS total_token_transfers,

    COALESCE(s.unique_tokens_sent, 0)
        AS unique_tokens_sent,

    COALESCE(r.unique_tokens_received, 0)
        AS unique_tokens_received,

    COALESCE(a.unique_tokens_interacted, 0)
        AS unique_tokens_interacted,

    COALESCE(s.unique_token_receivers, 0)
        AS unique_token_receivers,

    COALESCE(r.unique_token_senders, 0)
        AS unique_token_senders,

    COALESCE(a.token_active_days, 0)
        AS token_active_days,

    a.first_token_transfer,
    a.last_token_transfer,

    CASE
        WHEN a.first_token_transfer IS NOT NULL
             AND a.last_token_transfer IS NOT NULL
        THEN DATE_DIFF(
            DATE(a.last_token_transfer),
            DATE(a.first_token_transfer),
            DAY
        ) + 1
        ELSE 0
    END AS token_activity_lifetime_days,

    SAFE_DIVIDE(
        COALESCE(s.token_transfers_sent, 0)
            + COALESCE(r.token_transfers_received, 0),

        NULLIF(a.token_active_days, 0)
    ) AS token_transfers_per_active_day

FROM wallets w

LEFT JOIN token_sent_agg s
    ON w.address = s.address

LEFT JOIN token_received_agg r
    ON w.address = r.address

LEFT JOIN token_activity_agg a
    ON w.address = a.address;

-- Validation Check
SELECT
    COUNT(*) AS total_wallets,
    COUNT(DISTINCT address) AS unique_wallets,

    COUNTIF(
        token_transfers_sent = 0
        AND token_transfers_received = 0
    ) AS no_token_activity,

    COUNTIF(token_transfers_sent = 0)
        AS never_sent_tokens,

    COUNTIF(token_transfers_received = 0)
        AS never_received_tokens

FROM
    `ethereum-fraud-analysis.web3_fraud_us.token_features`;