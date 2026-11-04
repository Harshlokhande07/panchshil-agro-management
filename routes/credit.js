const express = require('express');
const router = express.Router();
const pool = require('../db/pool');
const { requireRole } = require('../middleware/auth');

// List credits with balance
router.get('/', async (req, res) => {
  const sql = `SELECT MAX(CASE WHEN ct.txn_type = 'CHARGE' THEN ct.credit_txn_id END) AS credit_id,
                      ca.customer_id,
                      CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
                      SUM(CASE WHEN ct.txn_type = 'CHARGE' THEN ct.amount ELSE 0 END) AS total_due,
                      SUM(CASE WHEN ct.txn_type = 'PAYMENT' THEN ct.amount ELSE 0 END) AS amount_paid,
                      GREATEST(
                        SUM(CASE WHEN ct.txn_type = 'CHARGE' THEN ct.amount ELSE 0 END) -
                        SUM(CASE WHEN ct.txn_type = 'PAYMENT' THEN ct.amount ELSE 0 END),
                        0
                      ) AS balance,
                      MAX(CASE WHEN ct.txn_type = 'CHARGE' THEN ct.due_date END) AS due_date,
                      CASE 
                        WHEN SUM(CASE WHEN ct.txn_type = 'CHARGE' THEN ct.amount ELSE 0 END) <=
                             SUM(CASE WHEN ct.txn_type = 'PAYMENT' THEN ct.amount ELSE 0 END) THEN 'Paid'
                        WHEN MAX(CASE WHEN ct.txn_type = 'CHARGE'
                                           AND ct.due_date < CURDATE() THEN 1 ELSE 0 END) = 1 THEN 'Overdue'
                        WHEN SUM(CASE WHEN ct.txn_type = 'PAYMENT' THEN ct.amount ELSE 0 END) > 0 THEN 'Partial'
                        ELSE 'Pending'
                      END AS status,
                      ca.credit_account_id
               FROM credit_accounts ca
               JOIN credit_transactions ct ON ct.credit_account_id = ca.credit_account_id
               JOIN customers c ON c.customer_id = ca.customer_id
               GROUP BY ca.credit_account_id, ca.customer_id, c.first_name, c.last_name
               HAVING SUM(CASE WHEN ct.txn_type = 'CHARGE' THEN ct.amount ELSE 0 END) > 0
               ORDER BY credit_id DESC`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create credit - admin or staff
router.post('/', requireRole('admin', 'staff'), async (req, res) => {
  const { customer_id, total_due, due_date } = req.body || {};
  const customerId = Number(customer_id);
  const amount = Number(total_due);
  if (!Number.isInteger(customerId) || customerId <= 0 ||
      !Number.isFinite(amount) || amount <= 0) {
    return res.status(400).json({ error: 'Customer and a positive credit amount are required' });
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

    await connection.query(
      `INSERT INTO credit_accounts (customer_id, credit_limit, payment_terms_days, opened_on)
       VALUES (?, 50000, 30, CURDATE())
       ON DUPLICATE KEY UPDATE is_active = TRUE`,
      [customerId]
    );

    const [accRows] = await connection.query('SELECT credit_account_id FROM credit_accounts WHERE customer_id=?', [customerId]);
    const accId = accRows[0].credit_account_id;

    const [resTxn] = await connection.query(
      `INSERT INTO credit_transactions (credit_account_id, txn_type, amount, due_date, notes)
       VALUES (?, 'CHARGE', ?, ?, 'Manual credit entry')`,
      [accId, amount, due_date || null]
    );

    await connection.commit();
    res.json({ ok: true, credit_id: resTxn.insertId });
  } catch (err) {
    if (connection) await connection.rollback();
    res.status(400).json({ error: err.message });
  } finally {
    if (connection) connection.release();
  }
});

// Mark overdue
router.post('/mark-overdue', requireRole('admin', 'staff'), async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT COUNT(*) AS count FROM credit_transactions WHERE due_date < CURDATE() AND txn_type = 'CHARGE'`
    );
    res.json({ ok: true, affectedRows: rows[0].count });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Delete - admin only
router.delete('/:id', requireRole('admin'), async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT credit_account_id FROM credit_transactions
       WHERE credit_txn_id = ? AND txn_type = 'CHARGE'`,
      [req.params.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Credit entry not found' });

    const [payments] = await pool.query(
      `SELECT COUNT(*) AS count FROM credit_transactions
       WHERE credit_account_id = ? AND txn_type = 'PAYMENT'`,
      [rows[0].credit_account_id]
    );
    if (Number(payments[0].count) > 0) {
      return res.status(400).json({ error: 'Cannot delete a credit account entry after payments have been recorded' });
    }

    await pool.query('DELETE FROM credit_transactions WHERE credit_txn_id=?', [req.params.id]);
    res.json({ ok: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
