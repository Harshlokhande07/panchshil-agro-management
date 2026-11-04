const express = require('express');
const { randomBytes } = require('crypto');
const router = express.Router();
const pool = require('../db/pool');
const { requireRole } = require('../middleware/auth');

router.get('/', async (req, res) => {
  const sql = `SELECT p.product_id, p.sku, p.product_name, pb.brand,
                      c.category_name AS category, p.category_id,
                      u.unit_code AS unit, ps.supplier_id,
                      COALESCE(s.supplier_name, 'Direct Supply') AS supplier_name,
                      COALESCE(ps.quoted_cost, 0) AS purchase_price,
                      p.sale_price AS selling_price,
                      p.reorder_level AS min_stock, p.is_active
               FROM products p
               LEFT JOIN categories c ON c.category_id = p.category_id
               LEFT JOIN units u ON u.unit_id = p.unit_id
               LEFT JOIN product_brands pb ON pb.product_id = p.product_id
               LEFT JOIN (
                 SELECT product_id, MIN(supplier_id) AS supplier_id,
                        AVG(quoted_cost) AS quoted_cost
                 FROM product_suppliers GROUP BY product_id
               ) ps ON ps.product_id = p.product_id
               LEFT JOIN suppliers s ON s.supplier_id = ps.supplier_id
               ORDER BY p.product_id`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/price-audit', async (req, res) => {
  const sql = `SELECT a.*, p.product_name
               FROM product_price_audit a
               JOIN products p ON p.product_id = a.product_id
               ORDER BY a.audit_id DESC`;
  try {
    const [rows] = await pool.query(sql);
    res.json({ rows, query: sql, params: [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', requireRole('admin'), async (req, res) => {
  const {
    supplier_id, product_name, category, brand,
    purchase_price, selling_price, min_stock
  } = req.body || {};
  const name = typeof product_name === 'string' ? product_name.trim() : '';
  const salePrice = Number(selling_price);
  const reorderLevel = Number(min_stock ?? 10);
  const cost = Number(purchase_price ?? 0);

  if (!name || !Number.isFinite(salePrice) || salePrice < 0 ||
      !Number.isFinite(reorderLevel) || reorderLevel < 0 ||
      !Number.isFinite(cost) || cost < 0) {
    return res.status(400).json({ error: 'Product name and valid non-negative prices and stock level are required' });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [cats] = await connection.query(
      'SELECT category_id FROM categories WHERE category_name = ? LIMIT 1',
      [category || 'Fertilizer']
    );
    if (cats.length === 0) {
      await connection.rollback();
      return res.status(400).json({ error: 'Selected product category does not exist' });
    }

    const [units] = await connection.query('SELECT unit_id FROM units ORDER BY unit_id LIMIT 1');
    if (units.length === 0) {
      await connection.rollback();
      return res.status(400).json({ error: 'No product units are configured' });
    }

    const sku = `PA-P${Date.now()}-${randomBytes(2).toString('hex')}`;
    const [result] = await connection.query(
      `INSERT INTO products
         (sku, product_name, category_id, unit_id, sale_price, reorder_level, is_active)
       VALUES (?, ?, ?, ?, ?, ?, TRUE)`,
      [sku, name, cats[0].category_id, units[0].unit_id, salePrice, reorderLevel]
    );

    if (typeof brand === 'string' && brand.trim()) {
      await connection.query(
        'INSERT INTO product_brands (product_id, brand) VALUES (?, ?)',
        [result.insertId, brand.trim()]
      );
    }

    if (supplier_id) {
      await connection.query(
        `INSERT INTO product_suppliers (product_id, supplier_id, quoted_cost)
         VALUES (?, ?, ?)`,
        [result.insertId, supplier_id, cost]
      );
    }

    await connection.commit();
    res.status(201).json({ ok: true, product_id: result.insertId, sku });
  } catch (err) {
    if (connection) await connection.rollback();
    res.status(400).json({ error: err.message });
  } finally {
    if (connection) connection.release();
  }
});

router.put('/:id', requireRole('admin'), async (req, res) => {
  const {
    supplier_id, product_name, category, brand,
    purchase_price, selling_price, min_stock
  } = req.body || {};
  const name = typeof product_name === 'string' ? product_name.trim() : '';
  const salePrice = Number(selling_price);
  const reorderLevel = Number(min_stock ?? 10);
  const cost = Number(purchase_price ?? 0);

  if (!name || !Number.isFinite(salePrice) || salePrice < 0 ||
      !Number.isFinite(reorderLevel) || reorderLevel < 0 ||
      !Number.isFinite(cost) || cost < 0) {
    return res.status(400).json({ error: 'Product name and valid non-negative prices and stock level are required' });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [products] = await connection.query(
      'SELECT sale_price FROM products WHERE product_id = ? FOR UPDATE',
      [req.params.id]
    );
    if (products.length === 0) {
      await connection.rollback();
      return res.status(404).json({ error: 'Product not found' });
    }

    const [cats] = await connection.query(
      'SELECT category_id FROM categories WHERE category_name = ? LIMIT 1',
      [category || 'Fertilizer']
    );
    if (cats.length === 0) {
      await connection.rollback();
      return res.status(400).json({ error: 'Selected product category does not exist' });
    }

    await connection.query(
      `UPDATE products
       SET product_name = ?, category_id = ?, sale_price = ?, reorder_level = ?
       WHERE product_id = ?`,
      [name, cats[0].category_id, salePrice, reorderLevel, req.params.id]
    );

    if (typeof brand === 'string' && brand.trim()) {
      await connection.query(
        `INSERT INTO product_brands (product_id, brand) VALUES (?, ?)
         ON DUPLICATE KEY UPDATE brand = VALUES(brand)`,
        [req.params.id, brand.trim()]
      );
    } else {
      await connection.query('DELETE FROM product_brands WHERE product_id = ?', [req.params.id]);
    }

    if (Number(products[0].sale_price) !== salePrice) {
      await connection.query(
        `INSERT INTO product_price_audit (product_id, old_price, new_price)
         VALUES (?, ?, ?)`,
        [req.params.id, products[0].sale_price, salePrice]
      );
    }

    await connection.query('DELETE FROM product_suppliers WHERE product_id = ?', [req.params.id]);
    if (supplier_id) {
      await connection.query(
        `INSERT INTO product_suppliers (product_id, supplier_id, quoted_cost)
         VALUES (?, ?, ?)`,
        [req.params.id, supplier_id, cost]
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
    const [result] = await connection.query('DELETE FROM products WHERE product_id = ?', [req.params.id]);
    if (result.affectedRows === 0) {
      await connection.rollback();
      return res.status(404).json({ error: 'Product not found' });
    }
    await connection.query('DELETE FROM product_brands WHERE product_id = ?', [req.params.id]);
    await connection.query('DELETE FROM product_price_audit WHERE product_id = ?', [req.params.id]);
    await connection.commit();
    res.json({ ok: true });
  } catch (err) {
    if (connection) await connection.rollback();
    if (err.errno === 1451) {
      return res.status(400).json({ error: 'Cannot delete: product is referenced by inventory or orders' });
    }
    res.status(400).json({ error: err.message });
  } finally {
    if (connection) connection.release();
  }
});

module.exports = router;
