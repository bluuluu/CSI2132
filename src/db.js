const { Pool } = require('pg');
require('dotenv').config();

const dbUser =
  process.env.DB_USER ||
  process.env.PGUSER ||
  process.env.USER ||
  'postgres';

const pool = new Pool({
  host: process.env.DB_HOST || process.env.PGHOST || 'localhost',
  port: Number(process.env.DB_PORT || process.env.PGPORT || 5432),
  database: process.env.DB_NAME || process.env.PGDATABASE || 'ehotels',
  user: dbUser,
  password: process.env.DB_PASSWORD || process.env.PGPASSWORD || ''
});

module.exports = {
  query: (text, params) => pool.query(text, params),
  getClient: () => pool.connect()
};
