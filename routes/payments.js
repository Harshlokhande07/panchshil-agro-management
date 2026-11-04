const express = require('express');
const { randomBytes } = require('crypto');
const router = express.Router();
const pool = require('../db/pool');
const { requireRole } = require('../middleware/auth');

// List payments
router.get('/', async (req, res) => {
  const sql = `SELECT pmt.payment_id,
                      pmt.order_id,
                      pmt.reference_code,
                      pmt.amount,
                      pmt.method AS mode,
                      pmt.status,
                      DATE(pmt.paid_at) AS payment_date,
                      pmt.paid_at,
                      so.customer_id,
                      CONCAT(c.first_name, ' ', c.last_name) AS customer_name
               FROM payments pmt
               LEFT JOIN sales_orders so ON so.order_id = pmt.order_id
               LEFT JOIN customers c ON c.customer_id = so.customer_id
               ORDER BY pmt.paid_at DESC, pmt.payment_id DESC`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Record payment
router.post('/', requireRole('admin', 'staff'), async (req, res) => {
  const { customer_id, credit_id, amount, mode } = req.body || {};
  const customerId = Number(customer_id);
  const paymentAmount = Number(amount);
  const paymentMode = String(mode || 'CASH').toUpperCase();
  if (!Number.isInteger(customerId) || customerId <= 0 ||
      !Number.isFinite(paymentAmount) || paymentAmount <= 0 ||
      !['CASH', 'UPI', 'CARD', 'BANK'].includes(paymentMode)) {
    return res.status(400).json({ error: 'Customer, positive payment amount and valid payment method are required' });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [customers] = await connection.query(
      'SELECT customer_id FROM customers WHERE customer_id = ? AND is_active = TRUE',
      [customerId]
    );
    if (customers.length === 0) {
      await connection.rollback();
      return res.status(400).json({ error: 'Customer does not exist or is inactive' });
    }

    if (credit_id) {
      const [credits] = await connection.query(
        `SELECT t.credit_account_id, b.outstanding
         FROM credit_transactions t
         JOIN credit_accounts a ON a.credit_account_id = t.credit_account_id
         JOIN v_credit_balances b ON b.credit_account_id = a.credit_account_id
         WHERE t.credit_txn_id = ? AND t.txn_type = 'CHARGE'
           AND a.customer_id = ? AND a.is_active = TRUE`,
        [credit_id, customerId]
      );
      if (credits.length === 0) {
        await connection.rollback();
        return res.status(400).json({ error: 'Credit entry does not belong to this customer' });
      }
      if (paymentAmount > Number(credits[0].outstanding)) {
        await connection.rollback();
        return res.status(400).json({ error: 'Payment exceeds the customer credit balance' });
      }

      await connection.query(
        `INSERT INTO credit_transactions (credit_account_id, txn_type, amount, notes)
         VALUES (?, 'PAYMENT', ?, 'Credit settlement payment')`,
        [credits[0].credit_account_id, paymentAmount]
      );
    }

    const [orders] = await connection.query(
      `SELECT order_id FROM sales_orders
       WHERE customer_id = ? AND status IN ('CONFIRMED', 'SHIPPED', 'DELIVERED')
       ORDER BY order_id DESC LIMIT 1`,
      [customerId]
    );
    if (orders.length === 0) {
      await connection.rollback();
      return res.status(400).json({ error: 'A confirmed or completed sales order is required to record a payment' });
    }

    const orderId = orders[0].order_id;
    const ref = `PAY-${Date.now()}-${randomBytes(3).toString('hex')}`;
    const [resPmt] = await connection.query(
      `INSERT INTO payments (order_id, reference_code, amount, method, status, paid_at)
       VALUES (?, ?, ?, ?, 'SUCCESS', NOW())`,
      [orderId, ref, paymentAmount, paymentMode]
    );

    await connection.commit();
    res.json({ ok: true, payment_id: resPmt.insertId, reference_code: ref });
  } catch (err) {
    if (connection) await connection.rollback();
    res.status(400).json({ error: err.message });
  } finally {
    if (connection) connection.release();
  }
});

// Total paid per customer
router.get('/totals-per-customer', async (req, res) => {
  const sql = `SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS name,
                      ROUND(COALESCE(SUM(pmt.amount),0),2) AS total_paid,
                      COUNT(pmt.payment_id) AS num_payments
               FROM customers c
               LEFT JOIN sales_orders so ON so.customer_id = c.customer_id
               LEFT JOIN payments pmt ON pmt.order_id = so.order_id AND pmt.status = 'SUCCESS'
               GROUP BY c.customer_id, c.first_name, c.last_name
               ORDER BY total_paid DESC`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Outstanding view
router.get('/outstanding-view', async (req, res) => {
  const sql = `SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS name,
                      c.phone, b.credit_limit, b.outstanding
               FROM v_credit_balances b
               JOIN customers c ON c.customer_id = b.customer_id
               WHERE b.outstanding > 0
               ORDER BY b.outstanding DESC`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
