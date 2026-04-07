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

## Video Presentation
- https://youtu.be/xcvwPfdYG-k


## Run Locally

Follow these steps in order from the project root.

### Prerequisites (install before starting)

- Node.js 18+ (includes `npm`)
- PostgreSQL 15+ (server + `psql` CLI)
- Git (for cloning)
- Optional GUI DB client: DBeaver or pgAdmin

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

No CSV import step is required. Seed data is inserted by `sql/seed.sql`.

If your local PostgreSQL role is not the default one:

```bash
createdb -U <db_user> ehotels
psql -U <db_user> -d ehotels -f sql/schema.sql
psql -U <db_user> -d ehotels -f sql/seed.sql
psql -U <db_user> -d ehotels -f sql/queries.sql
```

### 5) Run the web app

```bash
npm run dev
```

Open:

`http://localhost:3000`

Keep this terminal running while using the app.

## Reproducing The Same Database State

You have two options:

- Option A (recommended for graders): use `sql/schema.sql` + `sql/seed.sql` (+ optional `sql/queries.sql` demos).  
  This reproduces the official deliverable baseline consistently.
- Option B (exact personal snapshot): export your current local DB and include the dump in your submission zip.

### Option B commands (exact snapshot from your machine)

From your machine (after your latest edits/data):

```bash
pg_dump -d ehotels --clean --if-exists --no-owner --no-privileges > sql/evaluator_snapshot.sql
```

Then the evaluator can load that exact state:

```bash
createdb ehotels
psql -d ehotels -f sql/evaluator_snapshot.sql
```

Note: include `sql/evaluator_snapshot.sql` only if you want graders to load your exact current local database state.

## Role-Based Login

The app uses role-based login pages:

- `/login/customer`
- `/login/employee`
- `/login/admin`

You can also start from `/login` and choose a role card.

### Login Info

- Admin: `admin` / `admin123`
- Customer login uses SIN + password:
  - Example SIN: `200000001`
  - Default seeded password format: `customer<ID>123`
  - Example for `customer_id=1`: `customer1123`
- Manager accounts (seeded): `manager<ID>` / `manager<ID>123`  
  Example: `manager1` / `manager1123`  
  Use the staff login page: `/login/employee`
- Employee accounts (seeded): `employee<ID>` / `employee<ID>123`  
  Example: `employee2` / `employee2123`

### Access Differences

- Public (not signed in):
  - Can browse rooms and availability status from `/search`
  - Can open customer sign-up from `/signup/customer`
  - Cannot create bookings/rentings or access management pages
- Customer:
  - Can sign in using SIN + password
  - Can browse rooms and create bookings for their own account
  - Can self-disable or self-delete only when no active renting/reserved booking exists
  - Cannot create rentings or manage DB records
- Employee:
  - Can register customers at the desk using SIN (9 digits)
  - Can create bookings and direct rentings for registered customers by entering customer SIN
  - Can only book/rent rooms at their own hotel; unassigned customers are attached to that hotel on first booking/renting
  - Booking start date can be today or any future date (Eastern)
  - Can run check-in and direct renting workflows
  - Can insert renting payments through the Employee Panel (cash/card)
  - Can enable/disable customer accounts for customers in the same hotel
  - Can delete customer records for customers in the same hotel (or unassigned customers)
  - Cannot manage staff accounts, SQL views, or hotel/room admin CRUD pages
- Manager:
  - Includes all employee capabilities
  - Can view employees assigned to the same hotel
  - Can create new employee accounts for the same hotel
  - Can enable/disable employee accounts for the same hotel
  - Can enable/disable customer accounts for the same hotel
  - Can delete customer records for customers in the same hotel (or unassigned customers)
  - Cannot access admin-only CRUD or SQL views
- Admin:
  - Full access to all workflows
  - Can create customers, employees, and managers
  - Can enable/disable employee, manager, and customer accounts
  - Can delete customer, employee, and manager records
  - Can view full account details (including SIN and login status) for employees, managers, and customers
  - Can manage hotels/rooms/customers and SQL views


\


