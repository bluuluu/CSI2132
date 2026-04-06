# CSI2132 eHotels - Installation and Database Replication Guide

Date: April 5, 2026

This guide explains exactly how a corrector can:
- install prerequisites,
- run the web app,
- connect to PostgreSQL,
- and load either the baseline project database or an exact snapshot database.

## 1) Prerequisites

Install these first:

- Node.js 18+ (includes `npm`)
- PostgreSQL 15+ (includes `psql`)
- Git
- Optional database GUI: DBeaver or pgAdmin

Check versions:

```bash
node -v
npm -v
psql --version
```

## 2) Get the Project

```bash
git clone <REPO_URL>
cd CSI2132
```

## 3) Install Node Dependencies

```bash
npm install
```

## 4) Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with your local PostgreSQL role:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=ehotels
DB_USER=<your_postgres_role>
DB_PASSWORD=<your_postgres_password_or_blank>
PORT=3000
```

## 5) Start PostgreSQL

Example (macOS + Homebrew):

```bash
brew services start postgresql@15
pg_isready -h localhost -p 5432
```

`accepting connections` means PostgreSQL is ready.

## 6) Create and Load Database (Baseline - Recommended)

This is the recommended grading setup:

```bash
createdb -U <your_postgres_role> ehotels
psql -U <your_postgres_role> -d ehotels -f sql/schema.sql
psql -U <your_postgres_role> -d ehotels -f sql/seed.sql
psql -U <your_postgres_role> -d ehotels -f sql/queries.sql
```

No CSV import is required for this project setup. Data population is handled by `sql/seed.sql`.

If your local role is already the default role:

```bash
createdb ehotels
psql -d ehotels -f sql/schema.sql
psql -d ehotels -f sql/seed.sql
psql -d ehotels -f sql/queries.sql
```

## 7) Run the Web App

```bash
npm run dev
```

Open:

`http://localhost:3000`

## 8) Login Accounts (Seeded)

- Admin: `admin` / `admin123`
- Staff logins:
  - Managers: `manager<ID>` / `manager<ID>123`
  - Employees: `employee<ID>` / `employee<ID>123`
- Customer login is SIN + password:
  - Example SIN: `200000001`
  - Default format: `customer<ID>123`

## 9) How to Connect and Inspect DB

Open SQL shell:

```bash
psql -U <your_postgres_role> -d ehotels
```

Useful checks:

```sql
\dt
SELECT COUNT(*) FROM hotel_chain;
SELECT COUNT(*) FROM hotel;
SELECT COUNT(*) FROM room;
SELECT COUNT(*) FROM customer;
SELECT COUNT(*) FROM employee;
```

## 10) Exact Same Database As Presenter (Snapshot Mode)

If the presenter provides `sql/evaluator_snapshot.sql`, load that file for an exact match:

```bash
dropdb --if-exists -U <your_postgres_role> ehotels
createdb -U <your_postgres_role> ehotels
psql -U <your_postgres_role> -d ehotels -f sql/evaluator_snapshot.sql
```

To create this exact snapshot on presenter machine:

```bash
pg_dump -d ehotels --clean --if-exists --no-owner --no-privileges > sql/evaluator_snapshot.sql
```

Note:
- `sql/current_database_dump.sql` is an older legacy dump and is not recommended for final grading replication.

## 11) Quick Troubleshooting

- Error: `database "<user>" does not exist`
  - You likely connected without `-d ehotels`. Use:
  - `psql -U <role> -d ehotels`

- Error: role/password authentication failed
  - Update `.env` and command-line `-U`/password to match your local PostgreSQL setup.

- Port 3000 already in use
  - Stop old process or change `PORT` in `.env`.

- App starts but pages fail
  - Re-run schema and seed scripts.
  - Confirm PostgreSQL is running and `.env` DB settings are correct.
