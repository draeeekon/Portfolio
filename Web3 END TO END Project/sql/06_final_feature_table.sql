CREATE OR REPLACE TABLE
    `ethereum-fraud-analysis.web3_fraud_us.wallet_features`
AS

SELECT
    t.address,
    t.fraud_flag,

    -- Transaction features
    t.transactions_sent,
    t.transactions_received,
    t.total_transactions,

    t.unique_receivers,
    t.unique_senders,

    t.total_eth_sent,
    t.total_eth_received,

    t.avg_eth_sent,
    t.avg_eth_received,

    t.max_eth_sent,
    t.max_eth_received,

    t.avg_gas_limit,
    t.avg_gas_price,

    t.active_days,
    t.wallet_lifetime_days,
    t.transactions_per_active_day,

    -- Token features
    tok.token_transfers_sent,
    tok.token_transfers_received,
    tok.total_token_transfers,

    tok.unique_tokens_sent,
    tok.unique_tokens_received,
    tok.unique_tokens_interacted,

    tok.unique_token_receivers,
    tok.unique_token_senders,

    tok.token_active_days,
    tok.token_activity_lifetime_days,
    tok.token_transfers_per_active_day

FROM
    `ethereum-fraud-analysis.web3_fraud_us.transaction_features` t

LEFT JOIN
    `ethereum-fraud-analysis.web3_fraud_us.token_features` tok
    ON t.address = tok.address;

-- Validation checks

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT address) AS unique_wallets,
    COUNTIF(fraud_flag = 0) AS legitimate_wallets,
    COUNTIF(fraud_flag = 1) AS fraud_wallets
FROM
    `ethereum-fraud-analysis.web3_fraud_us.wallet_features`;

SELECT
    COUNTIF(transactions_per_active_day IS NULL)
        AS null_tx_frequency,

    COUNTIF(token_transfers_per_active_day IS NULL)
        AS null_token_frequency,

    COUNTIF(avg_eth_sent IS NULL)
        AS null_avg_eth_sent,

    COUNTIF(avg_eth_received IS NULL)
        AS null_avg_eth_received

FROM
    `ethereum-fraud-analysis.web3_fraud_us.wallet_features`;    

SELECT
    fraud_flag,

    COUNT(*) AS wallets,

    ROUND(AVG(total_transactions), 2)
        AS avg_transactions,

    ROUND(AVG(transactions_per_active_day), 2)
        AS avg_transactions_per_active_day,

    ROUND(AVG(total_token_transfers), 2)
        AS avg_token_transfers,

    ROUND(AVG(unique_receivers), 2)
        AS avg_unique_receivers,

    ROUND(AVG(wallet_lifetime_days), 2)
        AS avg_wallet_lifetime_days

FROM
    `ethereum-fraud-analysis.web3_fraud_us.wallet_features`

GROUP BY fraud_flag

ORDER BY fraud_flag;

SELECT
    fraud_flag,

    APPROX_QUANTILES(total_transactions, 100)[OFFSET(50)]
        AS median_transactions,

    APPROX_QUANTILES(total_transactions, 100)[OFFSET(90)]
        AS p90_transactions,

    APPROX_QUANTILES(total_transactions, 100)[OFFSET(99)]
        AS p99_transactions,

    MAX(total_transactions)
        AS max_transactions,

    APPROX_QUANTILES(total_token_transfers, 100)[OFFSET(50)]
        AS median_token_transfers,

    APPROX_QUANTILES(unique_receivers, 100)[OFFSET(50)]
        AS median_unique_receivers,

    APPROX_QUANTILES(wallet_lifetime_days, 100)[OFFSET(50)]
        AS median_wallet_lifetime_days

FROM
    `ethereum-fraud-analysis.web3_fraud_us.wallet_features`

GROUP BY fraud_flag

ORDER BY fraud_flag;

SELECT
    address,
    fraud_flag,
    total_transactions,
    total_token_transfers,
    unique_receivers,
    wallet_lifetime_days
FROM
    `ethereum-fraud-analysis.web3_fraud_us.wallet_features`
ORDER BY
    total_transactions DESC
LIMIT 20;

SELECT
    COUNTIF(transactions_per_active_day IS NULL)
        AS null_tx_frequency,

    COUNTIF(token_transfers_per_active_day IS NULL)
        AS null_token_frequency,

    COUNTIF(avg_eth_sent IS NULL)
        AS null_avg_eth_sent,

    COUNTIF(avg_eth_received IS NULL)
        AS null_avg_eth_received

FROM
    `ethereum-fraud-analysis.web3_fraud_us.wallet_features`;