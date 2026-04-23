---
title: SQL 성능 튜닝
date: 2026-04-23 05:00:00 +0900
categories: [DB, 이론]
order: 6
tags: [SQL, Oracle, MySQL, PostgreSQL, 성능튜닝, 실행계획, 슬로우쿼리, EXPLAIN, 인덱스튜닝, N+1]
---

## 1. 개요

성능 튜닝은 단순히 인덱스를 추가하는 것이 아니다. 실행 계획을 읽고 병목을 찾은 뒤, 쿼리 재작성·인덱스 추가·통계 갱신·힌트 적용 등 다양한 방법을 조합해서 해결한다. 이 글은 Oracle, MySQL, PostgreSQL 세 DBMS에서의 실행 계획 분석, 슬로우 쿼리 감지, 그리고 쿼리 작성 시 반드시 지켜야 할 성능 주의사항을 정리한다.

| 섹션 | 내용 |
|------|------|
| 2. 실행 계획 분석 | EXPLAIN 사용법, 핵심 용어 해석 |
| 3. 슬로우 쿼리 감지 | 로그 설정, 분석 쿼리, 튜닝 프로세스 |
| 4. 쿼리 작성 주의사항 | N+1, OFFSET, NULL, 조인 순서, 통계 갱신 |
| 5. 튜닝 체크리스트 | 실전 점검 항목 |

---

## 2. 실행 계획 분석 (Execution Plan)

실행 계획은 옵티마이저가 SQL을 어떻게 실행할지 결정한 경로다. 슬로우 쿼리를 튜닝하려면 실행 계획을 읽는 것이 첫 번째다.

### 📌 실행 계획 확인 방법

```sql
/**
 * Oracle:     EXPLAIN PLAN FOR + DBMS_XPLAN.DISPLAY()
 * MySQL:      EXPLAIN / EXPLAIN ANALYZE (8.0.18 이상)
 * PostgreSQL: EXPLAIN / EXPLAIN (ANALYZE, BUFFERS)
 *
 * EXPLAIN ANALYZE는 실제로 쿼리를 실행한다.
 * DML(INSERT/UPDATE/DELETE)에 사용 시 실제 반영되므로 주의해야 한다.
 * DML 분석이 필요하면 트랜잭션으로 감싸고 ROLLBACK해야 한다.
 */

-- ✅ Oracle: EXPLAIN PLAN + DBMS_XPLAN
EXPLAIN PLAN FOR
SELECT u.username, COUNT(o.order_id) AS 주문수
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
GROUP BY u.username;

-- 실행 계획 결과 조회
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());

-- 실제 실행 통계까지 함께 보기 (쿼리 실행 후 확인)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));

-- ✅ MySQL: EXPLAIN / EXPLAIN ANALYZE
EXPLAIN
SELECT u.username, COUNT(o.order_id) AS 주문수
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
GROUP BY u.username;

-- EXPLAIN ANALYZE: 실제 실행 + 예측값 vs 실제값 비교 (MySQL 8.0.18 이상)
EXPLAIN ANALYZE
SELECT u.username, COUNT(o.order_id)
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
GROUP BY u.username;

-- ✅ PostgreSQL: EXPLAIN / EXPLAIN ANALYZE
EXPLAIN
SELECT u.username, COUNT(o.order_id)
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
GROUP BY u.username;

-- EXPLAIN ANALYZE + BUFFERS: 실제 실행 + 버퍼 캐시 히트/미스 통계
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.username, COUNT(o.order_id)
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
GROUP BY u.username;
-- FORMAT JSON: JSON 형태 출력 (시각화 도구 연동 시 유용)
```

---

### 📌 MySQL EXPLAIN 결과 해석

```sql
/**
 * MySQL EXPLAIN 결과에서 가장 중요한 컬럼은 type과 key다.
 * type이 ALL이면 풀스캔, key가 NULL이면 인덱스 미사용이다.
 * Extra의 Using filesort, Using temporary는 반드시 개선해야 한다.
 */

/*
+----+-------------+-------+------+---------------+---------+---------+--------+------+----------------+
| id | select_type | table | type | possible_keys | key     | key_len | ref    | rows | Extra          |
+----+-------------+-------+------+---------------+---------+---------+--------+------+----------------+
|  1 | SIMPLE      | u     | ALL  | NULL          | NULL    | NULL    | NULL   | 1000 | Using filesort |
|  1 | SIMPLE      | o     | ref  | fk_user       | fk_user | 4       | u.id   |    5 | NULL           |
+----+-------------+-------+------+---------------+---------+---------+--------+------+----------------+
*/

-- type 접근 방식 (좋은 순서 → 나쁜 순서)
-- system  : 테이블에 행이 1개 (상수)
-- const   : PK/유니크 인덱스로 단 1건 조회
-- eq_ref  : JOIN에서 PK/유니크 인덱스로 1건 매칭
-- ref     : 인덱스로 여러 건 매칭
-- range   : 인덱스 범위 스캔 (BETWEEN, >, <, IN 등)
-- index   : 인덱스 풀스캔 (테이블 풀스캔보다는 나음)
-- ALL     : 테이블 풀스캔 → 가장 나쁨, 튜닝 필요
```

| 컬럼 | 의미 | 주의할 값 |
|------|------|----------|
| `type` | 접근 방식 | `ALL` (풀스캔) → 가장 나쁨 |
| `key` | 실제 사용된 인덱스 | `NULL` 이면 인덱스 미사용 |
| `rows` | 옵티마이저 예측 처리 행 수 | 클수록 성능 저하 |
| `Extra` | 추가 정보 | `Using filesort`, `Using temporary` → 개선 필요 |

---

### 📌 PostgreSQL EXPLAIN 결과 해석

```sql
/**
 * PostgreSQL EXPLAIN은 비용(cost)과 실제 실행 시간(actual time)을 함께 보여준다.
 * Seq Scan이 나오면 인덱스 적용을 검토해야 한다.
 * cost의 첫 번째 값은 첫 행을 반환하는 비용, 두 번째는 전체 비용이다.
 */

/*
Seq Scan on users  (cost=0.00..25.00 rows=1000 width=50)
                   (actual time=0.010..0.185 rows=1000 loops=1)
  -> Hash Join  (cost=15.00..45.00 rows=5000 width=30)
                (actual time=0.250..1.200 rows=4800 loops=1)
       Hash Cond: (o.user_id = u.user_id)
*/
```

| 항목 | 의미 |
|------|------|
| `cost=0.00..25.00` | 예상 비용 (시작비용..총비용) |
| `rows=1000` | 옵티마이저 예측 행 수 |
| `actual time` | 실제 실행 시간 (ms) |
| `Seq Scan` | 순차 스캔 (풀스캔) → 인덱스 검토 필요 |
| `Index Scan` | 인덱스 스캔 → 양호 |
| `Hash Join` | 해시 조인 → 대용량에서 일반적 |
| `Nested Loop` | 중첩 루프 조인 → 소량 데이터에 유리 |

---

## 3. 슬로우 쿼리 감지 및 분석

### 📌 슬로우 쿼리 로그 설정

```sql
/**
 * Oracle:     v$sqlarea 뷰로 누적 실행 통계를 조회한다.
 * MySQL:      slow_query_log를 활성화하고 mysqldumpslow로 분석한다.
 * PostgreSQL: pg_stat_statements 확장을 설치하고 쿼리별 통계를 조회한다.
 */

-- ✅ Oracle: v$sqlarea로 느린 SQL 조회
SELECT sql_text,
       elapsed_time,
       executions,
       ROUND(elapsed_time / NULLIF(executions, 0) / 1000000, 2) AS avg_sec
FROM v$sqlarea
ORDER BY elapsed_time DESC
FETCH FIRST 10 ROWS ONLY;

-- 특정 SQL의 실행 계획 조회
SELECT * FROM TABLE(
    DBMS_XPLAN.DISPLAY_CURSOR('sql_id_here', 0, 'ALLSTATS')
);

-- ✅ MySQL: slow_query_log 설정 (my.cnf)
-- slow_query_log      = 1
-- slow_query_log_file = /var/log/mysql/slow.log
-- long_query_time     = 2    -- 2초 이상 걸리는 쿼리 기록

-- 런타임 설정 (재시작 없이 즉시 적용)
SET GLOBAL slow_query_log    = 'ON';
SET GLOBAL long_query_time   = 2;
SET GLOBAL slow_query_log_file = '/var/log/mysql/slow.log';

-- 슬로우 쿼리 로그 분석 도구 (터미널)
-- mysqldumpslow -s t -t 10 /var/log/mysql/slow.log
-- (실행 시간 기준 상위 10개 출력)

-- 현재 실행 중인 쿼리 확인
SHOW PROCESSLIST;
SHOW FULL PROCESSLIST;   -- 전체 쿼리 텍스트 포함

-- performance_schema로 슬로우 쿼리 분석 (MySQL 5.6 이상)
SELECT
    DIGEST_TEXT AS 쿼리패턴,
    COUNT_STAR  AS 실행횟수,
    ROUND(AVG_TIMER_WAIT / 1000000000000, 3) AS 평균실행초,
    ROUND(MAX_TIMER_WAIT / 1000000000000, 3) AS 최대실행초
FROM performance_schema.events_statements_summary_by_digest
ORDER BY AVG_TIMER_WAIT DESC
LIMIT 10;

-- ✅ PostgreSQL: pg_stat_statements 확장
-- postgresql.conf에 추가 후 재시작:
-- shared_preload_libraries = 'pg_stat_statements'
-- pg_stat_statements.track = all

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 슬로우 쿼리 상위 10개 조회
SELECT
    LEFT(query, 100)       AS 쿼리,
    calls                  AS 실행횟수,
    ROUND(total_exec_time::NUMERIC / calls, 2) AS 평균ms,
    ROUND(total_exec_time::NUMERIC, 2)         AS 총ms
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- 현재 실행 중인 쿼리 확인 (5초 이상 실행 중인 쿼리)
SELECT
    pid,
    now() - query_start AS 경과시간,
    query,
    state
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start < now() - INTERVAL '5 seconds'
ORDER BY 경과시간 DESC;
```

---

### 📌 슬로우 쿼리 튜닝 프로세스

```
1. 슬로우 쿼리 로그에서 느린 쿼리 식별
         ↓
2. EXPLAIN / EXPLAIN ANALYZE로 실행 계획 확인
         ↓
3. 문제 원인 파악
   - 풀스캔 (ALL / Seq Scan)
   - 인덱스 미사용 (key = NULL)
   - Using filesort / Using temporary
   - 잘못된 JOIN 순서 또는 드라이빙 테이블 선택
         ↓
4. 튜닝 적용
   - 인덱스 추가 또는 복합 인덱스 재설계
   - 쿼리 재작성 (서브쿼리 → JOIN, OR → UNION ALL 등)
   - 힌트로 실행 계획 유도
   - 통계 정보 갱신
         ↓
5. 실행 계획 재확인 → 개선 여부 검증
```

---

## 4. 쿼리 작성 시 성능 주의사항

### 📌 SELECT 컬럼 명시 & 커버링 인덱스

```sql
/**
 * SELECT *는 불필요한 컬럼까지 읽어서 네트워크·메모리를 낭비한다.
 * 커버링 인덱스: 쿼리에 필요한 컬럼이 모두 인덱스에 포함된 경우
 * 테이블 접근 없이 인덱스만으로 결과를 반환하므로 매우 빠르다.
 */

-- ❌ SELECT * — 불필요한 컬럼까지 네트워크·메모리 낭비
SELECT * FROM orders WHERE user_id = 1;

-- ✅ 필요한 컬럼만 명시
SELECT order_id, amount, status FROM orders WHERE user_id = 1;

-- ✅ 커버링 인덱스 활용
-- idx_orders_user_status: (user_id, status, amount) 복합 인덱스가 있을 때
-- 아래 쿼리는 인덱스만으로 결과를 완성 → 테이블 접근 없음 (Index Only Scan)
SELECT status, amount FROM orders WHERE user_id = 1;
```

---

### 📌 N+1 문제

```sql
/**
 * N+1 문제: 목록 1번 조회 후 각 항목마다 추가 쿼리를 실행하는 패턴이다.
 * ORM(JPA, MyBatis 등)을 사용할 때 가장 자주 발생한다.
 * JOIN으로 한 번에 해결하거나 IN 절로 일괄 조회해야 한다.
 */

-- ❌ N+1 문제: 유저 100명 조회 후 각각 주문 조회 → 총 101번 쿼리
SELECT * FROM users;                              -- 1번
SELECT * FROM orders WHERE user_id = 1;           -- 2번
SELECT * FROM orders WHERE user_id = 2;           -- 3번
-- ... 100번 반복 → 총 101번 쿼리 실행

-- ✅ JOIN으로 한 번에 해결 → 1번 쿼리
SELECT u.user_id, u.username, o.order_id, o.amount
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id;
```

---

### 📌 페이지네이션 성능 — OFFSET의 함정

```sql
/**
 * OFFSET 방식은 앞의 N건을 모두 읽고 버린 뒤 필요한 건수를 반환한다.
 * OFFSET이 클수록 읽고 버리는 데이터가 많아져 점점 느려진다.
 * 대용량 페이지네이션에는 커서 기반(Keyset) 방식을 사용해야 한다.
 */

-- ❌ OFFSET 방식 — 페이지가 깊어질수록 느려짐
-- OFFSET 100000이면 앞의 100000건을 읽고 버린 뒤 10건 반환
SELECT * FROM orders ORDER BY order_id LIMIT 10 OFFSET 100000;

-- ✅ 커서 기반 페이지네이션 (Keyset Pagination) — 대용량 권장
-- 마지막으로 받은 order_id를 기준으로 다음 페이지 조회
-- 항상 인덱스 range 스캔 → 페이지가 깊어져도 성능 일정

-- MySQL / PostgreSQL
SELECT * FROM orders
WHERE order_id > :last_id    -- 마지막으로 받은 ID 이후부터
ORDER BY order_id
LIMIT 10;

-- Oracle
SELECT * FROM orders
WHERE order_id > :last_id
ORDER BY order_id
FETCH FIRST 10 ROWS ONLY;
```

---

### 📌 NULL 처리와 인덱스 — Oracle 주의사항

```sql
/**
 * Oracle B-Tree 인덱스는 NULL을 저장하지 않는다.
 * 따라서 IS NULL 조건에서는 인덱스가 사용되지 않는다.
 * MySQL과 PostgreSQL은 NULL도 인덱스에 저장하므로 문제없다.
 */

-- ❌ Oracle에서 IS NULL은 인덱스 미사용 → 풀스캔 발생
SELECT * FROM users WHERE last_login IS NULL;

-- ✅ Oracle 해결책 1: 함수 기반 인덱스로 NULL 포함
CREATE INDEX idx_users_login_null ON users(NVL(last_login, DATE '1900-01-01'));
SELECT * FROM users
WHERE NVL(last_login, DATE '1900-01-01') = DATE '1900-01-01';

-- ✅ Oracle 해결책 2: 복합 인덱스에 상수 추가 (NULL 저장 트릭)
-- 리프 노드에 0이라는 상수가 함께 저장되어 NULL 행도 인덱스에 포함됨
CREATE INDEX idx_users_login ON users(last_login, 0);

-- ✅ MySQL / PostgreSQL: NULL도 인덱스에 저장 → 추가 처리 불필요
CREATE INDEX idx_users_login ON users(last_login);
SELECT * FROM users WHERE last_login IS NULL;   -- 인덱스 사용 O
```

---

### 📌 조인 순서와 힌트

```sql
/**
 * 옵티마이저가 자동으로 최적 조인 순서를 결정하지만,
 * 통계가 부정확하거나 복잡한 조인에서는 힌트로 유도해야 할 때가 있다.
 * 힌트는 최후의 수단이며, 통계 갱신으로 해결되는 경우가 더 많다.
 */

-- ✅ Oracle: 힌트(Hint)로 실행 계획 유도
SELECT /*+ LEADING(u o) USE_NL(o) */   -- u → o 순서, Nested Loop 조인 강제
    u.username, o.order_id
FROM users u
JOIN orders o ON u.user_id = o.user_id
WHERE u.department = '개발팀';

-- 자주 쓰는 Oracle 힌트
-- /*+ FULL(테이블) */          : 풀스캔 강제
-- /*+ INDEX(테이블 인덱스명) */ : 특정 인덱스 사용 강제
-- /*+ NO_INDEX(테이블) */      : 인덱스 사용 금지
-- /*+ PARALLEL(테이블, 4) */   : 4개 병렬 처리

-- ✅ MySQL: STRAIGHT_JOIN 또는 인덱스 힌트
-- STRAIGHT_JOIN: 쿼리에 작성된 순서대로 조인 강제
SELECT STRAIGHT_JOIN u.username, o.order_id
FROM users u
JOIN orders o ON u.user_id = o.user_id;

-- 인덱스 힌트
SELECT * FROM orders USE INDEX (idx_orders_user_date)   -- 해당 인덱스 사용 권장
WHERE user_id = 1;

SELECT * FROM orders FORCE INDEX (idx_orders_user_date) -- 해당 인덱스 사용 강제
WHERE user_id = 1;

-- ✅ PostgreSQL: 설정으로 특정 스캔 방식 비활성화
-- pg_hint_plan 확장 설치 후 Oracle과 유사한 힌트 사용 가능
-- 또는 세션 레벨 설정으로 특정 스캔 방식 제어
SET enable_seqscan  = OFF;   -- 순차 스캔 비활성화 → 인덱스 스캔 유도
SET enable_hashjoin = OFF;   -- 해시 조인 비활성화
-- ⚠️ 반드시 테스트 후 원복해야 한다
SET enable_seqscan  = ON;
SET enable_hashjoin = ON;
```

---

### 📌 통계 정보 갱신

```sql
/**
 * 옵티마이저는 통계 정보를 기반으로 실행 계획을 세운다.
 * 통계가 오래되면 잘못된 실행 계획을 선택해 성능이 급격히 저하될 수 있다.
 * 대량 INSERT/DELETE/UPDATE 후에는 반드시 통계를 갱신해야 한다.
 */

-- ✅ Oracle: DBMS_STATS
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => 'MYSCHEMA',
        tabname => 'ORDERS',
        cascade => TRUE    -- 인덱스 통계도 함께 갱신
    );
END;
/

-- 전체 스키마 통계 갱신
BEGIN
    DBMS_STATS.GATHER_SCHEMA_STATS('MYSCHEMA');
END;
/

-- ✅ MySQL: ANALYZE TABLE
ANALYZE TABLE orders;

-- ✅ PostgreSQL: ANALYZE / VACUUM ANALYZE
ANALYZE orders;          -- 특정 테이블 통계 갱신
ANALYZE;                 -- 전체 DB 통계 갱신
VACUUM ANALYZE orders;   -- 불필요 공간 회수 + 통계 갱신 동시에 (권장)
```

---

## 5. 쿼리 작성 튜닝 체크리스트

> 💡 쿼리를 작성하거나 리뷰할 때 아래 항목을 순서대로 점검한다. 특히 EXPLAIN 확인은 운영 배포 전 필수다.

```
✅ SELECT 절
   □ SELECT * 대신 필요한 컬럼만 명시했는가?
   □ 스칼라 서브쿼리가 있다면 LEFT JOIN으로 대체할 수 있는가?
   □ 커버링 인덱스를 활용할 수 있는 컬럼 구성인가?

✅ WHERE 절
   □ 인덱스 컬럼에 함수를 적용하지 않았는가? (UPPER, TRUNC 등)
   □ 인덱스 컬럼과 비교하는 값의 타입이 일치하는가? (묵시적 형변환 방지)
   □ LIKE를 쓴다면 전방 일치(김%)인가?
   □ OR 조건 대신 UNION ALL로 분리할 수 있는가?
   □ NOT IN 대신 NOT EXISTS를 쓰는 것이 더 안전한가?
   □ Oracle에서 IS NULL 조건에 인덱스가 적용되는가?

✅ JOIN
   □ ON 조건 컬럼 양쪽 모두 인덱스가 있는가?
   □ JOIN 컬럼 타입이 양쪽 테이블에서 일치하는가?
   □ 불필요한 테이블을 JOIN하고 있지 않은가?
   □ N+1 문제가 발생하는 구조는 아닌가?

✅ GROUP BY / ORDER BY
   □ GROUP BY 컬럼에 인덱스가 있는가?
   □ ORDER BY 컬럼에 인덱스가 있는가?
   □ HAVING 대신 WHERE로 먼저 필터링해서 처리 행 수를 줄일 수 있는가?

✅ 페이지네이션
   □ OFFSET이 큰 경우 커서 기반 페이지네이션으로 전환했는가?

✅ 실행 계획 확인
   □ EXPLAIN으로 풀스캔(ALL / Seq Scan)이 없는지 확인했는가?
   □ MySQL EXPLAIN의 Extra에 Using filesort, Using temporary가 없는가?
   □ 예측 rows와 실제 rows가 크게 차이나면 통계 갱신이 필요하다
```

---

## 6. 정리

- 실행 계획은 EXPLAIN으로 확인하며, EXPLAIN ANALYZE는 실제로 쿼리를 실행하므로 DML에는 주의해야 한다
- MySQL type=ALL, PostgreSQL Seq Scan이 나오면 풀스캔이므로 인덱스 적용을 검토해야 한다
- Oracle 슬로우 쿼리는 v$sqlarea, MySQL은 slow_query_log, PostgreSQL은 pg_stat_statements로 찾는다
- N+1 문제는 JOIN 또는 IN 절로 한 번에 해결해야 한다
- OFFSET 방식 페이지네이션은 페이지가 깊어질수록 느려진다 — 대용량에는 커서 기반으로 전환할 것
- Oracle B-Tree 인덱스는 NULL을 저장하지 않아 IS NULL에서 인덱스가 동작하지 않는다
- 힌트는 최후의 수단이며, 대부분의 경우 통계 갱신으로 먼저 해결을 시도해야 한다
- 대량 DML 후에는 반드시 통계를 갱신해야 옵티마이저가 올바른 실행 계획을 선택한다

---

## 7. 참고 자료

- [Oracle DBMS_XPLAN 공식 문서](https://docs.oracle.com/en/database/oracle/oracle-database/21/arpls/DBMS_XPLAN.html)
- [Oracle DBMS_STATS 공식 문서](https://docs.oracle.com/en/database/oracle/oracle-database/21/arpls/DBMS_STATS.html)
- [MySQL EXPLAIN 공식 문서](https://dev.mysql.com/doc/refman/8.0/en/explain.html)
- [MySQL performance_schema 공식 문서](https://dev.mysql.com/doc/refman/8.0/en/performance-schema.html)
- [PostgreSQL EXPLAIN 공식 문서](https://www.postgresql.org/docs/current/sql-explain.html)
- [PostgreSQL pg_stat_statements 공식 문서](https://www.postgresql.org/docs/current/pgstatstatements.html)
- 출처: Claude Desktop 대화 (2026-04-23)
