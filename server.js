// ---------------------------------------------------------------------------
// Panchshil Agro Agencies - web server
// Node.js + Express, mysql2 connection pool, express-session
// ---------------------------------------------------------------------------
require('dotenv').config();

const express = require('express');
const session = require('express-session');
const path = require('path');
const bcrypt = require('bcryptjs');
const pool = require('./db/pool');
const ensureAppSchema = require('./db/ensureAppSchema');
const { requireLogin, requireRole } = require('./middleware/auth');

const app = express();

// Body parsers
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Session
app.use(session({
  secret: process.env.SESSION_SECRET || 'panchshil-dev-secret',
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    maxAge: 1000 * 60 * 60 * 8 // 8 hours
  }
}));

// Static files (frontend)
app.use(express.static(path.join(__dirname, 'public')));

// Helper to attach user to res.locals for simple templates if needed
app.use((req, res, next) => {
  res.locals.user = req.session && req.session.user ? req.session.user : null;
  next();
});

// ---------------------------------------------------------------------------
// Auth routes
// ---------------------------------------------------------------------------
app.get('/api/me', (req, res) => {
  if (req.session && req.session.user) {
    return res.json({ loggedIn: true, user: req.session.user });
  }
  return res.json({ loggedIn: false });
});

app.post('/api/login', async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required' });
  }
  try {
    const [rows] = await pool.query(
      'SELECT user_id, username, password_hash, role FROM app_user WHERE username = ?',
      [username]
    );
    if (rows.length === 0) {
      return res.status(401).json({ error: 'Invalid username or password' });
    }
    const user = rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({ error: 'Invalid username or password' });
    }
    // Save minimal user info in session (do NOT store hash)
    req.session.user = {
      user_id: user.user_id,
      username: user.username,
      role: user.role
    };
    return res.json({ ok: true, role: user.role });
  } catch (err) {
    console.error('Login error:', err);
    return res.status(500).json({ error: 'Login failed' });
  }
});

app.post('/api/logout', (req, res) => {
  req.session.destroy(() => {
    res.clearCookie('connect.sid');
    return res.json({ ok: true });
  });
});

// ---------------------------------------------------------------------------
// Mount feature routes
// ---------------------------------------------------------------------------
app.use('/api/dashboard', requireLogin, require('./routes/dashboard'));
app.use('/api/suppliers', requireLogin, require('./routes/suppliers'));
app.use('/api/customers', requireLogin, require('./routes/customers'));
app.use('/api/products', requireLogin, require('./routes/products'));
app.use('/api/inventory', requireLogin, require('./routes/inventory'));
app.use('/api/credit', requireLogin, require('./routes/credit'));
app.use('/api/payments', requireLogin, require('./routes/payments'));
app.use('/api/warranty', requireLogin, require('./routes/warranty'));
app.use('/api/routines', requireLogin, require('./routes/routines'));
app.use('/api/privileges', requireLogin, requireRole('admin'), require('./routes/privileges'));
app.use('/api/sql', requireLogin, require('./routes/sql'));

// ---------------------------------------------------------------------------
// Fallbacks
// ---------------------------------------------------------------------------
// If someone visits root directly, send to app
app.get('/', (req, res) => {
  if (req.session && req.session.user) {
    return res.sendFile(path.join(__dirname, 'public', 'app.html'));
  }
  return res.redirect('/login.html');
});

app.get('/app', requireLogin, (req, res) => {
  return res.sendFile(path.join(__dirname, 'public', 'app.html'));
});

async function ensureAppUserTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS app_user (
      user_id INT AUTO_INCREMENT PRIMARY KEY,
      username VARCHAR(50) NOT NULL UNIQUE,
      password_hash VARCHAR(255) NOT NULL,
      role ENUM('admin','staff','accountant') NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB
  `);

  const [existing] = await pool.query('SELECT COUNT(*) AS c FROM app_user');
  if (existing[0].c === 0) {
    const demoUsers = [
      { u: 'admin', p: 'Admin@123', r: 'admin' },
      { u: 'staff', p: 'Staff@123', r: 'staff' },
      { u: 'accountant', p: 'Account@123', r: 'accountant' }
    ];
    for (const u of demoUsers) {
      const hash = await bcrypt.hash(u.p, 10);
      await pool.query('INSERT IGNORE INTO app_user (username, password_hash, role) VALUES (?, ?, ?)', [u.u, hash, u.r]);
    }
    console.log('Demo app_users initialized.');
  }
}

const PORT = process.env.PORT || 3000;
Promise.resolve()
  .then(() => pool.query('SELECT 1'))
  .then(() => ensureAppSchema())
  .then(() => ensureAppUserTable())
  .then(() => {
    app.listen(PORT, () => {
      console.log(`Panchshil Agro app running at http://localhost:${PORT}`);
    });
  })
  .catch(async err => {
    console.error('Application startup failed:', err.message);
    try {
      await pool.end();
    } catch (closeError) {
      console.error('Failed to close database pool:', closeError.message);
    }
    process.exitCode = 1;
  });
