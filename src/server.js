const express = require('express');
const methodOverride = require('method-override');
const db = require('./db');

const app = express();
const PORT = Number(process.env.PORT || 3000);

app.set('view engine', 'ejs');
app.set('views', 'views');
app.use(express.urlencoded({ extended: true }));
app.use(methodOverride('_method'));
app.use(express.static('public'));

function sanitizeDate(value) {
  if (!value) return null;
  const candidate = new Date(value);
  return Number.isNaN(candidate.getTime()) ? null : value;
}

function buildMessage(query) {
  if (!query.msg) return null;
  return { type: query.type || 'info', text: query.msg };
}

function redirectWith(res, path, msg, type = 'info') {
  const separator = path.includes('?') ? '&' : '?';
  res.redirect(`${path}${separator}msg=${encodeURIComponent(msg)}&type=${encodeURIComponent(type)}`);
}

app.get('/', async (req, res) => {
  try {
    const [hotels, rooms, customers, employees] = await Promise.all([
      db.query('SELECT COUNT(*)::int AS count FROM hotel'),
      db.query('SELECT COUNT(*)::int AS count FROM room'),
      db.query('SELECT COUNT(*)::int AS count FROM customer'),
      db.query('SELECT COUNT(*)::int AS count FROM employee')
    ]);

    res.render('index', {
      message: buildMessage(req.query),
      counts: {
        hotels: hotels.rows[0].count,
        rooms: rooms.rows[0].count,
        customers: customers.rows[0].count,
        employees: employees.rows[0].count
      }
    });
  } catch (err) {
    res.status(500).send(err.message);
  }
});

app.get('/search', async (req, res) => {
  try {
    const filterData = await Promise.all([
      db.query('SELECT chain_id, chain_name FROM hotel_chain ORDER BY chain_name'),
      db.query('SELECT DISTINCT city FROM hotel ORDER BY city')
    ]);

    const values = [];
    const conditions = ["r.current_status = 'available'"];
    const q = req.query;

    if (q.capacity) {
      values.push(q.capacity);
      conditions.push(`r.capacity = $${values.length}`);
    }
    if (q.city) {
      values.push(q.city);
      conditions.push(`h.city = $${values.length}`);
    }
    if (q.chain_id) {
      values.push(Number(q.chain_id));
      conditions.push(`h.chain_id = $${values.length}`);
    }
    if (q.category) {
      values.push(Number(q.category));
      conditions.push(`h.category = $${values.length}`);
    }
    if (q.total_rooms_min) {
      values.push(Number(q.total_rooms_min));
      conditions.push(`h.total_rooms >= $${values.length}`);
    }
    if (q.max_price) {
      values.push(Number(q.max_price));
      conditions.push(`r.base_price <= $${values.length}`);
    }

    const startDate = sanitizeDate(q.start_date);
    const endDate = sanitizeDate(q.end_date);
    if (startDate && endDate) {
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
      `SELECT c.customer_id, p.first_name, p.last_name, p.legal_id
       FROM customer c
       JOIN person p ON p.person_id = c.person_id
       ORDER BY c.customer_id
       LIMIT 200`
    );

    res.render('search', {
      message: buildMessage(req.query),
      filters: q,
      chains: filterData[0].rows,
      cities: filterData[1].rows,
      rooms: rooms.rows,
      customers: customers.rows
    });
  } catch (err) {
    redirectWith(res, '/search', err.message, 'error');
  }
});

app.post('/bookings', async (req, res) => {
  const { room_id, customer_id, employee_id, start_date, end_date } = req.body;
  try {
    await db.query(
      `INSERT INTO booking (room_id, customer_id, created_by_employee_id, start_date, end_date, status)
       VALUES ($1, $2, $3, $4, $5, 'reserved')`,
      [Number(room_id), Number(customer_id), employee_id ? Number(employee_id) : null, start_date, end_date]
    );
    redirectWith(res, '/search', 'Booking created successfully.', 'success');
  } catch (err) {
    redirectWith(res, '/search', err.message, 'error');
  }
});

app.get('/employee', async (req, res) => {
  try {
    const [employees, customers, availableRooms, activeBookings, activeRentings] = await Promise.all([
      db.query(`SELECT e.employee_id, p.first_name, p.last_name, h.hotel_name
                FROM employee e
                JOIN person p ON p.person_id = e.person_id
                JOIN hotel h ON h.hotel_id = e.hotel_id
                ORDER BY e.employee_id`),
      db.query(`SELECT c.customer_id, p.first_name, p.last_name
                FROM customer c JOIN person p ON p.person_id = c.person_id
                ORDER BY c.customer_id LIMIT 200`),
      db.query(`SELECT r.room_id, r.room_number, h.hotel_name, h.city
                FROM room r JOIN hotel h ON h.hotel_id = r.hotel_id
                WHERE r.current_status = 'available'
                ORDER BY r.room_id LIMIT 200`),
      db.query(`SELECT b.booking_id, b.room_id, b.customer_id, b.start_date, b.end_date, b.status
                FROM booking b
                WHERE b.status IN ('reserved', 'checked_in')
                ORDER BY b.booking_id DESC LIMIT 200`),
      db.query(`SELECT renting_id, room_id, customer_id, employee_id, start_date, end_date, status
                FROM renting
                ORDER BY renting_id DESC LIMIT 200`)
    ]);

    res.render('employee', {
      message: buildMessage(req.query),
      employees: employees.rows,
      customers: customers.rows,
      availableRooms: availableRooms.rows,
      activeBookings: activeBookings.rows,
      activeRentings: activeRentings.rows
    });
  } catch (err) {
    redirectWith(res, '/employee', err.message, 'error');
  }
});

app.post('/employee/rentings/from-booking', async (req, res) => {
  const client = await db.getClient();
  try {
    const bookingId = Number(req.body.booking_id);
    const employeeId = Number(req.body.employee_id);

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

app.post('/employee/rentings/direct', async (req, res) => {
  const { room_id, customer_id, employee_id, start_date, end_date } = req.body;
  try {
    await db.query(
      `INSERT INTO renting (room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status)
       VALUES ($1, $2, $3, NULL, $4, $5, 'active')`,
      [Number(room_id), Number(customer_id), Number(employee_id), start_date, end_date]
    );
    redirectWith(res, '/employee', 'Direct renting created.', 'success');
  } catch (err) {
    redirectWith(res, '/employee', err.message, 'error');
  }
});

app.patch('/employee/rentings/:id/complete', async (req, res) => {
  try {
    await db.query(`UPDATE renting SET status = 'completed' WHERE renting_id = $1`, [Number(req.params.id)]);
    redirectWith(res, '/employee', 'Renting completed and archived.', 'success');
  } catch (err) {
    redirectWith(res, '/employee', err.message, 'error');
  }
});

app.post('/employee/payments', async (req, res) => {
  const { renting_id, employee_id, amount, method } = req.body;
  try {
    await db.query(
      `INSERT INTO payment (renting_id, employee_id, amount, method)
       VALUES ($1, $2, $3, $4)`,
      [Number(renting_id), Number(employee_id), Number(amount), method]
    );
    redirectWith(res, '/employee', 'Payment recorded.', 'success');
  } catch (err) {
    redirectWith(res, '/employee', err.message, 'error');
  }
});

app.get('/views', async (req, res) => {
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

app.get('/manage/customers', async (req, res) => {
  try {
    const customers = await db.query(
      `SELECT c.customer_id, c.registration_date, p.person_id, p.legal_id, p.id_type, p.first_name, p.last_name, p.email, p.phone, p.address_line
       FROM customer c JOIN person p ON p.person_id = c.person_id
       ORDER BY c.customer_id LIMIT 300`
    );
    res.render('manage/customers', { message: buildMessage(req.query), customers: customers.rows });
  } catch (err) {
    redirectWith(res, '/', err.message, 'error');
  }
});

app.post('/manage/customers', async (req, res) => {
  const client = await db.getClient();
  try {
    const { legal_id, id_type, first_name, last_name, email, phone, address_line, registration_date } = req.body;
    await client.query('BEGIN');
    const person = await client.query(
      `INSERT INTO person (legal_id, id_type, first_name, last_name, email, phone, address_line)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING person_id`,
      [legal_id, id_type, first_name, last_name, email, phone, address_line]
    );
    await client.query(
      `INSERT INTO customer (person_id, registration_date) VALUES ($1, $2)`,
      [person.rows[0].person_id, registration_date || null]
    );
    await client.query('COMMIT');
    redirectWith(res, '/manage/customers', 'Customer created.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/manage/customers', err.message, 'error');
  } finally {
    client.release();
  }
});

app.patch('/manage/customers/:id', async (req, res) => {
  const client = await db.getClient();
  try {
    const customerId = Number(req.params.id);
    const { first_name, last_name, email, phone, address_line, registration_date } = req.body;
    await client.query('BEGIN');
    const customer = await client.query('SELECT person_id FROM customer WHERE customer_id = $1', [customerId]);
    if (customer.rowCount === 0) throw new Error('Customer not found.');
    const personId = customer.rows[0].person_id;

    await client.query(
      `UPDATE person SET first_name=$1, last_name=$2, email=$3, phone=$4, address_line=$5 WHERE person_id=$6`,
      [first_name, last_name, email, phone, address_line, personId]
    );
    await client.query(`UPDATE customer SET registration_date=$1 WHERE customer_id=$2`, [registration_date, customerId]);
    await client.query('COMMIT');
    redirectWith(res, '/manage/customers', 'Customer updated.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/manage/customers', err.message, 'error');
  } finally {
    client.release();
  }
});

app.delete('/manage/customers/:id', async (req, res) => {
  const client = await db.getClient();
  try {
    const customerId = Number(req.params.id);
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

app.get('/manage/employees', async (req, res) => {
  try {
    const [employees, hotels] = await Promise.all([
      db.query(`SELECT e.employee_id, e.hotel_id, e.role_title, e.hired_on, e.is_manager,
                       p.person_id, p.legal_id, p.id_type, p.first_name, p.last_name, p.email, p.phone, p.address_line
                FROM employee e JOIN person p ON p.person_id = e.person_id
                ORDER BY e.employee_id LIMIT 300`),
      db.query('SELECT hotel_id, hotel_name FROM hotel ORDER BY hotel_id')
    ]);
    res.render('manage/employees', {
      message: buildMessage(req.query),
      employees: employees.rows,
      hotels: hotels.rows
    });
  } catch (err) {
    redirectWith(res, '/', err.message, 'error');
  }
});

app.post('/manage/employees', async (req, res) => {
  const client = await db.getClient();
  try {
    const { legal_id, id_type, first_name, last_name, email, phone, address_line, hotel_id, role_title, hired_on, is_manager } = req.body;
    await client.query('BEGIN');
    const person = await client.query(
      `INSERT INTO person (legal_id, id_type, first_name, last_name, email, phone, address_line)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING person_id`,
      [legal_id, id_type, first_name, last_name, email, phone, address_line]
    );
    await client.query(
      `INSERT INTO employee (person_id, hotel_id, role_title, hired_on, is_manager)
       VALUES ($1, $2, $3, $4, $5)`,
      [person.rows[0].person_id, Number(hotel_id), role_title, hired_on || null, is_manager === 'on']
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

app.patch('/manage/employees/:id', async (req, res) => {
  const client = await db.getClient();
  try {
    const employeeId = Number(req.params.id);
    const { first_name, last_name, email, phone, address_line, hotel_id, role_title, hired_on, is_manager } = req.body;

    await client.query('BEGIN');
    const employee = await client.query('SELECT person_id FROM employee WHERE employee_id = $1', [employeeId]);
    if (employee.rowCount === 0) throw new Error('Employee not found.');

    await client.query(
      'UPDATE person SET first_name=$1,last_name=$2,email=$3,phone=$4,address_line=$5 WHERE person_id=$6',
      [first_name, last_name, email, phone, address_line, employee.rows[0].person_id]
    );

    await client.query(
      'UPDATE employee SET hotel_id=$1, role_title=$2, hired_on=$3, is_manager=$4 WHERE employee_id=$5',
      [Number(hotel_id), role_title, hired_on, is_manager === 'on', employeeId]
    );
    await client.query('COMMIT');
    redirectWith(res, '/manage/employees', 'Employee updated.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/manage/employees', err.message, 'error');
  } finally {
    client.release();
  }
});

app.delete('/manage/employees/:id', async (req, res) => {
  const client = await db.getClient();
  try {
    const employeeId = Number(req.params.id);
    await client.query('BEGIN');
    const e = await client.query('SELECT person_id FROM employee WHERE employee_id=$1', [employeeId]);
    if (e.rowCount === 0) throw new Error('Employee not found.');
    await client.query('DELETE FROM employee WHERE employee_id=$1', [employeeId]);
    await client.query('DELETE FROM person WHERE person_id=$1', [e.rows[0].person_id]);
    await client.query('COMMIT');
    redirectWith(res, '/manage/employees', 'Employee deleted.', 'success');
  } catch (err) {
    await client.query('ROLLBACK');
    redirectWith(res, '/manage/employees', err.message, 'error');
  } finally {
    client.release();
  }
});

app.get('/manage/hotels', async (req, res) => {
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

app.post('/manage/hotels', async (req, res) => {
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
    await db.query(
      `INSERT INTO hotel (chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
      [Number(chain_id), hotel_name, Number(category), Number(total_rooms), address_line, city, state_province, country, postal_code, contact_email, contact_phone]
    );
    redirectWith(res, '/manage/hotels', 'Hotel created.', 'success');
  } catch (err) {
    redirectWith(res, '/manage/hotels', err.message, 'error');
  }
});

app.patch('/manage/hotels/:id', async (req, res) => {
  const hotelId = Number(req.params.id);
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
    await db.query(
      `UPDATE hotel
       SET chain_id=$1, hotel_name=$2, category=$3, total_rooms=$4, address_line=$5,
           city=$6, state_province=$7, country=$8, postal_code=$9, contact_email=$10, contact_phone=$11
       WHERE hotel_id=$12`,
      [
        Number(chain_id),
        hotel_name,
        Number(category),
        Number(total_rooms),
        address_line,
        city,
        state_province,
        country,
        postal_code,
        contact_email,
        contact_phone,
        hotelId
      ]
    );
    redirectWith(res, '/manage/hotels', 'Hotel updated.', 'success');
  } catch (err) {
    redirectWith(res, '/manage/hotels', err.message, 'error');
  }
});

app.delete('/manage/hotels/:id', async (req, res) => {
  try {
    await db.query('DELETE FROM hotel WHERE hotel_id = $1', [Number(req.params.id)]);
    redirectWith(res, '/manage/hotels', 'Hotel deleted.', 'success');
  } catch (err) {
    redirectWith(res, '/manage/hotels', err.message, 'error');
  }
});

app.get('/manage/rooms', async (req, res) => {
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

app.post('/manage/rooms', async (req, res) => {
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
    await db.query(
      `INSERT INTO room (hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [
        Number(hotel_id),
        room_number,
        capacity,
        Number(base_price),
        has_sea_view === 'on',
        has_mountain_view === 'on',
        is_extendable === 'on',
        amenities,
        issues || null,
        current_status
      ]
    );
    redirectWith(res, '/manage/rooms', 'Room created.', 'success');
  } catch (err) {
    redirectWith(res, '/manage/rooms', err.message, 'error');
  }
});

app.patch('/manage/rooms/:id', async (req, res) => {
  const roomId = Number(req.params.id);
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
    await db.query(
      `UPDATE room
       SET hotel_id=$1, room_number=$2, capacity=$3, base_price=$4, has_sea_view=$5,
           has_mountain_view=$6, is_extendable=$7, amenities=$8, issues=$9, current_status=$10
       WHERE room_id=$11`,
      [
        Number(hotel_id),
        room_number,
        capacity,
        Number(base_price),
        has_sea_view === 'on',
        has_mountain_view === 'on',
        is_extendable === 'on',
        amenities,
        issues || null,
        current_status,
        roomId
      ]
    );
    redirectWith(res, '/manage/rooms', 'Room updated.', 'success');
  } catch (err) {
    redirectWith(res, '/manage/rooms', err.message, 'error');
  }
});

app.delete('/manage/rooms/:id', async (req, res) => {
  try {
    await db.query('DELETE FROM room WHERE room_id = $1', [Number(req.params.id)]);
    redirectWith(res, '/manage/rooms', 'Room deleted.', 'success');
  } catch (err) {
    redirectWith(res, '/manage/rooms', err.message, 'error');
  }
});

app.use((req, res) => {
  res.status(404).send('Page not found');
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
