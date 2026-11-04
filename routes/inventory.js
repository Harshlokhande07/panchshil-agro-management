const express = require('express');
const router = express.Router();
const pool = require('../db/pool');
const { requireRole } = require('../middleware/auth');

router.get('/', async (req, res) => {
  const sql = `SELECT b.batch_id AS inventory_id, b.warehouse_id, w.warehouse_name,
                      b.product_id, p.sku, p.product_name,
                      c.category_name AS category, p.reorder_level AS min_stock,
                      b.batch_no, b.expiry_date, b.shelf_qty, b.godown_qty,
                      b.shelf_qty + b.godown_qty AS total
               FROM inventory_batches b
               JOIN warehouses w ON w.warehouse_id = b.warehouse_id
               JOIN products p ON p.product_id = b.product_id
               LEFT JOIN categories c ON c.category_id = p.category_id
               ORDER BY p.product_id, b.warehouse_id, b.batch_id`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/summary', async (req, res) => {
  const sql = `SELECT p.product_id, p.product_name, c.category_name,
                      p.reorder_level,
                      COALESCE(SUM(i.quantity), 0) AS total_stock
               FROM products p
               LEFT JOIN categories c ON c.category_id = p.category_id
               LEFT JOIN inventory i ON i.product_id = p.product_id
               GROUP BY p.product_id, p.product_name, c.category_name, p.reorder_level
               ORDER BY p.product_id`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/expiring', async (req, res) => {
  const sql = `SELECT b.batch_no, b.expiry_date, b.shelf_qty, b.godown_qty,
                      b.shelf_qty + b.godown_qty AS total,
                      p.product_name
               FROM inventory_batches b
               JOIN products p ON p.product_id = b.product_id
               WHERE b.expiry_date BETWEEN CURRENT_DATE
                 AND DATE_ADD(CURRENT_DATE, INTERVAL 90 DAY)
               ORDER BY b.expiry_date, p.product_name`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', requireRole('admin'), async (req, res) => {
  const { product_id, batch_no, expiry_date } = req.body || {};
  const shelfQty = Number(req.body && req.body.shelf_qty);
  const godownQty = Number(req.body && req.body.godown_qty);
  const productId = Number(product_id);
  const batchNo = typeof batch_no === 'string' ? batch_no.trim() : '';

  if (!Number.isInteger(productId) || productId <= 0 || !batchNo ||
      !Number.isFinite(shelfQty) || shelfQty < 0 ||
      !Number.isFinite(godownQty) || godownQty < 0 ||
      shelfQty + godownQty <= 0) {
    return res.status(400).json({ error: 'Product, batch number and a positive stock quantity are required' });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [warehouses] = await connection.query('SELECT warehouse_id FROM warehouses ORDER BY warehouse_id LIMIT 1');
    if (warehouses.length === 0) {
      await connection.rollback();
      return res.status(400).json({ error: 'No warehouse is configured' });
    }

    const warehouseId = warehouses[0].warehouse_id;
    const [batchResult] = await connection.query(
      `INSERT INTO inventory_batches
         (warehouse_id, product_id, batch_no, expiry_date, shelf_qty, godown_qty)
       VALUES (?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         expiry_date = VALUES(expiry_date),
         shelf_qty = shelf_qty + VALUES(shelf_qty),
         godown_qty = godown_qty + VALUES(godown_qty)`,
      [warehouseId, productId, batchNo, expiry_date || null, shelfQty, godownQty]
    );
    const total = shelfQty + godownQty;

    await connection.query(
      `INSERT INTO inventory (warehouse_id, product_id, quantity)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)`,
      [warehouseId, productId, total]
    );
    await connection.query(
      `INSERT INTO inventory_movements
         (warehouse_id, product_id, quantity_delta, reason)
       VALUES (?, ?, ?, 'ADJUSTMENT')`,
      [warehouseId, productId, total]
    );

    await connection.commit();
    res.status(201).json({ ok: true, inventory_id: batchResult.insertId });
  } catch (err) {
    if (connection) await connection.rollback();
    res.status(400).json({ error: err.message });
  } finally {
    if (connection) connection.release();
  }
});

router.put('/:id', requireRole('admin'), async (req, res) => {
  const { batch_no, expiry_date } = req.body || {};
  const shelfQty = Number(req.body && req.body.shelf_qty);
  const godownQty = Number(req.body && req.body.godown_qty);
  const batchNo = typeof batch_no === 'string' ? batch_no.trim() : '';

  if (!batchNo || !Number.isFinite(shelfQty) || shelfQty < 0 ||
      !Number.isFinite(godownQty) || godownQty < 0) {
    return res.status(400).json({ error: 'Batch number and non-negative stock quantities are required' });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [batches] = await connection.query(
      `SELECT warehouse_id, product_id, batch_no, shelf_qty, godown_qty
       FROM inventory_batches WHERE batch_id = ? FOR UPDATE`,
      [req.params.id]
    );
    if (batches.length === 0) {
      await connection.rollback();
      return res.status(404).json({ error: 'Inventory batch not found' });
    }

    const batch = batches[0];
    const oldTotal = Number(batch.shelf_qty) + Number(batch.godown_qty);
    const newTotal = shelfQty + godownQty;
    const delta = newTotal - oldTotal;

    await connection.query(
      `UPDATE inventory_batches
       SET batch_no = ?, expiry_date = ?, shelf_qty = ?, godown_qty = ?
       WHERE batch_id = ?`,
      [batchNo, expiry_date || null, shelfQty, godownQty, req.params.id]
    );

    if (delta !== 0) {
      await connection.query(
        `UPDATE inventory SET quantity = quantity + ?
         WHERE warehouse_id = ? AND product_id = ?`,
        [delta, batch.warehouse_id, batch.product_id]
      );
      await connection.query(
        `INSERT INTO inventory_movements
           (warehouse_id, product_id, quantity_delta, reason)
         VALUES (?, ?, ?, 'ADJUSTMENT')`,
        [batch.warehouse_id, batch.product_id, delta]
      );
    }

    await connection.commit();
    res.json({ ok: true });
  } catch (err) {
    if (connection) await connection.rollback();
    res.status(400).json({ error: err.message });
  } finally {
    if (connection) connection.release();
  }
});

router.delete('/:id', requireRole('admin'), async (req, res) => {
  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [batches] = await connection.query(
      `SELECT warehouse_id, product_id, shelf_qty, godown_qty
       FROM inventory_batches WHERE batch_id = ? FOR UPDATE`,
      [req.params.id]
    );
    if (batches.length === 0) {
      await connection.rollback();
      return res.status(404).json({ error: 'Inventory batch not found' });
    }

    const batch = batches[0];
    const total = Number(batch.shelf_qty) + Number(batch.godown_qty);
    if (total > 0) {
      await connection.query(
        `UPDATE inventory SET quantity = quantity - ?
         WHERE warehouse_id = ? AND product_id = ?`,
        [total, batch.warehouse_id, batch.product_id]
      );
      await connection.query(
        `INSERT INTO inventory_movements
           (warehouse_id, product_id, quantity_delta, reason)
         VALUES (?, ?, ?, 'ADJUSTMENT')`,
        [batch.warehouse_id, batch.product_id, -total]
      );
    }
    await connection.query('DELETE FROM inventory_batches WHERE batch_id = ?', [req.params.id]);
    await connection.commit();
    res.json({ ok: true });
  } catch (err) {
    if (connection) await connection.rollback();
    res.status(400).json({ error: err.message });
  } finally {
    if (connection) connection.release();
  }
});

router.post('/move-to-shelf', requireRole('admin', 'staff'), async (req, res) => {
  const inventoryId = Number(req.body && req.body.inventory_id);
  const qty = Number(req.body && req.body.qty);
  if (!Number.isInteger(inventoryId) || inventoryId <= 0 ||
      !Number.isFinite(qty) || qty <= 0) {
    return res.status(400).json({ error: 'Select a batch and enter a positive quantity' });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [batches] = await connection.query(
      `SELECT shelf_qty, godown_qty FROM inventory_batches
       WHERE batch_id = ? FOR UPDATE`,
      [inventoryId]
    );
    if (batches.length === 0) {
      await connection.rollback();
      return res.status(404).json({ error: 'Inventory batch not found' });
    }
    if (Number(batches[0].godown_qty) < qty) {
      await connection.rollback();
      return res.status(400).json({ error: 'Transfer quantity exceeds the batch godown stock' });
    }

    await connection.query(
      `UPDATE inventory_batches
       SET shelf_qty = shelf_qty + ?, godown_qty = godown_qty - ?
       WHERE batch_id = ?`,
      [qty, qty, inventoryId]
    );
    await connection.commit();
    res.json({ ok: true, message: `Successfully shifted ${qty} units to front shelf.` });
  } catch (err) {
    if (connection) await connection.rollback();
    res.status(400).json({ error: err.message });
  } finally {
    if (connection) connection.release();
  }
});

module.exports = router;
