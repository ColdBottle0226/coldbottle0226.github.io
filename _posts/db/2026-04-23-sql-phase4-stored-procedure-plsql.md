---
title: 저장 프로시저 & PL/SQL
date: 2026-04-23 03:00:00 +0900
categories: [DB, 이론]
tags: [SQL, Oracle, MySQL, PostgreSQL, 저장프로시저, PL/SQL, 함수, 트리거, 커서]
---

## 1. 개요

저장 프로시저와 PL/SQL 함수는 SQL 문과 제어 로직을 DB 서버에 저장해두고 이름으로 호출하는 프로그램 단위다. 비슷해 보이지만 반환값 유무, 호출 위치, 트랜잭션 처리 방식에서 차이가 있다. DBMS마다 선언 방식, 변수 대입 문법, 예외 처리 구조가 크게 달라 혼란이 생기기 쉬운 영역이다.

| 섹션 | 내용 |
|------|------|
| 2. 저장 프로시저 | 기본 구조, 조건문, 반복문, 커서, 예외 처리 |
| 3. PL/SQL 함수 | 함수 생성 및 호출, 트리거 |
| 4. 선택 기준 | 프로시저 vs 함수 vs 트리거 |

---

## 2. 저장 프로시저 (Stored Procedure)

저장 프로시저는 SQL 문과 제어 로직(조건문, 반복문)을 묶어서 DB 서버에 저장해두고, 이름으로 호출해서 실행하는 프로그램 단위다.

저장 프로시저를 쓰는 이유는 세 가지다. 반복적인 복잡한 SQL을 매번 작성하지 않고 이름 하나로 호출할 수 있고, 애플리케이션과 DB 사이의 네트워크 왕복 횟수를 줄일 수 있으며, 비즈니스 로직을 DB 레벨에서 캡슐화해 보안을 강화할 수 있다.

### 📌 기본 구조 — DBMS별 문법 비교

```sql
/**
 * Oracle: CREATE OR REPLACE PROCEDURE + IS/AS + BEGIN/END 구조
 * 파라미터 선언은 "이름 IN/OUT 타입" 순서다.
 * 변수 선언은 IS/AS와 BEGIN 사이에 위치한다.
 * 변수 대입은 := 연산자를 사용한다.
 */

-- ✅ Oracle
CREATE OR REPLACE PROCEDURE proc_name (
    p_param1 IN  VARCHAR2,   -- IN: 입력 파라미터
    p_param2 OUT NUMBER      -- OUT: 출력 파라미터
)
IS
    v_local VARCHAR2(100);   -- 지역 변수 선언 (IS/AS ~ BEGIN 사이)
BEGIN
    SELECT username INTO v_local
    FROM users
    WHERE user_id = p_param1;

    p_param2 := LENGTH(v_local);  -- := 대입 연산자

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_param2 := -1;
    WHEN OTHERS THEN
        RAISE;
END proc_name;
/
```

```sql
/**
 * MySQL: CREATE PROCEDURE + DELIMITER 변경 필수
 * 프로시저 내부에서 ;를 쓰기 때문에 종료 구분자를 $$로 바꿔야 한다.
 * 파라미터 선언은 "IN/OUT 이름 타입" 순서로 Oracle과 반대다.
 * 변수 선언은 BEGIN 직후에 DECLARE로 선언한다.
 * 변수 대입은 SET 변수 = 값 형태를 사용한다.
 */

-- ✅ MySQL
DELIMITER $$

CREATE PROCEDURE proc_name (
    IN  p_param1 VARCHAR(100),
    OUT p_param2 INT
)
BEGIN
    DECLARE v_local VARCHAR(100);  -- 지역 변수: BEGIN 직후 선언

    SELECT username INTO v_local
    FROM users
    WHERE user_id = p_param1;

    SET p_param2 = CHAR_LENGTH(v_local);  -- SET으로 변수 대입

END$$

DELIMITER ;
```

```sql
/**
 * PostgreSQL: CREATE OR REPLACE PROCEDURE + LANGUAGE plpgsql 명시 필수
 * 함수 본문은 $$ 달러 쿼팅으로 감싼다.
 * DECLARE 블록에서 변수를 선언한다.
 * OUT 대신 INOUT을 권장한다.
 */

-- ✅ PostgreSQL
CREATE OR REPLACE PROCEDURE proc_name (
    IN    p_param1 VARCHAR,
    INOUT p_param2 INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_local VARCHAR;
BEGIN
    SELECT username INTO v_local
    FROM users
    WHERE user_id = p_param1;

    p_param2 := LENGTH(v_local);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_param2 := -1;
END;
$$;
```

| 항목 | Oracle | MySQL | PostgreSQL |
|------|--------|-------|------------|
| 생성 키워드 | `CREATE OR REPLACE PROCEDURE` | `CREATE PROCEDURE` | `CREATE OR REPLACE PROCEDURE` |
| 파라미터 순서 | `이름 IN/OUT 타입` | `IN/OUT 이름 타입` | `IN/OUT 이름 타입` |
| 변수 선언 위치 | `IS ~ BEGIN` 사이 | `BEGIN` 직후 `DECLARE` | `DECLARE` 블록 |
| 변수 대입 | `:=` | `SET 변수 = 값` | `:=` 또는 `=` |
| 언어 지정 | 불필요 | 불필요 | `LANGUAGE plpgsql` 필수 |
| 예외 처리 | `EXCEPTION` 블록 | `DECLARE ... HANDLER` | `EXCEPTION` 블록 |

---

### 📌 프로시저 호출

```sql
/**
 * Oracle: EXECUTE 또는 익명 블록(BEGIN...END)으로 호출한다.
 * MySQL:  CALL 키워드로 호출하고, OUT 파라미터는 세션 변수(@변수)로 받는다.
 * PostgreSQL: CALL 키워드로 호출한다.
 */

-- ✅ Oracle
DECLARE
    v_result NUMBER;
BEGIN
    proc_name('user_001', v_result);
    DBMS_OUTPUT.PUT_LINE('결과: ' || v_result);
END;
/

-- OUT 파라미터 없는 경우 EXECUTE 사용 가능
EXECUTE proc_name('user_001');

-- ✅ MySQL
CALL proc_name('user_001', @result);
SELECT @result;   -- OUT 파라미터는 세션 변수로 받아서 조회

-- ✅ PostgreSQL
CALL proc_name('user_001', NULL);
```

---

### 📌 조건문 (IF / CASE)

```sql
/**
 * Oracle과 PostgreSQL은 ELSIF를 사용한다.
 * MySQL은 ELSEIF (E 하나)를 사용한다. 혼동하기 쉬운 포인트다.
 */

-- ✅ Oracle / PostgreSQL
IF v_salary > 5000000 THEN
    v_grade := 'S';
ELSIF v_salary > 3000000 THEN   -- ELSIF (E 두 개)
    v_grade := 'A';
ELSE
    v_grade := 'B';
END IF;

-- CASE 문 (Oracle / PostgreSQL)
CASE v_status
    WHEN 'PAID'    THEN v_label := '결제완료';
    WHEN 'PENDING' THEN v_label := '대기중';
    ELSE                v_label := '기타';
END CASE;

-- ✅ MySQL
IF v_salary > 5000000 THEN
    SET v_grade = 'S';
ELSEIF v_salary > 3000000 THEN  -- ELSEIF (E 하나, MySQL 전용)
    SET v_grade = 'A';
ELSE
    SET v_grade = 'B';
END IF;
```

---

### 📌 반복문 (LOOP / WHILE / FOR)

```sql
/**
 * Oracle: LOOP/WHILE/FOR 세 가지 모두 지원한다. FOR LOOP는 범위를 .. 으로 지정한다.
 * MySQL:  WHILE/REPEAT/LOOP 지원. FOR LOOP는 없다. LEAVE로 루프를 탈출한다.
 * PostgreSQL: FOR LOOP와 WHILE을 지원한다. Oracle과 문법이 유사하다.
 */

-- ✅ Oracle

-- 기본 LOOP (EXIT WHEN으로 탈출)
DECLARE
    v_i NUMBER := 1;
BEGIN
    LOOP
        DBMS_OUTPUT.PUT_LINE(v_i);
        v_i := v_i + 1;
        EXIT WHEN v_i > 10;
    END LOOP;
END;
/

-- WHILE LOOP
WHILE v_i <= 10 LOOP
    v_i := v_i + 1;
END LOOP;

-- FOR LOOP (자동 증가, 별도 변수 선언 불필요)
FOR i IN 1..10 LOOP
    DBMS_OUTPUT.PUT_LINE(i);
END LOOP;

-- ✅ MySQL

-- WHILE
WHILE v_i <= 10 DO
    SET v_i = v_i + 1;
END WHILE;

-- REPEAT UNTIL (do-while 패턴 — 먼저 실행 후 조건 확인)
REPEAT
    SET v_i = v_i + 1;
UNTIL v_i > 10
END REPEAT;

-- LOOP + LEAVE (레이블 필수)
my_loop: LOOP
    SET v_i = v_i + 1;
    IF v_i > 10 THEN LEAVE my_loop; END IF;
END LOOP;

-- ✅ PostgreSQL

-- FOR LOOP (Oracle과 유사)
FOR i IN 1..10 LOOP
    RAISE NOTICE '%', i;
END LOOP;

-- WHILE
WHILE v_i <= 10 LOOP
    v_i := v_i + 1;
END LOOP;
```

---

### 📌 커서 (CURSOR) — 행 단위 처리

커서는 SELECT 결과를 한 행씩 순서대로 처리할 때 사용한다. 집합 연산으로 해결할 수 없을 때만 사용해야 하며, 가능하면 집합 기반 SQL이 성능이 훨씬 좋다.

> 💡 커서는 행 단위 반복이므로 대용량 데이터에서 성능이 매우 나쁘다. 업무 로직상 반드시 행 단위 처리가 필요한 경우에만 사용하고, 대부분의 경우 UPDATE ... JOIN 또는 MERGE 문으로 대체할 수 있다.

```sql
/**
 * Oracle: 명시적 커서(OPEN/FETCH/CLOSE)와 FOR 커서(자동 처리) 두 가지 방식이 있다.
 * FOR 커서 방식이 훨씬 간결하고 CLOSE를 자동으로 처리해주므로 권장한다.
 */

-- ✅ Oracle: 명시적 커서
DECLARE
    CURSOR emp_cursor IS
        SELECT employee_id, name, salary
        FROM employees
        WHERE department = '개발팀';

    v_emp emp_cursor%ROWTYPE;
BEGIN
    OPEN emp_cursor;
    LOOP
        FETCH emp_cursor INTO v_emp;
        EXIT WHEN emp_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(v_emp.name || ': ' || v_emp.salary);
    END LOOP;
    CLOSE emp_cursor;
END;
/

-- ✅ Oracle: FOR 커서 (권장 — OPEN/FETCH/CLOSE 자동 처리)
BEGIN
    FOR v_emp IN (
        SELECT employee_id, name, salary
        FROM employees
        WHERE department = '개발팀'
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE(v_emp.name || ': ' || v_emp.salary);
    END LOOP;
END;
/

-- ✅ MySQL: CURSOR + NOT FOUND 핸들러
DELIMITER $$
CREATE PROCEDURE cursor_example()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_name   VARCHAR(100);
    DECLARE v_salary INT;

    DECLARE emp_cursor CURSOR FOR
        SELECT name, salary FROM employees WHERE department = '개발팀';

    -- NOT FOUND 핸들러: FETCH 결과가 없으면 done = TRUE
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN emp_cursor;
    read_loop: LOOP
        FETCH emp_cursor INTO v_name, v_salary;
        IF done THEN LEAVE read_loop; END IF;
        SELECT CONCAT(v_name, ': ', v_salary);
    END LOOP;
    CLOSE emp_cursor;
END$$
DELIMITER ;

-- ✅ PostgreSQL: FOR 루프 (가장 간결)
DO $$
DECLARE
    v_emp RECORD;
BEGIN
    FOR v_emp IN
        SELECT name, salary FROM employees WHERE department = '개발팀'
    LOOP
        RAISE NOTICE '%: %', v_emp.name, v_emp.salary;
    END LOOP;
END;
$$;
```

---

### 📌 예외 처리

```sql
/**
 * Oracle / PostgreSQL: EXCEPTION 블록으로 예외를 처리한다.
 * MySQL: DECLARE ... HANDLER 방식으로 예외를 처리한다.
 * 트랜잭션과 함께 쓸 때는 예외 발생 시 반드시 ROLLBACK을 처리해야 한다.
 */

-- ✅ Oracle
BEGIN
    INSERT INTO orders (order_id, user_id, amount)
    VALUES (seq_orders.NEXTVAL, p_user_id, p_amount);
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN   -- 중복 키 예외
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20001, '중복된 주문입니다.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;                   -- 예외 재발생
END;

-- ✅ MySQL
DELIMITER $$
CREATE PROCEDURE insert_order(IN p_user_id INT, IN p_amount DECIMAL)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;   -- 예외 재발생
    END;

    START TRANSACTION;
        INSERT INTO orders (user_id, amount) VALUES (p_user_id, p_amount);
    COMMIT;
END$$
DELIMITER ;

-- ✅ PostgreSQL
CREATE OR REPLACE PROCEDURE insert_order(p_user_id INT, p_amount NUMERIC)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO orders (user_id, amount) VALUES (p_user_id, p_amount);
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION '중복된 주문입니다. (SQLSTATE: %)', SQLSTATE;
    WHEN OTHERS THEN
        RAISE;
END;
$$;
```

---

## 3. PL/SQL 함수 (Function)

함수는 프로시저와 구조가 거의 같지만 반드시 값을 반환(RETURN)한다는 점이 다르다. SELECT 절, WHERE 절 등 SQL 문 안에서 직접 호출할 수 있다.

### 📌 기본 함수 생성 및 호출

```sql
/**
 * 함수는 RETURN 타입을 선언해야 하고, 반드시 RETURN 문으로 값을 반환해야 한다.
 * SQL 문 안에서 직접 사용할 수 있다는 것이 프로시저와의 핵심 차이다.
 */

-- ✅ Oracle
CREATE OR REPLACE FUNCTION get_user_grade (
    p_user_id IN NUMBER
) RETURN VARCHAR2
IS
    v_total_amount NUMBER;
    v_grade        VARCHAR2(10);
BEGIN
    SELECT NVL(SUM(amount), 0)
    INTO v_total_amount
    FROM orders
    WHERE user_id = p_user_id;

    IF    v_total_amount >= 1000000 THEN v_grade := 'VIP';
    ELSIF v_total_amount >= 500000  THEN v_grade := 'GOLD';
    ELSE                                 v_grade := 'NORMAL';
    END IF;

    RETURN v_grade;
END;
/

-- ✅ MySQL
DELIMITER $$
CREATE FUNCTION get_user_grade (
    p_user_id INT
) RETURNS VARCHAR(10)
DETERMINISTIC       -- 같은 입력 → 같은 출력 보장 선언
READS SQL DATA      -- 함수 내에서 SELECT 사용 시 명시
BEGIN
    DECLARE v_total DECIMAL(15,2);
    DECLARE v_grade VARCHAR(10);

    SELECT IFNULL(SUM(amount), 0)
    INTO v_total
    FROM orders
    WHERE user_id = p_user_id;

    IF    v_total >= 1000000 THEN SET v_grade = 'VIP';
    ELSEIF v_total >= 500000 THEN SET v_grade = 'GOLD';
    ELSE                          SET v_grade = 'NORMAL';
    END IF;

    RETURN v_grade;
END$$
DELIMITER ;

-- ✅ PostgreSQL
CREATE OR REPLACE FUNCTION get_user_grade (
    p_user_id INT
) RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_total  NUMERIC;
    v_grade  VARCHAR;
BEGIN
    SELECT COALESCE(SUM(amount), 0)
    INTO v_total
    FROM orders
    WHERE user_id = p_user_id;

    IF    v_total >= 1000000 THEN v_grade := 'VIP';
    ELSIF v_total >= 500000  THEN v_grade := 'GOLD';
    ELSE                          v_grade := 'NORMAL';
    END IF;

    RETURN v_grade;
END;
$$;

-- ✅ 호출 (세 DBMS 모두 동일 — SQL 문 안에서 직접 사용)
SELECT user_id, username, get_user_grade(user_id) AS 등급
FROM users;
```

---

### 📌 트리거 (TRIGGER)

트리거는 테이블에 특정 이벤트(INSERT, UPDATE, DELETE)가 발생할 때 자동으로 실행되는 PL/SQL 블록이다.

> 💡 PostgreSQL은 트리거 함수를 먼저 별도로 생성한 뒤, 트리거와 연결하는 2단계 방식을 사용한다. Oracle과 MySQL은 트리거 안에 로직을 직접 작성한다.

```sql
/**
 * 트리거 예시: 주문 INSERT 시 상품 재고를 자동으로 차감한다.
 * :NEW (Oracle) / NEW (MySQL, PostgreSQL): 새로 삽입/수정된 행의 값
 * :OLD (Oracle) / OLD (MySQL, PostgreSQL): 수정/삭제 전 행의 값
 */

-- ✅ Oracle
CREATE OR REPLACE TRIGGER trg_order_stock
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    UPDATE products
    SET stock = stock - :NEW.quantity   -- :NEW로 새 행의 값 참조
    WHERE product_id = :NEW.product_id;
END;
/

-- ✅ MySQL
DELIMITER $$
CREATE TRIGGER trg_order_stock
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    UPDATE products
    SET stock = stock - NEW.quantity    -- NEW (콜론 없음)
    WHERE product_id = NEW.product_id;
END$$
DELIMITER ;

-- ✅ PostgreSQL: 트리거 함수 먼저 생성 → 트리거 연결 (2단계)
-- 1단계: 트리거 함수 생성
CREATE OR REPLACE FUNCTION fn_order_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE products
    SET stock = stock - NEW.quantity
    WHERE product_id = NEW.product_id;
    RETURN NEW;   -- AFTER 트리거는 NEW 반환, BEFORE 트리거는 수정된 NEW 반환
END;
$$;

-- 2단계: 트리거 생성 및 함수 연결
CREATE TRIGGER trg_order_stock
AFTER INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION fn_order_stock();
```

| 항목 | Oracle | MySQL | PostgreSQL |
|------|--------|-------|------------|
| 새 값 참조 | `:NEW.컬럼` | `NEW.컬럼` | `NEW.컬럼` |
| 이전 값 참조 | `:OLD.컬럼` | `OLD.컬럼` | `OLD.컬럼` |
| 함수 분리 | 불필요 | 불필요 | **함수 먼저 생성 필수** |

---

## 4. 프로시저 vs 함수 vs 트리거 선택 기준

| 상황 | 선택 |
|------|------|
| SELECT 절 안에서 직접 호출하고 싶을 때 | 함수 (FUNCTION) |
| 값을 반환하지 않거나 여러 값을 OUT으로 내보낼 때 | 프로시저 (PROCEDURE) |
| INSERT / UPDATE / DELETE + 트랜잭션 처리 중심 | 프로시저 (PROCEDURE) |
| DB 이벤트에 자동 반응해야 할 때 | 트리거 (TRIGGER) |

---

## 5. 정리

- 파라미터 선언 순서: Oracle은 `이름 IN/OUT 타입`, MySQL·PostgreSQL은 `IN/OUT 이름 타입`
- 조건문 키워드: Oracle·PostgreSQL은 `ELSIF`, MySQL은 `ELSEIF`
- 변수 대입: Oracle·PostgreSQL은 `:=`, MySQL은 `SET 변수 = 값`
- MySQL 프로시저는 DELIMITER를 변경하지 않으면 내부 `;`에서 오류가 발생한다
- 커서는 행 단위 처리이므로 대용량에서 성능이 나쁘다 — 집합 기반 SQL로 대체할 것
- NOT IN에 NULL 포함 시 결과가 0건이 될 수 있다 — 커서 탈출 조건에서도 동일하게 주의
- PostgreSQL 트리거는 함수를 먼저 만든 뒤 연결하는 2단계 방식이다
- 함수는 SQL 문 안에서 직접 호출 가능, 프로시저는 CALL / EXECUTE로만 호출 가능

---

## 6. 참고 자료

- [Oracle PL/SQL 공식 문서](https://docs.oracle.com/en/database/oracle/oracle-database/21/lnpls/)
- [Oracle 트리거 공식 문서](https://docs.oracle.com/en/database/oracle/oracle-database/21/lnpls/plsql-triggers.html)
- [MySQL 저장 프로시저 공식 문서](https://dev.mysql.com/doc/refman/8.0/en/stored-programs-defining.html)
- [MySQL 트리거 공식 문서](https://dev.mysql.com/doc/refman/8.0/en/triggers.html)
- [PostgreSQL PL/pgSQL 공식 문서](https://www.postgresql.org/docs/current/plpgsql.html)
- [PostgreSQL 트리거 공식 문서](https://www.postgresql.org/docs/current/plpgsql-trigger.html)
- 출처: Claude Desktop 대화 (2026-04-23)
