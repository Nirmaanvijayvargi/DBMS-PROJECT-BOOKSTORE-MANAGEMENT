-- =====================================================================
-- Bookstore Inventory & Online Sales Management System  (Project 70)
-- Schema in 3NF for MySQL 8 / MariaDB 10.5+
-- Run:  mysql -u root -p < sql/schema.sql
-- =====================================================================
CREATE DATABASE IF NOT EXISTS bookstore CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE bookstore;

SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW  IF EXISTS v_order_summary, v_stock_report, v_category_sales, v_author_sales,
                     v_popular_books, v_customer_history;
DROP TABLE IF EXISTS returns, invoices, payments, shipments, order_items, orders, customers,
                     editions, book_authors, books, authors, publishers, categories;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------- master tables ----------
CREATE TABLE categories (
  category_id INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(60) NOT NULL UNIQUE
);
CREATE TABLE publishers (
  publisher_id INT AUTO_INCREMENT PRIMARY KEY,
  name         VARCHAR(100) NOT NULL UNIQUE,
  email        VARCHAR(120)
);
CREATE TABLE authors (
  author_id INT AUTO_INCREMENT PRIMARY KEY,
  name      VARCHAR(100) NOT NULL UNIQUE
);

-- ---------- catalogue ----------
CREATE TABLE books (                       -- the abstract "work"
  book_id     INT AUTO_INCREMENT PRIMARY KEY,
  title       VARCHAR(200) NOT NULL,
  category_id INT NOT NULL,
  FOREIGN KEY (category_id) REFERENCES categories(category_id),
  INDEX idx_books_title (title)
);
CREATE TABLE book_authors (                -- M:N between books and authors
  book_id   INT NOT NULL,
  author_id INT NOT NULL,
  PRIMARY KEY (book_id, author_id),
  FOREIGN KEY (book_id)   REFERENCES books(book_id)     ON DELETE CASCADE,
  FOREIGN KEY (author_id) REFERENCES authors(author_id) ON DELETE CASCADE
);
CREATE TABLE editions (                    -- a sellable item: one ISBN
  edition_id    INT AUTO_INCREMENT PRIMARY KEY,
  book_id       INT NOT NULL,
  publisher_id  INT NOT NULL,
  isbn          VARCHAR(13) NOT NULL,
  format        ENUM('Paperback','Hardcover','Digital') NOT NULL DEFAULT 'Paperback',
  edition_no    TINYINT UNSIGNED NOT NULL DEFAULT 1,
  pub_year      SMALLINT NOT NULL,
  price         DECIMAL(10,2) NOT NULL,
  stock_qty     INT NOT NULL DEFAULT 0,
  reorder_level INT NOT NULL DEFAULT 5,
  CONSTRAINT uq_edition_isbn UNIQUE (isbn),                       -- unique ISBN per edition
  CONSTRAINT ck_isbn_digits  CHECK (isbn REGEXP '^[0-9]{9}[0-9X]$|^[0-9]{13}$'),
  CONSTRAINT ck_price        CHECK (price > 0),
  CONSTRAINT ck_stock        CHECK (stock_qty >= 0),              -- stock can never go negative
  CONSTRAINT ck_reorder      CHECK (reorder_level >= 0),
  CONSTRAINT ck_year         CHECK (pub_year BETWEEN 1450 AND 2100),
  FOREIGN KEY (book_id)      REFERENCES books(book_id),
  FOREIGN KEY (publisher_id) REFERENCES publishers(publisher_id),
  INDEX idx_editions_book (book_id)
);

-- ---------- customers & sales ----------
CREATE TABLE customers (
  customer_id INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  email       VARCHAR(120) NOT NULL UNIQUE,
  phone       VARCHAR(15)  NOT NULL,
  address     VARCHAR(255) NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_customers_name (name)
);
CREATE TABLE orders (
  order_id    INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  order_date  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status      ENUM('Placed','Shipped','Delivered','Cancelled') NOT NULL DEFAULT 'Placed',
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
  INDEX idx_orders_customer (customer_id),
  INDEX idx_orders_date (order_date)
);
CREATE TABLE order_items (
  order_item_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id      INT NOT NULL,
  edition_id    INT NOT NULL,
  quantity      INT NOT NULL,
  unit_price    DECIMAL(10,2) NOT NULL,           -- price frozen at time of sale
  CONSTRAINT ck_qty    CHECK (quantity > 0),
  CONSTRAINT ck_uprice CHECK (unit_price >= 0),
  CONSTRAINT uq_order_edition UNIQUE (order_id, edition_id),
  FOREIGN KEY (order_id)   REFERENCES orders(order_id) ON DELETE CASCADE,
  FOREIGN KEY (edition_id) REFERENCES editions(edition_id),
  INDEX idx_items_edition (edition_id)
);
CREATE TABLE shipments (
  shipment_id    INT AUTO_INCREMENT PRIMARY KEY,
  order_id       INT NOT NULL UNIQUE,
  carrier        VARCHAR(60) NOT NULL,
  tracking_no    VARCHAR(40) NOT NULL,
  shipped_date   DATE NOT NULL,
  delivered_date DATE NULL,
  CONSTRAINT ck_ship_dates CHECK (delivered_date IS NULL OR delivered_date >= shipped_date),
  FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);
CREATE TABLE payments (
  payment_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id   INT NOT NULL UNIQUE,
  amount     DECIMAL(10,2) NOT NULL,
  method     ENUM('UPI','Card','NetBanking','COD') NOT NULL,
  status     ENUM('Paid','Refunded') NOT NULL DEFAULT 'Paid',
  paid_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT ck_pay_amount CHECK (amount > 0),
  FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);
CREATE TABLE invoices (
  invoice_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id   INT NOT NULL UNIQUE,
  invoice_no VARCHAR(30) NOT NULL UNIQUE,
  issued_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);
CREATE TABLE returns (
  return_id     INT AUTO_INCREMENT PRIMARY KEY,
  order_item_id INT NOT NULL,
  quantity      INT NOT NULL,
  reason        VARCHAR(200) NOT NULL,
  return_date   DATE NOT NULL,
  refund_amount DECIMAL(10,2) NOT NULL,
  CONSTRAINT ck_ret_qty    CHECK (quantity > 0),
  CONSTRAINT ck_ret_refund CHECK (refund_amount >= 0),
  FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id),
  INDEX idx_returns_item (order_item_id)
);

-- ---------- business-rule triggers ----------
DELIMITER $$

-- Rule: order within stock (physical books only)
CREATE TRIGGER trg_item_check_stock BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
  DECLARE v_stock INT; DECLARE v_fmt VARCHAR(10);
  SELECT stock_qty, format INTO v_stock, v_fmt FROM editions WHERE edition_id = NEW.edition_id;
  IF v_fmt IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Edition does not exist';
  END IF;
  IF v_fmt <> 'Digital' AND NEW.quantity > v_stock THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock: order quantity exceeds copies available';
  END IF;
END$$

CREATE TRIGGER trg_item_reduce_stock AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
  UPDATE editions SET stock_qty = stock_qty - NEW.quantity
   WHERE edition_id = NEW.edition_id AND format <> 'Digital';
END$$

-- Rules: return only after delivery, inside 30-day window, no digital returns,
--        cannot return more than bought, refund cannot exceed price paid
CREATE TRIGGER trg_return_rules BEFORE INSERT ON returns
FOR EACH ROW
BEGIN
  DECLARE v_bought INT; DECLARE v_price DECIMAL(10,2); DECLARE v_fmt VARCHAR(10);
  DECLARE v_order INT; DECLARE v_delivered DATE; DECLARE v_returned INT;
  SELECT oi.quantity, oi.unit_price, e.format, oi.order_id
    INTO v_bought, v_price, v_fmt, v_order
    FROM order_items oi JOIN editions e ON e.edition_id = oi.edition_id
   WHERE oi.order_item_id = NEW.order_item_id;
  IF v_fmt IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order item does not exist';
  END IF;
  IF v_fmt = 'Digital' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Digital books cannot be returned';
  END IF;
  SELECT delivered_date INTO v_delivered FROM shipments WHERE order_id = v_order;
  IF v_delivered IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return not allowed: this order has not been delivered yet';
  END IF;
  IF NEW.return_date < v_delivered OR DATEDIFF(NEW.return_date, v_delivered) > 30 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return window closed: returns are accepted within 30 days of delivery';
  END IF;
  SELECT COALESCE(SUM(quantity), 0) INTO v_returned FROM returns WHERE order_item_id = NEW.order_item_id;
  IF NEW.quantity + v_returned > v_bought THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return quantity exceeds the quantity purchased';
  END IF;
  IF NEW.refund_amount > NEW.quantity * v_price THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Refund cannot exceed the price paid';
  END IF;
END$$

CREATE TRIGGER trg_return_restock AFTER INSERT ON returns
FOR EACH ROW
BEGIN
  UPDATE editions e JOIN order_items oi ON oi.edition_id = e.edition_id
     SET e.stock_qty = e.stock_qty + NEW.quantity
   WHERE oi.order_item_id = NEW.order_item_id;
END$$
DELIMITER ;

-- ---------- reporting views ----------
CREATE VIEW v_order_summary AS
SELECT o.order_id, o.customer_id, c.name AS customer_name, o.order_date, o.status,
       COUNT(oi.order_item_id) AS line_items, COALESCE(SUM(oi.quantity),0) AS units,
       COALESCE(SUM(oi.quantity * oi.unit_price),0) AS total_amount
  FROM orders o JOIN customers c ON c.customer_id = o.customer_id
  LEFT JOIN order_items oi ON oi.order_id = o.order_id
 GROUP BY o.order_id, o.customer_id, c.name, o.order_date, o.status;

CREATE VIEW v_stock_report AS
SELECT e.edition_id, e.isbn, b.title, e.format, e.stock_qty, e.reorder_level,
       CASE WHEN e.format = 'Digital' THEN 'N/A'
            WHEN e.stock_qty = 0 THEN 'OUT'
            WHEN e.stock_qty <= e.reorder_level THEN 'LOW'
            ELSE 'OK' END AS stock_status
  FROM editions e JOIN books b ON b.book_id = e.book_id;

CREATE VIEW v_category_sales AS
SELECT c.name AS category,
       COALESCE(SUM(CASE WHEN o.status <> 'Cancelled' THEN oi.quantity END),0) AS units_sold,
       COALESCE(SUM(CASE WHEN o.status <> 'Cancelled' THEN oi.quantity * oi.unit_price END),0) AS revenue
  FROM categories c
  LEFT JOIN books b ON b.category_id = c.category_id
  LEFT JOIN editions e ON e.book_id = b.book_id
  LEFT JOIN order_items oi ON oi.edition_id = e.edition_id
  LEFT JOIN orders o ON o.order_id = oi.order_id
 GROUP BY c.category_id, c.name;

CREATE VIEW v_author_sales AS
SELECT a.name AS author, SUM(oi.quantity) AS units_sold,
       SUM(oi.quantity * oi.unit_price) AS revenue
  FROM authors a
  JOIN book_authors ba ON ba.author_id = a.author_id
  JOIN editions e ON e.book_id = ba.book_id
  JOIN order_items oi ON oi.edition_id = e.edition_id
  JOIN orders o ON o.order_id = oi.order_id AND o.status <> 'Cancelled'
 GROUP BY a.author_id, a.name;

CREATE VIEW v_popular_books AS
SELECT b.book_id, b.title, SUM(oi.quantity) AS units_sold,
       SUM(oi.quantity * oi.unit_price) AS revenue
  FROM books b
  JOIN editions e ON e.book_id = b.book_id
  JOIN order_items oi ON oi.edition_id = e.edition_id
  JOIN orders o ON o.order_id = oi.order_id AND o.status <> 'Cancelled'
 GROUP BY b.book_id, b.title;

CREATE VIEW v_customer_history AS
SELECT c.customer_id, c.name, c.email, COUNT(DISTINCT o.order_id) AS orders_placed,
       COALESCE(SUM(oi.quantity * oi.unit_price),0) AS total_spent, MAX(o.order_date) AS last_order
  FROM customers c
  LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.status <> 'Cancelled'
  LEFT JOIN order_items oi ON oi.order_id = o.order_id
 GROUP BY c.customer_id, c.name, c.email;
