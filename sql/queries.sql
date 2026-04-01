-- Q1 (Aggregation): Number of active reservations per hotel chain
SELECT
  hc.chain_name,
  COUNT(b.booking_id) AS active_bookings
FROM hotel_chain hc
JOIN hotel h ON h.chain_id = hc.chain_id
JOIN room r ON r.hotel_id = h.hotel_id
LEFT JOIN booking b ON b.room_id = r.room_id AND b.status IN ('reserved', 'checked_in')
GROUP BY hc.chain_name
ORDER BY active_bookings DESC;

-- Q2 (Nested query): Customers who spent above average payment amount
SELECT
  c.customer_id,
  p.first_name,
  p.last_name,
  SUM(pay.amount) AS total_spent
FROM customer c
JOIN person p ON p.legal_id = c.legal_id
JOIN renting rt ON rt.customer_id = c.customer_id
JOIN payment pay ON pay.renting_id = rt.renting_id
GROUP BY c.customer_id, p.first_name, p.last_name
HAVING SUM(pay.amount) > (
  SELECT AVG(customer_total) FROM (
    SELECT SUM(pay2.amount) AS customer_total
    FROM customer c2
    JOIN renting rt2 ON rt2.customer_id = c2.customer_id
    JOIN payment pay2 ON pay2.renting_id = rt2.renting_id
    GROUP BY c2.customer_id
  ) t
)
ORDER BY total_spent DESC;

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
      AND daterange(b.start_date, b.end_date, '[]') && daterange(DATE '2026-04-15', DATE '2026-04-20', '[]')
  )
  AND NOT EXISTS (
    SELECT 1
    FROM renting rt
    WHERE rt.room_id = r.room_id
      AND rt.status = 'active'
      AND daterange(rt.start_date, rt.end_date, '[]') && daterange(DATE '2026-04-15', DATE '2026-04-20', '[]')
  )
ORDER BY r.base_price;

-- Q4: Employee performance summary
SELECT
  e.employee_id,
  pp.first_name || ' ' || pp.last_name AS employee_name,
  h.hotel_name,
  COUNT(DISTINCT b.booking_id) AS bookings_handled,
  COUNT(DISTINCT rt.renting_id) AS rentings_handled,
  COALESCE(SUM(pay.amount), 0) AS total_payments_processed
FROM employee e
JOIN person pp ON pp.legal_id = e.legal_id
JOIN hotel h ON h.hotel_id = e.hotel_id
LEFT JOIN booking b ON b.created_by_employee_id = e.employee_id
LEFT JOIN renting rt ON rt.employee_id = e.employee_id
LEFT JOIN payment pay ON pay.employee_id = e.employee_id
GROUP BY e.employee_id, employee_name, h.hotel_name
ORDER BY total_payments_processed DESC, bookings_handled DESC;

-- Trigger demo 1: overlap protection (should fail)
-- INSERT INTO booking (room_id, customer_id, created_by_employee_id, start_date, end_date, status)
-- VALUES (5, 25, 1, CURRENT_DATE + 6, CURRENT_DATE + 7, 'reserved');

-- Trigger demo 2: status sync + archiving
-- UPDATE booking SET status = 'completed' WHERE booking_id = 3;
-- UPDATE renting SET status = 'completed' WHERE renting_id = 3;
-- SELECT * FROM archive ORDER BY archive_id DESC LIMIT 5;

-- Required views
SELECT * FROM v_available_rooms_per_area;
SELECT * FROM v_hotel_capacity_aggregate ORDER BY aggregated_capacity DESC LIMIT 10;
