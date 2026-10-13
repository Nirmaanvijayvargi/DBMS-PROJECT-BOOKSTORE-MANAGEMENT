-- Sample / test data for the Bookstore DBMS.  Run AFTER schema.sql:
--   mysql -u root -p bookstore < sql/test_data.sql
USE bookstore;

INSERT INTO categories(name) VALUES ('Fiction'),('Non-Fiction'),('Science & Technology'),('Self-Help'),('Children'),('History');
INSERT INTO publishers(name,email) VALUES ('Penguin Random House India','contact@penguin.example'),('HarperCollins India','contact@harpercollins.example'),('Oxford University Press','contact@oxford.example'),('Pearson India','contact@pearson.example'),('Scholastic India','contact@scholastic.example'),('Rupa Publications','contact@rupa.example'),('McGraw Hill India','contact@mcgraw.example');
INSERT INTO authors(name) VALUES ('Paulo Coelho'),('Arundhati Roy'),('A. P. J. Abdul Kalam'),('Arun Tiwari'),('Yuval Noah Harari'),('James Clear'),('Thomas H. Cormen'),('Charles E. Leiserson'),('Ronald L. Rivest'),('Clifford Stein'),('Abraham Silberschatz'),('Henry F. Korth'),('S. Sudarshan'),('J. K. Rowling'),('Jawaharlal Nehru'),('Hector Garcia'),('Francesc Miralles'),('Robert C. Martin'),('Ruskin Bond');
INSERT INTO books(title,category_id) VALUES ('The Alchemist',(SELECT category_id FROM categories WHERE name='Fiction'));
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='The Alchemist' AND a.name='Paulo Coelho';
INSERT INTO books(title,category_id) VALUES ('The God of Small Things',(SELECT category_id FROM categories WHERE name='Fiction'));
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='The God of Small Things' AND a.name='Arundhati Roy';
INSERT INTO books(title,category_id) VALUES ('Wings of Fire',(SELECT category_id FROM categories WHERE name='Non-Fiction'));
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Wings of Fire' AND a.name='A. P. J. Abdul Kalam';
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Wings of Fire' AND a.name='Arun Tiwari';
INSERT INTO books(title,category_id) VALUES ('Sapiens',(SELECT category_id FROM categories WHERE name='History'));
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Sapiens' AND a.name='Yuval Noah Harari';
INSERT INTO books(title,category_id) VALUES ('Atomic Habits',(SELECT category_id FROM categories WHERE name='Self-Help'));
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Atomic Habits' AND a.name='James Clear';
INSERT INTO books(title,category_id) VALUES ('Introduction to Algorithms',(SELECT category_id FROM categories WHERE name='Science & Technology'));
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Introduction to Algorithms' AND a.name='Thomas H. Cormen';
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Introduction to Algorithms' AND a.name='Charles E. Leiserson';
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Introduction to Algorithms' AND a.name='Ronald L. Rivest';
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Introduction to Algorithms' AND a.name='Clifford Stein';
INSERT INTO books(title,category_id) VALUES ('Database System Concepts',(SELECT category_id FROM categories WHERE name='Science & Technology'));
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Database System Concepts' AND a.name='Abraham Silberschatz';
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Database System Concepts' AND a.name='Henry F. Korth';
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Database System Concepts' AND a.name='S. Sudarshan';
INSERT INTO books(title,category_id) VALUES ('Harry Potter and the Philosopher''s Stone',(SELECT category_id FROM categories WHERE name='Children'));
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Harry Potter and the Philosopher''s Stone' AND a.name='J. K. Rowling';
INSERT INTO books(title,category_id) VALUES ('The Discovery of India',(SELECT category_id FROM categories WHERE name='History'));
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='The Discovery of India' AND a.name='Jawaharlal Nehru';
INSERT INTO books(title,category_id) VALUES ('Ikigai',(SELECT category_id FROM categories WHERE name='Self-Help'));
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Ikigai' AND a.name='Hector Garcia';
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Ikigai' AND a.name='Francesc Miralles';
INSERT INTO books(title,category_id) VALUES ('Clean Code',(SELECT category_id FROM categories WHERE name='Science & Technology'));
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='Clean Code' AND a.name='Robert C. Martin';
INSERT INTO books(title,category_id) VALUES ('The Room on the Roof',(SELECT category_id FROM categories WHERE name='Fiction'));
INSERT INTO book_authors SELECT b.book_id,a.author_id FROM books b,authors a WHERE b.title='The Room on the Roof' AND a.name='Ruskin Bond';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780101000116','Paperback',1,2015,299,40,5 FROM books b,publishers p WHERE b.title='The Alchemist' AND p.name='HarperCollins India';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780114000424','Digital',1,2018,149,0,5 FROM books b,publishers p WHERE b.title='The Alchemist' AND p.name='HarperCollins India';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780134000732','Paperback',2,2002,399,25,5 FROM books b,publishers p WHERE b.title='The God of Small Things' AND p.name='Penguin Random House India';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780154001047','Paperback',1,1999,275,30,5 FROM books b,publishers p WHERE b.title='Wings of Fire' AND p.name='Rupa Publications';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780167001355','Hardcover',1,1999,599,4,5 FROM books b,publishers p WHERE b.title='Wings of Fire' AND p.name='Rupa Publications';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780187001663','Paperback',1,2015,450,35,5 FROM books b,publishers p WHERE b.title='Sapiens' AND p.name='Penguin Random House India';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780200001977','Digital',1,2016,225,0,5 FROM books b,publishers p WHERE b.title='Sapiens' AND p.name='Penguin Random House India';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780220002282','Paperback',1,2018,499,50,5 FROM books b,publishers p WHERE b.title='Atomic Habits' AND p.name='Penguin Random House India';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780240002590','Hardcover',3,2009,1899,12,5 FROM books b,publishers p WHERE b.title='Introduction to Algorithms' AND p.name='Pearson India';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780253002907','Paperback',3,2009,1299,3,5 FROM books b,publishers p WHERE b.title='Introduction to Algorithms' AND p.name='Pearson India';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780273003212','Paperback',6,2011,899,20,5 FROM books b,publishers p WHERE b.title='Database System Concepts' AND p.name='McGraw Hill India';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780293003520','Paperback',1,1998,349,45,5 FROM books b,publishers p WHERE b.title='Harry Potter and the Philosopher''s Stone' AND p.name='Scholastic India';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780306003837','Hardcover',1,1998,799,10,5 FROM books b,publishers p WHERE b.title='Harry Potter and the Philosopher''s Stone' AND p.name='Scholastic India';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780326004142','Paperback',1,1946,425,15,5 FROM books b,publishers p WHERE b.title='The Discovery of India' AND p.name='Oxford University Press';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780346004450','Paperback',1,2017,350,28,5 FROM books b,publishers p WHERE b.title='Ikigai' AND p.name='Penguin Random House India';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780366004768','Paperback',1,2008,749,18,5 FROM books b,publishers p WHERE b.title='Clean Code' AND p.name='Pearson India';
INSERT INTO editions(book_id,publisher_id,isbn,format,edition_no,pub_year,price,stock_qty,reorder_level) SELECT b.book_id,p.publisher_id,'9780386005073','Paperback',1,1956,225,22,5 FROM books b,publishers p WHERE b.title='The Room on the Roof' AND p.name='Rupa Publications';
INSERT INTO customers(name,email,phone,address) VALUES ('Aarav Sharma','aarav.sharma@example.com','9876500001','12 MG Road, Bengaluru 560001'),('Priya Reddy','priya.reddy@example.com','9876500002','45 Banjara Hills, Hyderabad 500034'),('Rohan Mehta','rohan.mehta@example.com','9876500003','8 Linking Road, Mumbai 400050'),('Ananya Iyer','ananya.iyer@example.com','9876500004','22 Anna Nagar, Chennai 600040'),('Vikram Singh','vikram.singh@example.com','9876500005','101 Connaught Place, New Delhi 110001'),('Sneha Kulkarni','sneha.kulkarni@example.com','9876500006','7 FC Road, Pune 411004'),('Karthik Nair','karthik.nair@example.com','9876500007','3 MG Road, Kochi 682016'),('Divya Patel','divya.patel@example.com','9876500008','19 CG Road, Ahmedabad 380009');

-- order 1
INSERT INTO orders(customer_id,order_date,status) VALUES (1,DATE_SUB(NOW(),INTERVAL 40 DAY),'Delivered');
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780220002282';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (1,@e,1,@p);
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780101000116';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (1,@e,2,@p);
INSERT INTO payments(order_id,amount,method,status,paid_at) SELECT 1,SUM(quantity*unit_price),'UPI','Paid',DATE_SUB(NOW(),INTERVAL 40 DAY) FROM order_items WHERE order_id=1;
INSERT INTO invoices(order_id,invoice_no,issued_at) VALUES (1,CONCAT('INV-',DATE_FORMAT(DATE_SUB(NOW(),INTERVAL 40 DAY),'%Y%m'),'-',LPAD(1,5,'0')),DATE_SUB(NOW(),INTERVAL 40 DAY));
INSERT INTO shipments(order_id,carrier,tracking_no,shipped_date,delivered_date) VALUES (1,'BlueDart','BD700137',DATE_SUB(CURDATE(),INTERVAL 38 DAY),DATE_SUB(CURDATE(),INTERVAL 34 DAY));

-- order 2
INSERT INTO orders(customer_id,order_date,status) VALUES (2,DATE_SUB(NOW(),INTERVAL 30 DAY),'Delivered');
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780240002590';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (2,@e,1,@p);
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780273003212';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (2,@e,1,@p);
INSERT INTO payments(order_id,amount,method,status,paid_at) SELECT 2,SUM(quantity*unit_price),'Card','Paid',DATE_SUB(NOW(),INTERVAL 30 DAY) FROM order_items WHERE order_id=2;
INSERT INTO invoices(order_id,invoice_no,issued_at) VALUES (2,CONCAT('INV-',DATE_FORMAT(DATE_SUB(NOW(),INTERVAL 30 DAY),'%Y%m'),'-',LPAD(2,5,'0')),DATE_SUB(NOW(),INTERVAL 30 DAY));
INSERT INTO shipments(order_id,carrier,tracking_no,shipped_date,delivered_date) VALUES (2,'BlueDart','BD700274',DATE_SUB(CURDATE(),INTERVAL 28 DAY),DATE_SUB(CURDATE(),INTERVAL 24 DAY));

-- order 3
INSERT INTO orders(customer_id,order_date,status) VALUES (3,DATE_SUB(NOW(),INTERVAL 20 DAY),'Delivered');
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780187001663';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (3,@e,1,@p);
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780200001977';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (3,@e,1,@p);
INSERT INTO payments(order_id,amount,method,status,paid_at) SELECT 3,SUM(quantity*unit_price),'NetBanking','Paid',DATE_SUB(NOW(),INTERVAL 20 DAY) FROM order_items WHERE order_id=3;
INSERT INTO invoices(order_id,invoice_no,issued_at) VALUES (3,CONCAT('INV-',DATE_FORMAT(DATE_SUB(NOW(),INTERVAL 20 DAY),'%Y%m'),'-',LPAD(3,5,'0')),DATE_SUB(NOW(),INTERVAL 20 DAY));
INSERT INTO shipments(order_id,carrier,tracking_no,shipped_date,delivered_date) VALUES (3,'BlueDart','BD700411',DATE_SUB(CURDATE(),INTERVAL 18 DAY),DATE_SUB(CURDATE(),INTERVAL 15 DAY));

-- order 4
INSERT INTO orders(customer_id,order_date,status) VALUES (4,DATE_SUB(NOW(),INTERVAL 12 DAY),'Shipped');
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780293003520';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (4,@e,2,@p);
INSERT INTO payments(order_id,amount,method,status,paid_at) SELECT 4,SUM(quantity*unit_price),'UPI','Paid',DATE_SUB(NOW(),INTERVAL 12 DAY) FROM order_items WHERE order_id=4;
INSERT INTO invoices(order_id,invoice_no,issued_at) VALUES (4,CONCAT('INV-',DATE_FORMAT(DATE_SUB(NOW(),INTERVAL 12 DAY),'%Y%m'),'-',LPAD(4,5,'0')),DATE_SUB(NOW(),INTERVAL 12 DAY));
INSERT INTO shipments(order_id,carrier,tracking_no,shipped_date,delivered_date) VALUES (4,'BlueDart','BD700548',DATE_SUB(CURDATE(),INTERVAL 10 DAY),NULL);

-- order 5
INSERT INTO orders(customer_id,order_date,status) VALUES (5,DATE_SUB(NOW(),INTERVAL 6 DAY),'Placed');
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780326004142';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (5,@e,1,@p);
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780346004450';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (5,@e,1,@p);
INSERT INTO payments(order_id,amount,method,status,paid_at) SELECT 5,SUM(quantity*unit_price),'COD','Paid',DATE_SUB(NOW(),INTERVAL 6 DAY) FROM order_items WHERE order_id=5;
INSERT INTO invoices(order_id,invoice_no,issued_at) VALUES (5,CONCAT('INV-',DATE_FORMAT(DATE_SUB(NOW(),INTERVAL 6 DAY),'%Y%m'),'-',LPAD(5,5,'0')),DATE_SUB(NOW(),INTERVAL 6 DAY));

-- order 6
INSERT INTO orders(customer_id,order_date,status) VALUES (6,DATE_SUB(NOW(),INTERVAL 5 DAY),'Placed');
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780134000732';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (6,@e,1,@p);
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780366004768';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (6,@e,1,@p);
INSERT INTO payments(order_id,amount,method,status,paid_at) SELECT 6,SUM(quantity*unit_price),'Card','Paid',DATE_SUB(NOW(),INTERVAL 5 DAY) FROM order_items WHERE order_id=6;
INSERT INTO invoices(order_id,invoice_no,issued_at) VALUES (6,CONCAT('INV-',DATE_FORMAT(DATE_SUB(NOW(),INTERVAL 5 DAY),'%Y%m'),'-',LPAD(6,5,'0')),DATE_SUB(NOW(),INTERVAL 5 DAY));

-- order 7
INSERT INTO orders(customer_id,order_date,status) VALUES (7,DATE_SUB(NOW(),INTERVAL 9 DAY),'Cancelled');
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780154001047';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (7,@e,2,@p);
INSERT INTO payments(order_id,amount,method,status,paid_at) SELECT 7,SUM(quantity*unit_price),'UPI','Refunded',DATE_SUB(NOW(),INTERVAL 9 DAY) FROM order_items WHERE order_id=7;
INSERT INTO invoices(order_id,invoice_no,issued_at) VALUES (7,CONCAT('INV-',DATE_FORMAT(DATE_SUB(NOW(),INTERVAL 9 DAY),'%Y%m'),'-',LPAD(7,5,'0')),DATE_SUB(NOW(),INTERVAL 9 DAY));
UPDATE editions e JOIN order_items oi ON oi.edition_id=e.edition_id SET e.stock_qty=e.stock_qty+oi.quantity WHERE oi.order_id=7 AND e.format<>'Digital';

-- order 8
INSERT INTO orders(customer_id,order_date,status) VALUES (1,DATE_SUB(NOW(),INTERVAL 3 DAY),'Placed');
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780386005073';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (8,@e,3,@p);
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780114000424';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (8,@e,1,@p);
INSERT INTO payments(order_id,amount,method,status,paid_at) SELECT 8,SUM(quantity*unit_price),'UPI','Paid',DATE_SUB(NOW(),INTERVAL 3 DAY) FROM order_items WHERE order_id=8;
INSERT INTO invoices(order_id,invoice_no,issued_at) VALUES (8,CONCAT('INV-',DATE_FORMAT(DATE_SUB(NOW(),INTERVAL 3 DAY),'%Y%m'),'-',LPAD(8,5,'0')),DATE_SUB(NOW(),INTERVAL 3 DAY));

-- order 9
INSERT INTO orders(customer_id,order_date,status) VALUES (2,DATE_SUB(NOW(),INTERVAL 2 DAY),'Placed');
SELECT edition_id,price INTO @e,@p FROM editions WHERE isbn='9780167001355';
INSERT INTO order_items(order_id,edition_id,quantity,unit_price) VALUES (9,@e,1,@p);
INSERT INTO payments(order_id,amount,method,status,paid_at) SELECT 9,SUM(quantity*unit_price),'NetBanking','Paid',DATE_SUB(NOW(),INTERVAL 2 DAY) FROM order_items WHERE order_id=9;
INSERT INTO invoices(order_id,invoice_no,issued_at) VALUES (9,CONCAT('INV-',DATE_FORMAT(DATE_SUB(NOW(),INTERVAL 2 DAY),'%Y%m'),'-',LPAD(9,5,'0')),DATE_SUB(NOW(),INTERVAL 2 DAY));

-- a return inside the 30-day window
SELECT oi.order_item_id,oi.unit_price INTO @oi,@up FROM order_items oi JOIN editions e USING(edition_id) WHERE oi.order_id=1 AND e.isbn='9780101000116';
INSERT INTO returns(order_item_id,quantity,reason,return_date,refund_amount) VALUES (@oi,1,'Pages misprinted',DATE_SUB(CURDATE(),INTERVAL 20 DAY),@up);
