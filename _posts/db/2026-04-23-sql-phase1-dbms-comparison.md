---
title: DBMS별 SQL 문법 완전 정리 — Oracle, MySQL, PostgreSQL 비교 (PHASE 1 기초)
date: 2026-04-23 00:00:00 +0900
categories: [DB, 이론]
tags: [SQL, Oracle, MySQL, PostgreSQL, DatabaseKeys, 집계함수, 조건식]
---

## 1. 개요

Oracle, MySQL, PostgreSQL 세 가지 DBMS에서의 SQL 기초 문법 차이를 정리한다. 같은 기능이라도 DBMS마다 함수명이 다르거나 지원 여부가 다른 경우가 많기 때문에, 실무에서 DBMS를 바꾸거나 함께 다룰 때 혼란이 생기기 쉽다. 이 글은 그 차이를 표와 코드 예시 중심으로 명확하게 정리한다.

| 섹션 | 내용 |
|------|------|
| 2. 데이터베이스 키 | PK, FK, UK, 복합키 + DBMS별 자동증가/옵션 차이 |
| 3. 조건식과 연산자 | WHERE, LIKE, CASE, NULL 처리 함수 비교 |
| 4. 집계함수 | COUNT/SUM/AVG/COALESCE + 날짜 집계 DBMS별 차이 |

---

## 2. 데이터베이스 키

### 📌 기본 키 (Primary Key) — 자동 증가 방식 비교

테이블에서 각 행을 유일하게 식별하는 컬럼이다. NULL 불가, 중복 불가라는 두 가지 절대 규칙이 있다.

실생활 비유: 주민등록번호가 PK다. 같은 번호를 가진 두 사람은 없고, 번호가 없는 사람도 없다.

> 💡 DBMS별 자동 증가 방식이 다르다. 이 부분에서 가장 많이 헷갈린다.

```sql
/**
 * 각 DBMS마다 자동 증가 컬럼 선언 방식이 다르다.
 * Oracle은 12c 이후 IDENTITY를 지원하며, 이전 버전은 SEQUENCE + TRIGGER 조합을 써야 한다.
 */

-- Oracle (12c 이상)
CREATE TABLE users (
    user_id   NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username  VARCHAR2(50)  NOT NULL,
    email     VARCHAR2(100)
);

-- MySQL
CREATE TABLE users (
    user_id   INT           AUTO_INCREMENT PRIMARY KEY,
    username  VARCHAR(50)   NOT NULL,
    email     VARCHAR(100)
);

-- PostgreSQL
CREATE TABLE users (
    user_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- 권장 (10 이상)
    -- SERIAL도 가능하나 구방식
    username  VARCHAR(50)   NOT NULL,
    email     VARCHAR(100)
);
```

| 항목 | Oracle | MySQL | PostgreSQL |
|------|--------|-------|------------|
| 자동 증가 | `GENERATED AS IDENTITY` | `AUTO_INCREMENT` | `SERIAL` 또는 `GENERATED AS IDENTITY` |
| 문자열 타입 | `VARCHAR2` (권장) | `VARCHAR` | `VARCHAR` |
| 숫자 타입 | `NUMBER` | `INT`, `BIGINT` | `INTEGER`, `BIGINT` |

---

### 📌 외래 키 (Foreign Key) — ON DELETE/UPDATE 옵션 지원 차이

다른 테이블의 PK를 참조하는 컬럼이다. 참조 무결성(Referential Integrity)을 보장한다.

> 💡 Oracle은 ON UPDATE CASCADE를 지원하지 않는다. 실무에서 Oracle을 쓰다가 MySQL/PostgreSQL로 전환할 때 자주 놓치는 부분이다.

```sql
/**
 * ON DELETE 옵션:
 * - CASCADE  : 부모 삭제 시 자식도 같이 삭제
 * - SET NULL : 부모 삭제 시 자식 FK를 NULL로 변경
 * - RESTRICT : 자식이 존재하면 부모 삭제 불가 (기본값)
 */

-- Oracle (ON UPDATE 미지원)
CREATE TABLE orders (
    order_id  NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id   NUMBER NOT NULL,
    CONSTRAINT fk_orders_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE
);

-- MySQL (ON UPDATE 지원)
CREATE TABLE orders (
    order_id  INT AUTO_INCREMENT PRIMARY KEY,
    user_id   INT NOT NULL,
    CONSTRAINT fk_orders_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- PostgreSQL (ON UPDATE + DEFERRABLE 지원)
CREATE TABLE orders (
    order_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id   INT NOT NULL,
    CONSTRAINT fk_orders_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
        DEFERRABLE INITIALLY DEFERRED -- 트랜잭션 끝에 제약 검사 (PostgreSQL 전용)
);
```

| 옵션 | Oracle | MySQL | PostgreSQL |
|------|--------|-------|------------|
| ON DELETE CASCADE | ✅ | ✅ | ✅ |
| ON DELETE SET NULL | ✅ | ✅ | ✅ |
| ON DELETE RESTRICT | ✅ (기본) | ✅ | ✅ |
| ON UPDATE CASCADE | ❌ | ✅ | ✅ |
| DEFERRABLE | ✅ | ❌ | ✅ |

---

### 📌 유니크 키 & 복합 키

유니크 키는 PK와 달리 NULL을 허용하지만 중복 값은 허용하지 않는다. 세 DBMS 모두 문법이 동일하다.

```sql
/**
 * 복합 PK: 수강신청처럼 두 컬럼의 조합이 유일해야 할 때 사용한다.
 * 복합 UNIQUE: 한 유저가 동일 소셜 타입 계정을 중복 연결하지 못하도록 할 때 유용하다.
 */

-- 복합 PK (세 DBMS 동일)
CREATE TABLE enrollments (
    student_id INT,
    course_id  INT,
    enrolled_at DATE,
    PRIMARY KEY (student_id, course_id)
);

-- 복합 UNIQUE (세 DBMS 동일)
CREATE TABLE user_socials (
    id          INT PRIMARY KEY,
    user_id     INT,
    social_type VARCHAR(20),   -- 'google', 'kakao', 'naver'
    UNIQUE (user_id, social_type) -- 한 유저당 소셜 타입 하나만
);
```

---

## 3. 조건식과 연산자

### 📌 NULL 처리 함수 — 함수명이 DBMS마다 다르다

> 💡 NULL은 "값이 없음"이다. `= NULL`이 아닌 `IS NULL`로 비교해야 한다. NULL 대체 함수는 DBMS마다 이름이 달라서 이식성에서 자주 문제가 된다. 실무에서는 표준 SQL인 COALESCE를 쓰는 것이 가장 안전하다.

```sql
/**
 * NVL은 Oracle 전용, IFNULL은 MySQL 전용이다.
 * COALESCE는 세 DBMS 모두 지원하며, 여러 인자 중 첫 NOT NULL을 반환한다.
 */

-- Oracle: NVL, NVL2, NULLIF
SELECT
    NVL(phone, '번호없음')                AS phone,
    NVL2(last_login_at, '활성', '비활성') AS status, -- NVL2(컬럼, NOT NULL일때, NULL일때)
    NULLIF(grade, 'N/A')                   AS grade
FROM users;

-- MySQL: IFNULL, IF, NULLIF
SELECT
    IFNULL(phone, '번호없음')                       AS phone,
    IF(last_login_at IS NOT NULL, '활성', '비활성') AS status,
    NULLIF(grade, 'N/A')                            AS grade
FROM users;

-- PostgreSQL: COALESCE, NULLIF (NVL, IFNULL 없음)
SELECT
    COALESCE(phone, '번호없음')                     AS phone,
    CASE WHEN last_login_at IS NOT NULL
         THEN '활성' ELSE '비활성' END              AS status,
    NULLIF(grade, 'N/A')                            AS grade
FROM users;

-- 세 DBMS 모두 지원하는 COALESCE (가장 안전)
SELECT
    COALESCE(mobile_phone, home_phone, office_phone, '연락불가') AS contact
FROM users;
```

| 기능 | Oracle | MySQL | PostgreSQL |
|------|--------|-------|------------|
| NULL이면 대체값 | `NVL(a, b)` | `IFNULL(a, b)` | `COALESCE(a, b)` |
| 여러 값 중 첫 NOT NULL | `COALESCE(...)` | `COALESCE(...)` | `COALESCE(...)` |
| NULL이면 A, 아니면 B | `NVL2(c, A, B)` | `IF(c IS NOT NULL, A, B)` | `CASE WHEN ... END` |
| 두 값 같으면 NULL | `NULLIF(a, b)` | `NULLIF(a, b)` | `NULLIF(a, b)` |

---

### 📌 날짜 비교 함수

```sql
/**
 * 현재 날짜를 가져오는 함수명이 DBMS마다 다르다.
 * 날짜 연산 문법도 다르므로 주의해야 한다.
 */

-- Oracle
SELECT * FROM orders WHERE order_date >= SYSDATE - 30;      -- 현재 날짜+시간
SELECT * FROM orders WHERE order_date >= TRUNC(SYSDATE);    -- 오늘 날짜만

-- MySQL
SELECT * FROM orders WHERE order_date >= NOW() - INTERVAL 30 DAY;
SELECT * FROM orders WHERE order_date >= CURDATE();

-- PostgreSQL
SELECT * FROM orders WHERE order_date >= NOW() - INTERVAL '30 days';
SELECT * FROM orders WHERE order_date >= CURRENT_DATE;

-- ⚠️ LIKE 대소문자 구분 차이
-- Oracle:     기본적으로 대소문자 구분
-- MySQL:      기본적으로 대소문자 구분 안 함
-- PostgreSQL: LIKE는 구분, ILIKE는 구분 안 함 (PostgreSQL 전용)
SELECT * FROM users WHERE email ILIKE '%gmail%'; -- PostgreSQL 전용
```

| 기능 | Oracle | MySQL | PostgreSQL |
|------|--------|-------|------------|
| 현재 날짜+시간 | `SYSDATE` | `NOW()` | `NOW()` |
| 현재 날짜만 | `TRUNC(SYSDATE)` | `CURDATE()` | `CURRENT_DATE` |
| 날짜 포맷 | `TO_CHAR(d, 'YYYY-MM-DD')` | `DATE_FORMAT(d, '%Y-%m-%d')` | `TO_CHAR(d, 'YYYY-MM-DD')` |
| 날짜 더하기 | `SYSDATE + 30` | `NOW() + INTERVAL 30 DAY` | `NOW() + INTERVAL '30 days'` |
| 날짜 버림(월) | `TRUNC(d, 'MM')` | `DATE_FORMAT(d, '%Y-%m-01')` | `DATE_TRUNC('month', d)` |

---

## 4. 집계함수

### 📌 기본 집계함수

COUNT, SUM, AVG, MAX, MIN은 세 DBMS 모두 동일하다.

```sql
/**
 * COUNT(*)는 NULL 포함 전체 행을, COUNT(컬럼)은 NULL 제외 행을 센다.
 * WHERE는 집계 전 행 필터링, HAVING은 집계 후 그룹 필터링이다.
 */

SELECT
    COUNT(*)                   AS 전체행수,
    COUNT(phone)               AS 전화있는수,   -- NULL 제외
    COUNT(DISTINCT department) AS 부서수,       -- 중복 제거
    SUM(salary)                AS 총급여,
    AVG(salary)                AS 평균급여,
    MAX(salary)                AS 최고급여,
    MIN(salary)                AS 최저급여
FROM employees;

-- GROUP BY + HAVING
SELECT department, COUNT(*) AS 인원수
FROM employees
GROUP BY department
HAVING COUNT(*) >= 5; -- 5명 이상인 부서만
```

---

### 📌 소수점 처리 — PostgreSQL 주의사항

> 💡 PostgreSQL에서 `ROUND(AVG(...))`는 바로 쓰면 오류가 날 수 있다. AVG 결과가 FLOAT 타입이기 때문에 NUMERIC으로 캐스팅이 필요하다.

```sql
/**
 * Oracle/MySQL은 ROUND(AVG(...))가 바로 동작하지만,
 * PostgreSQL은 타입 캐스팅이 필요하다.
 */

-- Oracle
SELECT ROUND(AVG(salary), 2) FROM employees;
SELECT TRUNC(AVG(salary), 2) FROM employees; -- 버림 (Oracle 전용)

-- MySQL
SELECT ROUND(AVG(salary), 2) FROM employees;
SELECT TRUNCATE(AVG(salary), 2) FROM employees;

-- PostgreSQL (캐스팅 필수)
SELECT ROUND(AVG(salary)::NUMERIC, 2) FROM employees;
-- 또는
SELECT ROUND(CAST(AVG(salary) AS NUMERIC), 2) FROM employees;
```

---

### 📌 날짜별 집계 — GROUP BY에서 날짜 포맷 함수 차이

```sql
/**
 * 월별 집계 등 날짜를 그룹 기준으로 쓸 때,
 * 각 DBMS의 날짜 포맷 함수를 GROUP BY에도 동일하게 써줘야 한다.
 */

-- Oracle: TO_CHAR
SELECT TO_CHAR(order_date, 'YYYY-MM') AS 주문월, COUNT(*), SUM(amount)
FROM orders
GROUP BY TO_CHAR(order_date, 'YYYY-MM')
ORDER BY 주문월;

-- MySQL: DATE_FORMAT
SELECT DATE_FORMAT(order_date, '%Y-%m') AS 주문월, COUNT(*), SUM(amount)
FROM orders
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY 주문월;

-- PostgreSQL: TO_CHAR 또는 DATE_TRUNC
SELECT TO_CHAR(order_date, 'YYYY-MM') AS 주문월, COUNT(*), SUM(amount)
FROM orders
GROUP BY TO_CHAR(order_date, 'YYYY-MM')
ORDER BY 주문월;
```

---

### 📌 GROUP BY 별칭 사용 차이

> 💡 MySQL은 SELECT에서 선언한 별칭을 GROUP BY에서도 쓸 수 있지만, Oracle과 PostgreSQL은 GROUP BY에서 별칭 사용이 불가하다.

```sql
-- Oracle: GROUP BY에 원래 컬럼명 사용 (별칭 불가)
SELECT department AS dept, COUNT(*) FROM employees GROUP BY department;

-- MySQL: 별칭 사용 가능
SELECT department AS dept, COUNT(*) cnt FROM employees
GROUP BY dept ORDER BY cnt DESC;

-- PostgreSQL: GROUP BY 불가, ORDER BY는 가능
SELECT department AS dept, COUNT(*) AS cnt FROM employees
GROUP BY department ORDER BY cnt DESC;
```

---

## 5. 정리

- PK 자동 증가: Oracle은 `GENERATED AS IDENTITY`, MySQL은 `AUTO_INCREMENT`, PostgreSQL은 `SERIAL` 또는 `GENERATED AS IDENTITY`
- FK ON UPDATE: Oracle은 지원하지 않는다
- NULL 대체 함수: 표준인 `COALESCE`를 쓰면 세 DBMS 모두 호환 가능하다
- PostgreSQL ROUND: `AVG()` 결과에 `::NUMERIC` 캐스팅 필수
- GROUP BY 별칭: MySQL만 허용, Oracle·PostgreSQL은 불가
- 날짜 포맷: Oracle·PostgreSQL은 `TO_CHAR`, MySQL은 `DATE_FORMAT`

---

## 6. 참고 자료

- [Oracle SQL Reference](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/)
- [MySQL 8.0 Reference Manual](https://dev.mysql.com/doc/refman/8.0/en/)
- [PostgreSQL 16 Documentation](https://www.postgresql.org/docs/current/)
- 출처: Claude Desktop 대화 (2026-04-23)
