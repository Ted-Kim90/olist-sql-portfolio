-- Olist SQL 포트폴리오 프로젝트: 분석 쿼리 5선
USE olist;

-- ============================================================
-- 1. 카테고리별 매출 순위
-- 왜 물었나: 어떤 상품 카테고리가 매출을 견인하는지 파악하면
--            재고/마케팅 우선순위를 정할 수 있음
-- 발견: beleza_saude(뷰티/건강) 1위(약 126만),
--       relogios_presentes(시계/선물) 2위(약 121만)
-- ============================================================
SELECT p.product_category_name, COUNT(DISTINCT oi.order_id) AS order_count,
       ROUND(SUM(oi.price), 2) AS total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY total_revenue DESC
LIMIT 10;


-- ============================================================
-- 2. 월별 매출 추이
-- 왜 물었나: 서비스가 시간에 따라 어떻게 성장했는지, 계절성이 있는지 확인
-- 발견: 2016-09 2건(207.86) -> 2017-07 3,946건(492,287.30)으로 급성장
-- ============================================================
SELECT SUBSTRING(o.order_purchase_timestamp, 1, 7) AS ym,
       COUNT(DISTINCT o.order_id) AS order_count,
       ROUND(SUM(oi.price), 2) AS total_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY ym
ORDER BY ym;


-- ============================================================
-- 3. 재구매 고객 비율
-- 왜 물었나: 고객 충성도/리텐션 수준을 파악하여 CRM·마케팅 전략에 활용
-- 발견: 전체 96,096명 중 재구매 2,997명 (3.12%)
-- ============================================================
SELECT COUNT(*) AS total,
       SUM(CASE WHEN cnt > 1 THEN 1 ELSE 0 END) AS repeaters,
       ROUND(SUM(CASE WHEN cnt > 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct
FROM (
  SELECT c.customer_unique_id AS cid, COUNT(DISTINCT o.order_id) AS cnt
  FROM customers c
  JOIN orders o ON c.customer_id = o.customer_id
  GROUP BY cid
) t;


-- ============================================================
-- 4. 배송 소요일과 리뷰 평점의 관계
-- 왜 물었나: 배송 속도가 고객 만족도(평점)에 실제로 영향을 주는지 검증
-- 발견: 1점=21.3일, 2점=16.6일, 3점=14.2일, 4점=12.3일, 5점=10.6일
--       -> 배송이 빠를수록 평점이 높은 뚜렷한 역상관 관계
-- ============================================================
SELECT review_score,
       ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS avgdays,
       COUNT(*) AS cnt
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY review_score
ORDER BY review_score;


-- ============================================================
-- 5. 주문 비중이 높은 상위 도시
-- 왜 물었나: 물류센터 위치, 지역별 마케팅 예산 배분에 활용할 수 있는 지역 데이터 파악
-- 발견: 상파울루 15.63%(15,540건) 1위, 리우데자네이루 6.92% 2위
-- ============================================================
SELECT c.customer_city AS city, COUNT(DISTINCT o.order_id) AS cnt,
       ROUND(COUNT(DISTINCT o.order_id) / (SELECT COUNT(*) FROM orders) * 100, 2) AS pct
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY city
ORDER BY cnt DESC
LIMIT 10;
