BEGIN;

DROP VIEW IF EXISTS v_hotel_capacity_aggregate CASCADE;
DROP VIEW IF EXISTS v_available_rooms_per_area CASCADE;

DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS archive CASCADE;
DROP TABLE IF EXISTS renting CASCADE;
DROP TABLE IF EXISTS booking CASCADE;
DROP TABLE IF EXISTS room CASCADE;
DROP TABLE IF EXISTS auth_account CASCADE;
DROP TABLE IF EXISTS employee CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP TABLE IF EXISTS person CASCADE;
DROP TABLE IF EXISTS hotel CASCADE;
DROP TABLE IF EXISTS hotel_chain CASCADE;

CREATE TABLE hotel_chain (
  chain_id SERIAL PRIMARY KEY,
  chain_name VARCHAR(120) NOT NULL UNIQUE,
  central_office_address VARCHAR(255) NOT NULL,
  contact_email VARCHAR(120) NOT NULL,
  contact_phone VARCHAR(30) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE hotel (
  hotel_id SERIAL PRIMARY KEY,
  chain_id INT NOT NULL,
  hotel_name VARCHAR(140) NOT NULL,
  category SMALLINT NOT NULL CHECK (category BETWEEN 1 AND 5),
  total_rooms INT NOT NULL CHECK (total_rooms >= 1),
  address_line VARCHAR(255) NOT NULL,
  contact_email VARCHAR(120) NOT NULL,
  contact_phone VARCHAR(30) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_hotel_chain
    FOREIGN KEY (chain_id) REFERENCES hotel_chain(chain_id) ON DELETE CASCADE,
  UNIQUE(chain_id, hotel_name)
);

CREATE TABLE person (
  legal_id VARCHAR(9) PRIMARY KEY,
  id_type VARCHAR(20) NOT NULL CHECK (id_type = 'SIN'),
  first_name VARCHAR(80) NOT NULL,
  last_name VARCHAR(80) NOT NULL,
  email VARCHAR(120) NOT NULL UNIQUE,
  phone VARCHAR(30) NOT NULL,
  address_line VARCHAR(255) NOT NULL,
  CONSTRAINT person_legal_id_sin_format_check CHECK (legal_id ~ '^[0-9]{9}$')
);

CREATE TABLE customer (
  customer_id SERIAL PRIMARY KEY,
  legal_id VARCHAR(9) NOT NULL UNIQUE,
  hotel_id INT,
  registration_date DATE NOT NULL DEFAULT CURRENT_DATE,
  CONSTRAINT fk_customer_person
    FOREIGN KEY (legal_id) REFERENCES person(legal_id) ON DELETE CASCADE,
  CONSTRAINT fk_customer_hotel
    FOREIGN KEY (hotel_id) REFERENCES hotel(hotel_id) ON DELETE SET NULL
);

CREATE TABLE employee (
  employee_id SERIAL PRIMARY KEY,
  legal_id VARCHAR(9) NOT NULL UNIQUE,
  hotel_id INT NOT NULL,
  role_title VARCHAR(80) NOT NULL,
  hired_on DATE NOT NULL DEFAULT CURRENT_DATE,
  is_manager BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT fk_employee_person
    FOREIGN KEY (legal_id) REFERENCES person(legal_id) ON DELETE CASCADE,
  CONSTRAINT fk_employee_hotel
    FOREIGN KEY (hotel_id) REFERENCES hotel(hotel_id) ON DELETE CASCADE
);

CREATE TABLE auth_account (
  account_id SERIAL PRIMARY KEY,
  role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'manager', 'employee', 'customer')),
  username VARCHAR(60) NOT NULL UNIQUE,
  password_plain VARCHAR(120) NOT NULL,
  employee_id INT UNIQUE,
  customer_id INT UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_auth_account_employee
    FOREIGN KEY (employee_id) REFERENCES employee(employee_id) ON DELETE CASCADE,
  CONSTRAINT fk_auth_account_customer
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id) ON DELETE CASCADE,
  CHECK (
    (role = 'admin' AND employee_id IS NULL AND customer_id IS NULL)
    OR (role IN ('manager', 'employee') AND employee_id IS NOT NULL AND customer_id IS NULL)
    OR (role = 'customer' AND customer_id IS NOT NULL AND employee_id IS NULL)
  )
);

CREATE TABLE room (
  room_id SERIAL PRIMARY KEY,
  hotel_id INT NOT NULL,
  room_number VARCHAR(10) NOT NULL,
  capacity VARCHAR(20) NOT NULL CHECK (capacity IN ('single', 'double', 'suite', 'family')),
  base_price NUMERIC(10, 2) NOT NULL CHECK (base_price > 0),
  has_sea_view BOOLEAN NOT NULL DEFAULT FALSE,
  has_mountain_view BOOLEAN NOT NULL DEFAULT FALSE,
  is_extendable BOOLEAN NOT NULL DEFAULT FALSE,
  amenities TEXT NOT NULL,
  issues TEXT,
  current_status VARCHAR(20) NOT NULL DEFAULT 'available'
    CHECK (current_status IN ('available', 'booked', 'rented', 'maintenance')),
  CONSTRAINT fk_room_hotel
    FOREIGN KEY (hotel_id) REFERENCES hotel(hotel_id) ON DELETE CASCADE,
  UNIQUE (hotel_id, room_number)
);

CREATE TABLE booking (
  booking_id SERIAL PRIMARY KEY,
  room_id INT NOT NULL,
  customer_id INT NOT NULL,
  created_by_employee_id INT,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'reserved'
    CHECK (status IN ('reserved', 'checked_in', 'cancelled', 'completed')),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_booking_room
    FOREIGN KEY (room_id) REFERENCES room(room_id) ON DELETE CASCADE,
  CONSTRAINT fk_booking_customer
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id) ON DELETE CASCADE,
  CONSTRAINT fk_booking_created_by_employee
    FOREIGN KEY (created_by_employee_id) REFERENCES employee(employee_id) ON DELETE SET NULL,
  CHECK (end_date > start_date)
);

CREATE TABLE renting (
  renting_id SERIAL PRIMARY KEY,
  room_id INT NOT NULL,
  customer_id INT NOT NULL,
  employee_id INT NOT NULL,
  source_booking_id INT,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'completed', 'cancelled')),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_renting_room
    FOREIGN KEY (room_id) REFERENCES room(room_id) ON DELETE CASCADE,
  CONSTRAINT fk_renting_customer
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id) ON DELETE CASCADE,
  CONSTRAINT fk_renting_employee
    FOREIGN KEY (employee_id) REFERENCES employee(employee_id) ON DELETE RESTRICT,
  CONSTRAINT fk_renting_source_booking
    FOREIGN KEY (source_booking_id) REFERENCES booking(booking_id) ON DELETE SET NULL,
  CHECK (end_date > start_date)
);

CREATE TABLE archive (
  archive_id SERIAL PRIMARY KEY,
  record_type VARCHAR(20) NOT NULL CHECK (record_type IN ('booking', 'renting')),
  source_booking_id INT,
  source_renting_id INT,
  chain_name VARCHAR(120) NOT NULL,
  hotel_name VARCHAR(140) NOT NULL,
  room_number VARCHAR(10) NOT NULL,
  customer_full_name VARCHAR(180) NOT NULL,
  customer_legal_id VARCHAR(30) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  final_status VARCHAR(20) NOT NULL,
  archived_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE payment (
  payment_id SERIAL PRIMARY KEY,
  renting_id INT NOT NULL,
  employee_id INT NOT NULL,
  amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
  method VARCHAR(20) NOT NULL CHECK (method IN ('cash', 'credit', 'debit', 'online')),
  paid_at TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_payment_renting
    FOREIGN KEY (renting_id) REFERENCES renting(renting_id) ON DELETE CASCADE,
  CONSTRAINT fk_payment_employee
    FOREIGN KEY (employee_id) REFERENCES employee(employee_id) ON DELETE RESTRICT
);

CREATE OR REPLACE FUNCTION fn_validate_room_availability()
RETURNS TRIGGER AS $$
DECLARE
  overlap_count INT;
BEGIN
  IF TG_TABLE_NAME = 'booking' THEN
    IF NEW.status IN ('reserved', 'checked_in') THEN
      SELECT COUNT(*) INTO overlap_count
      FROM booking b
      WHERE b.room_id = NEW.room_id
        AND b.status IN ('reserved', 'checked_in')
        AND b.booking_id <> COALESCE(NEW.booking_id, -1)
        AND daterange(b.start_date, b.end_date, '[)') && daterange(NEW.start_date, NEW.end_date, '[)');

      IF overlap_count > 0 THEN
        RAISE EXCEPTION 'Room % already has an overlapping booking', NEW.room_id;
      END IF;

      SELECT COUNT(*) INTO overlap_count
      FROM renting r
      WHERE r.room_id = NEW.room_id
        AND r.status = 'active'
        AND daterange(r.start_date, r.end_date, '[)') && daterange(NEW.start_date, NEW.end_date, '[)');

      IF overlap_count > 0 THEN
        RAISE EXCEPTION 'Room % already has an overlapping renting', NEW.room_id;
      END IF;

      SELECT COUNT(*) INTO overlap_count
      FROM booking b
      WHERE b.customer_id = NEW.customer_id
        AND b.status IN ('reserved', 'checked_in')
        AND b.booking_id <> COALESCE(NEW.booking_id, -1)
        AND daterange(b.start_date, b.end_date, '[)') && daterange(NEW.start_date, NEW.end_date, '[)');

      IF overlap_count > 0 THEN
        RAISE EXCEPTION 'Customer % already has an overlapping booking', NEW.customer_id;
      END IF;

      SELECT COUNT(*) INTO overlap_count
      FROM renting r
      WHERE r.customer_id = NEW.customer_id
        AND r.status = 'active'
        AND daterange(r.start_date, r.end_date, '[)') && daterange(NEW.start_date, NEW.end_date, '[)');

      IF overlap_count > 0 THEN
        RAISE EXCEPTION 'Customer % already has an overlapping renting', NEW.customer_id;
      END IF;
    END IF;
  ELSIF TG_TABLE_NAME = 'renting' THEN
    IF NEW.status = 'active' THEN
      SELECT COUNT(*) INTO overlap_count
      FROM renting r
      WHERE r.room_id = NEW.room_id
        AND r.status = 'active'
        AND r.renting_id <> COALESCE(NEW.renting_id, -1)
        AND daterange(r.start_date, r.end_date, '[)') && daterange(NEW.start_date, NEW.end_date, '[)');

      IF overlap_count > 0 THEN
        RAISE EXCEPTION 'Room % already has an overlapping renting', NEW.room_id;
      END IF;

      SELECT COUNT(*) INTO overlap_count
      FROM booking b
      WHERE b.room_id = NEW.room_id
        AND b.status IN ('reserved', 'checked_in')
        AND (NEW.source_booking_id IS NULL OR b.booking_id <> NEW.source_booking_id)
        AND daterange(b.start_date, b.end_date, '[)') && daterange(NEW.start_date, NEW.end_date, '[)');

      IF overlap_count > 0 THEN
        RAISE EXCEPTION 'Room % already has an overlapping booking', NEW.room_id;
      END IF;

      SELECT COUNT(*) INTO overlap_count
      FROM renting r
      WHERE r.customer_id = NEW.customer_id
        AND r.status = 'active'
        AND r.renting_id <> COALESCE(NEW.renting_id, -1)
        AND daterange(r.start_date, r.end_date, '[)') && daterange(NEW.start_date, NEW.end_date, '[)');

      IF overlap_count > 0 THEN
        RAISE EXCEPTION 'Customer % already has an overlapping renting', NEW.customer_id;
      END IF;

      SELECT COUNT(*) INTO overlap_count
      FROM booking b
      WHERE b.customer_id = NEW.customer_id
        AND b.status IN ('reserved', 'checked_in')
        AND (NEW.source_booking_id IS NULL OR b.booking_id <> NEW.source_booking_id)
        AND daterange(b.start_date, b.end_date, '[)') && daterange(NEW.start_date, NEW.end_date, '[)');

      IF overlap_count > 0 THEN
        RAISE EXCEPTION 'Customer % already has an overlapping booking', NEW.customer_id;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_sync_room_status(target_room_id INT)
RETURNS VOID AS $$
DECLARE
  has_renting BOOLEAN;
  has_booking BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM renting r
    WHERE r.room_id = target_room_id
      AND r.status = 'active'
      AND daterange(r.start_date, r.end_date, '[)') @> CURRENT_DATE
  ) INTO has_renting;

  SELECT EXISTS (
    SELECT 1 FROM booking b
    WHERE b.room_id = target_room_id
      AND b.status IN ('reserved', 'checked_in')
      AND daterange(b.start_date, b.end_date, '[)') @> CURRENT_DATE
  ) INTO has_booking;

  UPDATE room
  SET current_status = CASE
    WHEN has_renting THEN 'rented'
    WHEN has_booking THEN 'booked'
    ELSE 'available'
  END
  WHERE room_id = target_room_id
    AND current_status <> 'maintenance';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_after_booking_change()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM fn_sync_room_status(COALESCE(NEW.room_id, OLD.room_id));
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_after_renting_change()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM fn_sync_room_status(COALESCE(NEW.room_id, OLD.room_id));
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_archive_booking()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('completed', 'cancelled')
     AND NOT EXISTS (
       SELECT 1
       FROM archive a
       WHERE a.record_type = 'booking'
         AND a.source_booking_id = NEW.booking_id
     ) THEN
    INSERT INTO archive (
      record_type,
      source_booking_id,
      source_renting_id,
      chain_name,
      hotel_name,
      room_number,
      customer_full_name,
      customer_legal_id,
      start_date,
      end_date,
      final_status
    )
    SELECT
      'booking',
      NEW.booking_id,
      NULL,
      hc.chain_name,
      h.hotel_name,
      rm.room_number,
      p.first_name || ' ' || p.last_name,
      p.legal_id,
      NEW.start_date,
      NEW.end_date,
      NEW.status
    FROM room rm
    JOIN hotel h ON h.hotel_id = rm.hotel_id
    JOIN hotel_chain hc ON hc.chain_id = h.chain_id
    JOIN customer c ON c.customer_id = NEW.customer_id
    JOIN person p ON p.legal_id = c.legal_id
    WHERE rm.room_id = NEW.room_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_archive_renting()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('completed', 'cancelled')
     AND NOT EXISTS (
       SELECT 1
       FROM archive a
       WHERE a.record_type = 'renting'
         AND a.source_renting_id = NEW.renting_id
     ) THEN
    INSERT INTO archive (
      record_type,
      source_booking_id,
      source_renting_id,
      chain_name,
      hotel_name,
      room_number,
      customer_full_name,
      customer_legal_id,
      start_date,
      end_date,
      final_status
    )
    SELECT
      'renting',
      NEW.source_booking_id,
      NEW.renting_id,
      hc.chain_name,
      h.hotel_name,
      rm.room_number,
      p.first_name || ' ' || p.last_name,
      p.legal_id,
      NEW.start_date,
      NEW.end_date,
      NEW.status
    FROM room rm
    JOIN hotel h ON h.hotel_id = rm.hotel_id
    JOIN hotel_chain hc ON hc.chain_id = h.chain_id
    JOIN customer c ON c.customer_id = NEW.customer_id
    JOIN person p ON p.legal_id = c.legal_id
    WHERE rm.room_id = NEW.room_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_booking_validate
BEFORE INSERT OR UPDATE ON booking
FOR EACH ROW EXECUTE FUNCTION fn_validate_room_availability();

CREATE TRIGGER trg_renting_validate
BEFORE INSERT OR UPDATE ON renting
FOR EACH ROW EXECUTE FUNCTION fn_validate_room_availability();

CREATE TRIGGER trg_booking_status_sync
AFTER INSERT OR UPDATE OR DELETE ON booking
FOR EACH ROW EXECUTE FUNCTION fn_after_booking_change();

CREATE TRIGGER trg_renting_status_sync
AFTER INSERT OR UPDATE OR DELETE ON renting
FOR EACH ROW EXECUTE FUNCTION fn_after_renting_change();

CREATE TRIGGER trg_archive_booking
AFTER UPDATE OF status ON booking
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION fn_archive_booking();

CREATE TRIGGER trg_archive_booking_insert
AFTER INSERT ON booking
FOR EACH ROW
WHEN (NEW.status IN ('completed', 'cancelled'))
EXECUTE FUNCTION fn_archive_booking();

CREATE TRIGGER trg_archive_renting
AFTER UPDATE OF status ON renting
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION fn_archive_renting();

CREATE TRIGGER trg_archive_renting_insert
AFTER INSERT ON renting
FOR EACH ROW
WHEN (NEW.status IN ('completed', 'cancelled'))
EXECUTE FUNCTION fn_archive_renting();

INSERT INTO archive (
  record_type,
  source_booking_id,
  source_renting_id,
  chain_name,
  hotel_name,
  room_number,
  customer_full_name,
  customer_legal_id,
  start_date,
  end_date,
  final_status
)
SELECT
  'booking',
  b.booking_id,
  NULL,
  hc.chain_name,
  h.hotel_name,
  rm.room_number,
  p.first_name || ' ' || p.last_name,
  p.legal_id,
  b.start_date,
  b.end_date,
  b.status
FROM booking b
JOIN room rm ON rm.room_id = b.room_id
JOIN hotel h ON h.hotel_id = rm.hotel_id
JOIN hotel_chain hc ON hc.chain_id = h.chain_id
JOIN customer c ON c.customer_id = b.customer_id
JOIN person p ON p.legal_id = c.legal_id
WHERE b.status IN ('completed', 'cancelled')
  AND NOT EXISTS (
    SELECT 1
    FROM archive a
    WHERE a.record_type = 'booking'
      AND a.source_booking_id = b.booking_id
  );

INSERT INTO archive (
  record_type,
  source_booking_id,
  source_renting_id,
  chain_name,
  hotel_name,
  room_number,
  customer_full_name,
  customer_legal_id,
  start_date,
  end_date,
  final_status
)
SELECT
  'renting',
  rt.source_booking_id,
  rt.renting_id,
  hc.chain_name,
  h.hotel_name,
  rm.room_number,
  p.first_name || ' ' || p.last_name,
  p.legal_id,
  rt.start_date,
  rt.end_date,
  rt.status
FROM renting rt
JOIN room rm ON rm.room_id = rt.room_id
JOIN hotel h ON h.hotel_id = rm.hotel_id
JOIN hotel_chain hc ON hc.chain_id = h.chain_id
JOIN customer c ON c.customer_id = rt.customer_id
JOIN person p ON p.legal_id = c.legal_id
WHERE rt.status IN ('completed', 'cancelled')
  AND NOT EXISTS (
    SELECT 1
    FROM archive a
    WHERE a.record_type = 'renting'
      AND a.source_renting_id = rt.renting_id
  );

CREATE INDEX idx_room_capacity_price_status ON room(capacity, base_price, current_status);
CREATE INDEX idx_hotel_filtering ON hotel(chain_id, category, total_rooms);
CREATE INDEX idx_booking_room_dates ON booking(room_id, start_date, end_date);
CREATE INDEX idx_booking_customer_dates ON booking(customer_id, start_date, end_date);
CREATE INDEX idx_renting_room_dates ON renting(room_id, start_date, end_date);
CREATE INDEX idx_renting_customer_dates ON renting(customer_id, start_date, end_date);
CREATE INDEX idx_auth_account_role_active ON auth_account(role, is_active);

CREATE OR REPLACE VIEW v_available_rooms_per_area AS
SELECT
  COALESCE(NULLIF(BTRIM(SPLIT_PART(h.address_line, ',', 2)), ''), h.address_line) AS area,
  COUNT(*)::INT AS available_rooms
FROM room r
JOIN hotel h ON h.hotel_id = r.hotel_id
WHERE r.current_status = 'available'
GROUP BY COALESCE(NULLIF(BTRIM(SPLIT_PART(h.address_line, ',', 2)), ''), h.address_line)
ORDER BY area;

CREATE OR REPLACE VIEW v_hotel_capacity_aggregate AS
SELECT
  h.hotel_id,
  h.hotel_name,
  h.address_line,
  SUM(
    CASE r.capacity
      WHEN 'single' THEN 1
      WHEN 'double' THEN 2
      WHEN 'suite' THEN 3
      WHEN 'family' THEN 4
      ELSE 0
    END
  )::INT AS aggregated_capacity
FROM hotel h
JOIN room r ON r.hotel_id = h.hotel_id
GROUP BY h.hotel_id, h.hotel_name, h.address_line
ORDER BY h.hotel_id;

COMMIT;
