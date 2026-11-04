const pool = require('./pool');

async function ensureAppSchema() {
  const connection = await pool.getConnection();
  try {
    await connection.query('SET SESSION lock_wait_timeout = 5');

    await connection.query(`
      CREATE TABLE IF NOT EXISTS product_brands (
        product_id INT PRIMARY KEY,
        brand VARCHAR(80) NOT NULL
      ) ENGINE=InnoDB
    `);

    await connection.query(`
      CREATE TABLE IF NOT EXISTS product_price_audit (
        audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
        product_id INT NOT NULL,
        old_price DECIMAL(12,2) NOT NULL,
        new_price DECIMAL(12,2) NOT NULL,
        changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_product_price_audit_product (product_id)
      ) ENGINE=InnoDB
    `);

    await connection.query(`
      CREATE TABLE IF NOT EXISTS inventory_batches (
        batch_id BIGINT AUTO_INCREMENT PRIMARY KEY,
        warehouse_id INT NOT NULL,
        product_id INT NOT NULL,
        batch_no VARCHAR(80) NOT NULL,
        expiry_date DATE NULL,
        shelf_qty DECIMAL(12,3) NOT NULL DEFAULT 0,
        godown_qty DECIMAL(12,3) NOT NULL DEFAULT 0,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_inventory_batches_location (warehouse_id, product_id, batch_no),
        INDEX idx_inventory_batches_expiry (expiry_date),
        CONSTRAINT chk_inventory_batches_shelf CHECK (shelf_qty >= 0),
        CONSTRAINT chk_inventory_batches_godown CHECK (godown_qty >= 0)
      ) ENGINE=InnoDB
    `);

    await connection.query(`
      INSERT INTO inventory_batches (warehouse_id, product_id, batch_no, shelf_qty, godown_qty)
      SELECT i.warehouse_id, i.product_id,
             CONCAT('OPENING-', i.warehouse_id, '-', i.product_id), 0, i.quantity
      FROM inventory i
      WHERE i.quantity > 0
        AND NOT EXISTS (
          SELECT 1
          FROM inventory_batches b
          WHERE b.warehouse_id = i.warehouse_id
            AND b.product_id = i.product_id
        )
    `);
  } finally {
    connection.release();
  }
}

module.exports = ensureAppSchema;
