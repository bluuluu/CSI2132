# Screenshot Checklist (Deliverable 2)

Use this list when preparing your PDF/video evidence.

1. Home page showing total counts (hotels/rooms/customers/employees).
2. Search page with filters filled (dates, capacity, area, chain, category, rooms, price).
3. Search results showing available rooms.
4. Booking form submission success message.
5. Employee panel: booking -> renting transformation form.
6. Employee panel: direct renting creation form.
7. Employee panel: payment insertion form.
8. SQL views page showing:
   - available rooms per area
   - aggregated hotel room capacity
9. Customers CRUD page: create + update + delete example.
10. Employees CRUD page: create + update + delete example.
11. Hotels CRUD page: create + update + delete example.
12. Rooms CRUD page: create + update + delete example.
13. SQL trigger demo in DB tool:
   - overlapping booking blocked
   - completion update inserts archive row
14. SQL index/view code snippet from `sql/schema.sql`.
15. Query examples from `sql/queries.sql` including:
   - aggregation query
   - nested query

---

## Copy/Paste Queries for DB Evidence

Use these directly in `psql` or pgAdmin for screenshot items 8, 13, 14, 15.

### Item 8: SQL Views

```sql
SELECT * FROM v_available_rooms_per_area ORDER BY area;
SELECT * FROM v_hotel_capacity_aggregate ORDER BY aggregated_capacity DESC, hotel_id LIMIT 20;
```

### Item 13A: Trigger Demo (Overlapping booking blocked)

This should fail on the second insert with overlap error.

```sql
WITH params AS (
  SELECT (CURRENT_DATE + 40)::date AS s, (CURRENT_DATE + 43)::date AS e
),
free_room AS (
  SELECT r.room_id, p.s, p.e
  FROM room r
  CROSS JOIN params p
  WHERE NOT EXISTS (
    SELECT 1
    FROM booking b
    WHERE b.room_id = r.room_id
      AND b.status IN ('reserved', 'checked_in')
      AND daterange(b.start_date, b.end_date, '[]') && daterange(p.s, p.e, '[]')
  )
  AND NOT EXISTS (
    SELECT 1
    FROM renting rt
    WHERE rt.room_id = r.room_id
      AND rt.status = 'active'
      AND daterange(rt.start_date, rt.end_date, '[]') && daterange(p.s, p.e, '[]')
  )
  ORDER BY r.room_id
  LIMIT 1
),
first_booking AS (
  INSERT INTO booking (room_id, customer_id, created_by_employee_id, start_date, end_date, status)
  SELECT
    fr.room_id,
    (SELECT customer_id FROM customer ORDER BY customer_id LIMIT 1),
    NULL,
    fr.s,
    fr.e,
    'reserved'
  FROM free_room fr
  RETURNING room_id, start_date, end_date
)
INSERT INTO booking (room_id, customer_id, created_by_employee_id, start_date, end_date, status)
SELECT
  fb.room_id,
  (SELECT customer_id FROM customer ORDER BY customer_id DESC LIMIT 1),
  NULL,
  fb.start_date + 1,
  fb.end_date + 1,
  'reserved'
FROM first_booking fb;
```

### Item 13B: Trigger Demo (Completion inserts archive row)

```sql
WITH params AS (
  SELECT (CURRENT_DATE + 50)::date AS s, (CURRENT_DATE + 52)::date AS e
),
free_room AS (
  SELECT r.room_id, p.s, p.e
  FROM room r
  CROSS JOIN params p
  WHERE NOT EXISTS (
    SELECT 1
    FROM booking b
    WHERE b.room_id = r.room_id
      AND b.status IN ('reserved', 'checked_in')
      AND daterange(b.start_date, b.end_date, '[]') && daterange(p.s, p.e, '[]')
  )
  AND NOT EXISTS (
    SELECT 1
    FROM renting rt
    WHERE rt.room_id = r.room_id
      AND rt.status = 'active'
      AND daterange(rt.start_date, rt.end_date, '[]') && daterange(p.s, p.e, '[]')
  )
  ORDER BY r.room_id
  LIMIT 1
),
new_booking AS (
  INSERT INTO booking (room_id, customer_id, created_by_employee_id, start_date, end_date, status)
  SELECT
    fr.room_id,
    (SELECT customer_id FROM customer ORDER BY customer_id LIMIT 1),
    NULL,
    fr.s,
    fr.e,
    'reserved'
  FROM free_room fr
  RETURNING booking_id
),
mark_complete AS (
  UPDATE booking b
  SET status = 'completed'
  WHERE b.booking_id = (SELECT booking_id FROM new_booking)
  RETURNING b.booking_id
)
SELECT a.*
FROM archive a
JOIN mark_complete mc ON mc.booking_id = a.source_booking_id
WHERE a.record_type = 'booking'
ORDER BY a.archived_at DESC;
```

### Item 14: Index + View Definitions from DB

```sql
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('hotel', 'room', 'booking', 'renting', 'auth_account')
ORDER BY tablename, indexname;

SELECT viewname, definition
FROM pg_views
WHERE schemaname = 'public'
  AND viewname IN ('v_available_rooms_per_area', 'v_hotel_capacity_aggregate')
ORDER BY viewname;
```

### Item 15: Query Examples (Aggregation + Nested)

```sql
-- Aggregation query
SELECT
  hc.chain_name,
  COUNT(b.booking_id) AS active_bookings
FROM hotel_chain hc
JOIN hotel h ON h.chain_id = hc.chain_id
JOIN room r ON r.hotel_id = h.hotel_id
LEFT JOIN booking b ON b.room_id = r.room_id AND b.status IN ('reserved', 'checked_in')
GROUP BY hc.chain_name
ORDER BY active_bookings DESC;
```

```sql
-- Nested query
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
```
