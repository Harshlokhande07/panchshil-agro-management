const express = require('express');
const router = express.Router();
const pool = require('../db/pool');

// Show grants for the three MySQL users
router.get('/grants', async (req, res) => {
  const users = ['shop_owner', 'shop_staff', 'shop_accountant'];
  const results = {};
  try {
    for (const u of users) {
      try {
        const [rows] = await pool.query(`SHOW GRANTS FOR '${u}'@'localhost'`);
        results[u] = rows.map(r => Object.values(r)[0]);
      } catch (e) {
        results[u] = [e.message];
      }
    }
    res.json({ ok: true, results });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Revoke demo
router.post('/revoke-staff-insert', async (req, res) => {
  try {
    await pool.query("REVOKE INSERT ON panchshilagro.payments FROM 'shop_staff'@'localhost'");
    const [rows] = await pool.query("SHOW GRANTS FOR 'shop_staff'@'localhost'");
    res.json({ ok: true, grants: rows.map(r => Object.values(r)[0]) });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Grant demo
router.post('/grant-staff-insert', async (req, res) => {
  try {
    await pool.query("GRANT INSERT ON panchshilagro.payments TO 'shop_staff'@'localhost'");
    const [rows] = await pool.query("SHOW GRANTS FOR 'shop_staff'@'localhost'");
    res.json({ ok: true, grants: rows.map(r => Object.values(r)[0]) });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
