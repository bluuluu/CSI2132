const fs = require('fs/promises');
const path = require('path');
const db = require('./db');

function isTruthy(value) {
  return ['1', 'true', 'yes', 'on'].includes(String(value || '').toLowerCase());
}

async function runSqlFile(fileName) {
  const sqlPath = path.resolve(__dirname, '../sql', fileName);
  const sql = await fs.readFile(sqlPath, 'utf8');
  await db.query(sql);
}

async function initializeDatabaseIfNeeded() {
  if (!isTruthy(process.env.AUTO_INIT_DB)) {
    return;
  }

  const tableCheck = await db.query("SELECT to_regclass('public.hotel_chain') AS table_name");
  if (tableCheck.rows[0].table_name) {
    console.log('AUTO_INIT_DB enabled: schema already present, skipping init.');
    return;
  }

  console.log('AUTO_INIT_DB enabled: initializing schema and seed data...');
  await runSqlFile('schema.sql');
  await runSqlFile('seed.sql');
  console.log('Database initialization complete.');
}

module.exports = { initializeDatabaseIfNeeded };
