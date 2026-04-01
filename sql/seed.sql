BEGIN;

INSERT INTO hotel_chain (chain_name, central_office_address, contact_email, contact_phone)
VALUES
  ('Cedar Key Hotels', '145 Wellington St W, Toronto, ON', 'ops@cedarkeyhotels.com', '4165558101'),
  ('Summit Harbor Group', '455 Burrard St, Vancouver, BC', 'contact@summitharbor.com', '6045558201'),
  ('Northern Bloom Inns', '700 Rene-Levesque Blvd, Montreal, QC', 'service@northernbloom.com', '5145558301'),
  ('Blue Ridge Stays', '25 Atlantic Ave, Boston, MA', 'desk@blueridgestays.com', '6175558401'),
  ('Lakeside Horizon', '520 Pike St, Seattle, WA', 'help@lakesidehorizon.com', '2065558501');

WITH cities AS (
  SELECT ARRAY[
    'Toronto','Ottawa','Montreal','Vancouver','Calgary','Edmonton','Winnipeg',
    'Halifax','Boston','New York','Chicago','Seattle','San Francisco','Los Angeles'
  ] AS c,
  ARRAY[
    'Cedar Point','Harbor View','Skyline Court','Maple Arc','North Gate',
    'Aurora Bay','Elm Grove','Riverlight','Summit Crest','Pine Terrace'
  ] AS n
)
INSERT INTO hotel (
  chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country,
  postal_code, contact_email, contact_phone
)
SELECT
  ((g - 1) / 8) + 1 AS chain_id,
  (SELECT n[((g - 1) % array_length(n, 1)) + 1] FROM cities) || ' Hotel ' || g AS hotel_name,
  ((g - 1) % 5) + 1 AS category,
  24 + (g % 14) AS total_rooms,
  (120 + g) || ' Market Street' AS address_line,
  (SELECT c[((g - 1) % array_length(c, 1)) + 1] FROM cities) AS city,
  CASE
    WHEN g % 2 = 0 THEN 'ON'
    WHEN g % 3 = 0 THEN 'QC'
    WHEN g % 5 = 0 THEN 'BC'
    ELSE 'USA'
  END AS state_province,
  CASE WHEN g % 4 = 0 THEN 'USA' ELSE 'Canada' END AS country,
  'H' || lpad((2000 + g)::text, 4, '0') AS postal_code,
  'frontdesk' || g || '@demo-ehotels.com' AS contact_email,
  '5557' || lpad(g::text, 6, '0') AS contact_phone
FROM generate_series(1, 40) AS g;

INSERT INTO room (
  hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view,
  is_extendable, amenities, issues, current_status
)
SELECT
  h.hotel_id,
  (100 + seq)::text,
  CASE seq
    WHEN 1 THEN 'single'
    WHEN 2 THEN 'double'
    WHEN 3 THEN 'suite'
    WHEN 4 THEN 'family'
    ELSE 'double'
  END AS capacity,
  (85 + (h.hotel_id * 3) + (seq * 12))::numeric(10,2) AS base_price,
  (h.hotel_id % 7 = 0 AND seq IN (3,4)) AS has_sea_view,
  (h.hotel_id % 5 = 0 AND seq IN (3,4)) AS has_mountain_view,
  (seq IN (2,4,5)) AS is_extendable,
  CASE seq
    WHEN 1 THEN 'WiFi, TV'
    WHEN 2 THEN 'WiFi, TV, Mini-Fridge'
    WHEN 3 THEN 'WiFi, TV, Balcony, Mini-Bar'
    WHEN 4 THEN 'WiFi, TV, Sofa-bed, Kitchenette'
    ELSE 'WiFi, TV, Air Conditioning'
  END AS amenities,
  CASE WHEN seq = 5 AND h.hotel_id % 9 = 0 THEN 'Minor paint damage' ELSE NULL END AS issues,
  'available'
FROM hotel h
CROSS JOIN generate_series(1, 5) AS seq;

INSERT INTO person (legal_id, id_type, first_name, last_name, email, phone, address_line)
SELECT
  lpad((200000000 + g)::text, 9, '0'),
  'SIN',
  (ARRAY['Maya','Noah','Liam','Olivia','Ethan','Sophia','Lucas','Ava','Mila','Leo'])[((g - 1) % 10) + 1],
  (ARRAY['Patel','Nguyen','Martin','Singh','Brown','Lopez','Khan','Wilson','Carter','Dubois'])[((g - 1) % 10) + 1] || g,
  'guest' || g || '@staymail.com',
  '6138' || lpad(g::text, 6, '0'),
  (40 + g) || ' Willow Crescent'
FROM generate_series(1, 120) AS g;

WITH customer_people AS (
  SELECT
    person_id,
    row_number() OVER (ORDER BY person_id) AS rn
  FROM person
  WHERE email LIKE 'guest%@staymail.com'
)
INSERT INTO customer (person_id, hotel_id, registration_date)
SELECT
  person_id,
  ((rn - 1) % 40) + 1 AS hotel_id,
  CURRENT_DATE - ((person_id % 400) || ' days')::interval
FROM customer_people;

INSERT INTO person (legal_id, id_type, first_name, last_name, email, phone, address_line)
SELECT
  lpad((700000000 + g)::text, 9, '0'),
  'SIN',
  (ARRAY['Amir','Chloe','Jordan','Ariana','Victor','Nina','Daniel','Ella','Marco','Riya'])[((g - 1) % 10) + 1],
  (ARRAY['Adams','Bennett','Clark','Diaz','Edwards','Fischer','Gray','Hughes','Iqbal','Jacobs'])[((g - 1) % 10) + 1] || g,
  'team' || g || '@workmail.com',
  '3439' || lpad(g::text, 6, '0'),
  (80 + g) || ' Lakeview Drive'
FROM generate_series(1, 80) AS g;

WITH emp_people AS (
  SELECT
    person_id,
    row_number() OVER (ORDER BY email) AS rn
  FROM person
  WHERE email LIKE 'team%@workmail.com'
)
INSERT INTO employee (person_id, hotel_id, role_title, hired_on, is_manager)
SELECT
  person_id,
  ((rn - 1) / 2) + 1 AS hotel_id,
  CASE WHEN rn % 2 = 1 THEN 'Manager' ELSE 'Guest Services Agent' END,
  CURRENT_DATE - ((rn % 365) || ' days')::interval,
  (rn % 2 = 1)
FROM emp_people;

INSERT INTO auth_account (role, username, password_plain, employee_id, customer_id, is_active)
VALUES ('admin', 'admin', 'admin123', NULL, NULL, TRUE);

INSERT INTO auth_account (role, username, password_plain, employee_id, customer_id, is_active)
SELECT
  CASE WHEN e.is_manager THEN 'manager' ELSE 'employee' END AS role,
  CASE
    WHEN e.is_manager THEN 'manager' || e.employee_id
    ELSE 'employee' || e.employee_id
  END AS username,
  CASE
    WHEN e.is_manager THEN 'manager' || e.employee_id || '123'
    ELSE 'employee' || e.employee_id || '123'
  END AS password_plain,
  e.employee_id,
  NULL,
  TRUE
FROM employee e
ORDER BY e.employee_id;

INSERT INTO auth_account (role, username, password_plain, employee_id, customer_id, is_active)
SELECT
  'customer',
  'customer' || c.customer_id,
  'customer' || c.customer_id || '123',
  NULL,
  c.customer_id,
  TRUE
FROM customer c
ORDER BY c.customer_id;

INSERT INTO booking (room_id, customer_id, created_by_employee_id, start_date, end_date, status)
SELECT
  g AS room_id,
  g AS customer_id,
  ((g - 1) % 80) + 1 AS created_by_employee_id,
  CURRENT_DATE + (g || ' days')::interval,
  CURRENT_DATE + ((g + 2) || ' days')::interval,
  CASE
    WHEN g <= 10 THEN 'reserved'
    WHEN g <= 15 THEN 'completed'
    ELSE 'cancelled'
  END
FROM generate_series(1, 20) AS g;

INSERT INTO renting (room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status)
SELECT
  30 + g AS room_id,
  20 + g AS customer_id,
  ((g - 1) % 80) + 1 AS employee_id,
  NULL,
  CASE WHEN g <= 4 THEN CURRENT_DATE - INTERVAL '1 day' ELSE CURRENT_DATE - ((g + 5) || ' days')::interval END,
  CASE WHEN g <= 4 THEN CURRENT_DATE + INTERVAL '2 day' ELSE CURRENT_DATE - ((g + 2) || ' days')::interval END,
  CASE
    WHEN g <= 4 THEN 'active'
    WHEN g <= 8 THEN 'completed'
    ELSE 'cancelled'
  END
FROM generate_series(1, 12) AS g;

INSERT INTO payment (renting_id, employee_id, amount, method)
SELECT
  r.renting_id,
  r.employee_id,
  (120 + r.renting_id * 15)::numeric(10,2),
  CASE
    WHEN r.renting_id % 4 = 0 THEN 'cash'
    WHEN r.renting_id % 4 = 1 THEN 'credit'
    WHEN r.renting_id % 4 = 2 THEN 'debit'
    ELSE 'online'
  END
FROM renting r
WHERE r.status IN ('active', 'completed');

UPDATE booking
SET status = 'completed'
WHERE booking_id IN (1, 2);

UPDATE renting
SET status = 'completed'
WHERE renting_id IN (1, 2);

COMMIT;
