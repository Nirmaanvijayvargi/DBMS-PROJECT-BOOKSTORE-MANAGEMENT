# Bookstore Inventory & Online Sales Management System (Project 70 - Review 3)

Python (Flask) web app on MySQL / MariaDB. Covers catalogue maintenance, search, stock update, order,
shipment, return, invoice, payment and reporting.

## 1. One-time setup
```
pip install -r requirements.txt
mysql -u root -p < sql/schema.sql        # creates database `bookstore`: tables, triggers, views
mysql -u root -p bookstore < sql/test_data.sql   # realistic sample data
```
## 2. Run
Windows (PowerShell):
```
$env:DB_USER="root"; $env:DB_PASSWORD="your-mysql-password"; python app.py
```
Mac/Linux:
```
DB_USER=root DB_PASSWORD='your-mysql-password' python app.py
```
Open http://127.0.0.1:5000  (other settings: DB_HOST, DB_PORT, DB_NAME)

## 3. Where each Review-3 requirement lives
| Requirement | Where |
|---|---|
| Catalogue maintenance (CRUD) | /books, /books/new, edit, delete |
| Search | /books (title / author / ISBN + category + format), /customers, /orders |
| Stock update | "Adjust stock" box on /books |
| Order, payment, invoice | /orders/new (one transaction) -> invoice page |
| Shipment | order page: Create shipment -> Mark delivered |
| Return | order page (after delivery) + /returns |
| Reports | /reports (views in schema.sql) |
| Validation | `validate_*` functions in app.py + HTML attributes + DB CHECK constraints |
| Error handling | `friendly()` + `@app.errorhandler(Error)` in app.py |

## 4. Business rules enforced INSIDE the database (triggers / constraints)
- unique ISBN per edition; ISBN format CHECK; price > 0; stock >= 0
- order quantity cannot exceed stock (trigger `trg_item_check_stock`); stock reduced automatically
- returns: only after delivery, within 30 days, never digital, never more than purchased, refund <= price paid
- order + items + payment + invoice are saved in a single transaction (all or nothing)

## 5. Demo script for viva
1. Add an edition with a bad ISBN -> validation message. Add a valid one.
2. New order for more copies than in stock -> database rejects it, nothing is saved.
3. Place a valid order -> invoice -> ship -> deliver.
4. Return one copy -> stock goes back up. Try returning a digital book / after 30 days -> rejected.
5. Open Reports.
