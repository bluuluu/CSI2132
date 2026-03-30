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

The app now uses separate login pages per role:

- `/login/customer`
- `/login/employee`
- `/login/manager`
- `/login/admin`

You can also start from `/login` and choose a role card.

### Login Info

- Admin: `admin` / `admin123`
- Manager accounts (seeded): `manager<ID>` / `manager<ID>123`  
  Example: `manager1` / `manager1123`
- Employee accounts (seeded): `employee<ID>` / `employee<ID>123`  
  Example: `employee2` / `employee2123`
- Customer accounts (seeded): `customer<ID>` / `customer<ID>123`  
  Example: `customer1` / `customer1123`

### Access Differences

- Public (not signed in):
  - Can browse available rooms/hotels in `/search`
  - Cannot create bookings, rentings, payments, or management actions
- Customer:
  - Can search/filter rooms and create bookings for their own customer account
  - Can open `/settings/customer` to update profile/login info
  - Can disable their own account (reactivation requires an employee/admin)
  - Cannot access employee, manager, or admin management pages
- Employee:
  - Can access employee panel (booking -> renting, direct renting, payments)
  - Can reactivate disabled customer accounts
  - Can book for valid customer IDs from `/search`
  - Cannot manage staff accounts, SQL views, or admin CRUD pages
- Manager:
  - Includes all employee capabilities
  - Can create/update/enable/disable employee accounts (no employee deletion)
  - Cannot create or disable manager accounts
  - Can access SQL views
- Admin:
  - Full access to all workflows
  - Can create customers, employees, and managers
  - Can enable/disable both employee and manager accounts
  - Can manage hotels/rooms/customers and SQL views



## What is Implemented

- Room search with multi-criteria filters:
  - dates, room capacity, area, hotel chain, category, total rooms, and price
- Public room/hotel browsing with authenticated booking flow
- Role-based login with separated customer/employee/manager/admin portals and permission controls
- DB-backed login accounts (`auth_account`) for admin, manager, employee, and customer
- Employee panel:
  - booking -> renting transformation
  - direct renting creation
  - payment insertion
- customer account reactivation by employee/manager/admin
- Staff account management with enable/disable workflows (no destructive staff deletion)
- Customer self-settings (profile update + self-disable)
- Admin CRUD pages for customers, hotels, and rooms
- Required SQL Views displayed in UI
- Triggers for overlap prevention, room status synchronization, and archiving
- Indexes for common filter/query paths

## Notes

- Archive records are stored without hard foreign keys to mutable entities so they remain available even if rooms/customers are deleted later.
- The UI is intentionally form-driven to match project rubric requirements for non-SQL users.
