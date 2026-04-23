---
title: 시퀀스 & 인덱스
date: 2026-04-23 04:00:00 +0900
categories: [DB, 이론]
order: 5
tags: [SQL, Oracle, MySQL, PostgreSQL, 시퀀스, 인덱스, BTree, 성능최적화, 인덱스튜닝]
---

## 1. 개요

시퀀스와 인덱스는 실무에서 가장 자주 마주치는 DB 객체다. 시퀀스는 DBMS마다 지원 방식이 크게 다르고, 인덱스는 만드는 것보다 "언제 사용되고 언제 무력화되는지"를 아는 것이 훨씬 중요하다. 이 글은 DBMS별 문법 차이와 함께 인덱스가 실제로 동작하는 원리, 그리고 실무에서 자주 하는 실수를 중심으로 정리한다.

| 섹션 | 내용 |
|------|------|
| 2. 시퀀스 | DBMS별 시퀀스 생성·사용·CACHE 옵션 |
| 3. 인덱스 | B-Tree 구조, 생성·관리, 사용/미사용 케이스 |
| 4. 인덱스 주의사항 | 만들면 안 되는 경우, 단편화 재구성 |

---

## 2. 시퀀스 (Sequence)

시퀀스는 자동으로 증가하는 숫자를 생성하는 DB 객체다. 주로 PK의 자동 증가 값을 생성할 때 사용한다.

### 📌 시퀀스 생성 및 사용 — DBMS별 차이가 큰 영역

```sql
/**
 * Oracle: 시퀀스를 별도 객체로 생성한 뒤 NEXTVAL / CURRVAL로 값을 꺼낸다.
 * NEXTVAL: 다음 값 생성 (INSERT마다 호출)
 * CURRVAL: 현재 세션에서 마지막으로 생성한 값 (NEXTVAL 호출 후에만 사용 가능)
 */

-- ✅ Oracle
CREATE SEQUENCE seq_users
    START WITH 1          -- 시작값
    INCREMENT BY 1        -- 증가값
    MINVALUE 1            -- 최솟값
    MAXVALUE 9999999999   -- 최댓값
    NOCYCLE               -- 최댓값 도달 시 오류 (CYCLE이면 처음부터 재시작)
    NOCACHE               -- 캐시 없음 (CACHE 20이면 20개 미리 생성해 성능 향상)
    NOORDER;              -- 순서 보장 안 함

-- 시퀀스 사용
INSERT INTO users (user_id, username)
VALUES (seq_users.NEXTVAL, '홍길동');

-- 현재 값 조회 (NEXTVAL 호출 후에만 가능)
SELECT seq_users.CURRVAL FROM DUAL;

-- 시퀀스 정보 조회
SELECT sequence_name, last_number, increment_by, cache_size
FROM user_sequences
WHERE sequence_name = 'SEQ_USERS';

-- 시퀀스 수정 (START WITH는 수정 불가 — 변경 필요 시 DROP 후 재생성)
ALTER SEQUENCE seq_users INCREMENT BY 2;

-- 시퀀스 삭제
DROP SEQUENCE seq_users;
```

```sql
/**
 * MySQL: 독립적인 시퀀스 객체가 없다. AUTO_INCREMENT로 대체한다.
 * 별도 시퀀스 기능이 필요하면 별도 테이블로 직접 구현해야 한다.
 */

-- ✅ MySQL: AUTO_INCREMENT로 시퀀스 대체
CREATE TABLE users (
    user_id  INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL
);

-- INSERT 시 user_id 생략 → 자동 증가
INSERT INTO users (username) VALUES ('홍길동');

-- 마지막 삽입 ID 조회
SELECT LAST_INSERT_ID();

-- AUTO_INCREMENT 시작값 변경
ALTER TABLE users AUTO_INCREMENT = 1000;

-- 현재 AUTO_INCREMENT 값 확인
SELECT AUTO_INCREMENT
FROM information_schema.TABLES
WHERE TABLE_NAME  = 'users'
  AND TABLE_SCHEMA = DATABASE();

-- 독립 시퀀스가 필요할 때: 별도 테이블로 구현
CREATE TABLE sequences (
    seq_name    VARCHAR(50) PRIMARY KEY,
    current_val INT NOT NULL DEFAULT 0
);

-- 다음 값 채번 (트랜잭션 안에서 사용)
UPDATE sequences SET current_val = current_val + 1 WHERE seq_name = 'order_seq';
SELECT current_val FROM sequences WHERE seq_name = 'order_seq';
```

```sql
/**
 * PostgreSQL: SEQUENCE 객체를 직접 생성하거나 SERIAL / GENERATED AS IDENTITY로 사용한다.
 * SERIAL은 구방식이며, GENERATED AS IDENTITY가 SQL 표준에 가깝고 권장된다.
 */

-- ✅ PostgreSQL

-- 방법 1: SERIAL (구방식 — 내부적으로 시퀀스 자동 생성)
CREATE TABLE users (
    user_id  SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL
);

-- 방법 2: GENERATED AS IDENTITY (신방식, 권장 — PostgreSQL 10 이상)
CREATE TABLE users (
    user_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(50) NOT NULL
);

-- 방법 3: 시퀀스 직접 생성 후 사용 (Oracle과 유사)
CREATE SEQUENCE seq_users
    START WITH 1
    INCREMENT BY 1
    NO CYCLE
    CACHE 20;

INSERT INTO users (user_id, username)
VALUES (NEXTVAL('seq_users'), '홍길동');

-- 현재 값 조회
SELECT CURRVAL('seq_users');   -- 현재 세션의 특정 시퀀스 마지막 값
SELECT LASTVAL();              -- 현재 세션의 가장 최근 시퀀스 값

-- 시퀀스 정보 조회
SELECT * FROM information_schema.sequences
WHERE sequence_name = 'seq_users';
```

| 항목 | Oracle | MySQL | PostgreSQL |
|------|--------|-------|------------|
| 독립 시퀀스 객체 | ✅ | ❌ | ✅ |
| 자동 증가 컬럼 | `GENERATED AS IDENTITY` | `AUTO_INCREMENT` | `SERIAL` / `GENERATED AS IDENTITY` |
| 다음 값 | `seq.NEXTVAL` | `LAST_INSERT_ID()` | `NEXTVAL('seq')` |
| 현재 값 | `seq.CURRVAL` | — | `CURRVAL('seq')` / `LASTVAL()` |
| CACHE 옵션 | ✅ | — | ✅ |

---

### 📌 CACHE 옵션과 성능

```sql
/**
 * CACHE N: 시퀀스 값 N개를 미리 메모리에 생성해두어 채번 속도를 높인다.
 * 단, DB 재시작 시 캐시된 값이 날아가 번호가 건너뛸 수 있다.
 * 번호 연속성이 중요한 업무(전표번호, 회계)에는 NOCACHE를 사용해야 한다.
 */

-- ✅ Oracle / PostgreSQL
CREATE SEQUENCE seq_orders
    START WITH 1
    INCREMENT BY 1
    CACHE 50;    -- 대용량 INSERT가 잦으면 캐시 크게 설정

-- ⚠️ CACHE 사용 시 주의사항
-- 번호가 연속적이지 않아도 되는 경우에만 사용
-- 회계·전표번호처럼 연속성이 중요한 경우 NOCACHE 사용
```

---

## 3. 인덱스 (Index)

인덱스는 테이블의 특정 컬럼에 대한 검색 속도를 높이기 위한 자료 구조다. 책의 목차처럼, 전체를 뒤지지 않고 원하는 데이터를 빠르게 찾을 수 있게 해준다.

### 📌 B-Tree 내부 구조

대부분의 인덱스는 B-Tree(Balanced Tree) 구조다.

```
              [50]
            /       \
      [20, 35]      [70, 90]
     /   |   \      /   |   \
  [10] [25] [40] [60] [80] [100]
```

루트 → 브랜치 → 리프 노드 순으로 탐색하며 항상 O(log N) 시간에 데이터를 찾을 수 있다. 리프 노드에는 실제 데이터의 주소(ROWID)가 저장되고, 삽입·삭제 시 트리를 재조정하므로 쓰기 성능에 영향을 준다.

---

### 📌 인덱스 생성 및 관리

```sql
/**
 * 단일 컬럼 인덱스: 하나의 컬럼에 대한 기본 인덱스
 * 복합 인덱스: 두 개 이상의 컬럼을 묶어서 생성, 컬럼 순서가 매우 중요하다
 * 유니크 인덱스: 중복값을 허용하지 않는 인덱스
 */

-- ✅ 단일 컬럼 인덱스 (세 DBMS 동일)
CREATE INDEX idx_users_email ON users(email);

-- ✅ 복합 인덱스 (세 DBMS 동일)
-- 선두 컬럼(user_id)부터 매칭되므로 컬럼 순서가 핵심이다
CREATE INDEX idx_orders_user_date ON orders(user_id, order_date);

-- ✅ 유니크 인덱스 (세 DBMS 동일)
CREATE UNIQUE INDEX idx_users_email_unique ON users(email);

-- ✅ Oracle 전용 인덱스 옵션

-- 내림차순 인덱스
CREATE INDEX idx_orders_date_desc ON orders(order_date DESC);

-- 함수 기반 인덱스 (Function-Based Index)
-- WHERE UPPER(email) = '...' 처럼 함수를 적용한 조건에서 인덱스를 사용할 수 있게 한다
CREATE INDEX idx_users_upper_email ON users(UPPER(email));

-- ✅ MySQL 전용

-- 전문 검색 인덱스 (FULLTEXT)
CREATE FULLTEXT INDEX idx_products_name ON products(name, description);
-- 사용: WHERE MATCH(name, description) AGAINST('검색어')

-- ✅ PostgreSQL 전용

-- 부분 인덱스: 조건을 만족하는 행에만 인덱스를 생성해 크기를 줄인다
CREATE INDEX idx_orders_pending ON orders(user_id)
WHERE status = 'PENDING';

-- GIN 인덱스: 배열, JSONB, 전문 검색에 사용
CREATE INDEX idx_products_tags ON products USING GIN(tags);

-- BRIN 인덱스: 대용량 순차 데이터(로그 테이블 등)에 효율적
CREATE INDEX idx_logs_created ON logs USING BRIN(created_at);
```

---

### 📌 인덱스 조회 및 삭제

```sql
/**
 * 인덱스 목록 조회 방법이 DBMS마다 다르다.
 * 삭제 시 MySQL은 테이블명을 함께 지정해야 한다.
 */

-- ✅ Oracle
SELECT index_name, table_name, column_name, column_position
FROM user_ind_columns
WHERE table_name = 'ORDERS'
ORDER BY index_name, column_position;

-- ✅ MySQL
SHOW INDEX FROM orders;
-- 또는
SELECT index_name, column_name, non_unique, seq_in_index
FROM information_schema.statistics
WHERE table_name  = 'orders'
  AND table_schema = DATABASE();

-- ✅ PostgreSQL
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'orders';

-- ✅ 인덱스 삭제

-- Oracle
DROP INDEX idx_users_email;

-- MySQL (테이블명 필수)
DROP INDEX idx_users_email ON users;
-- 또는
ALTER TABLE users DROP INDEX idx_users_email;

-- PostgreSQL
DROP INDEX idx_users_email;
DROP INDEX IF EXISTS idx_users_email;  -- 존재하지 않아도 오류 없음
```

---

### 📌 인덱스가 사용되는 경우 vs 사용되지 않는 경우

> 💡 인덱스를 만들었다고 해서 항상 사용되는 것이 아니다. 쿼리 작성 방식에 따라 인덱스가 완전히 무력화될 수 있다. 아래 패턴을 반드시 숙지해야 한다.

```sql
-- ✅ 인덱스 사용 O

-- 1. 컬럼을 가공하지 않고 그대로 비교
SELECT * FROM users WHERE email = 'test@gmail.com';

-- 2. 복합 인덱스 선두 컬럼 포함 범위 검색
-- idx_orders_user_date: (user_id, order_date) 복합 인덱스
SELECT * FROM orders WHERE user_id = 1 AND order_date >= '2024-01-01';

-- 3. LIKE 전방 일치 (% 가 뒤에만 있을 때)
SELECT * FROM users WHERE username LIKE '김%';

-- 4. IS NULL (MySQL / PostgreSQL은 인덱스 사용 가능)
SELECT * FROM users WHERE phone IS NULL;
-- ⚠️ Oracle은 NULL을 인덱스에 저장하지 않아 IS NULL에서 인덱스 미사용


-- ❌ 인덱스 사용 X — 실무에서 가장 자주 하는 실수

-- 1. 컬럼에 함수 적용
SELECT * FROM users WHERE UPPER(email) = 'TEST@GMAIL.COM';
-- → 해결책: Oracle/PostgreSQL은 함수 기반 인덱스 생성
--           또는 데이터를 처음부터 대문자로 저장

-- 2. 묵시적 형변환 — 타입 불일치
SELECT * FROM orders WHERE user_id = '1';
-- user_id가 INT인데 문자열로 비교 → 내부적으로 형변환 발생 → 인덱스 무력화
-- → 해결책: 타입을 맞춰서 WHERE user_id = 1 로 쿼리 작성

-- 3. LIKE 후방/양방 일치
SELECT * FROM users WHERE username LIKE '%길동';  -- ❌ 풀스캔
SELECT * FROM users WHERE username LIKE '%길%';   -- ❌ 풀스캔
-- → 전문 검색이 필요하면 FULLTEXT 인덱스 또는 Elasticsearch 사용

-- 4. OR 조건 (각각 인덱스가 있어도 최적화 안 될 수 있음)
SELECT * FROM users WHERE email = 'a@b.com' OR phone = '010-1234-5678';
-- → UNION ALL로 분리하면 각각 인덱스 사용 가능
SELECT * FROM users WHERE email = 'a@b.com'
UNION ALL
SELECT * FROM users WHERE phone = '010-1234-5678';

-- 5. NOT, <>, != 연산자
SELECT * FROM orders WHERE status != 'COMPLETE';
-- 대부분 풀스캔. 가능하면 역방향 조건으로 재작성

-- 6. 복합 인덱스에서 선두 컬럼 미포함
-- idx_orders_user_date: (user_id, order_date) 복합 인덱스
SELECT * FROM orders WHERE order_date = '2024-01-01';
-- user_id 없이 order_date만으로 검색 → 인덱스 사용 안 됨
SELECT * FROM orders WHERE user_id = 1;
-- user_id만 사용 → 선두 컬럼 포함이므로 인덱스 사용 O
```

---

## 4. 인덱스 주의사항

### 📌 인덱스를 만들면 안 되는 경우

```sql
/**
 * 인덱스가 오히려 성능을 해치는 상황이 있다.
 * 무분별한 인덱스 생성은 쓰기 성능 전반을 저하시키므로 반드시 선별해서 생성해야 한다.
 */

-- 1. 카디널리티(Cardinality)가 낮은 컬럼
-- gender 컬럼: 'M', 'F' 두 가지 값 → 전체 50% 선택 → 풀스캔이 더 빠름
CREATE INDEX idx_users_gender ON users(gender);  -- ❌ 효과 없음
-- 기준: 전체 데이터의 약 5~10% 이하를 선택하는 컬럼에만 인덱스가 효과적

-- 2. 자주 UPDATE되는 컬럼
-- 인덱스는 INSERT / UPDATE / DELETE 시마다 재구성된다
-- 쓰기가 매우 잦은 컬럼에 인덱스를 많이 만들면 쓰기 성능 저하

-- 3. 데이터가 적은 테이블
-- 수백~수천 건 수준이면 풀스캔이 오히려 빠르다
-- 옵티마이저가 자동으로 판단하지만 불필요한 인덱스는 관리 부담만 늘린다

-- 4. 인덱스 과다 생성
-- 테이블 하나에 인덱스가 너무 많으면 DML(INSERT/UPDATE/DELETE) 성능이 전반적으로 저하된다
-- 실제로 사용되는 인덱스만 유지하고, 안 쓰는 인덱스는 정기적으로 삭제해야 한다
```

---

### 📌 인덱스 재구성 — 단편화 해결

```sql
/**
 * 인덱스는 시간이 지나면서 INSERT / DELETE로 인해 단편화(fragmentation)가 발생한다.
 * 단편화가 심해지면 인덱스 성능이 저하되므로 주기적인 재구성이 필요하다.
 */

-- ✅ Oracle
ALTER INDEX idx_orders_user_date REBUILD;           -- 인덱스 재구성
ALTER INDEX idx_orders_user_date REBUILD ONLINE;    -- 서비스 중단 없이 재구성 (권장)

-- 인덱스 구조 분석
ANALYZE INDEX idx_orders_user_date VALIDATE STRUCTURE;

-- ✅ MySQL
OPTIMIZE TABLE orders;   -- 테이블 + 인덱스 전체 재구성

-- ✅ PostgreSQL
REINDEX INDEX idx_orders_user_date;   -- 특정 인덱스 재구성
REINDEX TABLE orders;                 -- 테이블 전체 인덱스 재구성
VACUUM ANALYZE orders;                -- 불필요 공간 회수 + 통계 갱신
```

---

## 5. 정리

- Oracle과 PostgreSQL은 독립 시퀀스 객체를 지원하지만 MySQL은 AUTO_INCREMENT로 대체한다
- CACHE 옵션은 채번 성능을 높이지만 번호 연속성이 필요한 업무에는 NOCACHE를 써야 한다
- B-Tree 인덱스는 항상 O(log N) 탐색을 보장하지만 쓰기 시 트리 재조정 비용이 발생한다
- 컬럼에 함수를 적용하거나 묵시적 형변환이 일어나면 인덱스가 무력화된다
- LIKE는 전방 일치(`김%`)만 인덱스를 사용하고, 후방·양방 일치는 풀스캔이 발생한다
- 복합 인덱스는 선두 컬럼을 반드시 포함해야 인덱스가 동작한다
- 카디널리티가 낮은 컬럼, 데이터가 적은 테이블, 자주 UPDATE되는 컬럼에는 인덱스를 만들지 않는다
- 인덱스 단편화는 주기적인 REBUILD / REINDEX / VACUUM으로 해소해야 한다

---

## 6. 참고 자료

- [Oracle 시퀀스 공식 문서](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/CREATE-SEQUENCE.html)
- [Oracle 인덱스 공식 문서](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/CREATE-INDEX.html)
- [MySQL AUTO_INCREMENT 공식 문서](https://dev.mysql.com/doc/refman/8.0/en/example-auto-increment.html)
- [MySQL 인덱스 공식 문서](https://dev.mysql.com/doc/refman/8.0/en/optimization-indexes.html)
- [PostgreSQL 시퀀스 공식 문서](https://www.postgresql.org/docs/current/sql-createsequence.html)
- [PostgreSQL 인덱스 공식 문서](https://www.postgresql.org/docs/current/indexes.html)
- 출처: Claude Desktop 대화 (2026-04-23)
