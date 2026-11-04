const express = require('express');
const router = express.Router();
const pool = require('../db/pool');
const { requireRole } = require('../middleware/auth');

// List
router.get('/', async (req, res) => {
  const sql = 'SELECT supplier_id, supplier_name AS name, phone, email, city FROM suppliers ORDER BY supplier_id';
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create - admin only
router.post('/', requireRole('admin'), async (req, res) => {
  const { name, phone, email, city } = req.body || {};
  const sql = 'INSERT INTO suppliers (supplier_name, phone, email, city) VALUES (?, ?, ?, ?)';
  const params = [name, phone || null, email || null, city || 'Nashik'];
  try {
    const [result] = await pool.query(sql, params);
    res.json({ ok: true, supplier_id: result.insertId, query: sql, params });
  } catch (err) {
    res.status(400).json({ error: err.message, query: sql, params });
  }
});

// Update - admin only
router.put('/:id', requireRole('admin'), async (req, res) => {
  const { name, phone, email, city } = req.body || {};
  const sql = 'UPDATE suppliers SET supplier_name=?, phone=?, email=?, city=? WHERE supplier_id=?';
  const params = [name, phone || null, email || null, city || 'Nashik', req.params.id];
  try {
    await pool.query(sql, params);
    res.json({ ok: true, query: sql, params });
  } catch (err) {
    res.status(400).json({ error: err.message, query: sql, params });
  }
});

// Delete - admin only
router.delete('/:id', requireRole('admin'), async (req, res) => {
  const sql = 'DELETE FROM suppliers WHERE supplier_id=?';
  const params = [req.params.id];
  try {
    await pool.query(sql, params);
    res.json({ ok: true, query: sql, params });
  } catch (err) {
    if (err.errno === 1451) {
      return res.status(400).json({ error: 'Cannot delete: this supplier still has products', query: sql, params });
    }
    res.status(400).json({ error: err.message, query: sql, params });
  }
});

module.exports = router;
