# snapshot-slowly-changing-dimensions-dbt-example

This repo shows how to maintain "type-2 Slowly Changing Dimensions" snapshots of a mutable table using DBT. What this is used for is to provide a "look back in time" view of a table which is updated in place (i.e. new data replaces old data).

The data warehouse I'm using for this example is google BigQuery.

```bash
# install dependencies #
python -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install dbt-core dbt-bigquery
```

```sql
-- create bigquery dataset --
CREATE SCHEMA `your-gcp-project-id.dbt_snapshot_example`
OPTIONS (
  location = 'europe-west2'
)
;
```

# 'timestamp' snapshot strategy

[The timestamp strategy uses an `updated_at` field to determine if a row has changed. If the configured `updated_at` column for a row is more recent than the last time the snapshot ran, then dbt will invalidate the old record and record the new one. If the timestamps are unchanged, then dbt will not take any action.](https://docs.getdbt.com/docs/build/snapshots#timestamp-strategy-recommended)

First, I create a table called _users_, and insert a single user with status 'active'

```sql
CREATE TABLE `your-gcp-project-id.dbt_snapshot_example.users` (
user_name STRING,
user_status STRING,
row_updated_at TIMESTAMP
);

INSERT INTO `your-gcp-project-id.dbt_snapshot_example.users`
(user_name, user_status, row_updated_at)
VALUES ('joe', 'active', CURRENT_TIMESTAMP())
;

SELECT  *
FROM    `your-gcp-project-id.dbt_snapshot_example.users`
;
```

| user_name | user_status | row_updated_at          |
| --------- | ----------- | ----------------------- |
| joe       | active      | 2024-09-01 12:43:36 UTC |

I take a snapshot of the _users_ table - the first time the _dbt snapshot_ command is run, it just creates a copy of the _users_ table (with some additional columns):

```bash
dbt snapshot --select users_snapshot_timestamp_strategy
```

Here is how the snapshot table looks:

```sql
SELECT  *
FROM    `your-gcp-project-id.dbt_snapshot_example.users_snapshot_timestamp_strategy`
;
```

| user_name | user_status | row_updated_at          | dbt_scd_id                       | dbt_updated_at          | dbt_valid_from          | dbt_valid_to |
| --------- | ----------- | ----------------------- | -------------------------------- | ----------------------- | ----------------------- | ------------ |
| joe       | active      | 2024-09-01 12:43:36 UTC | 7434bb97e2fb34e2c0b481959d70d155 | 2024-09-01 12:43:36 UTC | 2024-09-01 12:43:36 UTC |              |

Now, I change the status of the user 'joe' in the _users_ table to 'dormant' by overwriting the value in the _user_status_ column.

```sql
UPDATE  `your-gcp-project-id.dbt_snapshot_example.users`
SET     user_status = 'dormant'
      , row_updated_at = CURRENT_TIMESTAMP()
WHERE   user_name = 'joe'
;

SELECT  *
FROM    `your-gcp-project-id.dbt_snapshot_example.users`
;
```

| user_name | user_status | row_updated_at          |
| --------- | ----------- | ----------------------- |
| joe       | dormant     | 2024-09-01 12:57:10 UTC |

Running _dbt snapshot_ again appends a new row to the snapshot table, recording this row change:

```bash
dbt snapshot --select users_snapshot_timestamp_strategy
```

```sql
SELECT  *
FROM    `your-gcp-project-id.dbt_snapshot_example.users_snapshot_timestamp_strategy`
;
```

| user_name | user_status | row_updated_at          | dbt_scd_id                       | dbt_updated_at          | dbt_valid_from          | dbt_valid_to            |
| --------- | ----------- | ----------------------- | -------------------------------- | ----------------------- | ----------------------- | ----------------------- |
| joe       | dormant     | 2024-09-01 12:57:10 UTC | 27d047306121e541ed7a8a82b7d7758e | 2024-09-01 12:57:10 UTC | 2024-09-01 12:57:10 UTC | _null_                  |
| joe       | active      | 2024-09-01 12:43:36 UTC | 7434bb97e2fb34e2c0b481959d70d155 | 2024-09-01 12:43:36 UTC | 2024-09-01 12:43:36 UTC | 2024-09-01 12:57:10 UTC |

## 'check' snapshot strategy

[The check strategy is useful for tables which do not have a reliable `updated_at` column. This strategy works by comparing a list of columns between their current and historical values. If any of these columns have changed, then dbt will invalidate the old record and record the new one. If the column values are identical, then dbt will not take any action.](https://docs.getdbt.com/docs/build/snapshots#check-strategy)

```sql
DROP TABLE IF EXISTS `your-gcp-project-id.dbt_snapshot_example.users`
;

CREATE TABLE `your-gcp-project-id.dbt_snapshot_example.users` (
user_name STRING,
user_status STRING,
);

INSERT INTO `your-gcp-project-id.dbt_snapshot_example.users`
(user_name, user_status)
VALUES ('joe', 'active')
;

SELECT  *
FROM    `your-gcp-project-id.dbt_snapshot_example.users`
;
```

| user_name | user_status |
| --------- | ----------- |
| joe       | active      |

```bash
dbt snapshot --select users_snapshot_check_strategy
```

```sql
SELECT  *
FROM    `your-gcp-project-id.dbt_snapshot_example.users_snapshot_check_strategy`
;
```

| user_name | user_status | dbt_scd_id                       | dbt_updated_at          | dbt_valid_from          | dbt_valid_to |
| --------- | ----------- | -------------------------------- | ----------------------- | ----------------------- | ------------ |
| joe       | active      | 5dcf080ad5fc313f0781899e7d9ec442 | 2024-09-01 13:44:51 UTC | 2024-09-01 13:44:51 UTC | _null_       |

```sql
UPDATE `your-gcp-project-id.dbt_snapshot_example.users`
SET   user_status = 'dormant'
WHERE user_name = 'joe'
;

SELECT * FROM `your-gcp-project-id.dbt_snapshot_example.users`
;
```

| user_name | user_status |
| --------- | ----------- |
| joe       | dormant     |

```bash
dbt snapshot --select users_snapshot_check_strategy
```

```sql
SELECT  *
FROM    `your-gcp-project-id.dbt_snapshot_example.users_snapshot_check_strategy`
;
```

| user_name | user_status | dbt_scd_id                       | dbt_updated_at          | dbt_valid_from          | dbt_valid_to            |
| --------- | ----------- | -------------------------------- | ----------------------- | ----------------------- | ----------------------- |
| joe       | active      | 5dcf080ad5fc313f0781899e7d9ec442 | 2024-09-01 13:44:51 UTC | 2024-09-01 13:44:51 UTC | 2024-09-01 13:47:43 UTC |
| joe       | dormant     | 3928a06a330872968ed3aa305625b730 | 2024-09-01 13:47:43 UTC | 2024-09-01 13:47:43 UTC | _null_                  |
