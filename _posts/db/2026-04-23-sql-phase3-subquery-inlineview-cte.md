---
title: 서브쿼리 & 뷰
date: 2026-04-23 02:00:00 +0900
categories: [DB, DB 이론]
order: 3
tags: [SQL, Oracle, MySQL, PostgreSQL, 서브쿼리, 인라인뷰, CTE, WITH절, EXISTS]
---

## 1. 개요

서브쿼리, 인라인 뷰, WITH 절(CTE)은 복잡한 쿼리를 단계적으로 분리해서 처리하는 핵심 도구다. 기능은 유사해 보이지만 사용 위치와 목적이 다르고, TOP-N 쿼리나 재귀 CTE처럼 DBMS마다 문법이 크게 달라지는 영역이 있다. 이 글은 그 차이를 코드 예시 중심으로 정리한다.

| 섹션 | 내용 |
|------|------|
| 2. 서브쿼리 | 단일행 · 다중행 · EXISTS · 스칼라 서브쿼리 |
| 3. 인라인 뷰 | FROM 절 서브쿼리, TOP-N 쿼리 DBMS별 차이 |
| 4. WITH 절 (CTE) | 기본 CTE, 다중 CTE, 재귀 CTE |

---

## 2. 서브쿼리 (Subquery)

서브쿼리는 SQL 문 안에 포함된 또 다른 SELECT 문이다. 괄호 `()`로 감싸며, 메인 쿼리의 WHERE, SELECT, FROM, HAVING 절 등에서 사용할 수 있다.

### 📌 단일행 서브쿼리 (Single Row Subquery)

결과가 단 하나의 행만 반환하는 서브쿼리다. `=`, `>`, `<`, `>=`, `<=`, `<>` 같은 단일값 비교 연산자와 함께 쓴다.

> 💡 단일행 서브쿼리가 2행 이상 반환하면 런타임 오류가 발생한다. 서브쿼리 결과가 항상 1건임을 보장할 수 없다면 다중행 서브쿼리 방식으로 전환해야 한다.

```sql
/**
 * 단일행 서브쿼리: 반드시 1행 1열만 반환해야 한다.
 * 집계함수(MAX, MIN, AVG 등)는 항상 1행을 반환하므로 단일행 서브쿼리에 안전하다.
 * 세 DBMS 모두 동일한 문법을 사용한다.
 */

-- ✅ 세 DBMS 동일

-- 평균 급여보다 많이 받는 직원 조회
SELECT name, salary
FROM employees
WHERE salary > (
    SELECT AVG(salary)
    FROM employees
);

-- 가장 최근 주문한 날짜의 주문들 조회
SELECT order_id, user_id, amount
FROM orders
WHERE order_date = (
    SELECT MAX(order_date)
    FROM orders
);

-- ❌ 오류 발생 예시 — 서브쿼리가 여러 행 반환
SELECT * FROM employees
WHERE salary = (SELECT salary FROM employees WHERE department = '개발팀');
-- 개발팀 직원이 여럿이면 salary가 여러 개 → = 연산자로 비교 불가 → 오류
```

---

### 📌 다중행 서브쿼리 (Multi Row Subquery)

결과가 여러 행을 반환하는 서브쿼리다. `IN`, `ANY`, `ALL`과 함께 쓴다.

```sql
/**
 * IN:  서브쿼리 결과 중 하나라도 일치하면 TRUE
 * ANY: 서브쿼리 결과 중 하나라도 조건을 만족하면 TRUE (= ANY는 IN과 동일)
 * ALL: 서브쿼리 결과 전체에 대해 조건을 만족해야 TRUE
 *      > ALL은 MAX()와, < ALL은 MIN()과 동일한 의미다.
 */

-- ✅ 세 DBMS 동일

-- IN: 고연봉자가 있는 부서의 모든 직원 조회
SELECT name, department
FROM employees
WHERE department IN (
    SELECT DISTINCT department
    FROM employees
    WHERE salary > 5000000
);

-- ANY: 개발팀 직원 중 누구보다도 급여가 높은 직원
SELECT name, salary
FROM employees
WHERE salary > ANY (
    SELECT salary FROM employees WHERE department = '개발팀'
);

-- ALL: 개발팀 전체 직원보다 급여가 높은 직원 (= 개발팀 최고 급여 초과)
SELECT name, salary
FROM employees
WHERE salary > ALL (
    SELECT salary FROM employees WHERE department = '개발팀'
);
```

---

### 📌 EXISTS / NOT EXISTS

서브쿼리의 결과가 존재하는지 여부만 확인한다. 실제 값은 관심 없고, 행이 있냐 없냐만 본다.

> 💡 IN과 NOT IN은 NULL이 포함될 경우 의도치 않은 결과가 발생할 수 있다. 서브쿼리 결과에 NULL이 포함될 가능성이 있다면 EXISTS / NOT EXISTS를 쓰는 것이 안전하다.

```sql
/**
 * EXISTS: 서브쿼리에 결과가 하나라도 있으면 TRUE → 즉시 중단 (빠름)
 * NOT EXISTS: 서브쿼리에 결과가 없으면 TRUE
 * SELECT 절에는 관례적으로 1 또는 * 를 쓴다 (어차피 값을 쓰지 않음)
 */

-- ✅ 세 DBMS 동일

-- EXISTS: 주문이 하나라도 있는 유저
SELECT u.user_id, u.username
FROM users u
WHERE EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.user_id = u.user_id  -- 메인 쿼리와 연결 (상관 서브쿼리)
);

-- NOT EXISTS: 한 번도 주문하지 않은 유저
SELECT u.user_id, u.username
FROM users u
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.user_id = u.user_id
);

-- ⚠️ IN과 NULL 함정 — NOT IN에 NULL이 포함되면 결과가 0건이 됨
SELECT * FROM users
WHERE user_id NOT IN (1, 2, NULL);
-- NULL과의 비교는 항상 UNKNOWN → 전체 조건이 FALSE → 결과 없음

-- ✅ 안전한 대안: NOT EXISTS 사용
SELECT * FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM blacklist b WHERE b.user_id = u.user_id
);
```

| 상황 | 권장 |
|------|------|
| 서브쿼리 결과가 작을 때 | `IN` |
| 서브쿼리 결과가 클 때 | `EXISTS` (행 존재 확인 후 즉시 중단) |
| NULL이 포함될 수 있을 때 | `EXISTS` (`IN`은 NULL 포함 시 의도치 않은 결과) |

---

### 📌 스칼라 서브쿼리 (Scalar Subquery)

SELECT 절에 사용하는 서브쿼리다. 반드시 단 하나의 행, 단 하나의 열을 반환해야 한다.

> 💡 스칼라 서브쿼리는 메인 쿼리의 행 수만큼 반복 실행된다. 유저가 10만 명이면 서브쿼리도 10만 번 실행된다. 대용량에서는 LEFT JOIN으로 대체하는 것이 대부분 더 빠르다.

```sql
/**
 * 스칼라 서브쿼리: SELECT 절 안에 위치하며 각 행마다 개별 실행된다.
 * 반드시 1행 1열만 반환해야 하며, 결과가 없으면 NULL을 반환한다.
 */

-- ✅ 세 DBMS 동일

-- 각 유저의 총 주문 금액을 함께 조회
SELECT
    u.user_id,
    u.username,
    (
        SELECT SUM(o.amount)
        FROM orders o
        WHERE o.user_id = u.user_id
    ) AS 총주문금액
FROM users u;

-- 각 직원의 급여와 소속 부서 평균 급여를 함께 조회
SELECT
    e.name,
    e.salary,
    e.department,
    (
        SELECT ROUND(AVG(e2.salary), 0)
        FROM employees e2
        WHERE e2.department = e.department
    ) AS 부서평균급여
FROM employees e;

-- ⚠️ 대용량 성능 문제: 스칼라 서브쿼리 → LEFT JOIN으로 대체
-- 성능 나쁜 버전
SELECT u.user_id,
       (SELECT SUM(amount) FROM orders o WHERE o.user_id = u.user_id) AS 총액
FROM users u;

-- ✅ 성능 좋은 버전 (LEFT JOIN + GROUP BY)
SELECT u.user_id, SUM(o.amount) AS 총액
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
GROUP BY u.user_id;
```

---

## 3. 인라인 뷰 (Inline View)

FROM 절에 사용하는 서브쿼리다. 가상의 테이블처럼 사용하며, 반드시 별칭을 붙여야 한다.

### 📌 기본 인라인 뷰

```sql
/**
 * 인라인 뷰: FROM 절 안에 서브쿼리를 넣어 임시 테이블처럼 사용한다.
 * 별칭이 필수이며, MySQL은 AS 키워드 포함을 권장한다.
 * 집계 결과에 다시 WHERE 조건을 걸 때 주로 사용한다.
 */

-- ✅ Oracle / PostgreSQL
SELECT dept_avg.department, dept_avg.avg_salary
FROM (
    SELECT department, ROUND(AVG(salary), 0) AS avg_salary
    FROM employees
    GROUP BY department
) dept_avg
WHERE dept_avg.avg_salary > 4000000;

-- ✅ MySQL (AS 키워드 권장)
SELECT dept_avg.department, dept_avg.avg_salary
FROM (
    SELECT department, ROUND(AVG(salary), 0) AS avg_salary
    FROM employees
    GROUP BY department
) AS dept_avg
WHERE dept_avg.avg_salary > 4000000;
```

---

### 📌 TOP-N 쿼리 — DBMS별 차이가 가장 큰 영역

상위 N건을 가져오는 방법이 DBMS마다 완전히 다르다.

> 💡 Oracle 11g 이하의 ROWNUM은 ORDER BY보다 먼저 붙는다. 정렬 전에 번호가 매겨지므로 반드시 인라인 뷰로 감싸서 먼저 정렬한 뒤 ROWNUM을 적용해야 한다.

```sql
/**
 * TOP-N 쿼리: 정렬된 결과에서 상위 N건만 가져오는 패턴이다.
 * Oracle 버전에 따라 ROWNUM 방식과 FETCH FIRST 방식이 나뉜다.
 * MySQL과 PostgreSQL은 LIMIT / OFFSET 문법을 사용한다.
 */

-- ✅ Oracle 11g 이하 — ROWNUM + 인라인 뷰 (이중 중첩 필수)
SELECT *
FROM (
    SELECT name, salary, ROWNUM AS rn
    FROM (
        SELECT name, salary
        FROM employees
        ORDER BY salary DESC    -- 1단계: 먼저 정렬
    )
)
WHERE rn <= 5;                  -- 2단계: 그 후 상위 5건 필터

-- ✅ Oracle 12c 이상 — FETCH FIRST (권장)
SELECT name, salary
FROM employees
ORDER BY salary DESC
FETCH FIRST 5 ROWS ONLY;

-- 페이지네이션: 11번째부터 20번째
SELECT name, salary
FROM employees
ORDER BY salary DESC
OFFSET 10 ROWS FETCH NEXT 10 ROWS ONLY;

-- ✅ MySQL — LIMIT / OFFSET
SELECT name, salary
FROM employees
ORDER BY salary DESC
LIMIT 5;

-- 페이지네이션: 11번째부터 10건
SELECT name, salary
FROM employees
ORDER BY salary DESC
LIMIT 10 OFFSET 10;
-- 단축 문법: LIMIT 10, 10 (MySQL 전용)

-- ✅ PostgreSQL — LIMIT / OFFSET (MySQL과 동일)
SELECT name, salary
FROM employees
ORDER BY salary DESC
LIMIT 5;

-- 페이지네이션
SELECT name, salary
FROM employees
ORDER BY salary DESC
LIMIT 10 OFFSET 10;
```

| DBMS | 상위 N건 | 페이지네이션 |
|------|---------|------------|
| Oracle 11g↓ | `ROWNUM` + 인라인 뷰 | `ROWNUM BETWEEN` |
| Oracle 12c↑ | `FETCH FIRST N ROWS ONLY` | `OFFSET N ROWS FETCH NEXT N ROWS ONLY` |
| MySQL | `LIMIT N` | `LIMIT N OFFSET M` |
| PostgreSQL | `LIMIT N` | `LIMIT N OFFSET M` |

---

## 4. WITH 절 (CTE, Common Table Expression)

WITH 절은 쿼리 안에서 이름을 붙인 임시 결과 집합을 정의한다. 인라인 뷰와 기능은 같지만 가독성이 훨씬 좋고, 같은 결과를 여러 번 참조할 수 있다.

### 📌 기본 CTE

```sql
/**
 * CTE: WITH 이름 AS (서브쿼리) 형태로 정의하고 메인 쿼리에서 테이블처럼 참조한다.
 * 인라인 뷰와 달리 같은 CTE를 여러 번 참조할 수 있어 중복을 제거할 수 있다.
 * Oracle 9i, MySQL 8.0, PostgreSQL 8.4 이상에서 지원한다.
 */

-- ✅ 세 DBMS 동일

WITH dept_avg AS (
    SELECT
        department,
        ROUND(AVG(salary), 0) AS avg_salary
    FROM employees
    GROUP BY department
)
SELECT
    e.name,
    e.salary,
    d.avg_salary        AS 부서평균,
    e.salary - d.avg_salary AS 평균과의차이
FROM employees e
JOIN dept_avg d ON e.department = d.department
ORDER BY 평균과의차이 DESC;
```

---

### 📌 다중 CTE — 여러 개를 콤마로 연결

```sql
/**
 * 다중 CTE: 콤마로 구분해서 여러 CTE를 순서대로 정의한다.
 * 뒤의 CTE에서 앞에서 정의한 CTE를 참조할 수 있다.
 * 복잡한 쿼리를 단계별로 분리해 가독성을 크게 높일 수 있다.
 */

-- ✅ 세 DBMS 동일 (날짜 함수 부분만 DBMS별로 다름)

WITH
-- 1단계: 이번 달 주문 집계
monthly_orders AS (
    SELECT user_id, SUM(amount) AS total_amount
    FROM orders
    -- Oracle:     WHERE order_date >= TRUNC(SYSDATE, 'MM')
    -- MySQL:      WHERE order_date >= DATE_FORMAT(NOW(), '%Y-%m-01')
    -- PostgreSQL: WHERE order_date >= DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY user_id
),
-- 2단계: VIP 기준 필터 (이번 달 100만원 이상)
vip_users AS (
    SELECT user_id
    FROM monthly_orders
    WHERE total_amount >= 1000000
)
-- 최종 조회
SELECT u.user_id, u.username, mo.total_amount
FROM users u
JOIN monthly_orders mo ON u.user_id = mo.user_id
JOIN vip_users v       ON u.user_id = v.user_id
ORDER BY mo.total_amount DESC;
```

---

### 📌 재귀 CTE (Recursive CTE) — 계층 구조 탐색

계층형 데이터(조직도, 카테고리 트리)를 탐색할 때 사용한다. DBMS별로 `RECURSIVE` 키워드 사용 여부가 다르다.

> 💡 재귀 CTE는 앵커 멤버(시작점)와 재귀 멤버(반복 탐색)를 UNION ALL로 연결한다. 종료 조건이 없으면 무한 루프가 발생하므로 반드시 탈출 조건을 확인해야 한다.

```sql
/**
 * 재귀 CTE 구조:
 * 1. 앵커 멤버: 시작점 정의 (최상위 노드)
 * 2. UNION ALL
 * 3. 재귀 멤버: 앞 결과를 참조해서 다음 단계 탐색 (탈출 조건 필수)
 *
 * Oracle: RECURSIVE 키워드 불필요
 * MySQL / PostgreSQL: WITH RECURSIVE 키워드 필수
 */

-- ✅ Oracle (11gR2 이상) — RECURSIVE 키워드 없이 사용
WITH org_chart (employee_id, name, manager_id, depth) AS (
    -- 앵커 멤버: CEO (manager_id가 NULL인 최상위)
    SELECT employee_id, name, manager_id, 0 AS depth
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- 재귀 멤버: 앞에서 찾은 직원의 하위 직원 탐색
    SELECT e.employee_id, e.name, e.manager_id, oc.depth + 1
    FROM employees e
    JOIN org_chart oc ON e.manager_id = oc.employee_id
)
SELECT
    LPAD(' ', depth * 2) || name AS 조직도,
    depth AS 레벨
FROM org_chart
ORDER BY depth, name;

-- ✅ MySQL (8.0 이상) — RECURSIVE 키워드 필수
WITH RECURSIVE org_chart AS (
    SELECT employee_id, name, manager_id, 0 AS depth
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    SELECT e.employee_id, e.name, e.manager_id, oc.depth + 1
    FROM employees e
    JOIN org_chart oc ON e.manager_id = oc.employee_id
)
SELECT
    CONCAT(REPEAT('  ', depth), name) AS 조직도,
    depth AS 레벨
FROM org_chart
ORDER BY depth, name;

-- ✅ PostgreSQL (8.4 이상) — RECURSIVE 키워드 필수
WITH RECURSIVE org_chart AS (
    SELECT employee_id, name, manager_id, 0 AS depth
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    SELECT e.employee_id, e.name, e.manager_id, oc.depth + 1
    FROM employees e
    JOIN org_chart oc ON e.manager_id = oc.employee_id
)
SELECT
    REPEAT('  ', depth) || name AS 조직도,
    depth AS 레벨
FROM org_chart
ORDER BY depth, name;
```

| 항목 | Oracle | MySQL | PostgreSQL |
|------|--------|-------|------------|
| RECURSIVE 키워드 | 불필요 | **필수** | **필수** |
| 들여쓰기 함수 | `LPAD(' ', n)` | `REPEAT(' ', n)` | `REPEAT(' ', n)` |
| 문자열 연결 | `\|\|` | `CONCAT()` | `\|\|` 또는 `CONCAT()` |
| 지원 버전 | 11gR2 이상 | 8.0 이상 | 8.4 이상 |

---

### 📌 Oracle CONNECT BY — 레거시 계층 쿼리

Oracle 전용 계층 탐색 문법이다. 재귀 CTE보다 간결하지만 Oracle에서만 동작한다. 레거시 코드에서 자주 만나므로 독해할 수 있어야 한다.

```sql
/**
 * CONNECT BY: Oracle 전용 계층형 쿼리 문법이다.
 * START WITH: 시작 조건 (앵커 멤버 역할)
 * CONNECT BY PRIOR: 부모→자식 탐색 방향 정의
 * LEVEL: 현재 깊이 (1부터 시작)
 * ORDER SIBLINGS BY: 같은 레벨 내에서 정렬
 */

-- ✅ Oracle 전용 (레거시 독해용)
SELECT
    LEVEL,
    LPAD(' ', (LEVEL - 1) * 2) || name AS 조직도
FROM employees
START WITH manager_id IS NULL           -- 시작점: 최상위 직원
CONNECT BY PRIOR employee_id = manager_id  -- 부모의 id = 자식의 manager_id
ORDER SIBLINGS BY name;                 -- 같은 레벨 내 이름순 정렬
```

---

### 📌 WITH 절 vs 인라인 뷰 선택 기준

```sql
/**
 * 인라인 뷰: 단순하고 한 번만 참조하는 경우
 * CTE:      같은 결과를 여러 곳에서 참조하거나 쿼리가 복잡한 경우
 */

-- ❌ 인라인 뷰: 같은 집계를 두 번 써야 해서 중복 발생
SELECT a.department, a.avg_sal, b.max_sal
FROM (SELECT department, AVG(salary) avg_sal FROM employees GROUP BY department) a
JOIN (SELECT department, MAX(salary) max_sal FROM employees GROUP BY department) b
  ON a.department = b.department;

-- ✅ CTE: 한 번 정의하고 두 번 참조 — 중복 제거, 가독성 향상
WITH dept_stats AS (
    SELECT
        department,
        AVG(salary) AS avg_sal,
        MAX(salary) AS max_sal
    FROM employees
    GROUP BY department
)
SELECT department, avg_sal, max_sal
FROM dept_stats;
```

| 상황 | 선택 |
|------|------|
| 한 번만 참조하는 단순 필터 | 인라인 뷰 |
| 같은 결과를 여러 곳에서 참조 | WITH 절 (CTE) |
| 계층 구조 탐색 | 재귀 CTE |
| 쿼리가 복잡해서 단계를 나누고 싶을 때 | WITH 절 (CTE) |

---

## 5. 정리

- 단일행 서브쿼리는 반드시 1행 1열만 반환해야 하며, 집계함수(MAX, MIN, AVG)가 가장 안전하다
- `NOT IN`에 NULL이 포함되면 전체 결과가 0건이 될 수 있다 — `NOT EXISTS`를 쓰는 것이 안전하다
- 스칼라 서브쿼리는 행 수만큼 반복 실행된다 — 대용량에서는 LEFT JOIN으로 대체할 것
- TOP-N 쿼리: Oracle 11g↓는 ROWNUM + 이중 인라인 뷰, 12c↑는 FETCH FIRST, MySQL·PostgreSQL은 LIMIT
- Oracle 11g↓의 ROWNUM은 ORDER BY보다 먼저 붙으므로 인라인 뷰로 감싸야 정상 동작한다
- 재귀 CTE: MySQL·PostgreSQL은 `WITH RECURSIVE` 필수, Oracle은 키워드 불필요
- CTE는 같은 결과를 여러 번 참조하거나 쿼리를 단계적으로 나눌 때 인라인 뷰보다 유리하다

---

## 6. 참고 자료

- [Oracle Subquery 공식 문서](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/SELECT.html)
- [Oracle CONNECT BY 공식 문서](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/Hierarchical-Queries.html)
- [MySQL WITH (CTE) 공식 문서](https://dev.mysql.com/doc/refman/8.0/en/with.html)
- [MySQL LIMIT 공식 문서](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- [PostgreSQL WITH 공식 문서](https://www.postgresql.org/docs/current/queries-with.html)
- [PostgreSQL LIMIT 공식 문서](https://www.postgresql.org/docs/current/queries-limit.html)
- 출처: Claude Desktop 대화 (2026-04-23)
