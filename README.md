# CSI2132 - eHotels Deliverable 2

This repository contains a full Deliverable 2 implementation for the CSI2132 eHotels project using:
- PostgreSQL
- Node.js + Express
- EJS templates
- HTML/CSS

## Live App

Open the deployed web app here:  
[https://csi2132-ehotels.onrender.com/](https://csi2132-ehotels.onrender.com/)

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

## Role-Based Login

The app now uses staff-only login pages:

- `/login/employee`
- `/login/admin`

You can also start from `/login` and choose a role card.

### Login Info

- Admin: `admin` / `admin123`
- Manager accounts (seeded): `manager<ID>` / `manager<ID>123`  
  Example: `manager1` / `manager1123`  
  Use the staff login page: `/login/employee`
- Employee accounts (seeded): `employee<ID>` / `employee<ID>123`  
  Example: `employee2` / `employee2123`

### Access Differences

- Public (not signed in):
  - Can access login page only
  - Operational pages require staff/admin authentication
- Employee:
  - Can register customers at the desk using SIN (9 digits)
  - Can create bookings and direct rentings for registered customers by entering customer SIN
  - Booking start date is fixed to today's Eastern date
  - Can run check-in and direct renting workflows
  - Cannot manage staff accounts, SQL views, or hotel/room admin CRUD pages
- Manager:
  - Includes all employee capabilities
  - Can view employees assigned to the same hotel
  - Can create new employee accounts for the same hotel
  - Can enable/disable employee accounts for the same hotel
  - Cannot access admin-only CRUD or SQL views
- Admin:
  - Full access to all workflows
  - Can create customers, employees, and managers
  - Can enable/disable both employee and manager accounts
  - Can view full account details (including SIN and login status) for employees, managers, and customers
  - Can manage hotels/rooms/customers and SQL views



## What is Implemented

- Room search with multi-criteria filters:
  - dates, room capacity, area, hotel chain, category, total rooms, and price
- Staff-only authenticated booking flow
- Role-based login for employee/manager/admin portals and permission controls
- DB-backed login accounts (`auth_account`) for admin, manager, employee, and customer
- Employee panel:
  - booking -> renting transformation
  - direct renting creation
- Front-desk customer registration by SIN
- DB-level SIN enforcement for all people (customers, employees, managers): `id_type='SIN'` and exactly 9 digits
- Admin staff account management with enable/disable workflows (no destructive staff deletion)
- CRUD pages for customers (staff/admin), and hotels/rooms (admin)
- Required SQL Views displayed in UI
- Triggers for overlap prevention, room status synchronization, and archiving
- Indexes for common filter/query paths

## Notes

- Archive records are stored without hard foreign keys to mutable entities so they remain available even if rooms/customers are deleted later.
- The UI is intentionally form-driven to match project rubric requirements for non-SQL users.
