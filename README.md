# CSI2132 - eHotels Deliverable 2

This repository contains a full Deliverable 2 implementation for the CSI2132 eHotels project using:
- PostgreSQL
- Node.js + Express
- EJS templates
- HTML/CSS

## Project Structure

- `sql/schema.sql`: Full DDL, constraints, triggers, indexes, and required views.
- `sql/seed.sql`: Data population script (5 hotel chains, 40 hotels, room/customer/employee/booking/renting data).
- `sql/queries.sql`: Required sample queries (including aggregation + nested query) and trigger/view demos.
- `src/server.js`: Express application and routes.
- `src/db.js`: PostgreSQL connection layer.
- `views/`: EJS pages for customer, employee, and CRUD workflows.
- `public/styles.css`: Styling.
- `report/deliverable2_report.md`: Deliverable 2 report content.
- `report/video_timestamps_template.md`: Template for Table 1 timestamps.

## Run Locally

Follow these steps in order from the project root.

### 1) Install dependencies

```bash
npm install
```

### 2) Start PostgreSQL

Make sure PostgreSQL is running before loading SQL or starting the app.

Example (macOS + Homebrew):

```bash
brew services start postgresql@15
pg_isready -h localhost -p 5432
```

If `pg_isready` says `accepting connections`, you are good.

### 3) Configure environment

Create `.env`:

```bash
cp .env.example .env
```

Then edit `.env`.

For a typical local Homebrew setup:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=ehotels
DB_USER=<your_local_postgres_role>
DB_PASSWORD=
PORT=3000
```

Notes:
- `DB_USER` is often your macOS username (for example `luuluu2`) if no `postgres` role exists.
- Leave `DB_PASSWORD` empty if your local role has no password.

### 4) Create and load the database

```bash
createdb ehotels
psql -d ehotels -f sql/schema.sql
psql -d ehotels -f sql/seed.sql
psql -d ehotels -f sql/queries.sql
```

### 5) Run the web app

```bash
npm run dev
```

Open:

`http://localhost:3000`

Keep this terminal running while using the app.



## What is Implemented

- Room search with multi-criteria filters:
  - dates, room capacity, area, hotel chain, category, total rooms, and price
- Booking creation flow
- Employee panel:
  - booking -> renting transformation
  - direct renting creation
  - payment insertion
- Full CRUD pages:
  - customers, employees, hotels, rooms
- Required SQL Views displayed in UI
- Triggers for overlap prevention, room status synchronization, and archiving
- Indexes for common filter/query paths

## Notes

- Archive records are stored without hard foreign keys to mutable entities so they remain available even if rooms/customers are deleted later.
- The UI is intentionally form-driven to match project rubric requirements for non-SQL users.
