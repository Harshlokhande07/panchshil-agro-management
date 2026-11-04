const express = require('express');
const router = express.Router();
const pool = require('../db/pool');

// GET /api/dashboard/summary
router.get('/summary', async (req, res) => {
  try {
    const sql1 = `SELECT
      (SELECT COUNT(*) FROM products) AS total_products,
      (SELECT COUNT(*) FROM customers) AS total_customers,
      (SELECT COALESCE(SUM(amount),0) FROM payments WHERE status='SUCCESS') AS total_payments_received,
      (SELECT COALESCE(SUM(outstanding),0) FROM v_credit_balances) AS total_credit_outstanding,
      (SELECT COALESCE(AVG(sale_price),0) FROM products) AS avg_selling_price`;
    const [summary] = await pool.query(sql1);
    res.json({ summary: summary[0], query: sql1, params: [] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

// products per category
router.get('/by-category', async (req, res) => {
  const sql = `SELECT c.category_name AS category, COUNT(p.product_id) AS count,
               ROUND(AVG(p.sale_price),2) AS avg_selling,
               ROUND(AVG(p.sale_price - COALESCE(ps.quoted_cost, p.sale_price * 0.7)),2) AS avg_profit
               FROM categories c
               LEFT JOIN products p ON p.category_id = c.category_id
               LEFT JOIN (SELECT product_id, AVG(quoted_cost) AS quoted_cost FROM product_suppliers GROUP BY product_id) ps ON ps.product_id = p.product_id
               GROUP BY c.category_id, c.category_name
               ORDER BY c.category_name`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// payments per mode
router.get('/by-mode', async (req, res) => {
  const sql = `SELECT method AS mode, COUNT(*) AS count, ROUND(COALESCE(SUM(amount),0),2) AS total
               FROM payments GROUP BY method ORDER BY method`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// products supplied per supplier
router.get('/by-supplier', async (req, res) => {
  const sql = `SELECT s.supplier_id, s.supplier_name AS supplier, COUNT(DISTINCT ps.product_id) AS product_count,
               ROUND(COALESCE(AVG(p.sale_price),0),2) AS avg_price
               FROM suppliers s
               LEFT JOIN product_suppliers ps ON ps.supplier_id = s.supplier_id
               LEFT JOIN products p ON p.product_id = ps.product_id
               GROUP BY s.supplier_id, s.supplier_name
               ORDER BY product_count DESC, supplier`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// credit by status
router.get('/credit-status', async (req, res) => {
  const sql = `SELECT 
                 CASE 
                   WHEN outstanding = 0 THEN 'Paid'
                   WHEN outstanding > 0 AND outstanding < credit_limit THEN 'Partial'
                   WHEN outstanding >= credit_limit THEN 'Overdue'
                   ELSE 'Pending'
                 END AS status,
                 COUNT(*) AS count,
                 ROUND(COALESCE(SUM(outstanding),0),2) AS outstanding
               FROM v_credit_balances
               GROUP BY status
               ORDER BY status`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// outstanding per customer HAVING > 0
router.get('/outstanding-customers', async (req, res) => {
  const sql = `SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS name, c.phone,
               ROUND(b.outstanding,2) AS outstanding
               FROM customers c
               JOIN v_credit_balances b ON b.customer_id = c.customer_id
               WHERE b.outstanding > 0
               ORDER BY outstanding DESC`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// monthly payments
router.get('/monthly-payments', async (req, res) => {
  const sql = `SELECT DATE_FORMAT(paid_at, '%Y-%m') AS ym,
               COUNT(*) AS count, ROUND(COALESCE(SUM(amount),0),2) AS total
               FROM payments
               WHERE status = 'SUCCESS'
               GROUP BY ym
               ORDER BY ym`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
