{% snapshot users_snapshot_check_strategy %}

  {{ 
    config(
      target_schema='dbt_snapshot_example',
      target_database='your-gcp-project-id',
      unique_key='user_name',
      strategy='check',
      check_cols=['user_status'],
    ) 
  }}

  select * from {{ source('dbt_snapshot_example', 'users') }}

{% endsnapshot %}
