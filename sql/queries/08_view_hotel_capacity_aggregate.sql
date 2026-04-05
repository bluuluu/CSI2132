-- Run in terminal: psql -d ehotels -f sql/queries/08_view_hotel_capacity_aggregate.sql
-- Required view: hotel capacity aggregate
SELECT * FROM v_hotel_capacity_aggregate ORDER BY aggregated_capacity DESC LIMIT 10;
