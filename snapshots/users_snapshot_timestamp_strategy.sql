{% snapshot users_snapshot_timestamp_strategy %}

  {{ 
    config(
      target_schema='dbt_snapshot_example',
      target_database='your-gcp-project-id',
      unique_key='user_name',
      strategy='timestamp',
      updated_at='row_updated_at'
    ) 
  }}

  select * from {{ source('dbt_snapshot_example', 'users') }}

{% endsnapshot %}
