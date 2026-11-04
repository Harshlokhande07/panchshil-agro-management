const express = require('express');
const router = express.Router();
const pool = require('../db/pool');
const { requireRole } = require('../middleware/auth');

// List customers with optional search & date filters
router.get('/', async (req, res) => {
  const { from_date, to_date, type, search } = req.query;
  
  let sql = `SELECT c.customer_id, c.customer_code,
                    c.first_name, c.last_name,
                    CONCAT(c.first_name, ' ', c.last_name) AS name,
                    c.email, c.phone, c.customer_type, c.is_active,
                    DATE_FORMAT(c.created_at, '%Y-%m-%d') AS created_date,
                    c.created_at,
                    ca.address_id, ca.address_line, ca.city, ca.state_name, ca.postal_code,
                    CONCAT(COALESCE(ca.address_line, ''), IF(ca.city IS NOT NULL, CONCAT(', ', ca.city), '')) AS address
             FROM customers c
             LEFT JOIN customer_addresses ca ON ca.customer_id = c.customer_id
             WHERE 1=1`;
  const params = [];

  if (from_date) {
    sql += ` AND DATE(c.created_at) >= ?`;
    params.push(from_date);
  }
  if (to_date) {
    sql += ` AND DATE(c.created_at) <= ?`;
    params.push(to_date);
  }
  if (type && type !== 'ALL') {
    sql += ` AND c.customer_type = ?`;
    params.push(type);
  }
  if (search) {
    sql += ` AND (c.first_name LIKE ? OR c.last_name LIKE ? OR c.customer_code LIKE ? OR c.phone LIKE ? OR c.email LIKE ? OR ca.city LIKE ?)`;
    const s = `%${search}%`;
    params.push(s, s, s, s, s, s);
  }

  sql += ` ORDER BY c.customer_id DESC`;

  try {
    const [rows] = await pool.query(sql, params);
    res.json({ rows, query: sql, params });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Auto-generate next customer code and id preview
router.get('/next-code', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT MAX(customer_id) AS max_id FROM customers');
    const nextId = (rows[0].max_id || 0) + 1;
    const nextCode = `PA-C${String(nextId).padStart(4, '0')}`;
    res.json({ next_id: nextId, next_code: nextCode });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// CREATE Customer - Auto-generate ID & Customer Code
router.post('/', requireRole('admin', 'staff'), async (req, res) => {
  const {
    first_name, last_name, name,
    phone, email, customer_type,
    address_line, city, state_name, postal_code
  } = req.body || {};

  // Resolve first and last name
  let fName = first_name ? first_name.trim() : '';
  let lName = last_name ? last_name.trim() : '';
  if (!fName && name) {
    const parts = name.trim().split(/\s+/);
    fName = parts[0] || 'Customer';
    lName = parts.slice(1).join(' ') || 'Farmer';
  }
  if (!fName) fName = 'Customer';
  if (!lName) lName = 'Patil';

  try {
    // 1. Auto-generate unique Customer Code
    const [maxRows] = await pool.query('SELECT MAX(customer_id) AS max_id FROM customers');
    const nextNum = (maxRows[0].max_id || 0) + 1;
    const autoCode = `PA-C${String(nextNum).padStart(4, '0')}`;
    const autoEmail = email && email.trim() ? email.trim() : `customer${String(nextNum).padStart(3, '0')}@example.com`;
    const autoPhone = phone && phone.trim() ? phone.trim() : `DEMO-${String(nextNum).padStart(4, '0')}`;
    const custType = ['FARMER', 'RETAILER', 'WHOLESALER'].includes(customer_type) ? customer_type : 'FARMER';

    // 2. Insert into customers table
    const [custResult] = await pool.query(
      `INSERT INTO customers (customer_code, first_name, last_name, email, phone, customer_type, is_active, created_at)
       VALUES (?, ?, ?, ?, ?, ?, TRUE, NOW())`,
      [autoCode, fName, lName, autoEmail, autoPhone, custType]
    );
    const newCustomerId = custResult.insertId;

    // 3. Insert address into customer_addresses table
    const addrLine = address_line && address_line.trim() ? address_line.trim() : 'Agro Market Road';
    const addrCity = city && city.trim() ? city.trim() : 'Nashik';
    const addrState = state_name && state_name.trim() ? state_name.trim() : 'Maharashtra';
    const addrPin = postal_code && postal_code.trim() ? postal_code.trim() : '422001';

    await pool.query(
      `INSERT INTO customer_addresses (customer_id, address_type, address_line, city, state_name, postal_code, country_code)
       VALUES (?, 'SHIPPING', ?, ?, ?, ?, 'IN')
       ON DUPLICATE KEY UPDATE address_line=VALUES(address_line), city=VALUES(city)`,
      [newCustomerId, addrLine, addrCity, addrState, addrPin]
    );

    // 4. Create credit account for customer
    const creditLimit = custType === 'WHOLESALER' ? 100000 : (custType === 'RETAILER' ? 40000 : 20000);
    const terms = custType === 'WHOLESALER' ? 45 : 30;
    await pool.query(
      `INSERT INTO credit_accounts (customer_id, credit_limit, payment_terms_days, is_active, opened_on)
       VALUES (?, ?, ?, TRUE, CURDATE())
       ON DUPLICATE KEY UPDATE credit_limit=VALUES(credit_limit)`,
      [newCustomerId, creditLimit, terms]
    );

    res.json({
      ok: true,
      customer_id: newCustomerId,
      customer_code: autoCode,
      name: `${fName} ${lName}`,
      message: `Customer ${autoCode} created successfully with ID #${newCustomerId}`
    });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// UPDATE Customer - admin only
router.put('/:id', requireRole('admin'), async (req, res) => {
  const {
    first_name, last_name, name,
    phone, email, customer_type, is_active,
    address_line, city, state_name, postal_code
  } = req.body || {};

  let fName = first_name;
  let lName = last_name;
  if (!fName && name) {
    const parts = name.trim().split(/\s+/);
    fName = parts[0] || 'Customer';
    lName = parts.slice(1).join(' ') || 'Farmer';
  }

  try {
    // 1. Update customers table
    const [cRows] = await pool.query('SELECT * FROM customers WHERE customer_id=?', [req.params.id]);
    if (cRows.length === 0) return res.status(404).json({ error: 'Customer not found' });
    const current = cRows[0];

    await pool.query(
      `UPDATE customers
       SET first_name=?, last_name=?, phone=?, email=?, customer_type=?, is_active=?
       WHERE customer_id=?`,
      [
        fName || current.first_name,
        lName || current.last_name,
        phone || current.phone,
        email || current.email,
        customer_type || current.customer_type,
        is_active !== undefined ? (is_active ? 1 : 0) : current.is_active,
        req.params.id
      ]
    );

    // 2. Update address
    if (address_line || city) {
      await pool.query(
        `INSERT INTO customer_addresses (customer_id, address_type, address_line, city, state_name, postal_code, country_code)
         VALUES (?, 'SHIPPING', ?, ?, ?, ?, 'IN')
         ON DUPLICATE KEY UPDATE address_line=VALUES(address_line), city=VALUES(city), state_name=VALUES(state_name), postal_code=VALUES(postal_code)`,
        [
          req.params.id,
          address_line || 'Agro Market Road',
          city || 'Nashik',
          state_name || 'Maharashtra',
          postal_code || '422001'
        ]
      );
    }

    res.json({ ok: true, message: `Customer #${req.params.id} updated successfully` });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// DELETE Customer - admin only
router.delete('/:id', requireRole('admin'), async (req, res) => {
  const customerId = req.params.id;
  try {
    // Check if customer has sales orders
    const [orders] = await pool.query('SELECT COUNT(*) AS c FROM sales_orders WHERE customer_id=?', [customerId]);
    if (orders[0].c > 0) {
      // Soft-delete / deactivate instead of hard crash so database integrity is preserved
      await pool.query('UPDATE customers SET is_active=FALSE WHERE customer_id=?', [customerId]);
      return res.json({
        ok: true,
        soft_deleted: true,
        message: `Customer #${customerId} has ${orders[0].c} existing sales orders. Customer account has been deactivated (is_active = FALSE) to protect order history.`
      });
    }

    // Otherwise, clean up credit_accounts and address, then delete customer
    await pool.query('DELETE FROM customer_addresses WHERE customer_id=?', [customerId]);
    await pool.query('DELETE FROM credit_transactions WHERE credit_account_id IN (SELECT credit_account_id FROM credit_accounts WHERE customer_id=?)', [customerId]);
    await pool.query('DELETE FROM credit_accounts WHERE customer_id=?', [customerId]);
    await pool.query('DELETE FROM customers WHERE customer_id=?', [customerId]);

    res.json({ ok: true, message: `Customer #${customerId} deleted successfully` });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
