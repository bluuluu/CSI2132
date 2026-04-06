# CSI2132 Course Project - Deliverable 2 Report

## 1a) DBMS and Programming Languages

### DBMS
- PostgreSQL (tested on PostgreSQL 15; compatible with newer versions)

### Programming Languages / Frameworks
- JavaScript (Node.js)
- Express.js
- EJS
- HTML
- CSS
- SQL (PostgreSQL PL/pgSQL triggers/functions)

## 1b) Installation Steps

1. Install required software:
   - Node.js (LTS)
   - PostgreSQL 17 (or compatible)

2. Clone project and move into directory:
```bash
git clone <YOUR_REPO_URL>
cd CSI2132
```

3. Install dependencies:
```bash
npm install
```

4. Create environment file and set DB credentials:
```bash
cp .env.example .env
```

5. Create database:
```sql
CREATE DATABASE ehotels;
```

6. Run schema + seed scripts:
```bash
psql -U postgres -d ehotels -f sql/schema.sql
psql -U postgres -d ehotels -f sql/seed.sql
```

No CSV import is required; `sql/seed.sql` inserts the baseline dataset directly.

7. (Optional) Run sample queries:
```bash
psql -U postgres -d ehotels -f sql/queries.sql
```

8. Start the application:
```bash
npm run dev
```

9. Open browser:
- `http://localhost:3000`

## 1c) DDL Statements That Create the Database

All database DDL statements are included in:
- `sql/schema.sql`

The file contains:
- Table creation for hotel chains, hotels, persons, customers, employees, rooms, bookings, rentings, archive, payments
- Primary keys, foreign keys, and domain constraints
- User-defined constraints implemented through triggers/functions
- Trigger declarations
- Index creation statements
- View creation statements

### Main table creation statements
```sql
CREATE TABLE hotel_chain (...);
CREATE TABLE hotel (...);
CREATE TABLE person (...);
CREATE TABLE customer (...);
CREATE TABLE employee (...);
CREATE TABLE room (...);
CREATE TABLE booking (...);
CREATE TABLE renting (...);
CREATE TABLE archive (...);
CREATE TABLE payment (...);
```

### Trigger/function creation statements
```sql
CREATE OR REPLACE FUNCTION fn_validate_room_availability() ...;
CREATE OR REPLACE FUNCTION fn_sync_room_status(...) ...;
CREATE OR REPLACE FUNCTION fn_after_booking_change() ...;
CREATE OR REPLACE FUNCTION fn_after_renting_change() ...;
CREATE OR REPLACE FUNCTION fn_archive_booking() ...;
CREATE OR REPLACE FUNCTION fn_archive_renting() ...;

CREATE TRIGGER trg_booking_validate ...;
CREATE TRIGGER trg_renting_validate ...;
CREATE TRIGGER trg_booking_status_sync ...;
CREATE TRIGGER trg_renting_status_sync ...;
CREATE TRIGGER trg_archive_booking ...;
CREATE TRIGGER trg_archive_renting ...;
```

### Index statements
```sql
CREATE INDEX idx_room_capacity_price_status ON room(capacity, base_price, current_status);
CREATE INDEX idx_hotel_filtering ON hotel(chain_id, category, total_rooms);
CREATE INDEX idx_booking_room_dates ON booking(room_id, start_date, end_date);
CREATE INDEX idx_renting_room_dates ON renting(room_id, start_date, end_date);
```

### View statements
```sql
CREATE OR REPLACE VIEW v_available_rooms_per_area AS ...;
CREATE OR REPLACE VIEW v_hotel_capacity_aggregate AS ...;
```

## Included SQL Functionality Files

- `sql/schema.sql`
- `sql/seed.sql`
- `sql/queries.sql`
- `sql/queries/` (individual query demo scripts used in evidence/video)

## Included Application Code

- `src/server.js`
- `src/db.js`
- `views/`
- `public/styles.css`
- `package.json` and `package-lock.json` (dependency definitions)
- `.env.example` (environment template for correctors)
