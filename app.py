"""Bookstore Inventory & Online Sales Management System  -  Flask + MySQL/MariaDB
Run:  python app.py      then open http://127.0.0.1:5000
"""
import os, re, datetime as dt
from contextlib import contextmanager
from decimal import Decimal, InvalidOperation

import mysql.connector
from mysql.connector import Error
from flask import Flask, g, render_template, request, redirect, url_for, flash, abort

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "change-me-in-production")

DB_CONFIG = dict(
    host=os.environ.get("DB_HOST", "localhost"),
    port=int(os.environ.get("DB_PORT", "3306")),
    user=os.environ.get("DB_USER", "root"),
    password=os.environ.get("DB_PASSWORD", ""),
    database=os.environ.get("DB_NAME", "bookstore"),
)
FORMATS = ["Paperback", "Hardcover", "Digital"]
METHODS = ["UPI", "Card", "NetBanking", "COD"]
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$")


# ---------------------------------------------------------------- database layer
def db():
    """One connection per request, created lazily and closed at the end."""
    if "db" not in g:
        g.db = mysql.connector.connect(autocommit=True, **DB_CONFIG)
    return g.db


@app.teardown_appcontext
def close_db(_exc):
    conn = g.pop("db", None)
    if conn is not None and conn.is_connected():
        conn.close()


def query(sql, args=(), one=False):
    cur = db().cursor(dictionary=True)
    cur.execute(sql, args)
    rows = cur.fetchall()
    cur.close()
    return (rows[0] if rows else None) if one else rows


def execute(sql, args=()):
    cur = db().cursor()
    cur.execute(sql, args)
    new_id, count = cur.lastrowid, cur.rowcount
    cur.close()
    return new_id if new_id else count


@contextmanager
def transaction():
    """All-or-nothing block: any error rolls back every statement inside it."""
    conn = db()
    conn.start_transaction()
    try:
        yield
        conn.commit()
    except Exception:
        conn.rollback()
        raise


def friendly(err):
    """Translate a raw MySQL error into a sentence a user can act on."""
    n = getattr(err, "errno", None)
    msg = getattr(err, "msg", str(err))
    if n == 1644:                       # SIGNAL from our triggers
        return msg
    if n == 1062:
        low = msg.lower()
        what = "ISBN" if "isbn" in low else "email address" if "email" in low else "name" if "name" in low else "entry"
        return f"That {what} already exists - duplicates are not allowed."
    if n in (1451, 1217):
        return "Cannot delete: other records (orders, editions...) still depend on this item."
    if n == 1452:
        return "Invalid reference: the related record does not exist."
    if n in (4025, 3819):
        return "A data rule was violated: " + msg
    if n in (2003, 2002, 1045, 1049):
        return "Cannot reach the database - check DB_HOST / DB_USER / DB_PASSWORD / DB_NAME."
    return "Database error: " + msg


@app.errorhandler(Error)
def handle_db_error(err):
    flash(friendly(err), "error")
    return redirect(request.referrer or url_for("index"))


@app.errorhandler(404)
def not_found(_e):
    return render_template("base.html", page="404", body_404=True), 404


# ---------------------------------------------------------------- template helpers
@app.template_filter("inr")
def inr(v):
    try:
        return "\u20b9{:,.2f}".format(Decimal(v or 0))
    except InvalidOperation:
        return "\u20b90.00"


@app.template_filter("dmy")
def dmy(v):
    return v.strftime("%d %b %Y") if v else "-"


@app.context_processor
def inject():
    return dict(FORMATS=FORMATS, METHODS=METHODS, today=dt.date.today())


# ---------------------------------------------------------------- validation helpers
def valid_isbn(raw):
    s = raw.replace("-", "").replace(" ", "").upper()
    if re.fullmatch(r"\d{13}", s):
        ok = sum(int(c) * (1 if i % 2 == 0 else 3) for i, c in enumerate(s)) % 10 == 0
    elif re.fullmatch(r"\d{9}[\dX]", s):
        ok = sum((10 - i) * (10 if c == "X" else int(c)) for i, c in enumerate(s)) % 11 == 0
    else:
        return None
    return s if ok else None


def to_int(v, default=None):
    try:
        return int(str(v).strip())
    except (ValueError, TypeError):
        return default


def to_dec(v):
    try:
        d = Decimal(str(v).strip())
        return d if d.is_finite() else None
    except (InvalidOperation, ValueError):
        return None


# ---------------------------------------------------------------- dashboard
@app.route("/")
def index():
    stats = query("""SELECT
        (SELECT COUNT(*) FROM books) titles, (SELECT COUNT(*) FROM editions) editions,
        (SELECT COUNT(*) FROM customers) customers,
        (SELECT COUNT(*) FROM orders WHERE status <> 'Cancelled') orders,
        (SELECT COALESCE(SUM(total_amount),0) FROM v_order_summary WHERE status <> 'Cancelled') revenue,
        (SELECT COUNT(*) FROM orders WHERE status = 'Placed') to_ship,
        (SELECT COUNT(*) FROM v_stock_report WHERE stock_status IN ('LOW','OUT')) low""", one=True)
    recent = query("SELECT * FROM v_order_summary ORDER BY order_date DESC LIMIT 6")
    low = query("SELECT * FROM v_stock_report WHERE stock_status IN ('LOW','OUT') ORDER BY stock_qty LIMIT 6")
    return render_template("dashboard.html", s=stats, recent=recent, low=low, page="dashboard")


# ---------------------------------------------------------------- catalogue (CRUD + search)
CATALOGUE_SQL = """
SELECT e.edition_id, b.book_id, b.title, b.category_id, c.name AS category, p.name AS publisher,
       e.publisher_id, e.isbn, e.format, e.edition_no, e.pub_year, e.price, e.stock_qty, e.reorder_level,
       (SELECT GROUP_CONCAT(a.name ORDER BY a.name SEPARATOR ', ')
          FROM book_authors ba JOIN authors a ON a.author_id = ba.author_id
         WHERE ba.book_id = b.book_id) AS authors
  FROM editions e
  JOIN books b ON b.book_id = e.book_id
  JOIN categories c ON c.category_id = b.category_id
  JOIN publishers p ON p.publisher_id = e.publisher_id
"""


@app.route("/books")
def books():
    q = request.args.get("q", "").strip()
    cat = request.args.get("category", "")
    fmt = request.args.get("format", "")
    like = f"%{q}%"
    rows = query(CATALOGUE_SQL + """
     WHERE (%s = '' OR b.title LIKE %s OR e.isbn LIKE %s
            OR EXISTS (SELECT 1 FROM book_authors x JOIN authors y ON y.author_id = x.author_id
                        WHERE x.book_id = b.book_id AND y.name LIKE %s))
       AND (%s = '' OR b.category_id = %s) AND (%s = '' OR e.format = %s)
     ORDER BY b.title, e.format""", (q, like, like, like, cat, cat or 0, fmt, fmt))
    cats = query("SELECT * FROM categories ORDER BY name")
    return render_template("books.html", rows=rows, cats=cats, q=q, cat=cat, fmt=fmt, page="books")


def validate_edition(f):
    errs, d = [], {}
    d["title"] = f.get("title", "").strip()
    d["authors"] = [a.strip() for a in f.get("authors", "").split(",") if a.strip()]
    d["category_id"] = to_int(f.get("category_id"))
    d["publisher_id"] = to_int(f.get("publisher_id"))
    d["format"] = f.get("format")
    d["edition_no"] = to_int(f.get("edition_no"))
    d["pub_year"] = to_int(f.get("pub_year"))
    d["price"] = to_dec(f.get("price"))
    d["stock_qty"] = to_int(f.get("stock_qty"))
    d["reorder_level"] = to_int(f.get("reorder_level"), 5)
    d["isbn"] = valid_isbn(f.get("isbn", ""))
    if not d["title"] or len(d["title"]) > 200: errs.append("Title is required (max 200 characters).")
    if not d["authors"]: errs.append("Enter at least one author (separate several with commas).")
    if not d["category_id"]: errs.append("Choose a category.")
    if not d["publisher_id"]: errs.append("Choose a publisher.")
    if d["format"] not in FORMATS: errs.append("Choose a valid format.")
    if not d["isbn"]: errs.append("ISBN is invalid - enter a valid ISBN-10 or ISBN-13 (check digit must match).")
    if d["edition_no"] is None or not 1 <= d["edition_no"] <= 99: errs.append("Edition number must be 1-99.")
    if d["pub_year"] is None or not 1450 <= d["pub_year"] <= dt.date.today().year + 1:
        errs.append("Publication year looks wrong.")
    if d["price"] is None or d["price"] <= 0: errs.append("Price must be greater than zero.")
    if d["stock_qty"] is None or d["stock_qty"] < 0: errs.append("Stock must be zero or more.")
    if d["reorder_level"] is None or d["reorder_level"] < 0: errs.append("Reorder level must be zero or more.")
    if d["format"] == "Digital" and d["stock_qty"]: errs.append("Digital editions have no physical stock - set stock to 0.")
    return d, errs


def form_lists():
    return query("SELECT * FROM categories ORDER BY name"), query("SELECT * FROM publishers ORDER BY name")


def save_edition(d, edition_id=None):
    with transaction():
        if edition_id is None:
            book = query("SELECT book_id FROM books WHERE LOWER(title) = LOWER(%s) AND category_id = %s",
                         (d["title"], d["category_id"]), one=True)
            book_id = book["book_id"] if book else execute(
                "INSERT INTO books(title, category_id) VALUES (%s, %s)", (d["title"], d["category_id"]))
        else:
            book_id = query("SELECT book_id FROM editions WHERE edition_id = %s", (edition_id,), one=True)["book_id"]
            execute("UPDATE books SET title = %s, category_id = %s WHERE book_id = %s",
                    (d["title"], d["category_id"], book_id))
        execute("DELETE FROM book_authors WHERE book_id = %s", (book_id,))
        for name in dict.fromkeys(d["authors"]):          # de-duplicate, keep order
            a = query("SELECT author_id FROM authors WHERE name = %s", (name,), one=True)
            aid = a["author_id"] if a else execute("INSERT INTO authors(name) VALUES (%s)", (name,))
            execute("INSERT INTO book_authors VALUES (%s, %s)", (book_id, aid))
        vals = (d["publisher_id"], d["isbn"], d["format"], d["edition_no"], d["pub_year"],
                d["price"], d["stock_qty"], d["reorder_level"])
        if edition_id is None:
            execute("""INSERT INTO editions(book_id, publisher_id, isbn, format, edition_no, pub_year,
                       price, stock_qty, reorder_level) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)""", (book_id,) + vals)
        else:
            execute("""UPDATE editions SET publisher_id=%s, isbn=%s, format=%s, edition_no=%s, pub_year=%s,
                       price=%s, stock_qty=%s, reorder_level=%s WHERE edition_id=%s""", vals + (edition_id,))
        execute("""DELETE FROM authors WHERE author_id NOT IN (SELECT author_id FROM book_authors)""")


@app.route("/books/new", methods=["GET", "POST"])
def book_new():
    cats, pubs = form_lists()
    if request.method == "POST":
        d, errs = validate_edition(request.form)
        if not errs:
            try:
                save_edition(d)
                flash("Edition added to the catalogue.", "ok")
                return redirect(url_for("books"))
            except Error as e:
                errs.append(friendly(e))
        for e in errs: flash(e, "error")
        return render_template("book_form.html", v=request.form, cats=cats, pubs=pubs, page="books", edit=False)
    return render_template("book_form.html", v={"format": "Paperback", "edition_no": 1, "reorder_level": 5,
                                                "stock_qty": 0, "pub_year": dt.date.today().year},
                           cats=cats, pubs=pubs, page="books", edit=False)


@app.route("/books/<int:eid>/edit", methods=["GET", "POST"])
def book_edit(eid):
    row = query(CATALOGUE_SQL + " WHERE e.edition_id = %s", (eid,), one=True) or abort(404)
    cats, pubs = form_lists()
    if request.method == "POST":
        d, errs = validate_edition(request.form)
        if not errs:
            try:
                save_edition(d, eid)
                flash("Edition updated.", "ok")
                return redirect(url_for("books"))
            except Error as e:
                errs.append(friendly(e))
        for e in errs: flash(e, "error")
        return render_template("book_form.html", v=request.form, cats=cats, pubs=pubs, page="books", edit=True, eid=eid)
    return render_template("book_form.html", v=row, cats=cats, pubs=pubs, page="books", edit=True, eid=eid)


@app.post("/books/<int:eid>/delete")
def book_delete(eid):
    row = query("SELECT book_id FROM editions WHERE edition_id = %s", (eid,), one=True) or abort(404)
    with transaction():
        execute("DELETE FROM editions WHERE edition_id = %s", (eid,))
        execute("DELETE FROM books WHERE book_id = %s AND NOT EXISTS (SELECT 1 FROM editions WHERE book_id = %s)",
                (row["book_id"], row["book_id"]))
        execute("DELETE FROM authors WHERE author_id NOT IN (SELECT author_id FROM book_authors)")
    flash("Edition deleted.", "ok")
    return redirect(url_for("books"))


@app.post("/books/<int:eid>/stock")
def stock_update(eid):
    row = query("SELECT format, stock_qty FROM editions WHERE edition_id = %s", (eid,), one=True) or abort(404)
    delta = to_int(request.form.get("delta"))
    if delta is None or delta == 0:
        flash("Enter a whole number such as 10 (add stock) or -2 (remove stock).", "error")
    elif row["format"] == "Digital":
        flash("Digital editions do not hold physical stock.", "error")
    elif row["stock_qty"] + delta < 0:
        flash(f"Cannot remove {-delta}: only {row['stock_qty']} copies in stock.", "error")
    else:
        execute("UPDATE editions SET stock_qty = stock_qty + %s WHERE edition_id = %s", (delta, eid))
        flash(f"Stock adjusted by {delta:+d}.", "ok")
    return redirect(request.referrer or url_for("books"))


@app.route("/masters", methods=["GET", "POST"])
def masters():
    if request.method == "POST":
        kind, name = request.form.get("kind"), request.form.get("name", "").strip()
        if not name or len(name) > 100:
            flash("Name is required (max 100 characters).", "error")
        elif kind == "category":
            execute("INSERT INTO categories(name) VALUES (%s)", (name,)); flash("Category added.", "ok")
        elif kind == "publisher":
            execute("INSERT INTO publishers(name) VALUES (%s)", (name,)); flash("Publisher added.", "ok")
        return redirect(url_for("masters"))
    return render_template("masters.html", page="masters",
                           cats=query("""SELECT c.*, (SELECT COUNT(*) FROM books b WHERE b.category_id = c.category_id) n
                                           FROM categories c ORDER BY name"""),
                           pubs=query("""SELECT p.*, (SELECT COUNT(*) FROM editions e WHERE e.publisher_id = p.publisher_id) n
                                           FROM publishers p ORDER BY name"""))


# ---------------------------------------------------------------- customers
def validate_customer(f):
    d = {k: f.get(k, "").strip() for k in ("name", "email", "phone", "address")}
    errs = []
    if not d["name"] or len(d["name"]) > 100: errs.append("Name is required (max 100 characters).")
    if not EMAIL_RE.match(d["email"]): errs.append("Enter a valid email address.")
    if not re.fullmatch(r"\+?\d{10,14}", d["phone"]): errs.append("Phone must be 10-14 digits.")
    if len(d["address"]) < 5: errs.append("Enter a delivery address.")
    return d, errs


@app.route("/customers")
def customers():
    q = request.args.get("q", "").strip()
    like = f"%{q}%"
    rows = query("""SELECT h.*, c.phone FROM v_customer_history h JOIN customers c USING (customer_id)
                     WHERE %s = '' OR h.name LIKE %s OR h.email LIKE %s OR c.phone LIKE %s
                     ORDER BY h.name""", (q, like, like, like))
    return render_template("customers.html", rows=rows, q=q, page="customers")


@app.route("/customers/new", methods=["GET", "POST"])
def customer_new():
    if request.method == "POST":
        d, errs = validate_customer(request.form)
        if not errs:
            try:
                execute("INSERT INTO customers(name,email,phone,address) VALUES (%s,%s,%s,%s)",
                        (d["name"], d["email"], d["phone"], d["address"]))
                flash("Customer added.", "ok")
                return redirect(url_for("customers"))
            except Error as e:
                errs.append(friendly(e))
        for e in errs: flash(e, "error")
        return render_template("customer_form.html", v=request.form, page="customers", edit=False)
    return render_template("customer_form.html", v={}, page="customers", edit=False)


@app.route("/customers/<int:cid>")
def customer_detail(cid):
    c = query("SELECT * FROM customers WHERE customer_id = %s", (cid,), one=True) or abort(404)
    orders = query("SELECT * FROM v_order_summary WHERE customer_id = %s ORDER BY order_date DESC", (cid,))
    return render_template("customer_detail.html", c=c, orders=orders, page="customers")


@app.route("/customers/<int:cid>/edit", methods=["GET", "POST"])
def customer_edit(cid):
    c = query("SELECT * FROM customers WHERE customer_id = %s", (cid,), one=True) or abort(404)
    if request.method == "POST":
        d, errs = validate_customer(request.form)
        if not errs:
            try:
                execute("UPDATE customers SET name=%s,email=%s,phone=%s,address=%s WHERE customer_id=%s",
                        (d["name"], d["email"], d["phone"], d["address"], cid))
                flash("Customer updated.", "ok")
                return redirect(url_for("customer_detail", cid=cid))
            except Error as e:
                errs.append(friendly(e))
        for e in errs: flash(e, "error")
        return render_template("customer_form.html", v=request.form, page="customers", edit=True, cid=cid)
    return render_template("customer_form.html", v=c, page="customers", edit=True, cid=cid)


@app.post("/customers/<int:cid>/delete")
def customer_delete(cid):
    execute("DELETE FROM customers WHERE customer_id = %s", (cid,))
    flash("Customer deleted.", "ok")
    return redirect(url_for("customers"))


# ---------------------------------------------------------------- orders
@app.route("/orders")
def orders():
    status = request.args.get("status", "")
    q = request.args.get("q", "").strip()
    rows = query("""SELECT * FROM v_order_summary
                     WHERE (%s = '' OR status = %s) AND (%s = '' OR customer_name LIKE %s OR order_id = %s)
                     ORDER BY order_date DESC""", (status, status, q, f"%{q}%", to_int(q, 0)))
    return render_template("orders.html", rows=rows, status=status, q=q, page="orders")


@app.route("/orders/new", methods=["GET", "POST"])
def order_new():
    custs = query("SELECT customer_id, name, email FROM customers ORDER BY name")
    eds = query("""SELECT e.edition_id, b.title, e.format, e.isbn, e.price, e.stock_qty
                     FROM editions e JOIN books b ON b.book_id = e.book_id
                    ORDER BY b.title, e.format""")
    if request.method == "POST":
        cid = to_int(request.form.get("customer_id"))
        method = request.form.get("method")
        cart = {}
        for eid, qty in zip(request.form.getlist("edition_id"), request.form.getlist("qty")):
            eid, qty = to_int(eid), to_int(qty)
            if eid and qty and qty > 0:
                cart[eid] = cart.get(eid, 0) + qty            # merge duplicate lines
        errs = []
        if not cid: errs.append("Choose a customer.")
        if method not in METHODS: errs.append("Choose a payment method.")
        if not cart: errs.append("Add at least one book with quantity 1 or more.")
        if not errs:
            try:
                oid = place_order(cid, method, cart)
                flash(f"Order #{oid} placed, paid and invoiced.", "ok")
                return redirect(url_for("order_detail", oid=oid))
            except Error as e:
                errs.append(friendly(e))
        for e in errs: flash(e, "error")
    return render_template("order_new.html", custs=custs, eds=eds, page="orders")


def place_order(cid, method, cart):
    """Order + items + payment + invoice in ONE transaction. A trigger rejects over-stock lines,
    which rolls the whole order back (nothing half-saved)."""
    with transaction():
        oid = execute("INSERT INTO orders(customer_id, status) VALUES (%s, 'Placed')", (cid,))
        total, physical = Decimal(0), False
        for eid, qty in cart.items():
            e = query("SELECT price, format FROM editions WHERE edition_id = %s", (eid,), one=True)
            if not e:
                raise Error(msg="Edition does not exist", errno=1644)
            execute("INSERT INTO order_items(order_id, edition_id, quantity, unit_price) VALUES (%s,%s,%s,%s)",
                    (oid, eid, qty, e["price"]))                # trigger checks + reduces stock
            total += e["price"] * qty
            physical = physical or e["format"] != "Digital"
        execute("INSERT INTO payments(order_id, amount, method, status) VALUES (%s,%s,%s,'Paid')", (oid, total, method))
        execute("INSERT INTO invoices(order_id, invoice_no) VALUES (%s,%s)",
                (oid, f"INV-{dt.date.today():%Y%m}-{oid:05d}"))
        if not physical:                                       # digital-only orders need no shipping
            execute("UPDATE orders SET status = 'Delivered' WHERE order_id = %s", (oid,))
    return oid


def load_order(oid):
    o = query("SELECT * FROM v_order_summary WHERE order_id = %s", (oid,), one=True) or abort(404)
    cust = query("SELECT * FROM customers WHERE customer_id = %s", (o["customer_id"],), one=True)
    items = query("""SELECT oi.order_item_id, oi.quantity, oi.unit_price, oi.quantity * oi.unit_price AS line_total,
                            b.title, e.format, e.isbn,
                            (SELECT COALESCE(SUM(r.quantity),0) FROM returns r WHERE r.order_item_id = oi.order_item_id) AS returned
                       FROM order_items oi JOIN editions e ON e.edition_id = oi.edition_id
                       JOIN books b ON b.book_id = e.book_id WHERE oi.order_id = %s ORDER BY b.title""", (oid,))
    ship = query("SELECT * FROM shipments WHERE order_id = %s", (oid,), one=True)
    pay = query("SELECT * FROM payments WHERE order_id = %s", (oid,), one=True)
    inv = query("SELECT * FROM invoices WHERE order_id = %s", (oid,), one=True)
    return o, cust, items, ship, pay, inv


@app.route("/orders/<int:oid>")
def order_detail(oid):
    o, cust, items, ship, pay, inv = load_order(oid)
    return render_template("order_detail.html", o=o, c=cust, items=items, ship=ship, pay=pay, inv=inv, page="orders")


@app.route("/orders/<int:oid>/invoice")
def invoice(oid):
    o, cust, items, ship, pay, inv = load_order(oid)
    return render_template("invoice.html", o=o, c=cust, items=items, pay=pay, inv=inv)


@app.post("/orders/<int:oid>/ship")
def order_ship(oid):
    o = query("SELECT status FROM orders WHERE order_id = %s", (oid,), one=True) or abort(404)
    carrier, track = request.form.get("carrier", "").strip(), request.form.get("tracking_no", "").strip()
    if o["status"] != "Placed":
        flash("Only orders in 'Placed' status can be shipped.", "error")
    elif not carrier or not track:
        flash("Carrier and tracking number are required.", "error")
    else:
        with transaction():
            execute("INSERT INTO shipments(order_id, carrier, tracking_no, shipped_date) VALUES (%s,%s,%s,CURDATE())",
                    (oid, carrier, track))
            execute("UPDATE orders SET status = 'Shipped' WHERE order_id = %s", (oid,))
        flash("Shipment created.", "ok")
    return redirect(url_for("order_detail", oid=oid))


@app.post("/orders/<int:oid>/deliver")
def order_deliver(oid):
    o = query("SELECT status FROM orders WHERE order_id = %s", (oid,), one=True) or abort(404)
    if o["status"] != "Shipped":
        flash("Only shipped orders can be marked delivered.", "error")
    else:
        with transaction():
            execute("UPDATE shipments SET delivered_date = CURDATE() WHERE order_id = %s", (oid,))
            execute("UPDATE orders SET status = 'Delivered' WHERE order_id = %s", (oid,))
        flash("Order marked as delivered.", "ok")
    return redirect(url_for("order_detail", oid=oid))


@app.post("/orders/<int:oid>/cancel")
def order_cancel(oid):
    o = query("SELECT status FROM orders WHERE order_id = %s", (oid,), one=True) or abort(404)
    if o["status"] != "Placed":
        flash("Only orders that have not shipped can be cancelled.", "error")
    else:
        with transaction():                                    # put copies back on the shelf
            execute("""UPDATE editions e JOIN order_items oi ON oi.edition_id = e.edition_id
                          SET e.stock_qty = e.stock_qty + oi.quantity
                        WHERE oi.order_id = %s AND e.format <> 'Digital'""", (oid,))
            execute("UPDATE orders SET status = 'Cancelled' WHERE order_id = %s", (oid,))
            execute("UPDATE payments SET status = 'Refunded' WHERE order_id = %s", (oid,))
        flash("Order cancelled, stock restored and payment refunded.", "ok")
    return redirect(url_for("order_detail", oid=oid))


@app.post("/orders/<int:oid>/return")
def order_return(oid):
    item_id, qty = to_int(request.form.get("order_item_id")), to_int(request.form.get("quantity"))
    reason = request.form.get("reason", "").strip()
    if not item_id or not qty or qty < 1 or len(reason) < 3:
        flash("Choose an item, a quantity of 1 or more and give a reason.", "error")
        return redirect(url_for("order_detail", oid=oid))
    item = query("SELECT unit_price FROM order_items WHERE order_item_id = %s AND order_id = %s",
                 (item_id, oid), one=True) or abort(404)
    execute("INSERT INTO returns(order_item_id, quantity, reason, return_date, refund_amount) "
            "VALUES (%s,%s,%s,CURDATE(),%s)", (item_id, qty, reason, item["unit_price"] * qty))
    flash("Return recorded, refund calculated and stock restored.", "ok")
    return redirect(url_for("order_detail", oid=oid))


@app.route("/returns")
def returns():
    rows = query("""SELECT r.*, b.title, e.format, oi.order_id, c.name AS customer_name
                      FROM returns r JOIN order_items oi ON oi.order_item_id = r.order_item_id
                      JOIN editions e ON e.edition_id = oi.edition_id JOIN books b ON b.book_id = e.book_id
                      JOIN orders o ON o.order_id = oi.order_id JOIN customers c ON c.customer_id = o.customer_id
                     ORDER BY r.return_date DESC, r.return_id DESC""")
    return render_template("returns.html", rows=rows, page="returns")


# ---------------------------------------------------------------- reports
@app.route("/reports")
def reports():
    cat = query("SELECT * FROM v_category_sales ORDER BY revenue DESC")
    return render_template("reports.html", page="reports", cat=cat,
        max_cat=max([c["revenue"] for c in cat] + [1]),
        author=query("SELECT * FROM v_author_sales ORDER BY revenue DESC LIMIT 10"),
        popular=query("SELECT * FROM v_popular_books ORDER BY units_sold DESC, revenue DESC LIMIT 10"),
        stock=query("SELECT * FROM v_stock_report ORDER BY FIELD(stock_status,'OUT','LOW','OK','N/A'), stock_qty"),
        custs=query("SELECT * FROM v_customer_history ORDER BY total_spent DESC LIMIT 10"),
        rets=query("""SELECT b.title, SUM(r.quantity) AS qty, SUM(r.refund_amount) AS refunded
                        FROM returns r JOIN order_items oi ON oi.order_item_id = r.order_item_id
                        JOIN editions e ON e.edition_id = oi.edition_id JOIN books b ON b.book_id = e.book_id
                       GROUP BY b.book_id, b.title ORDER BY refunded DESC"""),
        monthly=query("""SELECT DATE_FORMAT(order_date,'%Y-%m') AS month, COUNT(*) AS orders, SUM(total_amount) AS revenue
                           FROM v_order_summary WHERE status <> 'Cancelled' GROUP BY month ORDER BY month DESC"""))


if __name__ == "__main__":
    app.run(debug=True)
