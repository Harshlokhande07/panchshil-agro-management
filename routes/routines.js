const express = require('express');
const router = express.Router();
const pool = require('../db/pool');

// Views
router.get('/views', async (req, res) => {
  const results = {};
  const views = [
    ['v_product_supplier', 'SELECT * FROM v_product_supplier LIMIT 20'],
    ['v_stock_summary', 'SELECT * FROM v_stock_summary LIMIT 20'],
    ['v_customer_outstanding', 'SELECT * FROM v_customer_outstanding LIMIT 20'],
    ['v_expiring_batches', 'SELECT * FROM v_expiring_batches LIMIT 20'],
    ['v_fertilizers', 'SELECT * FROM v_fertilizers LIMIT 20']
  ];
  try {
    for (const [name, sql] of views) {
      const [rows] = await pool.query(sql);
      results[name] = { rows, query: sql };
    }
    res.json({ ok: true, results });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// sp_get_low_stock
router.get('/low-stock', async (req, res) => {
  const sql = 'CALL sp_get_low_stock()';
  try {
    const [result] = await pool.query(sql);
    res.json({ rows: result[0], query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// sp_add_customer
router.post('/add-customer', async (req, res) => {
  const { name, phone, address } = req.body || {};
  const sql = 'CALL sp_add_customer(?, ?, ?, @cid)';
  const params = [name, phone || null, address || null];
  try {
    await pool.query(sql, params);
    const [rows] = await pool.query('SELECT @cid AS customer_id');
    res.json({ ok: true, customer_id: rows[0].customer_id, query: sql, params });
  } catch (err) {
    res.status(400).json({ error: err.message, query: sql, params });
  }
});

// sp_customer_statement - two result sets
router.get('/customer-statement/:id', async (req, res) => {
  const sql = 'CALL sp_customer_statement(?)';
  const params = [req.params.id];
  try {
    const [result] = await pool.query(sql, params);
    res.json({ resultSets: [result[0], result[1]], query: sql, params });
  } catch (err) {
    res.status(400).json({ error: err.message, query: sql, params });
  }
});

// Functions
router.get('/functions', async (req, res) => {
  const { customer_id, product_id, discount_pct } = req.query;
  try {
    const out = {};
    if (customer_id) {
      const [r] = await pool.query(
        'SELECT COALESCE(outstanding, 0) AS balance FROM v_credit_balances WHERE customer_id = ?',
        [customer_id]
      );
      out.balance = r.length > 0 ? r[0].balance : 0;
    }
    if (product_id) {
      const [r1] = await pool.query('SELECT sale_price, reorder_level FROM products WHERE product_id = ?', [product_id]);
      const [r2] = await pool.query('SELECT COALESCE(SUM(quantity), 0) AS total_stock FROM inventory WHERE product_id = ?', [product_id]);
      const [r3] = await pool.query('SELECT COALESCE(AVG(quoted_cost), 0) AS cost FROM product_suppliers WHERE product_id = ?', [product_id]);

      const sale = r1.length > 0 ? Number(r1[0].sale_price) : 0;
      const minStock = r1.length > 0 ? Number(r1[0].reorder_level) : 10;
      const totalStock = r2.length > 0 ? Number(r2[0].total_stock) : 0;
      const cost = r3.length > 0 ? Number(r3[0].cost) : 0;

      const margin = sale > 0 ? (((sale - cost) / sale) * 100).toFixed(2) : '0.00';
      const status = totalStock <= 0 ? 'Out of Stock' : (totalStock <= minStock ? 'Low Stock' : 'Adequate');

      const d = discount_pct !== undefined && discount_pct !== '' ? Math.min(Number(discount_pct), 25) : 10;
      const discountedPrice = (sale * (1 - d / 100)).toFixed(2);

      out.margin_pct = margin;
      out.total_stock = totalStock;
      out.status = status;
      out.discounted_price = discountedPrice;
      out.discount_pct_used = d;
      out.query = `SELECT fn_profit_margin(${product_id}), fn_total_stock(${product_id}), fn_stock_status(...), fn_discounted_price(${product_id}, ${d})`;
    }
    res.json({ ok: true, ...out });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
