const express = require('express');
const methodOverride = require('method-override');
const db = require('./db');
const { initializeDatabaseIfNeeded } = require('./db-init');

const app = express();
const PORT = Number(process.env.PORT || 3000);

app.set('view engine', 'ejs');
app.set('views', 'views');
app.use(express.urlencoded({ extended: true }));
app.use(methodOverride('_method'));
app.use(express.static('public'));

const AUTH_COOKIE = 'ehotels_session';
const AUTH_COOKIE_MAX_AGE = 60 * 60 * 8;
const VALID_ROLES = ['admin', 'manager', 'employee', 'customer'];
const ROLE_LABELS = {
  admin: 'Admin',
  manager: 'Manager',
  employee: 'Employee',
  customer: 'Customer'
};
const LOGIN_ROLES = ['admin', 'employee', 'customer'];
const ROLE_HOME = {
  admin: '/',
  manager: '/',
  employee: '/',
  customer: '/customer/bookings'
};

function parseCookies(cookieHeader = '') {
  return cookieHeader.split(';').reduce((acc, rawCookie) => {
    const [rawKey, ...rawValue] = rawCookie.trim().split('=');
    if (!rawKey) return acc;
    acc[rawKey] = decodeURIComponent(rawValue.join('='));
    return acc;
  }, {});
}

function setAuthCookie(res, accountId) {
  res.setHeader('Set-Cookie', `${AUTH_COOKIE}=${encodeURIComponent(String(accountId))}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${AUTH_COOKIE_MAX_AGE}`);
}

function clearAuthCookie(res) {
  res.setHeader('Set-Cookie', `${AUTH_COOKIE}=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0`);
}

function sanitizeDate(value) {
  if (!value) return null;
  const candidate = new Date(value);
  return Number.isNaN(candidate.getTime()) ? null : value;
}

function easternTodayISO() {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Toronto',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).formatToParts(new Date());
  const year = parts.find((p) => p.type === 'year')?.value;
  const month = parts.find((p) => p.type === 'month')?.value;
  const day = parts.find((p) => p.type === 'day')?.value;
  return `${year}-${month}-${day}`;
}

function toIsoDate(value) {
  if (!value) return null;
  if (typeof value === 'string') {
    return value.slice(0, 10);
  }
  return new Date(value).toISOString().slice(0, 10);
}

function normalizeString(value, fieldName, maxLength, allowEmpty = false) {
  const normalized = String(value || '').trim();
  if (!allowEmpty && normalized.length === 0) {
    throw new Error(`${fieldName} is required.`);
  }
  if (normalized.length > maxLength) {
    throw new Error(`${fieldName} must be at most ${maxLength} characters.`);
  }
  return normalized;
}

function normalizeOptionalString(value, fieldName, maxLength) {
  const normalized = String(value || '').trim();
  if (normalized.length === 0) return null;
  if (normalized.length > maxLength) {
    throw new Error(`${fieldName} must be at most ${maxLength} characters.`);
  }
  return normalized;
}

function normalizeEmail(value, fieldName = 'Email') {
  const email = normalizeString(value, fieldName, 120).toLowerCase();
  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailPattern.test(email)) {
    throw new Error(`${fieldName} is invalid.`);
  }
  return email;
}

function normalizePhone(value, fieldName = 'Phone') {
  const digitsOnly = String(value || '').replace(/\D/g, '');
  if (!/^\d{10}$/.test(digitsOnly)) {
    throw new Error(`${fieldName} must contain exactly 10 digits.`);
  }
  return digitsOnly;
}

function normalizeSin(value, fieldName = 'SIN') {
  const digitsOnly = String(value || '').replace(/\D/g, '');
  if (!/^\d{9}$/.test(digitsOnly)) {
    throw new Error(`${fieldName} must contain exactly 9 digits (example: 111111111).`);
  }
  return digitsOnly;
}

function parsePositiveInt(value, fieldName, min = 1) {
  const parsed = Number.parseInt(String(value || ''), 10);
  if (!Number.isInteger(parsed) || parsed < min) {
    throw new Error(`${fieldName} must be an integer greater than or equal to ${min}.`);
  }
  return parsed;
}

function parseOptionalPositiveInt(value, fieldName, min = 1) {
  if (value === undefined || value === null || String(value).trim() === '') {
    return null;
  }
  return parsePositiveInt(value, fieldName, min);
}

function parsePositiveNumber(value, fieldName, min = 0.01) {
  const parsed = Number.parseFloat(String(value || ''));
  if (!Number.isFinite(parsed) || parsed < min) {
    throw new Error(`${fieldName} must be a number greater than or equal to ${min}.`);
  }
  return parsed;
}

function parseEnum(value, allowedValues, fieldName) {
  const normalized = String(value || '').trim();
  if (!allowedValues.includes(normalized)) {
    throw new Error(`${fieldName} is invalid.`);
  }
  return normalized;
}

function parseDateInput(value, fieldName) {
  const normalized = sanitizeDate(String(value || '').trim());
  if (!normalized) {
    throw new Error(`${fieldName} is invalid.`);
  }
  return normalized;
}

function ensureEndDateAfterStartDate(startDate, endDate, startField = 'Start date', endField = 'End date') {
  if (new Date(endDate) <= new Date(startDate)) {
    throw new Error(`${endField} must be after ${startField}.`);
  }
}

function parseCheckbox(value) {
  return value === 'on';
}

function parseBooleanInput(value, fieldName) {
  const normalized = String(value || '').trim().toLowerCase();
  if (['true', '1', 'yes', 'on', 'active', 'enabled', 'enable'].includes(normalized)) {
    return true;
  }
  if (['false', '0', 'no', 'off', 'inactive', 'disabled', 'disable'].includes(normalized)) {
    return false;
  }
  throw new Error(`${fieldName} is invalid.`);
}

function normalizeUsername(value) {
  const username = normalizeString(value, 'Username', 60).toLowerCase();
  if (!/^[a-z0-9._-]{3,60}$/.test(username)) {
    throw new Error('Username must be 3-60 characters and use only letters, numbers, ".", "_" or "-".');
  }
  return username;
}

function normalizePassword(value) {
  const password = String(value || '');
  if (password.length < 6 || password.length > 120) {
    throw new Error('Password must be between 6 and 120 characters.');
  }
  return password;
}

function inactiveMessageForRole(role) {
  if (role === 'employee' || role === 'manager') {
    return 'Your account is inactive. You do not work here anymore.';
  }
  if (role === 'customer') {
    return 'Your customer account is inactive. Please contact an employee to reactivate it.';
  }
  return 'Your account is inactive.';
}

function parseStaffAccountRole(value) {
  return parseEnum(value, ['employee', 'manager'], 'Account role');
}

function buildMessage(query) {
  if (!query.msg) return null;
  return { type: query.type || 'info', text: query.msg };
}

function formatConstraintViolation(err) {
  if (!err || err.code !== '23505') return null;
  const constraint = String(err.constraint || '');
  if (constraint.includes('auth_account_username')) {
    return 'Username is already taken.';
  }
  if (constraint.includes('person_email')) {
    return 'Email is already registered.';
  }
  if (constraint.includes('person_legal_id')) {
    return 'SIN is already registered.';
  }
  return 'An account with the same unique information already exists.';
}

function redirectWith(res, path, msg, type = 'info') {
  const separator = path.includes('?') ? '&' : '?';
  res.redirect(`${path}${separator}msg=${encodeURIComponent(msg)}&type=${encodeURIComponent(type)}`);
}

function requireRole(allowedRoles) {
  return (req, res, next) => {
    if (!req.auth?.isAuthenticated) {
      return redirectWith(res, '/login', 'Please log in to continue.', 'info');
    }
    if (!allowedRoles.includes(req.auth.role)) {
      return redirectWith(res, ROLE_HOME[req.auth.role] || '/', 'You do not have permission for that page.', 'error');
    }
    return next();
  };
}

function emptyAuthState() {
  return {
    isAuthenticated: false,
    accountId: null,
    role: null,
    username: null,
    legalId: null,
    displayName: null,
    customerId: null,
    employeeId: null,
    personId: null,
    isActive: false
  };
}

async function fetchAccountById(accountId) {
  const result = await db.query(
    `SELECT
       a.account_id,
       a.role,
       a.username,
       a.password_plain,
       a.is_active,
       a.employee_id,
       a.customer_id,
       cp.legal_id,
       COALESCE(ep.person_id, cp.person_id) AS person_id,
       COALESCE(
         ep.first_name || ' ' || ep.last_name,
         cp.first_name || ' ' || cp.last_name,
         'Administrator'
       ) AS display_name
     FROM auth_account a
     LEFT JOIN employee e ON e.employee_id = a.employee_id
     LEFT JOIN person ep ON ep.person_id = e.person_id
     LEFT JOIN customer c ON c.customer_id = a.customer_id
     LEFT JOIN person cp ON cp.person_id = c.person_id
     WHERE a.account_id = $1`,
    [accountId]
  );

  return result.rows[0] || null;
}

async function fetchAccountByRoleAndUsername(role, username) {
  const result = await db.query(
    `SELECT
       a.account_id,
       a.role,
       a.username,
       a.password_plain,
       a.is_active,
       a.employee_id,
       a.customer_id,
       cp.legal_id,
       COALESCE(ep.person_id, cp.person_id) AS person_id,
       COALESCE(
         ep.first_name || ' ' || ep.last_name,
         cp.first_name || ' ' || cp.last_name,
         'Administrator'
       ) AS display_name
     FROM auth_account a
     LEFT JOIN employee e ON e.employee_id = a.employee_id
     LEFT JOIN person ep ON ep.person_id = e.person_id
     LEFT JOIN customer c ON c.customer_id = a.customer_id
     LEFT JOIN person cp ON cp.person_id = c.person_id
     WHERE a.role = $1 AND lower(a.username) = lower($2)
     LIMIT 1`,
    [role, username]
  );

  return result.rows[0] || null;
}

async function fetchStaffAccountByUsername(username) {
  const result = await db.query(
    `SELECT
       a.account_id,
       a.role,
       a.username,
       a.password_plain,
       a.is_active,
       a.employee_id,
       a.customer_id,
       cp.legal_id,
       COALESCE(ep.person_id, cp.person_id) AS person_id,
       COALESCE(
         ep.first_name || ' ' || ep.last_name,
         cp.first_name || ' ' || cp.last_name,
         'Administrator'
       ) AS display_name
     FROM auth_account a
     LEFT JOIN employee e ON e.employee_id = a.employee_id
     LEFT JOIN person ep ON ep.person_id = e.person_id
     LEFT JOIN customer c ON c.customer_id = a.customer_id
     LEFT JOIN person cp ON cp.person_id = c.person_id
     WHERE a.role IN ('employee', 'manager') AND lower(a.username) = lower($1)
     LIMIT 1`,
    [username]
  );

  return result.rows[0] || null;
}

async function fetchCustomerAccountBySin(sin) {
  const result = await db.query(
    `SELECT
       a.account_id,
       a.role,
       a.username,
       a.password_plain,
       a.is_active,
       a.employee_id,
       a.customer_id,
       p.legal_id,
       p.person_id,
       p.first_name || ' ' || p.last_name AS display_name
     FROM auth_account a
     JOIN customer c ON c.customer_id = a.customer_id
     JOIN person p ON p.person_id = c.person_id
     WHERE a.role = 'customer'
       AND p.legal_id = $1
     LIMIT 1`,
    [sin]
  );
  return result.rows[0] || null;
}

function mapAccountToAuth(account) {
  return {
    isAuthenticated: true,
    accountId: account.account_id,
    role: account.role,
    username: account.username,
    legalId: account.legal_id || null,
    displayName: account.display_name,
    customerId: account.customer_id,
    employeeId: account.employee_id,
    personId: account.person_id,
    isActive: account.is_active
  };
}

async function customerHasOpenBookingOrRenting(customerId, client = db) {
  const openRows = await client.query(
    `SELECT
       EXISTS (
         SELECT 1
         FROM booking
         WHERE customer_id = $1
           AND status IN ('reserved', 'checked_in')
       ) AS has_open_booking,
       EXISTS (
         SELECT 1
         FROM renting
         WHERE customer_id = $1
           AND status = 'active'
       ) AS has_active_renting`,
    [customerId]
  );
  const row = openRows.rows[0] || { has_open_booking: false, has_active_renting: false };
  return Boolean(row.has_open_booking || row.has_active_renting);
}

async function archiveCustomerHistory(client, customerId) {
  await client.query(
    `INSERT INTO archive (
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
     JOIN person p ON p.person_id = c.person_id
     WHERE b.customer_id = $1
       AND NOT EXISTS (
         SELECT 1
         FROM archive a
         WHERE a.record_type = 'booking'
           AND a.source_booking_id = b.booking_id
       )`,
    [customerId]
  );

  await client.query(
    `INSERT INTO archive (
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
     JOIN person p ON p.person_id = c.person_id
     WHERE rt.customer_id = $1
       AND NOT EXISTS (
         SELECT 1
         FROM archive a
         WHERE a.record_type = 'renting'
           AND a.source_renting_id = rt.renting_id
       )`,
    [customerId]
  );
}

function assertCanManageStaffAccount(currentRole, targetRole) {
  if (!['employee', 'manager'].includes(targetRole)) {
    throw new Error('Target account is not a staff account.');
  }
  if (currentRole === 'admin') {
    return;
  }
  if (currentRole === 'manager' && targetRole === 'employee') {
    return;
  }
  throw new Error('You do not have permission to manage this staff account.');
}

async function fetchStaffHotelId(employeeId, roleLabel = 'Staff') {
  const result = await db.query(
    `SELECT hotel_id
     FROM employee
     WHERE employee_id = $1
     LIMIT 1`,
    [employeeId]
  );
  if (result.rowCount === 0) {
    throw new Error(`${roleLabel} profile is not linked to a valid employee record.`);
  }
  return result.rows[0].hotel_id;
}

async function fetchManagerHotelId(employeeId) {
  return fetchStaffHotelId(employeeId, 'Manager');
}

async function ensurePersonSinSchemaAndData() {
  const personTable = await db.query("SELECT to_regclass('public.person') AS table_name");
  if (!personTable.rows[0].table_name) {
    return;
  }

  await db.query(`
    WITH valid_sins AS (
      SELECT legal_id::BIGINT AS sin_value
      FROM person
      WHERE legal_id ~ '^[0-9]{9}$'
    ),
    base AS (
      SELECT COALESCE(MAX(sin_value), 100000000) AS max_sin
      FROM valid_sins
    ),
    invalid_people AS (
      SELECT
        person_id,
        row_number() OVER (ORDER BY person_id) AS rn
      FROM person
      WHERE legal_id !~ '^[0-9]{9}$'
    )
    UPDATE person p
    SET legal_id = LPAD(((SELECT max_sin FROM base) + invalid_people.rn)::TEXT, 9, '0')
    FROM invalid_people
    WHERE p.person_id = invalid_people.person_id
  `);

  await db.query(`UPDATE person SET id_type = 'SIN' WHERE id_type <> 'SIN'`);
  await db.query(`ALTER TABLE person DROP CONSTRAINT IF EXISTS person_id_type_check`);
  await db.query(`ALTER TABLE person DROP CONSTRAINT IF EXISTS person_legal_id_sin_format_check`);
  await db.query(`ALTER TABLE person ALTER COLUMN legal_id TYPE VARCHAR(9)`);
  await db.query(`ALTER TABLE person ADD CONSTRAINT person_id_type_check CHECK (id_type = 'SIN')`);
  await db.query(`ALTER TABLE person ADD CONSTRAINT person_legal_id_sin_format_check CHECK (legal_id ~ '^[0-9]{9}$')`);
}

async function ensureCustomerHotelSchemaAndData() {
  const customerTable = await db.query("SELECT to_regclass('public.customer') AS table_name");
  if (!customerTable.rows[0].table_name) {
    return;
  }

  const hotelIdColumn = await db.query(
    `SELECT 1
     FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = 'customer'
       AND column_name = 'hotel_id'
     LIMIT 1`
  );

  if (hotelIdColumn.rowCount === 0) {
    await db.query(`ALTER TABLE customer ADD COLUMN hotel_id INT`);
  }

  await db.query(`
    WITH booking_hotel AS (
      SELECT b.customer_id, MIN(r.hotel_id) AS hotel_id
      FROM booking b
      JOIN room r ON r.room_id = b.room_id
      GROUP BY b.customer_id
    ),
    renting_hotel AS (
      SELECT rt.customer_id, MIN(r.hotel_id) AS hotel_id
      FROM renting rt
      JOIN room r ON r.room_id = rt.room_id
      GROUP BY rt.customer_id
    )
    UPDATE customer c
    SET hotel_id = COALESCE(booking_hotel.hotel_id, renting_hotel.hotel_id)
    FROM booking_hotel
    FULL OUTER JOIN renting_hotel ON renting_hotel.customer_id = booking_hotel.customer_id
    WHERE c.customer_id = COALESCE(booking_hotel.customer_id, renting_hotel.customer_id)
      AND c.hotel_id IS NULL
  `);

  await db.query(`ALTER TABLE customer DROP CONSTRAINT IF EXISTS customer_hotel_id_fkey`);
  await db.query(`ALTER TABLE customer ALTER COLUMN hotel_id DROP NOT NULL`);
  await db.query(`
    ALTER TABLE customer
    ADD CONSTRAINT customer_hotel_id_fkey
    FOREIGN KEY (hotel_id) REFERENCES hotel(hotel_id) ON DELETE SET NULL
  `);
  await db.query(`CREATE INDEX IF NOT EXISTS idx_customer_hotel_id ON customer(hotel_id)`);
}

async function ensureArchiveSchemaAndData() {
  const archiveTable = await db.query("SELECT to_regclass('public.archive') AS table_name");
  if (!archiveTable.rows[0].table_name) {
    return;
  }

  await db.query(`ALTER TABLE archive DROP COLUMN IF EXISTS amount_paid`);

  await db.query(`
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
        JOIN person p ON p.person_id = c.person_id
        WHERE rm.room_id = NEW.room_id;
      END IF;

      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
  `);

  await db.query(`
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
        JOIN person p ON p.person_id = c.person_id
        WHERE rm.room_id = NEW.room_id;
      END IF;

      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
  `);

  await db.query(`DROP TRIGGER IF EXISTS trg_archive_booking_insert ON booking`);
  await db.query(`
    CREATE TRIGGER trg_archive_booking_insert
    AFTER INSERT ON booking
    FOR EACH ROW
    WHEN (NEW.status IN ('completed', 'cancelled'))
    EXECUTE FUNCTION fn_archive_booking()
  `);

  await db.query(`DROP TRIGGER IF EXISTS trg_archive_renting_insert ON renting`);
  await db.query(`
    CREATE TRIGGER trg_archive_renting_insert
    AFTER INSERT ON renting
    FOR EACH ROW
    WHEN (NEW.status IN ('completed', 'cancelled'))
    EXECUTE FUNCTION fn_archive_renting()
  `);

  await db.query(`
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
    JOIN person p ON p.person_id = c.person_id
    WHERE b.status IN ('completed', 'cancelled')
      AND NOT EXISTS (
        SELECT 1
        FROM archive a
        WHERE a.record_type = 'booking'
          AND a.source_booking_id = b.booking_id
      )
  `);

  await db.query(`
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
    JOIN person p ON p.person_id = c.person_id
    WHERE rt.status IN ('completed', 'cancelled')
      AND NOT EXISTS (
        SELECT 1
        FROM archive a
        WHERE a.record_type = 'renting'
          AND a.source_renting_id = rt.renting_id
      )
  `);
}

async function ensureHotelCoverageBaseline() {
  const hotelsResult = await db.query(`SELECT hotel_id FROM hotel ORDER BY hotel_id`);
  if (hotelsResult.rowCount === 0) return;

  const hotelIds = hotelsResult.rows.map((row) => row.hotel_id);

  const sinResult = await db.query(
    `SELECT COALESCE(MAX(CASE WHEN legal_id ~ '^[0-9]{9}$' THEN legal_id::BIGINT END), 100000000) AS max_sin
     FROM person`
  );
  let nextSin = Number(sinResult.rows[0].max_sin);

  const roomCountsResult = await db.query(
    `SELECT hotel_id, COUNT(*)::INT AS count
     FROM room
     GROUP BY hotel_id`
  );
  const roomCountMap = new Map(roomCountsResult.rows.map((row) => [row.hotel_id, row.count]));

  const staffCountsResult = await db.query(
    `SELECT
       hotel_id,
       SUM(CASE WHEN is_manager THEN 1 ELSE 0 END)::INT AS manager_count,
       SUM(CASE WHEN NOT is_manager THEN 1 ELSE 0 END)::INT AS employee_count
     FROM employee
     GROUP BY hotel_id`
  );
  const staffCountMap = new Map(
    staffCountsResult.rows.map((row) => [row.hotel_id, {
      manager_count: row.manager_count || 0,
      employee_count: row.employee_count || 0
    }])
  );

  for (const hotelId of hotelIds) {
    const existingRooms = await db.query(
      `SELECT room_number
       FROM room
       WHERE hotel_id = $1`,
      [hotelId]
    );
    const usedRoomNumbers = new Set(existingRooms.rows.map((row) => String(row.room_number)));
    const currentRoomCount = roomCountMap.get(hotelId) || 0;
    let nextRoomNumber = 100;

    for (let i = currentRoomCount; i < 5; i += 1) {
      while (usedRoomNumbers.has(String(nextRoomNumber))) {
        nextRoomNumber += 1;
      }
      const roomNumber = String(nextRoomNumber);
      usedRoomNumbers.add(roomNumber);
      nextRoomNumber += 1;

      const capacityCycle = ['single', 'double', 'suite', 'family', 'double'];
      const capacity = capacityCycle[i % capacityCycle.length];
      const basePrice = (95 + hotelId * 2 + i * 12).toFixed(2);

      await db.query(
        `INSERT INTO room (
           hotel_id,
           room_number,
           capacity,
           base_price,
           has_sea_view,
           has_mountain_view,
           is_extendable,
           amenities,
           issues,
           current_status
         )
         VALUES ($1, $2, $3, $4, FALSE, FALSE, $5, $6, NULL, 'available')`,
        [hotelId, roomNumber, capacity, basePrice, capacity === 'double' || capacity === 'family', 'WiFi, TV']
      );
    }

    const staffCounts = staffCountMap.get(hotelId) || { manager_count: 0, employee_count: 0 };
    const needManager = staffCounts.manager_count < 1;
    const needEmployee = staffCounts.employee_count < 1;

    if (!needManager && !needEmployee) {
      continue;
    }

    const createStaff = async (isManager) => {
      nextSin += 1;
      const sin = String(nextSin).padStart(9, '0');
      const firstName = isManager ? 'Hotel' : 'Frontdesk';
      const lastName = `${isManager ? 'Manager' : 'Employee'}${hotelId}`;
      const email = `${isManager ? 'manager' : 'employee'}.hotel${hotelId}.${sin}@workmail.com`;
      const phone = String(2000000000 + (nextSin % 7000000000)).slice(-10);
      const address = `${300 + hotelId} Service Road`;

      const person = await db.query(
        `INSERT INTO person (legal_id, id_type, first_name, last_name, email, phone, address_line)
         VALUES ($1, 'SIN', $2, $3, $4, $5, $6)
         RETURNING person_id`,
        [sin, firstName, lastName, email, phone, address]
      );

      await db.query(
        `INSERT INTO employee (person_id, hotel_id, role_title, hired_on, is_manager)
         VALUES ($1, $2, $3, CURRENT_DATE, $4)`,
        [person.rows[0].person_id, hotelId, isManager ? 'Manager' : 'Guest Services Agent', isManager]
      );
    };

    if (needManager) {
      await createStaff(true);
    }
    if (needEmployee) {
      await createStaff(false);
    }
  }
}

async function ensureAuthSchemaAndSeed() {
  await db.query(`
    CREATE TABLE IF NOT EXISTS auth_account (
      account_id SERIAL PRIMARY KEY,
      role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'manager', 'employee', 'customer')),
      username VARCHAR(60) NOT NULL UNIQUE,
      password_plain VARCHAR(120) NOT NULL,
      employee_id INT UNIQUE REFERENCES employee(employee_id) ON DELETE CASCADE,
      customer_id INT UNIQUE REFERENCES customer(customer_id) ON DELETE CASCADE,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      CHECK (
        (role = 'admin' AND employee_id IS NULL AND customer_id IS NULL)
        OR (role IN ('manager', 'employee') AND employee_id IS NOT NULL AND customer_id IS NULL)
        OR (role = 'customer' AND customer_id IS NOT NULL AND employee_id IS NULL)
      )
    )
  `);
  await db.query(`CREATE INDEX IF NOT EXISTS idx_auth_account_role_active ON auth_account(role, is_active)`);

  await db.query(
    `INSERT INTO auth_account (role, username, password_plain, employee_id, customer_id, is_active)
     SELECT 'admin', 'admin', 'admin123', NULL, NULL, TRUE
     WHERE NOT EXISTS (SELECT 1 FROM auth_account WHERE role = 'admin')`
  );

  await db.query(
    `INSERT INTO auth_account (role, username, password_plain, employee_id, customer_id, is_active)
     SELECT
       CASE WHEN e.is_manager THEN 'manager' ELSE 'employee' END,
       CASE WHEN e.is_manager THEN 'manager' || e.employee_id ELSE 'employee' || e.employee_id END,
       CASE WHEN e.is_manager THEN 'manager' || e.employee_id || '123' ELSE 'employee' || e.employee_id || '123' END,
       e.employee_id,
       NULL,
       TRUE
     FROM employee e
     LEFT JOIN auth_account a ON a.employee_id = e.employee_id
     WHERE a.account_id IS NULL`
  );

  await db.query(
    `INSERT INTO auth_account (role, username, password_plain, employee_id, customer_id, is_active)
     SELECT
       'customer',
       'customer' || c.customer_id,
       'customer' || c.customer_id || '123',
       NULL,
       c.customer_id,
       TRUE
     FROM customer c
     LEFT JOIN auth_account a ON a.customer_id = c.customer_id
     WHERE a.account_id IS NULL`
  );
}

app.use(async (req, res, next) => {
  try {
    const cookies = parseCookies(req.headers.cookie || '');
    const rawSession = cookies[AUTH_COOKIE];
    const sessionAccountId = Number.parseInt(String(rawSession || ''), 10);

    req.auth = emptyAuthState();
    req.authDisabledMessage = null;

    if (Number.isInteger(sessionAccountId) && sessionAccountId > 0) {
      const account = await fetchAccountById(sessionAccountId);
      if (account && account.is_active) {
        req.auth = mapAccountToAuth(account);
      } else if (account && !account.is_active) {
        req.authDisabledMessage = inactiveMessageForRole(account.role);
        clearAuthCookie(res);
      } else {
        clearAuthCookie(res);
      }
    }

    res.locals.auth = req.auth;
    next();
  } catch (err) {
    next(err);
  }
});

app.get('/login', (req, res) => {
  if (req.auth.isAuthenticated) {
    return res.redirect(ROLE_HOME[req.auth.role] || '/');
  }
  return res.render('login-select', {
    title: 'Choose Login Role',
    message: buildMessage(req.query)
  });
});

app.get('/signup/customer', (req, res) => {
  if (req.auth.isAuthenticated) {
    return res.redirect(ROLE_HOME[req.auth.role] || '/');
  }
  return res.render('signup-customer', {
    title: 'Customer Sign Up',
    message: buildMessage(req.query)
  });
});

app.post('/signup/customer', async (req, res) => {
  const client = await db.getClient();
  try {
    const {
      legal_id,
      id_type,
      first_name,
      last_name,
      email,
      phone,
      address_line,
      username,
      password
    } = req.body;

    const normalizedLegalId = normalizeSin(legal_id, 'SIN');
    const normalizedIdType = parseEnum(id_type, ['SIN'], 'ID type');
    const normalizedFirstName = normalizeString(first_name, 'First name', 80);
    const normalizedLastName = normalizeString(last_name, 'Last name', 80);
    const normalizedEmail = normalizeEmail(email);
    const normalizedPhone = normalizePhone(phone);
    const normalizedAddress = normalizeString(address_line, 'Address', 255);
    const normalizedUsername = normalizeUsername(username);
    const normalizedPassword = normalizePassword(password);

    await client.query('BEGIN');
    const person = await client.query(
      `INSERT INTO person (legal_id, id_type, first_name, last_name, email, phone, address_line)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING person_id`,
      [
        normalizedLegalId,
        normalizedIdType,
        normalizedFirstName,
        normalizedLastName,
        normalizedEmail,
        normalizedPhone,
        normalizedAddress
      ]
    );
    const customer = await client.query(
      `INSERT INTO customer (person_id, hotel_id, registration_date)
       VALUES ($1, NULL, CURRENT_DATE)
       RETURNING customer_id`,
      [person.rows[0].person_id]
    );
    await client.query(
      `INSERT INTO auth_account (role, username, password_plain, employee_id, customer_id, is_active)
       VALUES ('customer', $1, $2, NULL, $3, TRUE)`,
      [normalizedUsername, normalizedPassword, customer.rows[0].customer_id]
    );

    await client.query('COMMIT');
    return redirectWith(res, '/login/customer', 'Customer account created. You can now sign in with SIN + password.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    const friendly = formatConstraintViolation(err);
    return redirectWith(res, '/signup/customer', friendly || err.message, 'error');
  } finally {
    client.release();
  }
});

app.get('/login/:role', (req, res) => {
  const role = req.params.role === 'manager' ? 'employee' : req.params.role;
  if (!LOGIN_ROLES.includes(role)) {
    return res.status(404).send('Unknown login role');
  }
  if (req.auth.isAuthenticated) {
    const staffLoginAlready = role === 'employee' && ['employee', 'manager'].includes(req.auth.role);
    const sameRoleLogin = req.auth.role === role;
    if (staffLoginAlready || sameRoleLogin) {
      return res.redirect(ROLE_HOME[req.auth.role] || '/');
    }
  }
  return res.render('login-role', {
    title: `${role === 'employee' ? 'Employee / Manager' : ROLE_LABELS[role]} Login`,
    message: buildMessage(req.query),
    role,
    roleLabel: role === 'employee' ? 'Employee / Manager' : ROLE_LABELS[role]
  });
});

app.post('/login/:role', (req, res) => {
  (async () => {
    const role = req.params.role === 'manager' ? 'employee' : req.params.role;
    if (!LOGIN_ROLES.includes(role)) {
      return res.status(404).send('Unknown login role');
    }

    let account = null;
    let password = '';
    if (role === 'customer') {
      const sin = normalizeSin(req.body.sin, 'SIN');
      password = normalizePassword(req.body.password);
      account = await fetchCustomerAccountBySin(sin);
    } else {
      const username = normalizeUsername(req.body.username);
      password = normalizePassword(req.body.password);
      account = role === 'employee'
        ? await fetchStaffAccountByUsername(username)
        : await fetchAccountByRoleAndUsername(role, username);
    }
    if (!account || account.password_plain !== password) {
      return redirectWith(res, `/login/${role}`, 'Invalid username or password.', 'error');
    }

    if (!account.is_active) {
      return redirectWith(res, `/login/${role}`, inactiveMessageForRole(account.role), 'error');
    }

    setAuthCookie(res, account.account_id);
    return redirectWith(
      res,
      ROLE_HOME[account.role] || '/',
      `Logged in as ${ROLE_LABELS[account.role]}.`,
      'success'
    );
  })().catch((err) => {
    const fallbackRole = req.params.role === 'manager' ? 'employee' : req.params.role;
    redirectWith(res, `/login/${fallbackRole}`, err.message, 'error');
  });
});

app.post('/logout', (req, res) => {
  clearAuthCookie(res);
  redirectWith(res, '/login', 'You have been logged out.', 'info');
});

app.get('/', async (req, res) => {
  try {
    const [hotels, rooms] = await Promise.all([
      db.query('SELECT COUNT(*)::int AS count FROM hotel'),
      db.query('SELECT COUNT(*)::int AS count FROM room')
    ]);

    let customerCount = null;
    let employeeCount = null;
    let managerTeam = [];
    let managerHotelName = null;

    if (req.auth.role === 'admin') {
      const [customers, employees] = await Promise.all([
        db.query('SELECT COUNT(*)::int AS count FROM customer'),
        db.query('SELECT COUNT(*)::int AS count FROM employee')
      ]);
      customerCount = customers.rows[0].count;
      employeeCount = employees.rows[0].count;
    }

    if (req.auth.role === 'manager' && req.auth.employeeId) {
      const managerHotel = await db.query(
        `SELECT h.hotel_id, h.hotel_name
         FROM employee e
         JOIN hotel h ON h.hotel_id = e.hotel_id
         WHERE e.employee_id = $1
         LIMIT 1`,
        [req.auth.employeeId]
      );

      if (managerHotel.rowCount > 0) {
        managerHotelName = managerHotel.rows[0].hotel_name;
        const team = await db.query(
          `SELECT e.employee_id, p.first_name, p.last_name, e.role_title
           FROM employee e
           JOIN person p ON p.person_id = e.person_id
           WHERE e.hotel_id = $1
           ORDER BY p.last_name, p.first_name`,
          [managerHotel.rows[0].hotel_id]
        );
        managerTeam = team.rows;
      }
    }

    res.render('index', {
      message: buildMessage(req.query),
      counts: {
        hotels: hotels.rows[0].count,
        rooms: rooms.rows[0].count,
        customers: customerCount,
        employees: employeeCount
      },
      managerTeam,
      managerHotelName
    });
  } catch (err) {
    res.status(500).send(err.message);
  }
});

app.get('/search', async (req, res) => {
  try {
    const easternToday = easternTodayISO();
    const canCreateBooking = ['employee', 'manager', 'admin', 'customer'].includes(req.auth.role);
    const isStaffRole = req.auth.role === 'employee' || req.auth.role === 'manager';
    const staffHotelId = isStaffRole ? await fetchStaffHotelId(req.auth.employeeId, 'Staff') : null;
    const filterData = await Promise.all([
      db.query('SELECT chain_id, chain_name FROM hotel_chain ORDER BY chain_name'),
      db.query('SELECT DISTINCT city FROM hotel ORDER BY city')
    ]);

    const q = req.query;
    const values = [];
    const conditions = [];

    if (q.capacity) {
      const capacity = parseEnum(q.capacity, ['single', 'double', 'suite', 'family'], 'Capacity');
      values.push(capacity);
      conditions.push(`r.capacity = $${values.length}`);
    }
    if (q.city) {
      values.push(normalizeString(q.city, 'City', 100));
      conditions.push(`h.city = $${values.length}`);
    }
    if (q.chain_id) {
      values.push(parsePositiveInt(q.chain_id, 'Hotel chain'));
      conditions.push(`h.chain_id = $${values.length}`);
    }
    if (q.category) {
      const category = parsePositiveInt(q.category, 'Hotel category');
      if (category < 1 || category > 5) throw new Error('Hotel category must be between 1 and 5.');
      values.push(category);
      conditions.push(`h.category = $${values.length}`);
    }
    if (q.total_rooms_min) {
      values.push(parsePositiveInt(q.total_rooms_min, 'Minimum hotel rooms'));
      conditions.push(`h.total_rooms >= $${values.length}`);
    }
    if (q.max_price) {
      values.push(parsePositiveNumber(q.max_price, 'Maximum room price'));
      conditions.push(`r.base_price <= $${values.length}`);
    }
    if (q.current_status) {
      const normalizedStatus = parseEnum(
        q.current_status,
        ['available', 'booked', 'rented', 'maintenance'],
        'Room status'
      );
      values.push(normalizedStatus);
      conditions.push(`r.current_status = $${values.length}`);
    }
    if (isStaffRole) {
      values.push(staffHotelId);
      conditions.push(`h.hotel_id = $${values.length}`);
    }

    const startDate = sanitizeDate(q.start_date);
    const endDate = sanitizeDate(q.end_date);
    if ((startDate && !endDate) || (!startDate && endDate)) {
      throw new Error('Both start date and end date are required for date filtering.');
    }
    if (startDate && endDate) {
      ensureEndDateAfterStartDate(startDate, endDate);
      values.push(startDate, endDate, startDate, endDate);
      const s1 = values.length - 3;
      const e1 = values.length - 2;
      const s2 = values.length - 1;
      const e2 = values.length;

      conditions.push(`NOT EXISTS (
        SELECT 1 FROM booking b
        WHERE b.room_id = r.room_id
          AND b.status IN ('reserved', 'checked_in')
          AND daterange(b.start_date, b.end_date, '[]') && daterange($${s1}, $${e1}, '[]')
      )`);

      conditions.push(`NOT EXISTS (
        SELECT 1 FROM renting rt
        WHERE rt.room_id = r.room_id
          AND rt.status = 'active'
          AND daterange(rt.start_date, rt.end_date, '[]') && daterange($${s2}, $${e2}, '[]')
      )`);
    }

    const rooms = await db.query(
      `SELECT
        r.room_id,
        r.room_number,
        r.capacity,
        r.base_price,
        r.has_sea_view,
        r.has_mountain_view,
        r.is_extendable,
        r.amenities,
        r.current_status,
        h.hotel_id,
        h.hotel_name,
        h.city,
        h.category,
        h.total_rooms,
        hc.chain_name
      FROM room r
      JOIN hotel h ON h.hotel_id = r.hotel_id
      JOIN hotel_chain hc ON hc.chain_id = h.chain_id
      ${conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : ''}
      ORDER BY h.city ASC, h.hotel_name ASC, r.base_price ASC
      LIMIT 300`,
      values
    );

    let unavailableRangesByRoom = {};
    if (rooms.rows.length > 0) {
      const roomIds = rooms.rows.map((row) => row.room_id);
      const unavailableRanges = await db.query(
        `SELECT room_id, start_date, end_date, source_type
         FROM (
           SELECT
             b.room_id,
             b.start_date,
             b.end_date,
             'booking'::text AS source_type
           FROM booking b
           WHERE b.status IN ('reserved', 'checked_in')
             AND b.room_id = ANY($1::int[])
             AND b.end_date >= $2::date
           UNION ALL
           SELECT
             rt.room_id,
             rt.start_date,
             rt.end_date,
             'renting'::text AS source_type
           FROM renting rt
           WHERE rt.status = 'active'
             AND rt.room_id = ANY($1::int[])
             AND rt.end_date >= $2::date
         ) u
         ORDER BY room_id, start_date, end_date`,
        [roomIds, easternToday]
      );

      unavailableRangesByRoom = unavailableRanges.rows.reduce((acc, row) => {
        const key = String(row.room_id);
        if (!acc[key]) {
          acc[key] = [];
        }
        acc[key].push({
          start_date: toIsoDate(row.start_date),
          end_date: toIsoDate(row.end_date),
          source_type: row.source_type
        });
        return acc;
      }, {});
    }

    const customers = req.auth.role === 'customer'
      ? { rows: [] }
      : canCreateBooking
      ? (
          isStaffRole
            ? await db.query(
                `SELECT c.customer_id, p.legal_id
                 FROM customer c
                 JOIN person p ON p.person_id = c.person_id
                 WHERE c.hotel_id = $1 OR c.hotel_id IS NULL
                 ORDER BY c.customer_id
                 LIMIT 200`,
                [staffHotelId]
              )
            : await db.query(
                `SELECT c.customer_id, p.legal_id
                 FROM customer c
                 JOIN person p ON p.person_id = c.person_id
                 ORDER BY c.customer_id
                 LIMIT 200`
              )
        )
      : { rows: [] };

    const renderedFilters = { ...q };

    res.render('search', {
      message: buildMessage(req.query),
      filters: renderedFilters,
      chains: filterData[0].rows,
      cities: filterData[1].rows,
      rooms: rooms.rows,
      customers: customers.rows,
      easternToday,
      canCreateBooking,
      unavailableRangesByRoom
    });
  } catch (err) {
    redirectWith(res, '/search', err.message, 'error');
  }
});

app.post('/bookings', requireRole(['employee', 'manager', 'admin', 'customer']), async (req, res) => {
  const { room_id, customer_sin, employee_id, start_date, end_date } = req.body;
  try {
    const isStaffRole = req.auth.role === 'employee' || req.auth.role === 'manager';
    const staffHotelId = isStaffRole ? await fetchStaffHotelId(req.auth.employeeId, 'Staff') : null;
    const roomId = parsePositiveInt(room_id, 'Room');
    const normalizedCustomerSin = req.auth.role === 'customer' ? null : normalizeSin(customer_sin, 'Customer SIN');
    const effectiveEmployeeId = req.auth.role === 'employee' || req.auth.role === 'manager'
      ? parsePositiveInt(req.auth.employeeId, 'Employee')
      : parseOptionalPositiveInt(employee_id, 'Employee');
    const normalizedStartDate = parseDateInput(start_date, 'Start date');
    const normalizedEndDate = parseDateInput(end_date, 'End date');
    const easternToday = easternTodayISO();
    if (normalizedStartDate < easternToday) {
      throw new Error(`Start date cannot be in the past. Use ${easternToday} (Eastern) or later.`);
    }
    ensureEndDateAfterStartDate(normalizedStartDate, normalizedEndDate);

    const roomCheck = await db.query(
      `SELECT room_id, hotel_id
       FROM room
       WHERE room_id = $1
       LIMIT 1`,
      [roomId]
    );
    if (roomCheck.rowCount === 0) {
      throw new Error('Room not found.');
    }

    const customerCheck = req.auth.role === 'customer'
      ? await db.query(
          `SELECT c.customer_id, c.hotel_id
           FROM customer c
           WHERE c.customer_id = $1
           LIMIT 1`,
          [parsePositiveInt(req.auth.customerId, 'Customer')]
        )
      : await db.query(
          `SELECT c.customer_id, c.hotel_id
           FROM customer c
           JOIN person p ON p.person_id = c.person_id
           WHERE p.legal_id = $1
           LIMIT 1`,
          [normalizedCustomerSin]
        );
    if (customerCheck.rowCount === 0) {
      throw new Error('No customer found with that SIN.');
    }

    if (isStaffRole) {
      if (roomCheck.rows[0].hotel_id !== staffHotelId) {
        throw new Error('You can only book rooms at your assigned hotel.');
      }
      if (customerCheck.rows[0].hotel_id && customerCheck.rows[0].hotel_id !== staffHotelId) {
        throw new Error('You can only book for customers registered at your hotel.');
      }
    }

    const effectiveCustomerId = customerCheck.rows[0].customer_id;
    if (!customerCheck.rows[0].hotel_id) {
      await db.query(
        `UPDATE customer
         SET hotel_id = $1
         WHERE customer_id = $2
           AND hotel_id IS NULL`,
        [roomCheck.rows[0].hotel_id, effectiveCustomerId]
      );
    }

    await db.query(
      `INSERT INTO booking (room_id, customer_id, created_by_employee_id, start_date, end_date, status)
       VALUES ($1, $2, $3, $4, $5, 'reserved')`,
      [roomId, effectiveCustomerId, effectiveEmployeeId, normalizedStartDate, normalizedEndDate]
    );
    redirectWith(res, '/search', 'Booking created successfully.', 'success');
  } catch (err) {
    redirectWith(res, '/search', err.message, 'error');
  }
});

app.get('/customer/bookings', requireRole(['customer']), async (req, res) => {
  try {
    const customerId = parsePositiveInt(req.auth.customerId, 'Customer');
    const [bookings, rentings] = await Promise.all([
      db.query(
        `SELECT
           b.booking_id,
           b.room_id,
           rm.room_number,
           h.hotel_name,
           h.city,
           b.start_date,
           b.end_date,
           b.status,
           b.created_at,
           rt.renting_id AS linked_renting_id,
           rt.status AS linked_renting_status
         FROM booking b
         JOIN room rm ON rm.room_id = b.room_id
         JOIN hotel h ON h.hotel_id = rm.hotel_id
         LEFT JOIN renting rt ON rt.source_booking_id = b.booking_id
         WHERE b.customer_id = $1
         ORDER BY b.created_at DESC, b.booking_id DESC
         LIMIT 300`,
        [customerId]
      ),
      db.query(
        `SELECT
           rt.renting_id,
           rt.source_booking_id,
           rt.room_id,
           rm.room_number,
           h.hotel_name,
           h.city,
           rt.start_date,
           rt.end_date,
           rt.status,
           rt.created_at
         FROM renting rt
         JOIN room rm ON rm.room_id = rt.room_id
         JOIN hotel h ON h.hotel_id = rm.hotel_id
         WHERE rt.customer_id = $1
         ORDER BY rt.created_at DESC, rt.renting_id DESC
         LIMIT 300`,
        [customerId]
      )
    ]);

    res.render('customer-bookings', {
      message: buildMessage(req.query),
      bookings: bookings.rows,
      rentings: rentings.rows
    });
  } catch (err) {
    redirectWith(res, '/', err.message, 'error');
  }
});

app.patch('/customer/bookings/:id/cancel', requireRole(['customer']), async (req, res) => {
  const client = await db.getClient();
  try {
    const bookingId = parsePositiveInt(req.params.id, 'Booking');
    const customerId = parsePositiveInt(req.auth.customerId, 'Customer');
    const easternToday = easternTodayISO();

    await client.query('BEGIN');
    const bookingResult = await client.query(
      `SELECT booking_id, status, end_date
       FROM booking
       WHERE booking_id = $1
         AND customer_id = $2
       FOR UPDATE`,
      [bookingId, customerId]
    );
    if (bookingResult.rowCount === 0) {
      throw new Error('Booking not found for your account.');
    }

    const booking = bookingResult.rows[0];
    if (booking.status !== 'reserved') {
      throw new Error('Only reserved bookings can be cancelled.');
    }
    const bookingEndDate = toIsoDate(booking.end_date);
    if (bookingEndDate < easternToday) {
      throw new Error('This booking has already ended. Ask staff to mark it completed.');
    }

    await client.query(`UPDATE booking SET status = 'cancelled' WHERE booking_id = $1`, [bookingId]);
    await client.query('COMMIT');
    redirectWith(res, '/customer/bookings', 'Booking cancelled and archived.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/customer/bookings', err.message, 'error');
  } finally {
    client.release();
  }
});

app.get('/settings/customer', requireRole(['customer']), async (req, res) => {
  try {
    const details = await db.query(
      `SELECT
         c.customer_id,
         p.first_name,
         p.last_name,
         p.email,
         p.phone,
         p.address_line,
         a.username
       FROM customer c
       JOIN person p ON p.person_id = c.person_id
       JOIN auth_account a ON a.customer_id = c.customer_id
       WHERE c.customer_id = $1
       LIMIT 1`,
      [req.auth.customerId]
    );
    if (details.rowCount === 0) {
      throw new Error('Customer profile not found.');
    }
    const hasOpenStays = await customerHasOpenBookingOrRenting(req.auth.customerId);
    res.render('settings-customer', {
      message: buildMessage(req.query),
      profile: details.rows[0],
      hasOpenStays
    });
  } catch (err) {
    redirectWith(res, '/search', err.message, 'error');
  }
});

app.patch('/settings/customer/profile', requireRole(['customer']), async (req, res) => {
  const client = await db.getClient();
  try {
    const {
      first_name,
      last_name,
      email,
      phone,
      address_line,
      username,
      password
    } = req.body;
    const normalizedFirstName = normalizeString(first_name, 'First name', 80);
    const normalizedLastName = normalizeString(last_name, 'Last name', 80);
    const normalizedEmail = normalizeEmail(email);
    const normalizedPhone = normalizePhone(phone);
    const normalizedAddress = normalizeString(address_line, 'Address', 255);
    const normalizedUsername = normalizeUsername(username);
    const passwordProvided = String(password || '').trim().length > 0;
    const normalizedPassword = passwordProvided ? normalizePassword(password) : null;

    await client.query('BEGIN');
    const customer = await client.query(
      `SELECT c.person_id, a.account_id
       FROM customer c
       JOIN auth_account a ON a.customer_id = c.customer_id
       WHERE c.customer_id = $1 AND a.role = 'customer'
       FOR UPDATE`,
      [req.auth.customerId]
    );
    if (customer.rowCount === 0) {
      throw new Error('Customer profile not found.');
    }

    await client.query(
      `UPDATE person
       SET first_name = $1, last_name = $2, email = $3, phone = $4, address_line = $5
       WHERE person_id = $6`,
      [
        normalizedFirstName,
        normalizedLastName,
        normalizedEmail,
        normalizedPhone,
        normalizedAddress,
        customer.rows[0].person_id
      ]
    );

    if (passwordProvided) {
      await client.query(
        `UPDATE auth_account
         SET username = $1, password_plain = $2
         WHERE account_id = $3`,
        [normalizedUsername, normalizedPassword, customer.rows[0].account_id]
      );
    } else {
      await client.query(
        `UPDATE auth_account
         SET username = $1
         WHERE account_id = $2`,
        [normalizedUsername, customer.rows[0].account_id]
      );
    }

    await client.query('COMMIT');
    redirectWith(res, '/settings/customer', 'Profile updated.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/settings/customer', err.message, 'error');
  } finally {
    client.release();
  }
});

app.patch('/settings/customer/deactivate', requireRole(['customer']), async (req, res) => {
  try {
    const hasOpenStays = await customerHasOpenBookingOrRenting(req.auth.customerId);
    if (hasOpenStays) {
      throw new Error('You cannot disable your account while you have an active renting or reserved booking. Please ask staff for help.');
    }
    await db.query(
      `UPDATE auth_account
       SET is_active = FALSE
       WHERE account_id = $1 AND role = 'customer'`,
      [req.auth.accountId]
    );
    clearAuthCookie(res);
    redirectWith(
      res,
      '/login',
      'Your account has been disabled. Please contact an employee to reactivate it.',
      'info'
    );
  } catch (err) {
    redirectWith(res, '/settings/customer', err.message, 'error');
  }
});

app.delete('/settings/customer/delete', requireRole(['customer']), async (req, res) => {
  const client = await db.getClient();
  try {
    const customerId = parsePositiveInt(req.auth.customerId, 'Customer');
    await client.query('BEGIN');
    const hasOpenStays = await customerHasOpenBookingOrRenting(customerId, client);
    if (hasOpenStays) {
      throw new Error('You cannot delete your account while you have an active renting or reserved booking. Please ask staff for help.');
    }

    const customer = await client.query(
      `SELECT customer_id, person_id
       FROM customer
       WHERE customer_id = $1
       FOR UPDATE`,
      [customerId]
    );
    if (customer.rowCount === 0) {
      throw new Error('Customer account not found.');
    }

    await archiveCustomerHistory(client, customerId);
    await client.query('DELETE FROM customer WHERE customer_id = $1', [customerId]);
    await client.query('DELETE FROM person WHERE person_id = $1', [customer.rows[0].person_id]);
    await client.query('COMMIT');

    clearAuthCookie(res);
    redirectWith(res, '/login', 'Your customer account was deleted.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/settings/customer', err.message, 'error');
  } finally {
    client.release();
  }
});

app.get('/employee', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  try {
    const easternToday = easternTodayISO();
    const isStaffRole = req.auth.role === 'employee' || req.auth.role === 'manager';
    const staffHotelId = isStaffRole ? await fetchStaffHotelId(req.auth.employeeId, 'Staff') : null;

    const [employees, customers, availableRooms, activeBookings, activeRentings, recentPayments] = isStaffRole
      ? await Promise.all([
          db.query(`SELECT e.employee_id, p.first_name, p.last_name, h.hotel_name
                    FROM employee e
                    JOIN person p ON p.person_id = e.person_id
                    JOIN hotel h ON h.hotel_id = e.hotel_id
                    WHERE e.hotel_id = $1
                    ORDER BY e.employee_id`, [staffHotelId]),
          db.query(`SELECT c.customer_id, p.legal_id, p.first_name, p.last_name
                    FROM customer c
                    JOIN person p ON p.person_id = c.person_id
                    WHERE c.hotel_id = $1 OR c.hotel_id IS NULL
                    ORDER BY c.customer_id LIMIT 200`, [staffHotelId]),
          db.query(`SELECT r.room_id, r.room_number, h.hotel_name, h.city
                    FROM room r
                    JOIN hotel h ON h.hotel_id = r.hotel_id
                    WHERE r.current_status = 'available'
                      AND r.hotel_id = $1
                    ORDER BY r.room_id LIMIT 200`, [staffHotelId]),
          db.query(`SELECT
                      b.booking_id,
                      b.room_id,
                      b.customer_id,
                      p.legal_id AS customer_sin,
                      b.start_date,
                      b.end_date,
                      b.status
                    FROM booking b
                    JOIN room rm ON rm.room_id = b.room_id
                    JOIN customer c ON c.customer_id = b.customer_id
                    JOIN person p ON p.person_id = c.person_id
                    WHERE b.status IN ('reserved', 'checked_in')
                      AND rm.hotel_id = $2
                    ORDER BY
                      (b.end_date < $1) DESC,
                      b.start_date ASC,
                      b.booking_id DESC
                    LIMIT 200`, [easternToday, staffHotelId]),
          db.query(`SELECT
                      rt.renting_id,
                      rt.room_id,
                      rt.customer_id,
                      p.legal_id AS customer_sin,
                      rt.employee_id,
                      rt.start_date,
                      rt.end_date,
                      rt.status
                    FROM renting rt
                    JOIN room rm ON rm.room_id = rt.room_id
                    JOIN customer c ON c.customer_id = rt.customer_id
                    JOIN person p ON p.person_id = c.person_id
                    WHERE rm.hotel_id = $1
                      AND rt.status = 'active'
                    ORDER BY rt.renting_id DESC LIMIT 200`, [staffHotelId]),
          db.query(`SELECT
                      pay.payment_id,
                      pay.renting_id,
                      pay.employee_id,
                      pay.amount,
                      pay.method,
                      pay.paid_at,
                      rt.room_id,
                      p.legal_id AS customer_sin
                    FROM payment pay
                    JOIN renting rt ON rt.renting_id = pay.renting_id
                    JOIN room rm ON rm.room_id = rt.room_id
                    JOIN customer c ON c.customer_id = rt.customer_id
                    JOIN person p ON p.person_id = c.person_id
                    WHERE rm.hotel_id = $1
                    ORDER BY pay.payment_id DESC LIMIT 200`, [staffHotelId])
        ])
      : await Promise.all([
          db.query(`SELECT e.employee_id, p.first_name, p.last_name, h.hotel_name
                    FROM employee e
                    JOIN person p ON p.person_id = e.person_id
                    JOIN hotel h ON h.hotel_id = e.hotel_id
                    ORDER BY e.employee_id`),
          db.query(`SELECT c.customer_id, p.legal_id, p.first_name, p.last_name
                    FROM customer c
                    JOIN person p ON p.person_id = c.person_id
                    ORDER BY c.customer_id LIMIT 200`),
          db.query(`SELECT r.room_id, r.room_number, h.hotel_name, h.city
                    FROM room r
                    JOIN hotel h ON h.hotel_id = r.hotel_id
                    WHERE r.current_status = 'available'
                    ORDER BY r.room_id LIMIT 200`),
          db.query(`SELECT
                      b.booking_id,
                      b.room_id,
                      b.customer_id,
                      p.legal_id AS customer_sin,
                      b.start_date,
                      b.end_date,
                      b.status
                    FROM booking b
                    JOIN customer c ON c.customer_id = b.customer_id
                    JOIN person p ON p.person_id = c.person_id
                    WHERE b.status IN ('reserved', 'checked_in')
                    ORDER BY
                      (b.end_date < $1) DESC,
                      b.start_date ASC,
                      b.booking_id DESC
                    LIMIT 200`, [easternToday]),
          db.query(`SELECT
                      rt.renting_id,
                      rt.room_id,
                      rt.customer_id,
                      p.legal_id AS customer_sin,
                      rt.employee_id,
                      rt.start_date,
                      rt.end_date,
                      rt.status
                    FROM renting rt
                    JOIN customer c ON c.customer_id = rt.customer_id
                    JOIN person p ON p.person_id = c.person_id
                    WHERE rt.status = 'active'
                    ORDER BY rt.renting_id DESC LIMIT 200`),
          db.query(`SELECT
                      pay.payment_id,
                      pay.renting_id,
                      pay.employee_id,
                      pay.amount,
                      pay.method,
                      pay.paid_at,
                      rt.room_id,
                      p.legal_id AS customer_sin
                    FROM payment pay
                    JOIN renting rt ON rt.renting_id = pay.renting_id
                    JOIN customer c ON c.customer_id = rt.customer_id
                    JOIN person p ON p.person_id = c.person_id
                    ORDER BY pay.payment_id DESC LIMIT 200`)
        ]);

    res.render('employee', {
      message: buildMessage(req.query),
      employees: employees.rows,
      customers: customers.rows,
      availableRooms: availableRooms.rows,
      activeBookings: activeBookings.rows,
      activeRentings: activeRentings.rows,
      recentPayments: recentPayments.rows,
      easternToday
    });
  } catch (err) {
    redirectWith(res, '/', err.message, 'error');
  }
});

app.get('/archives', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  try {
    const isStaffRole = req.auth.role === 'employee' || req.auth.role === 'manager';
    let archiveRows = null;

    if (isStaffRole) {
      const staffHotel = await db.query(
        `SELECT h.hotel_name, hc.chain_name
         FROM employee e
         JOIN hotel h ON h.hotel_id = e.hotel_id
         JOIN hotel_chain hc ON hc.chain_id = h.chain_id
         WHERE e.employee_id = $1
         LIMIT 1`,
        [req.auth.employeeId]
      );
      if (staffHotel.rowCount === 0) {
        throw new Error('Staff profile is not linked to a hotel.');
      }
      archiveRows = await db.query(
        `SELECT
           archive_id,
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
           final_status,
           archived_at
         FROM archive
         WHERE hotel_name = $1
           AND chain_name = $2
         ORDER BY archived_at DESC, archive_id DESC
         LIMIT 400`,
        [staffHotel.rows[0].hotel_name, staffHotel.rows[0].chain_name]
      );
    } else {
      archiveRows = await db.query(
        `SELECT
           archive_id,
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
           final_status,
           archived_at
         FROM archive
         ORDER BY archived_at DESC, archive_id DESC
         LIMIT 700`
      );
    }

    res.render('archives', {
      message: buildMessage(req.query),
      archives: archiveRows.rows
    });
  } catch (err) {
    redirectWith(res, '/', err.message, 'error');
  }
});

app.patch('/employee/bookings/:id/cancel', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  const client = await db.getClient();
  try {
    const bookingId = parsePositiveInt(req.params.id, 'Booking');
    const isStaffRole = req.auth.role === 'employee' || req.auth.role === 'manager';
    const staffHotelId = isStaffRole ? await fetchStaffHotelId(req.auth.employeeId, 'Staff') : null;
    const easternToday = easternTodayISO();

    await client.query('BEGIN');
    const bookingResult = await client.query(
      `SELECT b.booking_id, b.status, b.end_date, rm.hotel_id
       FROM booking b
       JOIN room rm ON rm.room_id = b.room_id
       WHERE b.booking_id = $1
       FOR UPDATE`,
      [bookingId]
    );
    if (bookingResult.rowCount === 0) {
      throw new Error('Booking not found.');
    }

    const booking = bookingResult.rows[0];
    if (isStaffRole && booking.hotel_id !== staffHotelId) {
      throw new Error('You can only cancel bookings from your assigned hotel.');
    }
    if (!['reserved', 'checked_in'].includes(booking.status)) {
      throw new Error('Only reserved/checked-in bookings can be cancelled.');
    }
    const bookingEndDate = toIsoDate(booking.end_date);
    if (bookingEndDate < easternToday) {
      throw new Error('This booking has already ended. Mark it completed instead.');
    }

    await client.query(`UPDATE booking SET status = 'cancelled' WHERE booking_id = $1`, [bookingId]);
    await client.query('COMMIT');
    redirectWith(res, '/employee', 'Booking cancelled and archived.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/employee', err.message, 'error');
  } finally {
    client.release();
  }
});

app.patch('/employee/bookings/:id/dates', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  const client = await db.getClient();
  try {
    const bookingId = parsePositiveInt(req.params.id, 'Booking');
    const { start_date, end_date } = req.body;
    const normalizedStartDate = parseDateInput(start_date, 'Start date');
    const normalizedEndDate = parseDateInput(end_date, 'End date');
    const easternToday = easternTodayISO();
    if (normalizedStartDate < easternToday) {
      throw new Error(`Start date cannot be in the past. Use ${easternToday} (Eastern) or later.`);
    }
    ensureEndDateAfterStartDate(normalizedStartDate, normalizedEndDate);

    const isStaffRole = req.auth.role === 'employee' || req.auth.role === 'manager';
    const staffHotelId = isStaffRole ? await fetchStaffHotelId(req.auth.employeeId, 'Staff') : null;

    await client.query('BEGIN');
    const bookingResult = await client.query(
      `SELECT b.booking_id, b.status, rm.hotel_id
       FROM booking b
       JOIN room rm ON rm.room_id = b.room_id
       WHERE b.booking_id = $1
       FOR UPDATE`,
      [bookingId]
    );
    if (bookingResult.rowCount === 0) {
      throw new Error('Booking not found.');
    }
    const booking = bookingResult.rows[0];
    if (isStaffRole && booking.hotel_id !== staffHotelId) {
      throw new Error('You can only update bookings from your assigned hotel.');
    }
    if (booking.status !== 'reserved') {
      throw new Error('Only reserved bookings can be updated.');
    }

    await client.query(
      `UPDATE booking
       SET start_date = $1,
           end_date = $2
       WHERE booking_id = $3`,
      [normalizedStartDate, normalizedEndDate, bookingId]
    );
    await client.query('COMMIT');
    redirectWith(res, '/employee', 'Booking dates updated.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/employee', err.message, 'error');
  } finally {
    client.release();
  }
});

app.patch('/employee/bookings/:id/complete', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  const client = await db.getClient();
  try {
    const bookingId = parsePositiveInt(req.params.id, 'Booking');
    const isStaffRole = req.auth.role === 'employee' || req.auth.role === 'manager';
    const staffHotelId = isStaffRole ? await fetchStaffHotelId(req.auth.employeeId, 'Staff') : null;
    const easternToday = easternTodayISO();

    await client.query('BEGIN');
    const bookingResult = await client.query(
      `SELECT b.booking_id, b.status, b.end_date, rm.hotel_id
       FROM booking b
       JOIN room rm ON rm.room_id = b.room_id
       WHERE b.booking_id = $1
       FOR UPDATE`,
      [bookingId]
    );
    if (bookingResult.rowCount === 0) {
      throw new Error('Booking not found.');
    }

    const booking = bookingResult.rows[0];
    if (isStaffRole && booking.hotel_id !== staffHotelId) {
      throw new Error('You can only complete bookings from your assigned hotel.');
    }
    if (!['reserved', 'checked_in'].includes(booking.status)) {
      throw new Error('Only reserved/checked-in bookings can be completed.');
    }
    const bookingEndDate = toIsoDate(booking.end_date);
    if (bookingEndDate >= easternToday) {
      throw new Error(`Booking can be completed only after its end date (${bookingEndDate}).`);
    }

    await client.query(`UPDATE booking SET status = 'completed' WHERE booking_id = $1`, [bookingId]);
    await client.query('COMMIT');
    redirectWith(res, '/employee', 'Booking marked completed and archived.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/employee', err.message, 'error');
  } finally {
    client.release();
  }
});

app.post('/employee/rentings/from-booking', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  const client = await db.getClient();
  try {
    const easternToday = easternTodayISO();
    const isStaffRole = req.auth.role === 'employee' || req.auth.role === 'manager';
    const staffHotelId = isStaffRole ? await fetchStaffHotelId(req.auth.employeeId, 'Staff') : null;
    const bookingId = parsePositiveInt(req.body.booking_id, 'Booking');
    const employeeId = req.auth.role === 'employee' || req.auth.role === 'manager'
      ? parsePositiveInt(req.auth.employeeId, 'Employee')
      : parsePositiveInt(req.body.employee_id, 'Employee');

    await client.query('BEGIN');
    const bookingResult = await client.query(
      `SELECT b.booking_id, b.room_id, b.customer_id, b.start_date, b.end_date, b.status, rm.hotel_id
       FROM booking b
       JOIN room rm ON rm.room_id = b.room_id
       WHERE b.booking_id = $1
       FOR UPDATE`,
      [bookingId]
    );

    if (bookingResult.rowCount === 0) {
      throw new Error('Booking not found.');
    }

    const b = bookingResult.rows[0];
    if (!['reserved', 'checked_in'].includes(b.status)) {
      throw new Error('Booking cannot be transformed from current status.');
    }
    if (isStaffRole && b.hotel_id !== staffHotelId) {
      throw new Error('You can only check in bookings from your assigned hotel.');
    }
    const bookingStartDate = typeof b.start_date === 'string'
      ? b.start_date.slice(0, 10)
      : new Date(b.start_date).toISOString().slice(0, 10);
    if (bookingStartDate !== easternToday) {
      throw new Error(`Only bookings that start today (${easternToday}, Eastern Time) can be checked in.`);
    }

    await client.query(
      `INSERT INTO renting (room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'active')`,
      [b.room_id, b.customer_id, employeeId, b.booking_id, b.start_date, b.end_date]
    );

    await client.query(`UPDATE booking SET status = 'completed' WHERE booking_id = $1`, [bookingId]);
    await client.query('COMMIT');

    redirectWith(res, '/employee', 'Booking transformed to renting.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/employee', err.message, 'error');
  } finally {
    client.release();
  }
});

app.post('/employee/rentings/direct', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  const { room_id, customer_sin, employee_id, start_date, end_date } = req.body;
  try {
    const isStaffRole = req.auth.role === 'employee' || req.auth.role === 'manager';
    const staffHotelId = isStaffRole ? await fetchStaffHotelId(req.auth.employeeId, 'Staff') : null;
    const roomId = parsePositiveInt(room_id, 'Room');
    const normalizedCustomerSin = normalizeSin(customer_sin, 'Customer SIN');
    const effectiveEmployeeId = req.auth.role === 'employee' || req.auth.role === 'manager'
      ? parsePositiveInt(req.auth.employeeId, 'Employee')
      : parsePositiveInt(employee_id, 'Employee');
    const normalizedStartDate = parseDateInput(start_date, 'Start date');
    const normalizedEndDate = parseDateInput(end_date, 'End date');
    ensureEndDateAfterStartDate(normalizedStartDate, normalizedEndDate);

    const roomCheck = await db.query(
      `SELECT room_id, hotel_id
       FROM room
       WHERE room_id = $1
       LIMIT 1`,
      [roomId]
    );
    if (roomCheck.rowCount === 0) {
      throw new Error('Room not found.');
    }

    const customerCheck = await db.query(
      `SELECT c.customer_id, c.hotel_id
       FROM customer c
       JOIN person p ON p.person_id = c.person_id
       WHERE p.legal_id = $1
       LIMIT 1`,
      [normalizedCustomerSin]
    );
    if (customerCheck.rowCount === 0) {
      throw new Error('No customer found with that SIN.');
    }
    if (isStaffRole) {
      if (roomCheck.rows[0].hotel_id !== staffHotelId) {
        throw new Error('You can only create rentings for rooms at your assigned hotel.');
      }
      if (customerCheck.rows[0].hotel_id && customerCheck.rows[0].hotel_id !== staffHotelId) {
        throw new Error('You can only create rentings for customers registered at your hotel.');
      }
    }
    const customerId = customerCheck.rows[0].customer_id;
    if (!customerCheck.rows[0].hotel_id) {
      await db.query(
        `UPDATE customer
         SET hotel_id = $1
         WHERE customer_id = $2
           AND hotel_id IS NULL`,
        [roomCheck.rows[0].hotel_id, customerId]
      );
    }

    await db.query(
      `INSERT INTO renting (room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status)
       VALUES ($1, $2, $3, NULL, $4, $5, 'active')`,
      [roomId, customerId, effectiveEmployeeId, normalizedStartDate, normalizedEndDate]
    );
    redirectWith(res, '/employee', 'Direct renting created.', 'success');
  } catch (err) {
    redirectWith(res, '/employee', err.message, 'error');
  }
});

app.post('/employee/payments', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  const { renting_id, employee_id, amount, method } = req.body;
  try {
    const isStaffRole = req.auth.role === 'employee' || req.auth.role === 'manager';
    const staffHotelId = isStaffRole ? await fetchStaffHotelId(req.auth.employeeId, 'Staff') : null;
    const rentingId = parsePositiveInt(renting_id, 'Renting');
    const effectiveEmployeeId = isStaffRole
      ? parsePositiveInt(req.auth.employeeId, 'Employee')
      : parsePositiveInt(employee_id, 'Employee');
    const normalizedAmount = parsePositiveNumber(amount, 'Payment amount');
    const normalizedMethod = parseEnum(method, ['cash', 'card'], 'Payment method');
    const dbMethod = normalizedMethod === 'card' ? 'credit' : 'cash';

    const rentingCheck = await db.query(
      `SELECT rt.renting_id, rt.status, rm.hotel_id
       FROM renting rt
       JOIN room rm ON rm.room_id = rt.room_id
       WHERE rt.renting_id = $1
       LIMIT 1`,
      [rentingId]
    );
    if (rentingCheck.rowCount === 0) {
      throw new Error('Renting not found.');
    }
    if (rentingCheck.rows[0].status !== 'active') {
      throw new Error('Payment can only be inserted for an active renting.');
    }
    if (isStaffRole && rentingCheck.rows[0].hotel_id !== staffHotelId) {
      throw new Error('You can only insert payments for rentings at your assigned hotel.');
    }

    await db.query(
      `INSERT INTO payment (renting_id, employee_id, amount, method)
       VALUES ($1, $2, $3, $4)`,
      [rentingId, effectiveEmployeeId, normalizedAmount, dbMethod]
    );
    redirectWith(res, '/employee', 'Payment inserted successfully.', 'success');
  } catch (err) {
    redirectWith(res, '/employee', err.message, 'error');
  }
});

app.patch('/employee/rentings/:id/complete', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  try {
    const rentingId = parsePositiveInt(req.params.id, 'Renting');
    await db.query(`UPDATE renting SET status = 'completed' WHERE renting_id = $1`, [rentingId]);
    redirectWith(res, '/employee', 'Renting completed and archived.', 'success');
  } catch (err) {
    redirectWith(res, '/employee', err.message, 'error');
  }
});

app.get('/views', requireRole(['admin']), async (req, res) => {
  try {
    const [byArea, byHotel] = await Promise.all([
      db.query('SELECT * FROM v_available_rooms_per_area ORDER BY area'),
      db.query('SELECT * FROM v_hotel_capacity_aggregate ORDER BY aggregated_capacity DESC, hotel_id LIMIT 200')
    ]);

    res.render('views-page', {
      message: buildMessage(req.query),
      byArea: byArea.rows,
      byHotel: byHotel.rows
    });
  } catch (err) {
    redirectWith(res, '/', err.message, 'error');
  }
});

app.get('/manage/customers', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  try {
    const isStaffRole = req.auth.role === 'employee' || req.auth.role === 'manager';
    const staffHotelId = isStaffRole ? await fetchStaffHotelId(req.auth.employeeId, 'Staff') : null;

    const customers = isStaffRole
      ? await db.query(
          `SELECT
             c.customer_id,
             c.hotel_id,
             COALESCE(h.hotel_name, 'Unassigned') AS hotel_name,
             c.registration_date,
             p.person_id,
             p.legal_id,
             p.id_type,
             p.first_name,
             p.last_name,
             p.email,
             p.phone,
             p.address_line,
             a.account_id,
             a.username,
             a.is_active
           FROM customer c
           JOIN person p ON p.person_id = c.person_id
           LEFT JOIN hotel h ON h.hotel_id = c.hotel_id
           LEFT JOIN auth_account a
             ON a.customer_id = c.customer_id
            AND a.role = 'customer'
           WHERE c.hotel_id = $1 OR c.hotel_id IS NULL
           ORDER BY c.customer_id
           LIMIT 300`,
          [staffHotelId]
        )
      : await db.query(
          `SELECT
             c.customer_id,
             c.hotel_id,
             COALESCE(h.hotel_name, 'Unassigned') AS hotel_name,
             c.registration_date,
             p.person_id,
             p.legal_id,
             p.id_type,
             p.first_name,
             p.last_name,
             p.email,
             p.phone,
             p.address_line,
             a.account_id,
             a.username,
             a.is_active
           FROM customer c
           JOIN person p ON p.person_id = c.person_id
           LEFT JOIN hotel h ON h.hotel_id = c.hotel_id
           LEFT JOIN auth_account a
             ON a.customer_id = c.customer_id
            AND a.role = 'customer'
           ORDER BY c.customer_id
           LIMIT 300`
        );

    res.render('manage/customers', {
      message: buildMessage(req.query),
      customers: customers.rows
    });
  } catch (err) {
    redirectWith(res, '/', err.message, 'error');
  }
});

app.post('/manage/customers', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  const client = await db.getClient();
  try {
    const {
      legal_id,
      id_type,
      first_name,
      last_name,
      email,
      phone,
      address_line,
      registration_date
    } = req.body;
    const normalizedLegalId = normalizeSin(legal_id, 'SIN');
    const normalizedIdType = parseEnum(id_type, ['SIN'], 'ID type');
    const normalizedFirstName = normalizeString(first_name, 'First name', 80);
    const normalizedLastName = normalizeString(last_name, 'Last name', 80);
    const normalizedEmail = normalizeEmail(email);
    const normalizedPhone = normalizePhone(phone);
    const normalizedAddress = normalizeString(address_line, 'Address', 255);
    const normalizedRegistrationDate = parseDateInput(registration_date, 'Registration date');

    await client.query('BEGIN');
    const person = await client.query(
      `INSERT INTO person (legal_id, id_type, first_name, last_name, email, phone, address_line)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING person_id`,
      [
        normalizedLegalId,
        normalizedIdType,
        normalizedFirstName,
        normalizedLastName,
        normalizedEmail,
        normalizedPhone,
        normalizedAddress
      ]
    );
    const customer = await client.query(
      `INSERT INTO customer (person_id, hotel_id, registration_date)
       VALUES ($1, $2, $3)
       RETURNING customer_id`,
      [person.rows[0].person_id, null, normalizedRegistrationDate]
    );
    const customerId = customer.rows[0].customer_id;
    await client.query(
      `INSERT INTO auth_account (role, username, password_plain, employee_id, customer_id, is_active)
       VALUES ('customer', $1, $2, NULL, $3, TRUE)`,
      [`customer${customerId}`, `customer${customerId}123`, customerId]
    );
    await client.query('COMMIT');
    redirectWith(res, '/manage/customers', 'Customer created with linked account.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/manage/customers', err.message, 'error');
  } finally {
    client.release();
  }
});

app.patch('/manage/customers/:id', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  const client = await db.getClient();
  try {
    const customerId = parsePositiveInt(req.params.id, 'Customer');
    const { first_name, last_name, email, phone, address_line, registration_date } = req.body;
    const isStaffRole = req.auth.role === 'employee' || req.auth.role === 'manager';
    const staffHotelId = isStaffRole ? await fetchStaffHotelId(req.auth.employeeId, 'Staff') : null;
    const normalizedFirstName = normalizeString(first_name, 'First name', 80);
    const normalizedLastName = normalizeString(last_name, 'Last name', 80);
    const normalizedEmail = normalizeEmail(email);
    const normalizedPhone = normalizePhone(phone);
    const normalizedAddress = normalizeString(address_line, 'Address', 255);
    const normalizedRegistrationDate = parseDateInput(registration_date, 'Registration date');

    await client.query('BEGIN');
    const customer = await client.query(
      `SELECT person_id, hotel_id
       FROM customer
       WHERE customer_id = $1
       FOR UPDATE`,
      [customerId]
    );
    if (customer.rowCount === 0) throw new Error('Customer not found.');
    if (isStaffRole && customer.rows[0].hotel_id && customer.rows[0].hotel_id !== staffHotelId) {
      throw new Error('You can only update customers registered at your hotel.');
    }
    const personId = customer.rows[0].person_id;

    await client.query(
      `UPDATE person SET first_name=$1, last_name=$2, email=$3, phone=$4, address_line=$5 WHERE person_id=$6`,
      [normalizedFirstName, normalizedLastName, normalizedEmail, normalizedPhone, normalizedAddress, personId]
    );
    await client.query(
      `UPDATE customer
       SET registration_date = $1
       WHERE customer_id = $2`,
      [normalizedRegistrationDate, customerId]
    );
    await client.query('COMMIT');
    redirectWith(res, '/manage/customers', 'Customer updated.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/manage/customers', err.message, 'error');
  } finally {
    client.release();
  }
});

app.patch('/manage/customers/:id/account-status', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  const client = await db.getClient();
  try {
    const customerId = parsePositiveInt(req.params.id, 'Customer');
    const isActive = parseBooleanInput(req.body.is_active, 'Account status');
    const isStaffRole = req.auth.role === 'employee' || req.auth.role === 'manager';
    const staffHotelId = isStaffRole ? await fetchStaffHotelId(req.auth.employeeId, 'Staff') : null;

    await client.query('BEGIN');

    const customerAccount = await client.query(
      `SELECT c.customer_id, c.hotel_id, a.account_id
       FROM customer c
       LEFT JOIN auth_account a
         ON a.customer_id = c.customer_id
        AND a.role = 'customer'
       WHERE c.customer_id = $1
       FOR UPDATE`,
      [customerId]
    );
    if (customerAccount.rowCount === 0) {
      throw new Error('Customer not found.');
    }
    if (isStaffRole && customerAccount.rows[0].hotel_id && customerAccount.rows[0].hotel_id !== staffHotelId) {
      throw new Error('You can only manage customer accounts registered at your hotel.');
    }

    if (customerAccount.rows[0].account_id) {
      await client.query(
        `UPDATE auth_account
         SET is_active = $1
         WHERE account_id = $2`,
        [isActive, customerAccount.rows[0].account_id]
      );
    } else {
      await client.query(
        `INSERT INTO auth_account (role, username, password_plain, employee_id, customer_id, is_active)
         VALUES ('customer', $1, $2, NULL, $3, $4)`,
        [`customer${customerId}`, `customer${customerId}123`, customerId, isActive]
      );
    }

    await client.query('COMMIT');
    redirectWith(res, '/manage/customers', `Customer account ${isActive ? 'enabled' : 'disabled'}.`, 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/manage/customers', err.message, 'error');
  } finally {
    client.release();
  }
});

app.delete('/manage/customers/:id', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  const client = await db.getClient();
  try {
    const customerId = parsePositiveInt(req.params.id, 'Customer');
    const isStaffRole = req.auth.role === 'employee' || req.auth.role === 'manager';
    const staffHotelId = isStaffRole ? await fetchStaffHotelId(req.auth.employeeId, 'Staff') : null;
    await client.query('BEGIN');
    const c = await client.query(
      `SELECT person_id, hotel_id
       FROM customer
       WHERE customer_id = $1
       FOR UPDATE`,
      [customerId]
    );
    if (c.rowCount === 0) throw new Error('Customer not found.');
    if (isStaffRole && c.rows[0].hotel_id && c.rows[0].hotel_id !== staffHotelId) {
      throw new Error('You can only delete customers assigned to your hotel.');
    }
    await archiveCustomerHistory(client, customerId);
    await client.query('DELETE FROM customer WHERE customer_id = $1', [customerId]);
    await client.query('DELETE FROM person WHERE person_id = $1', [c.rows[0].person_id]);
    await client.query('COMMIT');
    redirectWith(res, '/manage/customers', 'Customer deleted.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/manage/customers', err.message, 'error');
  } finally {
    client.release();
  }
});

app.get('/manage/employees', requireRole(['manager', 'admin']), async (req, res) => {
  try {
    const isManager = req.auth.role === 'manager';
    const managerHotelId = isManager ? await fetchManagerHotelId(req.auth.employeeId) : null;
    const visibleRoles = isManager ? ['employee'] : ['employee', 'manager'];

    const employeeQuery = isManager
      ? db.query(
          `SELECT
             e.employee_id,
             e.hotel_id,
             h.hotel_name,
             e.role_title,
             e.hired_on,
             p.person_id,
             p.legal_id,
             p.first_name,
             p.last_name,
             p.email,
             p.phone,
             p.address_line,
             a.account_id,
             a.role AS account_role,
             a.username,
             a.is_active
           FROM employee e
           JOIN person p ON p.person_id = e.person_id
           JOIN hotel h ON h.hotel_id = e.hotel_id
           JOIN auth_account a ON a.employee_id = e.employee_id
           WHERE a.role = ANY($1::text[])
             AND e.hotel_id = $2
           ORDER BY e.employee_id
           LIMIT 300`,
          [visibleRoles, managerHotelId]
        )
      : db.query(
          `SELECT
             e.employee_id,
             e.hotel_id,
             h.hotel_name,
             e.role_title,
             e.hired_on,
             p.person_id,
             p.legal_id,
             p.first_name,
             p.last_name,
             p.email,
             p.phone,
             p.address_line,
             a.account_id,
             a.role AS account_role,
             a.username,
             a.is_active
           FROM employee e
           JOIN person p ON p.person_id = e.person_id
           JOIN hotel h ON h.hotel_id = e.hotel_id
           JOIN auth_account a ON a.employee_id = e.employee_id
           WHERE a.role = ANY($1::text[])
           ORDER BY e.employee_id
           LIMIT 300`,
          [visibleRoles]
        );

    const hotelsQuery = isManager
      ? db.query('SELECT hotel_id, hotel_name FROM hotel WHERE hotel_id = $1 ORDER BY hotel_id', [managerHotelId])
      : db.query('SELECT hotel_id, hotel_name FROM hotel ORDER BY hotel_id');

    const [employees, hotels] = await Promise.all([
      employeeQuery,
      hotelsQuery
    ]);
    res.render('manage/employees', {
      message: buildMessage(req.query),
      employees: employees.rows,
      hotels: hotels.rows,
      canManageManagers: req.auth.role === 'admin'
    });
  } catch (err) {
    redirectWith(res, '/', err.message, 'error');
  }
});

app.post('/manage/employees', requireRole(['manager', 'admin']), async (req, res) => {
  const client = await db.getClient();
  try {
    const {
      legal_id,
      id_type,
      first_name,
      last_name,
      email,
      phone,
      address_line,
      hotel_id,
      role_title,
      hired_on,
      account_role,
      username,
      password
    } = req.body;
    const isManager = req.auth.role === 'manager';
    const managerHotelId = isManager ? await fetchManagerHotelId(req.auth.employeeId) : null;
    const normalizedLegalId = normalizeSin(legal_id, 'SIN');
    const normalizedIdType = parseEnum(id_type, ['SIN'], 'ID type');
    const normalizedFirstName = normalizeString(first_name, 'First name', 80);
    const normalizedLastName = normalizeString(last_name, 'Last name', 80);
    const normalizedEmail = normalizeEmail(email);
    const normalizedPhone = normalizePhone(phone);
    const normalizedAddress = normalizeString(address_line, 'Address', 255);
    const normalizedHotelId = isManager ? managerHotelId : parsePositiveInt(hotel_id, 'Hotel');
    const normalizedRoleTitle = normalizeString(role_title, 'Role title', 80);
    const normalizedHiredOn = parseDateInput(hired_on, 'Hire date');
    const normalizedAccountRole = isManager ? 'employee' : parseStaffAccountRole(account_role);
    const normalizedUsername = normalizeUsername(username);
    const normalizedPassword = normalizePassword(password);

    await client.query('BEGIN');
    const hotelStaffCounts = await client.query(
      `SELECT
         SUM(CASE WHEN is_manager THEN 1 ELSE 0 END)::INT AS manager_count,
         SUM(CASE WHEN NOT is_manager THEN 1 ELSE 0 END)::INT AS employee_count
       FROM employee
       WHERE hotel_id = $1`,
      [normalizedHotelId]
    );
    const managerCount = hotelStaffCounts.rows[0].manager_count || 0;
    const employeeCount = hotelStaffCounts.rows[0].employee_count || 0;
    if (normalizedAccountRole === 'manager' && managerCount >= 1) {
      throw new Error('Each hotel can have only one manager account.');
    }
    if (normalizedAccountRole === 'employee' && employeeCount >= 3) {
      throw new Error('Each hotel can have at most 3 employee accounts.');
    }

    const person = await client.query(
      `INSERT INTO person (legal_id, id_type, first_name, last_name, email, phone, address_line)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING person_id`,
      [
        normalizedLegalId,
        normalizedIdType,
        normalizedFirstName,
        normalizedLastName,
        normalizedEmail,
        normalizedPhone,
        normalizedAddress
      ]
    );
    const employee = await client.query(
      `INSERT INTO employee (person_id, hotel_id, role_title, hired_on, is_manager)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING employee_id`,
      [
        person.rows[0].person_id,
        normalizedHotelId,
        normalizedRoleTitle,
        normalizedHiredOn,
        normalizedAccountRole === 'manager'
      ]
    );
    await client.query(
      `INSERT INTO auth_account (role, username, password_plain, employee_id, customer_id, is_active)
       VALUES ($1, $2, $3, $4, NULL, TRUE)`,
      [normalizedAccountRole, normalizedUsername, normalizedPassword, employee.rows[0].employee_id]
    );
    await client.query('COMMIT');
    redirectWith(res, '/manage/employees', 'Employee created.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/manage/employees', err.message, 'error');
  } finally {
    client.release();
  }
});

app.patch('/manage/employees/:id', requireRole(['manager', 'admin']), async (req, res) => {
  const client = await db.getClient();
  try {
    const employeeId = parsePositiveInt(req.params.id, 'Employee');
    const {
      first_name,
      last_name,
      email,
      phone,
      address_line,
      hotel_id,
      role_title,
      hired_on,
      username,
      password,
      account_role
    } = req.body;
    const isManager = req.auth.role === 'manager';
    const managerHotelId = isManager ? await fetchManagerHotelId(req.auth.employeeId) : null;
    const normalizedFirstName = normalizeString(first_name, 'First name', 80);
    const normalizedLastName = normalizeString(last_name, 'Last name', 80);
    const normalizedEmail = normalizeEmail(email);
    const normalizedPhone = normalizePhone(phone);
    const normalizedAddress = normalizeString(address_line, 'Address', 255);
    const normalizedHotelId = isManager ? managerHotelId : parsePositiveInt(hotel_id, 'Hotel');
    const normalizedRoleTitle = normalizeString(role_title, 'Role title', 80);
    const normalizedHiredOn = parseDateInput(hired_on, 'Hire date');
    const normalizedUsername = normalizeUsername(username);
    const normalizedAccountRole = isManager ? 'employee' : parseStaffAccountRole(account_role);
    const passwordProvided = String(password || '').trim().length > 0;
    const normalizedPassword = passwordProvided ? normalizePassword(password) : null;

    await client.query('BEGIN');
    const employee = await client.query(
      `SELECT e.person_id, e.hotel_id, a.account_id, a.role AS account_role
       FROM employee e
       LEFT JOIN auth_account a ON a.employee_id = e.employee_id
       WHERE e.employee_id = $1
       FOR UPDATE`,
      [employeeId]
    );
    if (employee.rowCount === 0) throw new Error('Employee not found.');
    const currentAccount = employee.rows[0];
    if (isManager) {
      if (currentAccount.account_role !== 'employee') {
        throw new Error('Managers can only manage employee accounts.');
      }
      if (currentAccount.hotel_id !== managerHotelId) {
        throw new Error('You can only manage employees assigned to your hotel.');
      }
    }
    if (currentAccount.account_role) {
      assertCanManageStaffAccount(req.auth.role, currentAccount.account_role);
    }

    const destinationStaffCounts = await client.query(
      `SELECT
         SUM(CASE WHEN is_manager THEN 1 ELSE 0 END)::INT AS manager_count,
         SUM(CASE WHEN NOT is_manager THEN 1 ELSE 0 END)::INT AS employee_count
       FROM employee
       WHERE hotel_id = $1
         AND employee_id <> $2`,
      [normalizedHotelId, employeeId]
    );
    const managerCount = destinationStaffCounts.rows[0].manager_count || 0;
    const employeeCount = destinationStaffCounts.rows[0].employee_count || 0;
    if (normalizedAccountRole === 'manager' && managerCount >= 1) {
      throw new Error('Each hotel can have only one manager account.');
    }
    if (normalizedAccountRole === 'employee' && employeeCount >= 3) {
      throw new Error('Each hotel can have at most 3 employee accounts.');
    }

    await client.query(
      'UPDATE person SET first_name=$1,last_name=$2,email=$3,phone=$4,address_line=$5 WHERE person_id=$6',
      [
        normalizedFirstName,
        normalizedLastName,
        normalizedEmail,
        normalizedPhone,
        normalizedAddress,
        employee.rows[0].person_id
      ]
    );

    await client.query(
      'UPDATE employee SET hotel_id=$1, role_title=$2, hired_on=$3, is_manager=$4 WHERE employee_id=$5',
      [normalizedHotelId, normalizedRoleTitle, normalizedHiredOn, normalizedAccountRole === 'manager', employeeId]
    );

    if (currentAccount.account_id) {
      if (passwordProvided) {
        await client.query(
          `UPDATE auth_account
           SET role = $1, username = $2, password_plain = $3
           WHERE account_id = $4`,
          [normalizedAccountRole, normalizedUsername, normalizedPassword, currentAccount.account_id]
        );
      } else {
        await client.query(
          `UPDATE auth_account
           SET role = $1, username = $2
           WHERE account_id = $3`,
          [normalizedAccountRole, normalizedUsername, currentAccount.account_id]
        );
      }
    } else {
      if (!passwordProvided) {
        throw new Error('Password is required when creating a missing account.');
      }
      await client.query(
        `INSERT INTO auth_account (role, username, password_plain, employee_id, customer_id, is_active)
         VALUES ($1, $2, $3, $4, NULL, TRUE)`,
        [normalizedAccountRole, normalizedUsername, normalizedPassword, employeeId]
      );
    }
    await client.query('COMMIT');
    redirectWith(res, '/manage/employees', 'Employee updated.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/manage/employees', err.message, 'error');
  } finally {
    client.release();
  }
});

app.patch('/manage/employees/:id/account-status', requireRole(['manager', 'admin']), async (req, res) => {
  const client = await db.getClient();
  try {
    const employeeId = parsePositiveInt(req.params.id, 'Employee');
    const isActive = parseBooleanInput(req.body.is_active, 'Account status');
    const isManager = req.auth.role === 'manager';
    const managerHotelId = isManager ? await fetchManagerHotelId(req.auth.employeeId) : null;

    await client.query('BEGIN');
    const staffAccount = await client.query(
      `SELECT a.account_id, a.role, a.is_active, e.hotel_id
       FROM auth_account a
       JOIN employee e ON e.employee_id = a.employee_id
       WHERE a.employee_id = $1 AND a.role IN ('employee', 'manager')
       FOR UPDATE`,
      [employeeId]
    );
    if (staffAccount.rowCount === 0) {
      throw new Error('Staff account not found.');
    }
    if (isManager) {
      if (staffAccount.rows[0].role !== 'employee') {
        throw new Error('Managers can only manage employee accounts.');
      }
      if (staffAccount.rows[0].hotel_id !== managerHotelId) {
        throw new Error('You can only manage employees assigned to your hotel.');
      }
    }
    assertCanManageStaffAccount(req.auth.role, staffAccount.rows[0].role);

    if (!isActive && req.auth.accountId === staffAccount.rows[0].account_id) {
      throw new Error('You cannot disable your own account while signed in.');
    }

    await client.query(
      `UPDATE auth_account
       SET is_active = $1
       WHERE account_id = $2`,
      [isActive, staffAccount.rows[0].account_id]
    );
    await client.query('COMMIT');
    redirectWith(res, '/manage/employees', `Account ${isActive ? 'enabled' : 'disabled'}.`, 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/manage/employees', err.message, 'error');
  } finally {
    client.release();
  }
});

app.delete('/manage/employees/:id', requireRole(['manager', 'admin']), async (req, res) => {
  const client = await db.getClient();
  try {
    const employeeId = parsePositiveInt(req.params.id, 'Employee');
    const isManager = req.auth.role === 'manager';
    const managerHotelId = isManager ? await fetchManagerHotelId(req.auth.employeeId) : null;

    await client.query('BEGIN');
    const staffRecord = await client.query(
      `SELECT
         e.employee_id,
         e.person_id,
         e.hotel_id,
         a.account_id,
         a.role AS account_role
       FROM employee e
       LEFT JOIN auth_account a ON a.employee_id = e.employee_id
       WHERE e.employee_id = $1
       FOR UPDATE`,
      [employeeId]
    );
    if (staffRecord.rowCount === 0) {
      throw new Error('Employee not found.');
    }

    const target = staffRecord.rows[0];
    if (isManager) {
      if (target.account_role !== 'employee') {
        throw new Error('Managers can only delete employee accounts.');
      }
      if (target.hotel_id !== managerHotelId) {
        throw new Error('You can only delete employees assigned to your hotel.');
      }
    }
    if (target.account_role) {
      assertCanManageStaffAccount(req.auth.role, target.account_role);
    }
    if (target.account_id && target.account_id === req.auth.accountId) {
      throw new Error('You cannot delete your own account while signed in.');
    }

    await client.query('DELETE FROM employee WHERE employee_id = $1', [employeeId]);
    await client.query('DELETE FROM person WHERE person_id = $1', [target.person_id]);
    await client.query('COMMIT');
    redirectWith(res, '/manage/employees', 'Staff record deleted.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    if (err.code === '23503') {
      redirectWith(
        res,
        '/manage/employees',
        'This staff member cannot be deleted because they are referenced by existing renting/payment records.',
        'error'
      );
      return;
    }
    redirectWith(res, '/manage/employees', err.message, 'error');
  } finally {
    client.release();
  }
});

app.get('/manage/hotels', requireRole(['admin']), async (req, res) => {
  try {
    const [hotels, chains] = await Promise.all([
      db.query('SELECT * FROM hotel ORDER BY hotel_id LIMIT 300'),
      db.query('SELECT chain_id, chain_name FROM hotel_chain ORDER BY chain_name')
    ]);

    res.render('manage/hotels', {
      message: buildMessage(req.query),
      hotels: hotels.rows,
      chains: chains.rows
    });
  } catch (err) {
    redirectWith(res, '/', err.message, 'error');
  }
});

app.post('/manage/hotels', requireRole(['admin']), async (req, res) => {
  const {
    chain_id,
    hotel_name,
    category,
    total_rooms,
    address_line,
    city,
    state_province,
    country,
    postal_code,
    contact_email,
    contact_phone
  } = req.body;
  try {
    const normalizedChainId = parsePositiveInt(chain_id, 'Hotel chain');
    const normalizedHotelName = normalizeString(hotel_name, 'Hotel name', 140);
    const normalizedCategory = parsePositiveInt(category, 'Hotel category');
    if (normalizedCategory < 1 || normalizedCategory > 5) throw new Error('Hotel category must be between 1 and 5.');
    const normalizedTotalRooms = parsePositiveInt(total_rooms, 'Total rooms');
    const normalizedAddress = normalizeString(address_line, 'Address', 255);
    const normalizedCity = normalizeString(city, 'City', 100);
    const normalizedStateProvince = normalizeString(state_province, 'State/Province', 100);
    const normalizedCountry = normalizeString(country, 'Country', 80);
    const normalizedPostalCode = normalizeString(postal_code, 'Postal code', 20);
    const normalizedContactEmail = normalizeEmail(contact_email, 'Contact email');
    const normalizedContactPhone = normalizePhone(contact_phone, 'Contact phone');

    await db.query(
      `INSERT INTO hotel (chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
      [
        normalizedChainId,
        normalizedHotelName,
        normalizedCategory,
        normalizedTotalRooms,
        normalizedAddress,
        normalizedCity,
        normalizedStateProvince,
        normalizedCountry,
        normalizedPostalCode,
        normalizedContactEmail,
        normalizedContactPhone
      ]
    );
    redirectWith(res, '/manage/hotels', 'Hotel created.', 'success');
  } catch (err) {
    redirectWith(res, '/manage/hotels', err.message, 'error');
  }
});

app.patch('/manage/hotels/:id', requireRole(['admin']), async (req, res) => {
  const {
    chain_id,
    hotel_name,
    category,
    total_rooms,
    address_line,
    city,
    state_province,
    country,
    postal_code,
    contact_email,
    contact_phone
  } = req.body;
  try {
    const hotelId = parsePositiveInt(req.params.id, 'Hotel');
    const normalizedChainId = parsePositiveInt(chain_id, 'Hotel chain');
    const normalizedHotelName = normalizeString(hotel_name, 'Hotel name', 140);
    const normalizedCategory = parsePositiveInt(category, 'Hotel category');
    if (normalizedCategory < 1 || normalizedCategory > 5) throw new Error('Hotel category must be between 1 and 5.');
    const normalizedTotalRooms = parsePositiveInt(total_rooms, 'Total rooms');
    const normalizedAddress = normalizeString(address_line, 'Address', 255);
    const normalizedCity = normalizeString(city, 'City', 100);
    const normalizedStateProvince = normalizeString(state_province, 'State/Province', 100);
    const normalizedCountry = normalizeString(country, 'Country', 80);
    const normalizedPostalCode = normalizeString(postal_code, 'Postal code', 20);
    const normalizedContactEmail = normalizeEmail(contact_email, 'Contact email');
    const normalizedContactPhone = normalizePhone(contact_phone, 'Contact phone');

    await db.query(
      `UPDATE hotel
       SET chain_id=$1, hotel_name=$2, category=$3, total_rooms=$4, address_line=$5,
           city=$6, state_province=$7, country=$8, postal_code=$9, contact_email=$10, contact_phone=$11
       WHERE hotel_id=$12`,
      [
        normalizedChainId,
        normalizedHotelName,
        normalizedCategory,
        normalizedTotalRooms,
        normalizedAddress,
        normalizedCity,
        normalizedStateProvince,
        normalizedCountry,
        normalizedPostalCode,
        normalizedContactEmail,
        normalizedContactPhone,
        hotelId
      ]
    );
    redirectWith(res, '/manage/hotels', 'Hotel updated.', 'success');
  } catch (err) {
    redirectWith(res, '/manage/hotels', err.message, 'error');
  }
});

app.delete('/manage/hotels/:id', requireRole(['admin']), async (req, res) => {
  try {
    const hotelId = parsePositiveInt(req.params.id, 'Hotel');
    await db.query('DELETE FROM hotel WHERE hotel_id = $1', [hotelId]);
    redirectWith(res, '/manage/hotels', 'Hotel deleted.', 'success');
  } catch (err) {
    redirectWith(res, '/manage/hotels', err.message, 'error');
  }
});

app.get('/manage/rooms', requireRole(['admin']), async (req, res) => {
  try {
    const [rooms, hotels] = await Promise.all([
      db.query('SELECT * FROM room ORDER BY room_id LIMIT 500'),
      db.query('SELECT hotel_id, hotel_name, city FROM hotel ORDER BY hotel_id')
    ]);
    res.render('manage/rooms', {
      message: buildMessage(req.query),
      rooms: rooms.rows,
      hotels: hotels.rows
    });
  } catch (err) {
    redirectWith(res, '/', err.message, 'error');
  }
});

app.post('/manage/rooms', requireRole(['admin']), async (req, res) => {
  const {
    hotel_id,
    room_number,
    capacity,
    base_price,
    has_sea_view,
    has_mountain_view,
    is_extendable,
    amenities,
    issues,
    current_status
  } = req.body;

  try {
    const normalizedHotelId = parsePositiveInt(hotel_id, 'Hotel');
    const normalizedRoomNumber = normalizeString(room_number, 'Room number', 10);
    const normalizedCapacity = parseEnum(capacity, ['single', 'double', 'suite', 'family'], 'Capacity');
    const normalizedBasePrice = parsePositiveNumber(base_price, 'Room price');
    const normalizedAmenities = normalizeString(amenities, 'Amenities', 4000);
    const normalizedIssues = normalizeOptionalString(issues, 'Issues', 4000);
    const normalizedCurrentStatus = parseEnum(
      current_status,
      ['available', 'booked', 'rented', 'maintenance'],
      'Room status'
    );

    await db.query(
      `INSERT INTO room (hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [
        normalizedHotelId,
        normalizedRoomNumber,
        normalizedCapacity,
        normalizedBasePrice,
        parseCheckbox(has_sea_view),
        parseCheckbox(has_mountain_view),
        parseCheckbox(is_extendable),
        normalizedAmenities,
        normalizedIssues,
        normalizedCurrentStatus
      ]
    );
    redirectWith(res, '/manage/rooms', 'Room created.', 'success');
  } catch (err) {
    redirectWith(res, '/manage/rooms', err.message, 'error');
  }
});

app.patch('/manage/rooms/:id', requireRole(['admin']), async (req, res) => {
  const {
    hotel_id,
    room_number,
    capacity,
    base_price,
    has_sea_view,
    has_mountain_view,
    is_extendable,
    amenities,
    issues,
    current_status
  } = req.body;

  try {
    const roomId = parsePositiveInt(req.params.id, 'Room');
    const normalizedHotelId = parsePositiveInt(hotel_id, 'Hotel');
    const normalizedRoomNumber = normalizeString(room_number, 'Room number', 10);
    const normalizedCapacity = parseEnum(capacity, ['single', 'double', 'suite', 'family'], 'Capacity');
    const normalizedBasePrice = parsePositiveNumber(base_price, 'Room price');
    const normalizedAmenities = normalizeString(amenities, 'Amenities', 4000);
    const normalizedIssues = normalizeOptionalString(issues, 'Issues', 4000);
    const normalizedCurrentStatus = parseEnum(
      current_status,
      ['available', 'booked', 'rented', 'maintenance'],
      'Room status'
    );

    await db.query(
      `UPDATE room
       SET hotel_id=$1, room_number=$2, capacity=$3, base_price=$4, has_sea_view=$5,
           has_mountain_view=$6, is_extendable=$7, amenities=$8, issues=$9, current_status=$10
       WHERE room_id=$11`,
      [
        normalizedHotelId,
        normalizedRoomNumber,
        normalizedCapacity,
        normalizedBasePrice,
        parseCheckbox(has_sea_view),
        parseCheckbox(has_mountain_view),
        parseCheckbox(is_extendable),
        normalizedAmenities,
        normalizedIssues,
        normalizedCurrentStatus,
        roomId
      ]
    );
    redirectWith(res, '/manage/rooms', 'Room updated.', 'success');
  } catch (err) {
    redirectWith(res, '/manage/rooms', err.message, 'error');
  }
});

app.delete('/manage/rooms/:id', requireRole(['admin']), async (req, res) => {
  try {
    const roomId = parsePositiveInt(req.params.id, 'Room');
    await db.query('DELETE FROM room WHERE room_id = $1', [roomId]);
    redirectWith(res, '/manage/rooms', 'Room deleted.', 'success');
  } catch (err) {
    redirectWith(res, '/manage/rooms', err.message, 'error');
  }
});

app.use((req, res) => {
  res.status(404).send('Page not found');
});

async function startServer() {
  try {
    await initializeDatabaseIfNeeded();
    await ensurePersonSinSchemaAndData();
    await ensureCustomerHotelSchemaAndData();
    await ensureArchiveSchemaAndData();
    await ensureHotelCoverageBaseline();
    await ensureAuthSchemaAndSeed();
    app.listen(PORT, () => {
      console.log(`Server running on http://localhost:${PORT}`);
    });
  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
}

startServer();
