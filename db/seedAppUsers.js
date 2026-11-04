// ---------------------------------------------------------------------------
// Creates the app_user table (if needed) and inserts one login for each role.
// Run with:  npm run seed:users
// Re-running is safe: existing usernames get a fresh password hash.
// ---------------------------------------------------------------------------
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');

const USERS = [
  { username: 'admin', password: 'Admin@123', role: 'admin' },
  { username: 'staff', password: 'Staff@123', role: 'staff' },
  { username: 'accountant', password: 'Account@123', role: 'accountant' }
];

async function main() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'PanchshilAgro',
    multipleStatements: true
  });

  // 1. Make sure the app_user table exists.
  const ddl = fs.readFileSync(path.join(__dirname, 'app_user.sql'), 'utf8');
  await connection.query(ddl);

  // 2. Insert / refresh the three demo logins with bcrypt hashes.
  for (const user of USERS) {
    const hash = await bcrypt.hash(user.password, 10);
    await connection.execute(
      `INSERT INTO app_user (username, password_hash, role)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash), role = VALUES(role)`,
      [user.username, hash, user.role]
    );
    console.log(`  [OK] ${user.role.padEnd(10)} username: ${user.username.padEnd(10)} password: ${user.password}`);
  }

  await connection.end();
  console.log('\napp_user seeded successfully.');
}

main().catch((err) => {
  console.error('\nCould not seed app_user:', err.message);
  console.error('Check DB_HOST / DB_USER / DB_PASSWORD in your .env file and make sure');
  console.error('PanchshilAgro_MySQL.sql has already been run in MySQL Workbench.');
  process.exit(1);
});
