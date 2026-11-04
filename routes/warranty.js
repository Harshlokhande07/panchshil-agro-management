const express = require('express');
const router = express.Router();
const pool = require('../db/pool');
const { requireRole } = require('../middleware/auth');

// List
router.get('/', async (req, res) => {
  const sql = `SELECT wc.claim_id AS warranty_id,
                      wc.claim_id,
                      wc.order_id,
                      wc.product_id,
                      p.product_name,
                      so.customer_id,
                      CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
                      COALESCE(s.supplier_name, 'Agro Supplies Ltd') AS supplier_name,
                      CONCAT('Order #', wc.order_id) AS batch_no,
                      DATE(wc.claimed_on) AS start_date,
                      DATE(wc.resolved_on) AS end_date,
                      wc.issue_description AS return_reason,
                      CASE wc.status
                        WHEN 'OPEN' THEN 'Sent'
                        WHEN 'APPROVED' THEN 'Sent'
                        WHEN 'RESOLVED' THEN 'Replaced'
                        WHEN 'REJECTED' THEN 'Rejected'
                        ELSE 'Sent'
                      END AS supplier_status,
                      wc.status,
                      wc.resolution
               FROM warranty_claims wc
               JOIN products p ON p.product_id = wc.product_id
               JOIN sales_orders so ON so.order_id = wc.order_id
               JOIN customers c ON c.customer_id = so.customer_id
               LEFT JOIN product_suppliers ps ON ps.product_id = p.product_id
               LEFT JOIN suppliers s ON s.supplier_id = ps.supplier_id
               ORDER BY wc.claim_id DESC`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create
router.post('/', requireRole('admin', 'staff'), async (req, res) => {
  const { product_id, customer_id, return_reason } = req.body || {};
  const productId = Number(product_id);
  const customerId = Number(customer_id);
  if (!Number.isInteger(productId) || productId <= 0 ||
      !Number.isInteger(customerId) || customerId <= 0 ||
      typeof return_reason !== 'string' || !return_reason.trim()) {
    return res.status(400).json({ error: 'Product, customer and defect description are required' });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [items] = await connection.query(
      `SELECT i.order_id, i.product_id 
       FROM sales_order_items i 
       JOIN sales_orders o ON o.order_id = i.order_id 
       WHERE o.customer_id = ? AND i.product_id = ?
         AND o.status IN ('CONFIRMED', 'SHIPPED', 'DELIVERED')
       LIMIT 1`,
      [customerId, productId]
    );
    if (items.length === 0) {
      await connection.rollback();
      return res.status(400).json({ error: 'No completed order for this product and customer was found' });
    }

    const [result] = await connection.query(
      `INSERT INTO warranty_claims (order_id, product_id, claimed_on, issue_description, status)
       VALUES (?, ?, NOW(), ?, 'OPEN')`,
      [items[0].order_id, productId, return_reason.trim()]
    );

    await connection.commit();
    res.json({ ok: true, warranty_id: result.insertId });
  } catch (err) {
    if (connection) await connection.rollback();
    res.status(400).json({ error: err.message });
  } finally {
    if (connection) connection.release();
  }
});

// Update status
router.put('/:id/status', requireRole('admin', 'staff'), async (req, res) => {
  const { supplier_status } = req.body || {};
  if (!['Sent', 'Replaced', 'Rejected'].includes(supplier_status)) {
    return res.status(400).json({ error: 'Status must be Sent, Replaced or Rejected' });
  }
  const claimStatus = supplier_status === 'Replaced' ? 'RESOLVED' : (supplier_status === 'Rejected' ? 'REJECTED' : 'APPROVED');
  const sql = 'UPDATE warranty_claims SET status=?, resolution=? WHERE claim_id=?';
  const params = [claimStatus, supplier_status, req.params.id];
  try {
    const [result] = await pool.query(sql, params);
    if (result.affectedRows === 0) return res.status(404).json({ error: 'Warranty claim not found' });
    res.json({ ok: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Delete - admin only
router.delete('/:id', requireRole('admin'), async (req, res) => {
  const sql = 'DELETE FROM warranty_claims WHERE claim_id=?';
  try {
    const [result] = await pool.query(sql, [req.params.id]);
    if (result.affectedRows === 0) return res.status(404).json({ error: 'Warranty claim not found' });
    res.json({ ok: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// By supplier status
router.get('/by-status', async (req, res) => {
  const sql = `SELECT 
                 CASE status
                   WHEN 'OPEN' THEN 'Sent'
                   WHEN 'APPROVED' THEN 'Sent'
                   WHEN 'RESOLVED' THEN 'Replaced'
                   WHEN 'REJECTED' THEN 'Rejected'
                   ELSE 'Sent'
                 END AS supplier_status,
                 COUNT(*) AS count
               FROM warranty_claims 
               GROUP BY supplier_status 
               ORDER BY supplier_status`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
