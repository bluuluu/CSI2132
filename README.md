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

## Setup

1. Install dependencies:
```bash
npm install
```

2. Configure environment:
```bash
cp .env.example .env
```
Then edit `.env` with your PostgreSQL credentials.

3. Create database (example):
```sql
CREATE DATABASE ehotels;
```

4. Run SQL scripts in order:
```bash
psql -U postgres -d ehotels -f sql/schema.sql
psql -U postgres -d ehotels -f sql/seed.sql
psql -U postgres -d ehotels -f sql/queries.sql
```

5. Start application:
```bash
npm run dev
```
Open: `http://localhost:3000`

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
