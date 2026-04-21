with base as (
    select
        airport,
        split_part(airport_name, ':', 1) as airport_city,
        split_part(airport_name, ':', 2) as airport_name
    from {{ ref('stg_airline_delay_cause') }}
)

select
    airport                              as airport_id,
    airport_city                         as airport_city,
    max(airport_name)                    as airport_name
from base
group by airport, airport_city