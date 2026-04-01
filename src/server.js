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
const LOGIN_ROLES = ['admin', 'employee'];
const ROLE_HOME = {
  admin: '/',
  manager: '/',
  employee: '/',
  customer: '/'
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

function mapAccountToAuth(account) {
  return {
    isAuthenticated: true,
    accountId: account.account_id,
    role: account.role,
    username: account.username,
    displayName: account.display_name,
    customerId: account.customer_id,
    employeeId: account.employee_id,
    personId: account.person_id,
    isActive: account.is_active
  };
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

async function fetchManagerHotelId(employeeId) {
  const result = await db.query(
    `SELECT hotel_id
     FROM employee
     WHERE employee_id = $1
     LIMIT 1`,
    [employeeId]
  );
  if (result.rowCount === 0) {
    throw new Error('Manager profile is not linked to a valid employee record.');
  }
  return result.rows[0].hotel_id;
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
        if (account.role === 'customer') {
          clearAuthCookie(res);
        } else {
          req.auth = mapAccountToAuth(account);
        }
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
  return redirectWith(res, '/login', 'Customer self-signup is disabled. Staff must register customers.', 'info');
});

app.post('/signup/customer', async (req, res) => {
  return redirectWith(res, '/login', 'Customer self-signup is disabled. Staff must register customers.', 'info');
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

    const username = normalizeUsername(req.body.username);
    const password = normalizePassword(req.body.password);

    const account = role === 'employee'
      ? await fetchStaffAccountByUsername(username)
      : await fetchAccountByRoleAndUsername(role, username);
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

app.get('/search', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  try {
    const easternToday = easternTodayISO();
    const filterData = await Promise.all([
      db.query('SELECT chain_id, chain_name FROM hotel_chain ORDER BY chain_name'),
      db.query('SELECT DISTINCT city FROM hotel ORDER BY city')
    ]);

    const q = req.query;
    const values = [];
    const conditions = ["r.current_status = 'available'"];

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

    const startDate = sanitizeDate(q.start_date);
    const endDate = sanitizeDate(q.end_date);
    if (startDate && startDate > easternToday) {
      throw new Error(`Start date cannot be in the future. Use Eastern today (${easternToday}).`);
    }
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
        h.hotel_id,
        h.hotel_name,
        h.city,
        h.category,
        h.total_rooms,
        hc.chain_name
      FROM room r
      JOIN hotel h ON h.hotel_id = r.hotel_id
      JOIN hotel_chain hc ON hc.chain_id = h.chain_id
      WHERE ${conditions.join(' AND ')}
      ORDER BY r.base_price ASC
      LIMIT 200`,
      values
    );

    const customers = await db.query(
      `SELECT c.customer_id, p.legal_id
       FROM customer c
       JOIN person p ON p.person_id = c.person_id
       ORDER BY c.customer_id
       LIMIT 200`
    );

    const renderedFilters = { ...q, start_date: q.start_date || easternToday };

    res.render('search', {
      message: buildMessage(req.query),
      filters: renderedFilters,
      chains: filterData[0].rows,
      cities: filterData[1].rows,
      rooms: rooms.rows,
      customers: customers.rows,
      easternToday
    });
  } catch (err) {
    redirectWith(res, '/search', err.message, 'error');
  }
});

app.post('/bookings', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  const { room_id, customer_sin, employee_id, start_date, end_date } = req.body;
  try {
    const roomId = parsePositiveInt(room_id, 'Room');
    const normalizedCustomerSin = normalizeSin(customer_sin, 'Customer SIN');
    const effectiveEmployeeId = req.auth.role === 'employee' || req.auth.role === 'manager'
      ? parsePositiveInt(req.auth.employeeId, 'Employee')
      : parseOptionalPositiveInt(employee_id, 'Employee');
    const normalizedStartDate = parseDateInput(start_date, 'Start date');
    const normalizedEndDate = parseDateInput(end_date, 'End date');
    const easternToday = easternTodayISO();
    if (normalizedStartDate !== easternToday) {
      throw new Error(`Start date must be today (${easternToday}) based on Eastern Time.`);
    }
    ensureEndDateAfterStartDate(normalizedStartDate, normalizedEndDate);

    const customerCheck = await db.query(
      `SELECT c.customer_id
       FROM customer c
       JOIN person p ON p.person_id = c.person_id
       WHERE p.legal_id = $1
       LIMIT 1`,
      [normalizedCustomerSin]
    );
    if (customerCheck.rowCount === 0) {
      throw new Error('No customer found with that SIN.');
    }
    const effectiveCustomerId = customerCheck.rows[0].customer_id;

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
    res.render('settings-customer', {
      message: buildMessage(req.query),
      profile: details.rows[0]
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

app.get('/employee', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  try {
    const easternToday = easternTodayISO();
    const [employees, customers, availableRooms, activeBookings, activeRentings] = await Promise.all([
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
                FROM room r JOIN hotel h ON h.hotel_id = r.hotel_id
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
                  AND b.start_date = $1
                ORDER BY b.booking_id DESC LIMIT 200`, [easternToday]),
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
                ORDER BY rt.renting_id DESC LIMIT 200`)
    ]);

    res.render('employee', {
      message: buildMessage(req.query),
      employees: employees.rows,
      customers: customers.rows,
      availableRooms: availableRooms.rows,
      activeBookings: activeBookings.rows,
      activeRentings: activeRentings.rows,
      easternToday
    });
  } catch (err) {
    redirectWith(res, '/employee', err.message, 'error');
  }
});

app.post('/employee/rentings/from-booking', requireRole(['employee', 'manager', 'admin']), async (req, res) => {
  const client = await db.getClient();
  try {
    const easternToday = easternTodayISO();
    const bookingId = parsePositiveInt(req.body.booking_id, 'Booking');
    const employeeId = req.auth.role === 'employee' || req.auth.role === 'manager'
      ? parsePositiveInt(req.auth.employeeId, 'Employee')
      : parsePositiveInt(req.body.employee_id, 'Employee');

    await client.query('BEGIN');
    const bookingResult = await client.query(
      `SELECT booking_id, room_id, customer_id, start_date, end_date, status
       FROM booking WHERE booking_id = $1 FOR UPDATE`,
      [bookingId]
    );

    if (bookingResult.rowCount === 0) {
      throw new Error('Booking not found.');
    }

    const b = bookingResult.rows[0];
    if (!['reserved', 'checked_in'].includes(b.status)) {
      throw new Error('Booking cannot be transformed from current status.');
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
    const easternToday = easternTodayISO();
    const roomId = parsePositiveInt(room_id, 'Room');
    const normalizedCustomerSin = normalizeSin(customer_sin, 'Customer SIN');
    const effectiveEmployeeId = req.auth.role === 'employee' || req.auth.role === 'manager'
      ? parsePositiveInt(req.auth.employeeId, 'Employee')
      : parsePositiveInt(employee_id, 'Employee');
    const normalizedStartDate = parseDateInput(start_date, 'Start date');
    const normalizedEndDate = parseDateInput(end_date, 'End date');
    if (normalizedStartDate !== easternToday) {
      throw new Error(`Start date must be today (${easternToday}) based on Eastern Time.`);
    }
    ensureEndDateAfterStartDate(normalizedStartDate, normalizedEndDate);

    const customerCheck = await db.query(
      `SELECT c.customer_id
       FROM customer c
       JOIN person p ON p.person_id = c.person_id
       WHERE p.legal_id = $1
       LIMIT 1`,
      [normalizedCustomerSin]
    );
    if (customerCheck.rowCount === 0) {
      throw new Error('No customer found with that SIN.');
    }
    const customerId = customerCheck.rows[0].customer_id;

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
    const customers = await db.query(
      `SELECT
         c.customer_id,
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
       LEFT JOIN auth_account a
         ON a.customer_id = c.customer_id
        AND a.role = 'customer'
       ORDER BY c.customer_id LIMIT 300`
    );
    res.render('manage/customers', { message: buildMessage(req.query), customers: customers.rows });
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
      `INSERT INTO customer (person_id, registration_date)
       VALUES ($1, $2)
       RETURNING customer_id`,
      [person.rows[0].person_id, normalizedRegistrationDate]
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
    const normalizedFirstName = normalizeString(first_name, 'First name', 80);
    const normalizedLastName = normalizeString(last_name, 'Last name', 80);
    const normalizedEmail = normalizeEmail(email);
    const normalizedPhone = normalizePhone(phone);
    const normalizedAddress = normalizeString(address_line, 'Address', 255);
    const normalizedRegistrationDate = parseDateInput(registration_date, 'Registration date');

    await client.query('BEGIN');
    const customer = await client.query('SELECT person_id FROM customer WHERE customer_id = $1', [customerId]);
    if (customer.rowCount === 0) throw new Error('Customer not found.');
    const personId = customer.rows[0].person_id;

    await client.query(
      `UPDATE person SET first_name=$1, last_name=$2, email=$3, phone=$4, address_line=$5 WHERE person_id=$6`,
      [normalizedFirstName, normalizedLastName, normalizedEmail, normalizedPhone, normalizedAddress, personId]
    );
    await client.query(`UPDATE customer SET registration_date=$1 WHERE customer_id=$2`, [normalizedRegistrationDate, customerId]);
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
  try {
    redirectWith(res, '/manage/customers', 'Customer login accounts are disabled in staff-only mode.', 'info');
  } catch (err) {
    redirectWith(res, '/manage/customers', err.message, 'error');
  }
});

app.delete('/manage/customers/:id', requireRole(['admin']), async (req, res) => {
  const client = await db.getClient();
  try {
    const customerId = parsePositiveInt(req.params.id, 'Customer');
    await client.query('BEGIN');
    const c = await client.query('SELECT person_id FROM customer WHERE customer_id = $1', [customerId]);
    if (c.rowCount === 0) throw new Error('Customer not found.');
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
  try {
    redirectWith(res, '/manage/employees', 'Deleting staff is disabled. Set account status to inactive instead.', 'info');
  } catch (err) {
    redirectWith(res, '/manage/employees', err.message, 'error');
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
