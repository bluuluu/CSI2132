const { Pool } = require('pg');
require('dotenv').config();

function isTruthy(value) {
  return ['1', 'true', 'yes', 'on'].includes(String(value || '').toLowerCase());
}

const dbUser =
  process.env.DB_USER ||
  process.env.PGUSER ||
  process.env.USER ||
  'postgres';

const connectionString = process.env.DATABASE_URL;
const enableSsl = isTruthy(process.env.DB_SSL);

const poolConfig = connectionString
  ? { connectionString }
  : {
      host: process.env.DB_HOST || process.env.PGHOST || 'localhost',
      port: Number(process.env.DB_PORT || process.env.PGPORT || 5432),
      database: process.env.DB_NAME || process.env.PGDATABASE || 'ehotels',
      user: dbUser,
      password: process.env.DB_PASSWORD || process.env.PGPASSWORD || ''
    };

if (enableSsl) {
  poolConfig.ssl = { rejectUnauthorized: false };
}

const pool = new Pool(poolConfig);

module.exports = {
  pool,
  query: (text, params) => pool.query(text, params),
  getClient: () => pool.connect()
};
