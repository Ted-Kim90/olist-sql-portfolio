# SQL 포트폴리오 프로젝트: 브라질 이커머스(Olist) 데이터 분석

**김태훈 | 2026년 9월**

MySQL로 실제 공개 이커머스 데이터셋을 직접 적재·정제하고, 비즈니스 질문에 답하는 SQL 분석을 수행한 개인 포트폴리오 프로젝트입니다.

---

## 프로젝트 개요

- **데이터셋**: [Olist Brazilian E-commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle)
  - 실제 브라질 이커머스 마켓플레이스의 2016~2018년 주문 데이터
  - 고객, 주문, 주문상품, 리뷰, 상품 정보 등 5개 테이블, 총 40만 건 이상의 레코드
- **사용 도구**: MySQL 8.0, MySQL Workbench, Python(pandas) — 데이터 정제용
- **목표**: 실무형 SQL 역량(테이블 설계, 조인, 집계, 데이터 정제)을 직접 증명하는 개인 프로젝트

## 폴더 구조

```
.
├── README.md              이 파일
├── sql/
│   ├── schema.sql          5개 테이블 생성 DDL
│   └── queries.sql         5개 분석 쿼리 (설명 포함)
└── scripts/
    └── clean_reviews.py    리뷰 CSV 정제 스크립트 (Python/pandas)
```

## 데이터 준비 과정에서 겪은 이슈와 해결

실제 공개 데이터셋은 깔끔하지 않았습니다. 이 과정 자체가 실무에서 자주 마주치는 "데이터 품질 문제 대응 경험"이라 면접에서 이야기하기 좋은 포인트입니다.

- **빈 날짜값 처리**: 배송 미완료 주문의 빈 날짜값(`''`)이 `DATETIME` 컬럼에 들어가며 타입 에러 발생 → `LOAD DATA INFILE`의 변수 캡처 + `NULLIF(@var, '')` 패턴으로 빈 문자열을 NULL로 변환하여 해결
- **CSV 줄바꿈 문제**: 리뷰 텍스트(`review_comment_message`)에 포함된 줄바꿈이 `LOAD DATA INFILE`의 행 구분(`LINES TERMINATED BY`)을 깨뜨려, 약 99,224건 중 일부만 정상 적재되고 이후 모든 행의 컬럼이 밀리는 문제 발생 → PowerShell 기반 정제를 먼저 시도했으나 부분적으로만 해결(약 9,600건 복구) → Python(pandas)의 `read_csv`로 원본을 강건하게 재파싱하고, 줄바꿈을 공백으로 치환한 뒤 재적재하여 **99,224건 전량 정상 적재** 성공 (`scripts/clean_reviews.py` 참고)
- 최종적으로 5개 테이블 모두 정상 적재 완료

| 테이블 | 설명 | 건수 |
|---|---|---|
| customers | 고객 | 99,441 |
| orders | 주문 | 99,441 |
| order_items | 주문상품 | 112,650 |
| order_reviews | 리뷰 | 99,224 |
| products | 상품 | 32,951 |

---

## 분석 1. 카테고리별 매출 순위

**왜 물었나**: 어떤 상품 카테고리가 매출을 견인하는지 파악하면 재고/마케팅 우선순위를 정할 수 있음

```sql
SELECT p.product_category_name, COUNT(DISTINCT oi.order_id) AS order_count,
       ROUND(SUM(oi.price), 2) AS total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY total_revenue DESC
LIMIT 10;
```

**발견**: `beleza_saude`(뷰티/건강)가 매출 1위(약 126만), `relogios_presentes`(시계/선물)가 2위(약 121만)로 뷰티·선물 카테고리가 매출을 견인. 상위 3개 카테고리가 전체 상위 10개 매출의 약 35%를 차지.

---

## 분석 2. 월별 매출 추이

**왜 물었나**: 서비스가 시간에 따라 어떻게 성장했는지, 계절성이 있는지 확인

```sql
SELECT SUBSTRING(o.order_purchase_timestamp, 1, 7) AS ym,
       COUNT(DISTINCT o.order_id) AS order_count,
       ROUND(SUM(oi.price), 2) AS total_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY ym
ORDER BY ym;
```

**발견**: 2016년 9월 2건(207.86) → 2017년 7월 3,946건(492,287.30)으로 폭발적 성장. 스타트업 초기 급성장 곡선이 뚜렷하게 나타남.

---

## 분석 3. 재구매 고객 비율

**왜 물었나**: 고객 충성도/리텐션 수준을 파악하여 CRM·마케팅 전략에 활용

```sql
SELECT COUNT(*) AS total,
       SUM(CASE WHEN cnt > 1 THEN 1 ELSE 0 END) AS repeaters,
       ROUND(SUM(CASE WHEN cnt > 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct
FROM (
  SELECT c.customer_unique_id AS cid, COUNT(DISTINCT o.order_id) AS cnt
  FROM customers c
  JOIN orders o ON c.customer_id = o.customer_id
  GROUP BY cid
) t;
```

**발견**: 전체 고객 96,096명 중 재구매 고객은 2,997명(**3.12%**)에 불과. 마켓플레이스 특성상 대부분 1회성 구매이며, 재구매 유도 전략(리마케팅, 쿠폰 등)의 필요성을 시사.

---

## 분석 4. 배송 소요일과 리뷰 평점의 관계

**왜 물었나**: 배송 속도가 고객 만족도(평점)에 실제로 영향을 주는지 검증

```sql
SELECT review_score,
       ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS avgdays,
       COUNT(*) AS cnt
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY review_score
ORDER BY review_score;
```

**발견**: 평점과 배송일이 뚜렷한 역상관 관계를 보임.

| 평점 | 평균 배송일 | 건수 |
|---|---|---|
| 1점 | 21.3일 | 9,409 |
| 2점 | 16.6일 | 2,941 |
| 3점 | 14.2일 | 7,962 |
| 4점 | 12.3일 | 18,987 |
| 5점 | 10.6일 | 57,060 |

배송이 1점 평균 대비 약 2배 빠른 경우(10.6일) 5점 평점으로 이어짐. **배송 속도가 고객 만족도의 핵심 요인**임을 데이터로 증명.

---

## 분석 5. 주문 비중이 높은 상위 도시

**왜 물었나**: 물류센터 위치, 지역별 마케팅 예산 배분에 활용할 수 있는 지역 데이터 파악

```sql
SELECT c.customer_city AS city, COUNT(DISTINCT o.order_id) AS cnt,
       ROUND(COUNT(DISTINCT o.order_id) / (SELECT COUNT(*) FROM orders) * 100, 2) AS pct
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY city
ORDER BY cnt DESC
LIMIT 10;
```

**발견**: 상파울루가 전체 주문의 **15.63%**(15,540건)로 압도적 1위, 리우데자네이루가 6.92%로 2위. 상위 2개 도시가 전체 주문의 22% 이상을 차지 — 특정 대도시에 대한 물류/마케팅 집중 전략의 근거 데이터로 활용 가능.

---

## 이력서/자기소개서 활용 예시

> **SQL 기반 이커머스 데이터 분석 프로젝트 (개인, 2026)**
> Brazilian E-commerce(Olist) 공개 데이터셋(40만 건 이상)을 MySQL로 직접 적재 및 정제하여, 카테고리별 매출, 월별 성장 추이, 재구매율, 배송-만족도 상관관계 등을 SQL로 분석. 데이터 정제 과정에서 발생한 텍스트 파싱 이슈를 Python(pandas)으로 해결하며 실무형 데이터 처리 역량을 기름.

**면접에서 이야기하기 좋은 포인트**:
1. 원본 데이터가 지저분해서(줄바꿈, 빈 값) 직접 정제해야 했던 경험 → 문제 해결 능력
2. 배송-평점 상관관계처럼 "왜 이 지표가 중요한가"를 설명할 수 있는 비즈니스 인사이트
3. JOIN, GROUP BY, 서브쿼리, CASE WHEN, 윈도우 함수급 집계 로직을 직접 작성한 경험
