// ---------------------------------------------------------------------------
// MySQL connection pool
// Every route gets a connection from this pool. mysql2 handles escaping of
// every "?" placeholder, so user input never becomes part of the SQL text.
// ---------------------------------------------------------------------------
require('dotenv').config();
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'PanchshilAgro',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  // Return DECIMAL columns as JS numbers and DATE columns as plain strings.
  // This keeps the JSON sent to the browser easy to display.
  decimalNumbers: true,
  dateStrings: true
});

module.exports = pool;
