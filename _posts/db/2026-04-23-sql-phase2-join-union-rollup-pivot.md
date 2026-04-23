---
title: 조인 & 집합 문법 (Oracle, MySQL, PostgreSQL)
date: 2026-04-23 01:00:00 +0900
categories: [DB, 이론]
order: 2
tags: [SQL, Oracle, MySQL, PostgreSQL, JOIN, UNION, ROLLUP, PIVOT, 집합연산]
---

## 1. 개요

JOIN, UNION, ROLLUP, PIVOT은 실무에서 가장 자주 쓰이는 SQL 구문이다. 특히 PIVOT과 FULL OUTER JOIN은 DBMS마다 지원 여부와 문법이 크게 달라 혼란이 생기기 쉽다. 이 글은 Oracle, MySQL, PostgreSQL 세 DBMS의 차이를 코드 예시와 표 중심으로 명확하게 정리한다.

| 섹션 | 내용 |
|------|------|
| 2. JOIN | INNER / OUTER / CROSS / SELF JOIN + DBMS별 차이 |
| 3. UNION / UNION ALL | 집합 결합, 중복 처리, 성능 차이 |
| 4. ROLLUP / PIVOT | 소계·합계 자동 생성, 행↔열 변환 |

예제에서 사용하는 테이블 구조는 다음과 같다.

```sql
-- users:       user_id, username, department_id
-- orders:      order_id, user_id, amount, status
-- departments: department_id, department_name
-- employees:   employee_id, name, manager_id, department, job_title, salary
```

---

## 2. JOIN

JOIN은 두 개 이상의 테이블을 특정 조건으로 연결해서 하나의 결과로 만드는 연산이다. 실무에서 가장 많이 쓰이는 SQL 기능 중 하나다.

### 📌 INNER JOIN (내부 조인)

두 테이블에서 조건을 만족하는 행만 반환한다. 가장 기본적인 JOIN이다.

> 💡 비유: 출석부와 시험 결과표를 놓고, 둘 다에 이름이 있는 학생만 뽑는 것이다. 한쪽에만 있는 학생은 결과에서 제외된다.

```sql
/**
 * INNER JOIN: 양쪽 테이블 모두에 조건을 만족하는 행만 반환한다.
 * orders가 없는 user, user가 없는 orders는 모두 결과에서 제외된다.
 * 세 DBMS 모두 동일한 문법을 사용한다.
 */

-- ✅ Oracle / MySQL / PostgreSQL 모두 동일
SELECT
    u.user_id,
    u.username,
    o.order_id,
    o.amount
FROM users u
INNER JOIN orders o ON u.user_id = o.user_id;
```

---

### 📌 LEFT OUTER JOIN (왼쪽 외부 조인)

왼쪽 테이블의 모든 행을 반환하고, 오른쪽 테이블에 매칭되는 행이 없으면 NULL로 채운다.

```sql
/**
 * LEFT JOIN: 왼쪽(users) 테이블 기준으로 모든 행을 반환한다.
 * 오른쪽(orders)에 매칭이 없으면 order_id, amount는 NULL로 채워진다.
 * "한 번도 주문하지 않은 유저" 같은 패턴을 찾을 때 핵심적으로 활용된다.
 */

-- ✅ 세 DBMS 모두 동일
SELECT
    u.user_id,
    u.username,
    o.order_id,     -- 주문이 없는 user는 NULL
    o.amount        -- 주문이 없는 user는 NULL
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id;

-- 활용: 한 번도 주문하지 않은 유저 찾기
SELECT u.user_id, u.username
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
WHERE o.order_id IS NULL;  -- 오른쪽이 NULL인 행 = 매칭 없음
```

---

### 📌 RIGHT OUTER JOIN (오른쪽 외부 조인)

RIGHT JOIN은 LEFT JOIN의 반대다. 오른쪽 테이블의 모든 행을 반환한다.

```sql
/**
 * RIGHT JOIN은 LEFT JOIN에서 테이블 순서를 바꾼 것과 동일하다.
 * 실무에서는 가독성을 위해 LEFT JOIN으로 통일해서 쓰는 경우가 많다.
 */

-- ✅ 세 DBMS 모두 동일
SELECT
    u.username,
    o.order_id,
    o.amount
FROM users u
RIGHT JOIN orders o ON u.user_id = o.user_id;
-- 탈퇴 회원의 주문처럼 user가 없는 orders도 포함

-- 위와 동일한 결과 (LEFT JOIN으로 표현)
SELECT
    u.username,
    o.order_id,
    o.amount
FROM orders o
LEFT JOIN users u ON o.user_id = u.user_id;
```

---

### 📌 FULL OUTER JOIN (완전 외부 조인)

양쪽 테이블의 모든 행을 반환한다. 매칭되지 않는 쪽은 NULL로 채운다.

> 💡 MySQL은 FULL OUTER JOIN을 지원하지 않는다. LEFT JOIN과 RIGHT JOIN을 UNION으로 합쳐서 대체해야 한다.

```sql
/**
 * FULL OUTER JOIN: 양쪽 테이블의 모든 행을 포함한다.
 * 데이터 정합성 검증, 두 시스템 간 데이터 비교 시 유용하다.
 */

-- ✅ Oracle
SELECT u.username, o.order_id
FROM users u
FULL OUTER JOIN orders o ON u.user_id = o.user_id;

-- ✅ PostgreSQL (Oracle과 동일한 문법)
SELECT u.username, o.order_id
FROM users u
FULL OUTER JOIN orders o ON u.user_id = o.user_id;

-- ✅ MySQL (FULL OUTER JOIN 미지원 → LEFT + RIGHT UNION으로 대체)
SELECT u.username, o.order_id
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
UNION
SELECT u.username, o.order_id
FROM users u
RIGHT JOIN orders o ON u.user_id = o.user_id;
```

| DBMS | FULL OUTER JOIN 지원 |
|------|---------------------|
| Oracle | ✅ |
| MySQL | ❌ (UNION으로 대체) |
| PostgreSQL | ✅ |

---

### 📌 CROSS JOIN (교차 조인)

조건 없이 두 테이블의 모든 행의 조합을 만들어낸다. N행 × M행 = N×M행 결과가 나온다.

> 💡 주의: 테이블이 크면 결과가 폭발적으로 늘어난다. WHERE 조건 없이 대용량 테이블에 쓰면 DB가 멈출 수 있다.

```sql
/**
 * CROSS JOIN: 두 테이블의 모든 조합을 생성한다.
 * 사이즈 3개 × 색상 4개 = 12가지 조합처럼, 경우의 수를 모두 만들 때 사용한다.
 */

-- ✅ 세 DBMS 동일 (표준 문법)
SELECT s.size_name, c.color_name
FROM sizes s
CROSS JOIN colors c;

-- Oracle에서는 콤마(,) 방식도 동일하게 동작 (구형 문법)
SELECT s.size_name, c.color_name
FROM sizes s, colors c;
```

---

### 📌 SELF JOIN (자기 자신과 조인)

같은 테이블을 별칭을 다르게 해서 조인한다. 계층 구조(조직도, 카테고리) 표현에 유용하다.

```sql
/**
 * SELF JOIN: 동일 테이블을 두 번 참조해 계층 관계를 표현한다.
 * employees 테이블에서 직원과 그 직원의 상사를 함께 조회할 때 사용한다.
 * LEFT JOIN을 쓰는 이유: 상사가 없는 최상위 직원(CEO)도 포함하기 위해서다.
 */

-- ✅ 세 DBMS 동일
SELECT
    e.employee_id,
    e.name      AS 직원명,
    m.name      AS 상사명
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.employee_id;
```

---

### 📌 3개 이상 테이블 JOIN

```sql
/**
 * JOIN은 순서대로 체인처럼 연결된다.
 * 각 JOIN의 ON 조건이 명확해야 의도치 않은 카테시안 곱이 발생하지 않는다.
 */

-- ✅ 세 DBMS 동일
SELECT
    u.username,
    d.department_name,
    COUNT(o.order_id) AS 주문수,
    SUM(o.amount)     AS 총주문액
FROM users u
INNER JOIN departments d ON u.department_id = d.department_id
LEFT  JOIN orders o      ON u.user_id       = o.user_id
GROUP BY u.username, d.department_name
ORDER BY 총주문액 DESC;
```

---

### 📌 Oracle 구형 JOIN 문법 — 레거시 코드 독해용

Oracle 레거시 코드에서 자주 보이는 구형 문법이다. 신규 작성 시에는 사용하지 않는다.

```sql
/**
 * 콤마(,) + WHERE 방식은 ANSI 표준이 아닌 Oracle 구형 문법이다.
 * 유지보수 중인 레거시 코드에서 이 문법을 만나면 현대 문법으로 변환할 것을 권장한다.
 */

-- ⚠️ Oracle 구형 문법 (읽기 전용, 신규 작성 금지)
SELECT u.username, o.order_id
FROM users u, orders o
WHERE u.user_id = o.user_id;    -- INNER JOIN

-- (+) 기호로 OUTER JOIN 표현 (Oracle 전용 구형 문법)
SELECT u.username, o.order_id
FROM users u, orders o
WHERE u.user_id = o.user_id(+); -- LEFT JOIN 효과 (오른쪽에 + 붙이면 NULL 허용)

-- ✅ 현대 ANSI 문법 (항상 이걸 사용할 것)
SELECT u.username, o.order_id
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id;
```

---

### 📌 JOIN 성능 주의사항

> 💡 JOIN 성능 문제는 대부분 아래 세 가지 원인에서 발생한다. 인덱스 설계 단계에서 미리 고려해야 한다.

- JOIN 컬럼에 인덱스가 없으면 풀스캔이 발생해 성능이 크게 저하된다
- 조인 조건 컬럼의 데이터 타입이 일치해야 인덱스를 탄다. `INT`와 `VARCHAR`를 조인하면 묵시적 형변환으로 인덱스가 무력화된다
- `SELECT *` 대신 필요한 컬럼만 명시해야 네트워크·메모리 낭비를 막을 수 있다

---

## 3. UNION / UNION ALL

UNION은 두 SELECT의 결과를 위아래로 합친다. JOIN이 컬럼을 옆으로 붙이는 것과 반대다. 두 SELECT의 컬럼 수와 데이터 타입이 일치해야 한다.

### 📌 UNION vs UNION ALL

```sql
/**
 * UNION:     중복 행을 제거한다. 내부적으로 정렬/해시 연산이 발생해 느리다.
 * UNION ALL: 중복을 포함한 채 단순 결합한다. 정렬 없이 빠르다.
 * 중복이 없다는 것을 알고 있다면 항상 UNION ALL을 써야 한다.
 */

-- ✅ 세 DBMS 동일

-- UNION: 중복 제거 (느림)
SELECT user_id, username, 'BUYER'  AS user_type FROM buyers
UNION
SELECT user_id, username, 'SELLER' AS user_type FROM sellers;

-- UNION ALL: 중복 포함 (빠름)
SELECT user_id, username FROM buyers
UNION ALL
SELECT user_id, username FROM sellers;
```

| 항목 | UNION | UNION ALL |
|------|-------|-----------|
| 중복 처리 | 제거 | 포함 |
| 성능 | 느림 (정렬 발생) | 빠름 |
| 사용 시점 | 중복 제거가 반드시 필요할 때 | 중복이 없거나 상관없을 때 |

---

### 📌 UNION과 ORDER BY

```sql
/**
 * ORDER BY는 마지막 SELECT 뒤에 한 번만 쓴다.
 * 각 SELECT에 개별 ORDER BY를 쓰면 대부분의 DBMS에서 오류가 발생한다.
 * Oracle에서 개별 정렬이 필요할 경우 서브쿼리로 감싸야 한다.
 */

-- ✅ 세 DBMS 동일 — ORDER BY는 마지막에 한 번만
SELECT user_id, username, 'BUYER' AS type FROM buyers
UNION ALL
SELECT user_id, username, 'SELLER'         FROM sellers
ORDER BY username ASC;

-- Oracle에서 각 SELECT를 개별 정렬하고 싶을 때 (서브쿼리로 감싸기)
SELECT * FROM (SELECT user_id FROM buyers   ORDER BY user_id)
UNION ALL
SELECT * FROM (SELECT user_id FROM sellers  ORDER BY user_id);
```

---

### 📌 실전 활용 패턴

```sql
/**
 * 활용 1: 여러 종류의 집계를 하나의 리포트로 합칠 때
 * 활용 2: 동일 구조의 분리된 테이블을 통합 조회할 때
 */

-- 활용 1: 이번 달 지표 요약 리포트 (Oracle 기준)
SELECT '이번달 신규회원' AS 구분, COUNT(*) AS 수
FROM users
WHERE created_at >= TRUNC(SYSDATE, 'MM')
UNION ALL
SELECT '이번달 주문건수', COUNT(*)
FROM orders
WHERE order_date >= TRUNC(SYSDATE, 'MM')
UNION ALL
SELECT '이번달 취소건수', COUNT(*)
FROM orders
WHERE status = 'CANCELLED'
  AND order_date >= TRUNC(SYSDATE, 'MM');

-- 활용 2: 연도별로 분리된 테이블 통합 조회
SELECT * FROM orders_2024
UNION ALL
SELECT * FROM orders_2025;
```

---

## 4. ROLLUP / PIVOT

### 📌 ROLLUP — 소계·합계 자동 생성

`GROUP BY ROLLUP`은 일반 집계에 소계와 총계 행을 자동으로 추가해준다. 엑셀의 소계 기능과 유사하다.

```sql
/**
 * ROLLUP(A, B): A별 소계 → 전체 총계 순서로 집계 행을 자동 추가한다.
 * MySQL은 WITH ROLLUP 키워드를 사용한다는 점이 다르다.
 */

-- ✅ Oracle
SELECT
    department,
    job_title,
    SUM(salary) AS 급여합
FROM employees
GROUP BY ROLLUP(department, job_title);
/*
결과:
개발팀 | 백엔드  | 15,000,000
개발팀 | 프론트  | 10,000,000
개발팀 | NULL    | 25,000,000  ← 개발팀 소계
영업팀 | 영업1팀 | 12,000,000
영업팀 | NULL    | 12,000,000  ← 영업팀 소계
NULL   | NULL    | 37,000,000  ← 전체 총계
*/

-- ✅ MySQL (8.0 이상) — WITH ROLLUP 키워드 사용
SELECT department, job_title, SUM(salary)
FROM employees
GROUP BY department, job_title WITH ROLLUP;

-- ✅ PostgreSQL — Oracle과 동일한 문법
SELECT department, job_title, SUM(salary)
FROM employees
GROUP BY ROLLUP(department, job_title);
```

| DBMS | ROLLUP 문법 |
|------|------------|
| Oracle | `GROUP BY ROLLUP(col1, col2)` |
| MySQL | `GROUP BY col1, col2 WITH ROLLUP` |
| PostgreSQL | `GROUP BY ROLLUP(col1, col2)` |

---

### 📌 ROLLUP의 NULL 구분 — GROUPING() 함수

ROLLUP이 만든 소계 행의 NULL과 원본 데이터의 NULL을 구분해야 할 때 사용한다.

```sql
/**
 * GROUPING(컬럼): 해당 행이 ROLLUP에 의해 생성된 집계 행이면 1, 실제 데이터면 0을 반환한다.
 * CASE와 함께 쓰면 NULL 대신 '소계', '전체합계' 같은 레이블을 붙일 수 있다.
 * 세 DBMS 모두 GROUPING() 함수를 동일하게 지원한다.
 */

-- ✅ Oracle / PostgreSQL
SELECT
    CASE GROUPING(department) WHEN 1 THEN '전체합계' ELSE department END AS 부서,
    CASE GROUPING(job_title)  WHEN 1 THEN '소계'     ELSE job_title  END AS 직책,
    SUM(salary) AS 급여합
FROM employees
GROUP BY ROLLUP(department, job_title);

-- ✅ MySQL
SELECT
    CASE GROUPING(department) WHEN 1 THEN '전체합계' ELSE department END AS 부서,
    CASE GROUPING(job_title)  WHEN 1 THEN '소계'     ELSE job_title  END AS 직책,
    SUM(salary) AS 급여합
FROM employees
GROUP BY department, job_title WITH ROLLUP;
```

---

### 📌 PIVOT — 행을 열로 변환

PIVOT은 행 데이터를 열로 펼쳐서 교차표(크로스탭) 형태로 만든다. DBMS별로 문법 차이가 가장 크다.

```sql
/**
 * 원본: department | quarter | sales 형태의 행 데이터를
 * 결과: department | Q1 | Q2 | Q3 | Q4 형태의 열 데이터로 변환한다.
 *
 * Oracle은 PIVOT 절을 네이티브로 지원한다.
 * MySQL과 PostgreSQL은 CASE + GROUP BY로 직접 구현해야 한다.
 */

-- ✅ Oracle: PIVOT 절 네이티브 지원
SELECT *
FROM (
    SELECT department, quarter, sales
    FROM quarterly_sales
)
PIVOT (
    SUM(sales)                          -- 집계할 값과 함수
    FOR quarter                         -- 피벗 기준 컬럼
    IN ('Q1', 'Q2', 'Q3', 'Q4')        -- 열로 만들 값 목록
);

-- ✅ MySQL: 네이티브 PIVOT 없음 — CASE + GROUP BY로 구현
SELECT
    department,
    SUM(CASE WHEN quarter = 'Q1' THEN sales ELSE 0 END) AS Q1,
    SUM(CASE WHEN quarter = 'Q2' THEN sales ELSE 0 END) AS Q2,
    SUM(CASE WHEN quarter = 'Q3' THEN sales ELSE 0 END) AS Q3,
    SUM(CASE WHEN quarter = 'Q4' THEN sales ELSE 0 END) AS Q4
FROM quarterly_sales
GROUP BY department;

-- ✅ PostgreSQL: CASE + GROUP BY (범용) 또는 crosstab() (확장 모듈)

-- 방법 1: CASE + GROUP BY (MySQL과 동일, 추가 설치 불필요)
SELECT
    department,
    SUM(CASE WHEN quarter = 'Q1' THEN sales ELSE 0 END) AS Q1,
    SUM(CASE WHEN quarter = 'Q2' THEN sales ELSE 0 END) AS Q2,
    SUM(CASE WHEN quarter = 'Q3' THEN sales ELSE 0 END) AS Q3,
    SUM(CASE WHEN quarter = 'Q4' THEN sales ELSE 0 END) AS Q4
FROM quarterly_sales
GROUP BY department;

-- 방법 2: crosstab() — tablefunc 확장 모듈 설치 후 사용 가능
CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT *
FROM crosstab(
    'SELECT department, quarter, SUM(sales)
     FROM quarterly_sales
     GROUP BY department, quarter
     ORDER BY 1, 2',
    'SELECT DISTINCT quarter FROM quarterly_sales ORDER BY 1'
) AS ct(
    department TEXT,
    "Q1" NUMERIC,
    "Q2" NUMERIC,
    "Q3" NUMERIC,
    "Q4" NUMERIC
);
```

| DBMS | 네이티브 PIVOT | 대안 |
|------|--------------|------|
| Oracle | ✅ `PIVOT` 절 | — |
| MySQL | ❌ | `CASE + GROUP BY` |
| PostgreSQL | ❌ (기본) | `CASE + GROUP BY` 또는 `crosstab()` |

---

### 📌 UNPIVOT — 열을 행으로 변환 (PIVOT의 반대)

```sql
/**
 * UNPIVOT: 열로 펼쳐진 데이터를 다시 행 형태로 되돌린다.
 * Oracle은 UNPIVOT 절을 네이티브로 지원한다.
 * MySQL과 PostgreSQL은 UNION ALL로 직접 구현해야 한다.
 */

-- ✅ Oracle: UNPIVOT 네이티브 지원
SELECT department, quarter, sales
FROM quarterly_pivot_table
UNPIVOT (
    sales             -- 값을 담을 새 컬럼명
    FOR quarter       -- 기존 컬럼명을 담을 새 컬럼명
    IN (Q1, Q2, Q3, Q4)  -- 행으로 풀 컬럼들
);

-- ✅ MySQL / PostgreSQL: UNION ALL로 구현
SELECT department, 'Q1' AS quarter, Q1 AS sales FROM quarterly_pivot_table
UNION ALL
SELECT department, 'Q2',            Q2           FROM quarterly_pivot_table
UNION ALL
SELECT department, 'Q3',            Q3           FROM quarterly_pivot_table
UNION ALL
SELECT department, 'Q4',            Q4           FROM quarterly_pivot_table
ORDER BY department, quarter;
```

---

## 5. 정리

- INNER JOIN: 양쪽 모두 매칭되는 행만 반환, 세 DBMS 문법 동일
- LEFT JOIN: 왼쪽 테이블 기준 전체 반환, 매칭 없으면 NULL — "없는 것 찾기" 패턴에 핵심
- FULL OUTER JOIN: MySQL은 미지원, LEFT + RIGHT UNION으로 대체
- Oracle 구형 콤마/`(+)` 문법은 레거시 독해용이며 신규 작성 시 사용 금지
- UNION ALL이 UNION보다 빠르다 — 중복이 없다면 항상 UNION ALL을 쓸 것
- ROLLUP 문법: MySQL은 `WITH ROLLUP`, Oracle·PostgreSQL은 `ROLLUP()` 함수 형태
- PIVOT: Oracle만 네이티브 지원, MySQL·PostgreSQL은 `CASE + GROUP BY`로 구현
- JOIN 컬럼 타입 불일치 시 묵시적 형변환으로 인덱스 무력화 — 반드시 타입 맞출 것

---

## 6. 참고 자료

- [Oracle JOIN 공식 문서](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/SELECT.html)
- [Oracle PIVOT 공식 문서](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/SELECT.html#GUID-CFA006CA-6FF1-4972-821E-6996142A51C6)
- [MySQL JOIN 공식 문서](https://dev.mysql.com/doc/refman/8.0/en/join.html)
- [MySQL UNION 공식 문서](https://dev.mysql.com/doc/refman/8.0/en/union.html)
- [PostgreSQL SELECT 공식 문서](https://www.postgresql.org/docs/current/sql-select.html)
- [PostgreSQL tablefunc (crosstab)](https://www.postgresql.org/docs/current/tablefunc.html)
- 출처: Claude Desktop 대화 (2026-04-23)
