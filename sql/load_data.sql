-- Olist SQL 포트폴리오 프로젝트: CSV 데이터 적재
-- MySQL Workbench 26.x에는 기존의 GUI "Table Data Import Wizard"가 없어,
-- LOAD DATA INFILE 문으로 직접 CSV를 적재했습니다.
--
-- 사전 준비:
--   1) SHOW VARIABLES LIKE 'secure_file_priv'; 로 확인한 폴더(예: C:\ProgramData\MySQL\MySQL Server 8.0\Uploads\)에
--      CSV 파일을 복사해 둘 것
--   2) 리뷰 CSV는 텍스트 안에 줄바꿈이 포함되어 있어 scripts/clean_reviews.py로
--      먼저 정제한 파일(olist_order_reviews_clean2.csv)을 사용할 것

USE olist;

-- 1) customers
LOAD DATA INFILE 'olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 2) orders (빈 날짜 문자열 -> NULL 처리)
LOAD DATA INFILE 'olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, customer_id, order_status,
 @purchase, @approved, @carrier, @delivered, @estimated)
SET
  order_purchase_timestamp = NULLIF(@purchase, ''),
  order_approved_at = NULLIF(@approved, ''),
  order_delivered_carrier_date = NULLIF(@carrier, ''),
  order_delivered_customer_date = NULLIF(@delivered, ''),
  order_estimated_delivery_date = NULLIF(@estimated, '');

-- 3) order_items
LOAD DATA INFILE 'olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 4) order_reviews (정제된 clean2.csv 사용, 빈 날짜 -> NULL 처리)
LOAD DATA INFILE 'olist_order_reviews_clean2.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(review_id, order_id, review_score, review_comment_title, review_comment_message,
 @creation, @answer)
SET
  review_creation_date = NULLIF(@creation, ''),
  review_answer_timestamp = NULLIF(@answer, '');

-- 5) products
LOAD DATA INFILE 'olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 적재 검증
SELECT COUNT(*) FROM customers;      -- 99,441
SELECT COUNT(*) FROM orders;         -- 99,441
SELECT COUNT(*) FROM order_items;    -- 112,650
SELECT COUNT(*) FROM order_reviews;  -- 99,224
SELECT COUNT(*) FROM products;       -- 32,951
