# CSI2132 Course Project - Deliverable 2 Report (Draft)

> This draft is based on your provided PDF structure and aligned to the current repository implementation.
> Update names/links/timestamps where needed before final submission.

## 1) Project Technologies

### 1a) DBMS and Programming Languages

**DBMS**
- PostgreSQL (local development via `psql`; pgAdmin optional)

**Programming Languages / Frameworks**
- SQL (PostgreSQL + PL/pgSQL for triggers/functions)
- JavaScript (Node.js)
- Express.js
- EJS
- HTML/CSS

## 2) Installation and Setup Guide

### 1b) Steps to install and run the application

1. Clone the repository:
```bash
git clone <YOUR_REPO_URL>
cd CSI2132
```

2. Install dependencies:
```bash
npm install
```

3. Ensure PostgreSQL is running.

4. Create database:
```bash
createdb ehotels
```

5. Apply schema and data:
```bash
psql -d ehotels -f sql/schema.sql
psql -d ehotels -f sql/seed.sql
```

6. (Optional) Run sample query file:
```bash
psql -d ehotels -f sql/queries.sql
```

7. Configure `.env` (copy from `.env.example`) and set DB credentials.

8. Start the web app:
```bash
npm run dev
```

9. Open:
- `http://localhost:3000`

## 3) DDL Statements and Database Definition

### 1c) List of DDL statements creating the database

All creation DDL is in:
- `sql/schema.sql`

Main tables created:
- `hotel_chain`
- `hotel`
- `person`
- `customer`
- `employee`
- `auth_account`
- `room`
- `booking`
- `renting`
- `archive`
- `payment`

Also included in `schema.sql`:
- PK/FK constraints
- CHECK constraints
- Trigger functions and triggers
- Indexes
- SQL views

## 4) SQL Functionality Implemented

### 2b) Database population

Population script:
- `sql/seed.sql`

Coverage:
- 5 hotel chains
- 40 hotels total (8 per chain)
- 5 rooms per hotel minimum
- Seeded customers, employees/managers, bookings, rentings, and payments

### 2c) Database queries

Implemented in:
- `sql/queries.sql`

At least 4 queries are included, including:
- Aggregation query (active bookings per chain)
- Nested query (customers spending above average)
- Multi-criteria room availability query
- Employee performance summary query

### 2d) Database modifications (queries + triggers)

Implemented in:
- `sql/schema.sql`

Key trigger/function logic includes:
- Prevent overlapping bookings/rentings (`fn_validate_room_availability`)
- Synchronize room status after booking/renting changes (`fn_sync_room_status` and post-change triggers)
- Archive completed/cancelled booking and renting records (`fn_archive_booking`, `fn_archive_renting`)

### 2e) Database indexes

Implemented indexes include:
- `idx_room_capacity_price_status`
- `idx_hotel_filtering`
- `idx_booking_room_dates`
- `idx_renting_room_dates`
- `idx_auth_account_role_active`

Justification summary:
- Speeds common filter/search operations
- Speeds date-overlap and history lookups
- Speeds login/account role filtering

### 2f) Database views

Two required SQL views are implemented:
1. `v_available_rooms_per_area`
   - number of available rooms per area
2. `v_hotel_capacity_aggregate`
   - aggregated room capacity per hotel

Views are defined in:
- `sql/schema.sql`

Views are displayed in the UI (admin):
- `/views`

## 5) Web Application Functionality (2g)

Implemented functionality includes:
- Public room browsing and availability calendar
- Multi-criteria room filtering (dates, capacity, area, chain, category, total rooms, max price)
- Role-based authentication (admin, employee/manager, customer)
- Booking creation and validation
- Check-in flow: booking transformed to renting
- Direct renting flow by staff
- Payment insertion for active rentings
- CRUD operations for customers, employees, hotels, and rooms (role-restricted)
- Archive history for completed/cancelled bookings and rentings
- Required SQL views presented through UI

## 6) Files Included in Submission ZIP

1. Report (`.pdf` generated from this `.md` draft)
2. SQL code:
   - `sql/schema.sql`
   - `sql/seed.sql`
   - `sql/queries.sql`
3. Application code:
   - `src/`
   - `views/`
   - `public/`
   - `package.json`
4. Video link + timestamps
5. Filled Table 1 PDF

## 7) Video Section (Fill Before Submission)

### Project video link
- `<PASTE_VIDEO_LINK_HERE>`

### Requirement timestamp table
| Requirement | Timestamp |
|---|---|
| Intro + stack | `<mm:ss>` |
| Schema overview | `<mm:ss>` |
| Data population | `<mm:ss>` |
| Queries demo | `<mm:ss>` |
| Trigger demo | `<mm:ss>` |
| Index/view demo | `<mm:ss>` |
| UI role demo | `<mm:ss>` |
| Booking to renting flow | `<mm:ss>` |
| Archive/history demo | `<mm:ss>` |

## 8) Notes for Final Report Editing

- Replace placeholders (`<...>`) with your final values.
- If your professor requires exact rubric wording, copy section headings exactly from the deliverable PDF.
- Keep screenshots concise and match each screenshot to one requirement.
