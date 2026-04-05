-- Run in terminal: psql -d ehotels -f sql/queries/03_q3_available_rooms_with_filters.sql
-- Q3: Available rooms with multiple filters
-- Parameters: start_date, end_date, capacity, area, chain_id, category, max_price
SELECT
  r.room_id,
  h.hotel_name,
  hc.chain_name,
  COALESCE(NULLIF(BTRIM(SPLIT_PART(h.address_line, ',', 2)), ''), h.address_line) AS area,
  h.category,
  r.capacity,
  r.base_price
FROM room r
JOIN hotel h ON h.hotel_id = r.hotel_id
JOIN hotel_chain hc ON hc.chain_id = h.chain_id
WHERE r.current_status = 'available'
  AND r.capacity = 'double'
  AND COALESCE(NULLIF(BTRIM(SPLIT_PART(h.address_line, ',', 2)), ''), h.address_line) = 'Toronto'
  AND h.chain_id = 1
  AND h.category >= 3
  AND r.base_price <= 250
  AND NOT EXISTS (
    SELECT 1
    FROM booking b
    WHERE b.room_id = r.room_id
      AND b.status IN ('reserved', 'checked_in')
      AND daterange(b.start_date, b.end_date, '[)') && daterange(DATE '2026-04-15', DATE '2026-04-20', '[)')
  )
  AND NOT EXISTS (
    SELECT 1
    FROM renting rt
    WHERE rt.room_id = r.room_id
      AND rt.status = 'active'
      AND daterange(rt.start_date, rt.end_date, '[)') && daterange(DATE '2026-04-15', DATE '2026-04-20', '[)')
  )
ORDER BY r.base_price;
