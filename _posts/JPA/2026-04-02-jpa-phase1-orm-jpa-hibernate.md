---
title: "Phase 1 — ORM / JPA / Hibernate 이론"
date: 2026-04-02 09:00:00 +0900
categories: [JPA, ORM 이론]
tags: [JPA, ORM, Hibernate, JDBC, SpringDataJPA, Dialect, 패러다임불일치, MyBatis]
---

##  1. JDBC의 한계

---

### 📌 JDBC란

JDBC(Java Database Connectivity)는 자바 표준 API로, 자바 애플리케이션이 관계형 데이터베이스에 접근할 수 있게 해주는 인터페이스 명세다. `java.sql` 패키지 하위에 정의된 `Connection`, `PreparedStatement`, `ResultSet` 등이 모두 JDBC 스펙에 해당한다.

실제 데이터베이스 제조사(MySQL, Oracle 등)는 이 스펙을 구현한 JDBC 드라이버를 제공하고, 자바 애플리케이션은 드라이버를 통해 DB와 통신한다.

---

### 📌 반복적인 보일러플레이트 코드

JDBC로 `Member` 한 명을 저장하고 조회하는 전체 코드다.

```java
// 회원 저장
public void save(Member member) throws SQLException {
    String sql = "INSERT INTO member (name, age, email) VALUES (?, ?, ?)";

    Connection conn = null;
    PreparedStatement pstmt = null;

    try {
        conn = dataSource.getConnection();
        pstmt = conn.prepareStatement(sql);
        pstmt.setString(1, member.getName());
        pstmt.setInt(2, member.getAge());
        pstmt.setString(3, member.getEmail());
        pstmt.executeUpdate();
    } catch (SQLException e) {
        throw e;
    } finally {
        if (pstmt != null) pstmt.close();
        if (conn != null) conn.close();
    }
}

// 회원 단건 조회
public Member findById(Long id) throws SQLException {
    String sql = "SELECT member_id, name, age, email FROM member WHERE member_id = ?";

    Connection conn = null;
    PreparedStatement pstmt = null;
    ResultSet rs = null;

    try {
        conn = dataSource.getConnection();
        pstmt = conn.prepareStatement(sql);
        pstmt.setLong(1, id);
        rs = pstmt.executeQuery();

        if (rs.next()) {
            Member member = new Member();
            member.setId(rs.getLong("member_id"));
            member.setName(rs.getString("name"));
            member.setAge(rs.getInt("age"));
            member.setEmail(rs.getString("email"));
            return member;
        }
        return null;
    } catch (SQLException e) {
        throw e;
    } finally {
        if (rs != null) rs.close();
        if (pstmt != null) pstmt.close();
        if (conn != null) conn.close();
    }
}
```

저장 한 번, 조회 한 번인데 이 분량이다. 수정, 삭제, 목록 조회까지 합치면 같은 패턴이 무한 반복된다. `Member`에 필드 하나만 추가되어도 SQL 문자열과 파라미터 바인딩을 전부 수정해야 한다. 이것이 표면적으로 드러나는 문제이지만, 더 깊은 본질적인 문제가 있다.

---

### 📌 패러다임 불일치 — JDBC의 근본 문제

객체지향(OOP)과 관계형 데이터베이스(RDB)는 데이터를 표현하는 방식 자체가 다르다. 이 차이를 **패러다임 불일치(Paradigm Mismatch)** 라고 한다. JDBC는 이 불일치를 해결하지 못하고 개발자에게 그 비용을 전가한다. 4가지 불일치를 살펴본다.

**① 상속 불일치**

객체 세계에서 상속은 자연스러운 개념이다.

```java
abstract class Item {
    Long id;
    String name;
    int price;
}

class Album extends Item { String artist; }
class Movie extends Item { String director; }
```

이 구조를 DB에 저장하려면 RDB에는 상속 개념이 없기 때문에 여러 전략 중 하나를 선택해야 한다. 조인 테이블 전략으로 보면 이렇다.

```sql
-- Album 저장 시 두 테이블에 각각 INSERT 필요
INSERT INTO item (item_id, name, price, dtype) VALUES (?, ?, ?, 'A');
INSERT INTO album (item_id, artist) VALUES (?, ?);

-- Album 조회 시 JOIN 필요
SELECT i.*, a.artist
FROM item i
JOIN album a ON i.item_id = a.item_id
WHERE i.item_id = ?
```

저장 한 번에 SQL 2개, 조회 시 JOIN. 이걸 개발자가 전부 직접 작성해야 한다. `Movie`, `Book` 타입이 추가될수록 이 비용은 선형으로 늘어난다.

**② 연관관계 불일치**

객체는 참조(Reference)로 다른 객체를 가리킨다.

```java
class Order {
    Long id;
    Member member;          // 참조로 연관 표현
    List<OrderItem> orderItems;
}

order.getMember().getName();             // 자연스러운 그래프 탐색
order.getMember().getTeam().getName();
```

테이블은 외래 키(FK)로 연관을 표현한다. 핵심 문제는 **탐색 범위가 처음 실행하는 SQL에 고정된다**는 점이다.

```java
Member member = memberDAO.findById(10L);
member.getTeam().getName();   // team이 null이면 NPE
```

**③ 그래프 탐색 불일치**

처음 실행된 SQL이 어디까지 JOIN했는지에 따라 탐색 가능 범위가 결정된다. 개발자는 코드를 보는 것만으로 `member.getTeam()`이 null인지 아닌지 알 수 없다. 이는 신뢰하기 어려운 코드로 이어진다.

```java
// 이 코드가 NPE를 던질지 정상 동작할지는
// memberDAO.findById()의 SQL을 직접 봐야만 알 수 있다
String teamName = member.getTeam().getName();
```

**④ 동일성(Identity) 불일치**

```java
Member m1 = memberDAO.findById(1L);   // 새 인스턴스 생성
Member m2 = memberDAO.findById(1L);   // 또 새 인스턴스 생성

m1 == m2  // false — 같은 PK인데 다른 인스턴스
```

JDBC는 조회할 때마다 `new Member()`로 새 인스턴스를 만들기 때문에 같은 PK를 가진 두 객체라도 `==` 비교가 `false`다.

> 💡 패러다임 불일치를 해결하는 비용을 개발자가 전부 부담하는 것이 JDBC의 본질적인 한계다. ORM은 이 비용을 프레임워크가 대신 지불하도록 만든 기술이다.

| 문제 | 내용 |
|---|---|
| 보일러플레이트 | Connection, PreparedStatement, ResultSet 관리 코드 반복 |
| 상속 불일치 | DB에 상속 개념 없음 → 개발자가 SQL 분기 직접 작성 |
| 연관관계 불일치 | 객체는 참조, DB는 FK → 탐색 범위를 SQL에서 미리 결정해야 함 |
| 그래프 탐색 불일치 | 처음 실행한 SQL 이후 어디까지 탐색 가능한지 보장 불가 |
| 동일성 불일치 | 같은 PK 조회 시 매번 다른 인스턴스 생성 |

---

##  2. ORM이란

---

### 📌 정의

ORM(Object-Relational Mapping)은 **객체와 관계형 테이블 사이의 패러다임 불일치를 자동으로 해결해주는 기술**이다. 개발자는 객체 중심으로 코드를 작성하고, ORM이 SQL 생성·실행·결과 매핑을 처리한다.

```java
// JDBC 방식 — SQL과 매핑을 직접 작성
String sql = "INSERT INTO member (name, age) VALUES (?, ?)";
pstmt.setString(1, member.getName());
pstmt.setInt(2, member.getAge());
pstmt.executeUpdate();

// ORM(JPA) 방식 — 객체만 전달하면 SQL은 ORM이 자동 생성
em.persist(member);
```

---

### 📌 ORM이 패러다임 불일치를 해결하는 방식

| 불일치 문제 | ORM이 해결하는 방식 |
|---|---|
| 상속 불일치 | 상속 전략(`@Inheritance`) 선언만으로 INSERT/JOIN SQL 자동 처리 |
| 연관관계 불일치 | 참조 필드(`@ManyToOne` 등) 선언으로 FK 매핑 자동화 |
| 그래프 탐색 불일치 | 지연 로딩(Lazy Loading)으로 실제 접근 시점에 SQL 자동 실행 |
| 동일성 불일치 | 같은 트랜잭션 내 동일 PK 조회 시 같은 인스턴스 반환 (1차 캐시) |
| 보일러플레이트 | Connection 관리, ResultSet 매핑 등 전부 ORM 내부에서 처리 |

ORM은 연관 객체 자리에 **프록시 객체**를 끼워두고, 실제 접근이 일어날 때 SQL을 실행하는 방식으로 그래프 탐색 문제를 해결한다.

```java
Member member = em.find(Member.class, 1L);
// 이 시점에는 member만 조회. team SQL은 아직 실행되지 않음

String teamName = member.getTeam().getName();
// getTeam() 호출 시점에 SELECT * FROM team WHERE ... 자동 실행
```

---

### 📌 MyBatis vs JPA — 핵심 차이

MyBatis는 ORM이 아니라 **SQL Mapper**다. 해결하는 문제가 근본적으로 다르다.

| 구분 | MyBatis (SQL Mapper) | JPA (ORM) |
|---|---|---|
| SQL 작성 | 개발자가 직접 XML 또는 어노테이션으로 작성 | 기본 CRUD 자동 생성, 복잡한 경우 JPQL/QueryDSL |
| 패러다임 불일치 | 해결하지 않음. ResultMap으로 수동 매핑 | ORM이 자동 해결 |
| 복잡한 쿼리 | SQL 직접 작성 가능, 직관적 | JPQL, Criteria API, QueryDSL 필요 |
| 객체 그래프 | 지원 안 함 (SQL 범위에 제한) | 지연 로딩으로 자유로운 탐색 |
| 학습 난이도 | 낮음 — SQL을 알면 바로 사용 가능 | 높음 — 영속성 컨텍스트, FetchType 등 이해 필요 |
| 적합한 상황 | 복잡한 통계 쿼리, 레거시 DB, 세밀한 쿼리 제어 | 도메인 중심 비즈니스 로직, 표준 CRUD 중심 |

실무에서는 둘이 공존하는 경우도 있다. 도메인 CRUD와 비즈니스 로직은 JPA, 복잡한 통계·리포팅 쿼리는 QueryDSL(Native) 또는 MyBatis로 처리한다.

---

### 📌 ORM의 단점

ORM이 만능은 아니다. 아래 단점들을 모르고 쓰면 오히려 성능 문제를 만들어낸다.

**학습 곡선이 가파르다.** 영속성 컨텍스트, 지연 로딩, 트랜잭션 범위, N+1 문제 등을 이해하지 못하면 예상치 못한 동작이 계속 발생한다. 단순히 JPA를 "SQL 대신 쓰는 것"으로 이해하면 반드시 문제가 생긴다.

**복잡한 쿼리 표현이 어렵다.** 다중 조인, 서브쿼리가 복잡하게 엮인 통계 쿼리는 JPQL이나 QueryDSL로도 표현이 어색하거나 불가능한 경우가 있다. 이 경우 Native Query를 사용하거나 별도 처리가 필요하다.

**N+1 문제가 발생할 수 있다.** 잘못된 FetchType 설정이나 부주의한 연관관계 탐색으로 인해 1번 조회에서 N개의 추가 SQL이 발생하는 N+1 문제가 생긴다. 해결 방법은 Phase 6에서 상세히 다룬다.

**ORM을 써도 SQL을 알아야 한다.** JPA가 생성하는 SQL이 어떻게 나오는지 이해하고, 성능 문제가 생겼을 때 SQL 레벨에서 분석하고 튜닝할 수 있어야 한다.

---

##  3. JPA 명세와 구현체

---

### 📌 JPA는 명세(스펙)다

JPA(Jakarta Persistence API)는 **자바 진영의 ORM 표준 명세**다. 구현체가 아니라 인터페이스의 집합이다. `jakarta.persistence` 패키지 아래에 있는 어노테이션(`@Entity`, `@Table`, `@Id` 등)과 인터페이스(`EntityManager`, `EntityManagerFactory` 등)가 모두 JPA 명세에 해당한다.

```
JPA 명세 (인터페이스)
    jakarta.persistence.*
    → @Entity, @Id, EntityManager, EntityTransaction ...

    ↑ 구현 (implements)

구현체
    ├── Hibernate    ← 사실상 표준 (Spring Boot 기본값)
    ├── EclipseLink  ← Jakarta EE 레퍼런스 구현체
    └── DataNucleus
```

이 구조는 JDBC와 유사하다. JDBC가 `java.sql.Connection` 인터페이스를 정의하고 MySQL Driver가 구현하듯이, JPA가 `EntityManager` 인터페이스를 정의하고 Hibernate가 구현한다.

---

### 📌 javax.persistence vs jakarta.persistence

Spring Boot 버전에 따라 패키지명이 다르다. 반드시 구분해야 한다.

| Spring Boot | JPA 패키지 | Hibernate | Java EE |
|---|---|---|---|
| 2.x | `javax.persistence` | 5.x | Java EE 8 |
| 3.x | `jakarta.persistence` | 6.x | Jakarta EE 9+ |

Spring Boot 3.x에서 2.x 코드를 마이그레이션할 때 import가 `javax.persistence` → `jakarta.persistence`로 전부 바뀌어야 한다.

---

### 📌 Spring Data JPA와의 관계 — 레이어 구분

이 세 가지를 혼동하는 경우가 많다. 명확하게 레이어로 구분해야 한다.

```
애플리케이션 코드
       ↓
Spring Data JPA          ← 레포지토리 추상화 계층
  JpaRepository, @Query
       ↓ 내부적으로 사용
JPA 명세                 ← 표준 인터페이스 정의
  jakarta.persistence.*
       ↓ 구현체
Hibernate                ← 실제 SQL 생성 및 실행 담당
       ↓
JDBC
       ↓
Database
```

`JpaRepository.save(member)`를 호출하면 내부적으로 `EntityManager.persist(member)`를 호출하고, 이것이 Hibernate를 통해 `INSERT SQL`로 변환되어 실행된다.

---

### 📌 JPA 버전 히스토리

| 버전 | 주요 변경 사항 |
|---|---|
| JPA 1.0 (2006) | 기본 ORM 표준 명세 최초 제정 |
| JPA 2.0 (2009) | Criteria API 추가, 맵 컬렉션 지원 |
| JPA 2.1 (2013) | `@NamedEntityGraph`, ON 절 조인, Stored Procedure 지원 |
| JPA 2.2 (2017) | Java 8 Stream 반환, `@Repeatable` 어노테이션 지원 |
| Jakarta Persistence 3.0 (2020) | 패키지명 `javax` → `jakarta` 전환 |
| Jakarta Persistence 3.1 (2022) | UUID PK 공식 지원, 수치 함수 추가 |
| Jakarta Persistence 3.2 (2023) | Record 타입 지원, Instant/LocalDate 타입 매핑 개선 |

---

##  4. Hibernate 아키텍처

---

### 📌 Hibernate와 JPA의 관계

Hibernate는 JPA 명세를 구현한 ORM 프레임워크다. JPA가 생기기 전부터 존재했고, JPA 명세 자체가 Hibernate의 개념을 상당 부분 수용하여 만들어졌다.

| JPA 명세 (인터페이스) | Hibernate 구현체 |
|---|---|
| `EntityManagerFactory` | `SessionFactory` |
| `EntityManager` | `Session` |
| `EntityTransaction` | `Transaction` |
| `TypedQuery` | `Query` |

Spring Boot에서는 JPA 표준 인터페이스(`EntityManager`)를 사용하는 것이 권장된다. Hibernate 고유 `Session`을 직접 사용하면 구현체 종속성이 생긴다.

---

### 📌 핵심 컴포넌트 구조

```
애플리케이션 시작 시 1회 생성 (무거운 객체)
┌──────────────────────────────────┐
│       SessionFactory             │  ← EntityManagerFactory에 대응
│  - DB 연결 풀 관리                │
│  - SQL 쿼리 캐시                  │
│  - 2차 캐시 (선택)                │
│  - 메타데이터 파싱                │
└──────────────┬───────────────────┘
               │ 요청(트랜잭션)마다 생성 (가벼운 객체)
               ▼
┌──────────────────────────────────┐
│          Session                 │  ← EntityManager에 대응
│  - 영속성 컨텍스트 (1차 캐시)     │
│  - 변경 감지 (Dirty Checking)     │
│  - 쓰기 지연 SQL 저장소           │
└──────────────────────────────────┘
```

`SessionFactory`는 애플리케이션 당 하나만 생성한다. Spring Boot는 이를 자동으로 관리한다. `Session`은 하나의 요청(트랜잭션)마다 생성되고 종료되는 가벼운 객체다.

---

### 📌 Dialect (방언)

SQL 표준이 있지만 데이터베이스마다 문법이 조금씩 다르다. Hibernate는 이 차이를 Dialect로 추상화한다.

```
Hibernate → "페이지 단위로 10개 조회"
    ↓
Dialect가 DB에 맞는 문법으로 변환
    ├── MySQL8Dialect     → LIMIT 0, 10
    ├── OracleDialect     → ROWNUM <= 10
    └── SQLServerDialect  → OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY
```

| Dialect 클래스 | 대상 DB |
|---|---|
| `H2Dialect` | H2 |
| `MySQL8Dialect` | MySQL 8.x |
| `PostgreSQLDialect` | PostgreSQL |
| `Oracle12cDialect` | Oracle 12c 이상 |
| `SQLServerDialect` | MS SQL Server |

Spring Boot는 JDBC URL을 분석해서 Dialect를 자동 감지한다. 명시적으로 지정하려면 아래와 같이 설정한다.

```yaml
spring:
  jpa:
    database-platform: org.hibernate.dialect.MySQL8Dialect
```

---

### 📌 HQL vs JPQL

HQL(Hibernate Query Language)은 Hibernate 고유 쿼리 언어다. JPQL(Jakarta Persistence Query Language)은 JPA 표준 쿼리 언어로, HQL의 부분집합에 가깝다. 대부분의 쿼리 문법이 동일하며, Spring Boot 환경에서는 JPQL을 사용하는 것이 표준이다. HQL만의 고유 기능(예: `with` 절, 일부 함수)이 필요한 경우가 아니라면 JPQL로 충분하다.

---

### 📌 Hibernate 6.x의 주요 변화 (Spring Boot 3.x 기준)

Spring Boot 3.x 환경에서 레퍼런스나 구글 검색 결과를 볼 때 버전을 반드시 확인해야 한다.

**패키지명 변경**: `javax.persistence` → `jakarta.persistence`

**`fetchResults()` Deprecated**: QueryDSL과 연동 시 자주 쓰이던 `fetchResults()`가 Deprecated 됐다. 카운트 쿼리를 별도로 작성해야 한다. Phase 9 QueryDSL에서 상세히 다룬다.

**SQL 로깅 패키지 변경**: 파라미터 바인딩 로깅이 `org.hibernate.type.descriptor.sql` → `org.hibernate.orm.jdbc.bind`로 변경됐다.

**UUID PK 공식 지원**: `@GeneratedValue(strategy = GenerationType.UUID)` 사용 가능해졌다.

---

##  5. 정리

---

| 개념 | 핵심 요약 |
|---|---|
| JDBC의 한계 | 보일러플레이트 코드 + 객체-RDB 패러다임 불일치 (상속, 연관관계, 그래프탐색, 동일성) |
| ORM | 패러다임 불일치를 프레임워크가 해결. 개발자는 객체 중심으로 코딩 |
| MyBatis vs JPA | MyBatis는 SQL Mapper, JPA는 ORM. 해결하는 문제가 다름 |
| JPA | 자바 ORM 표준 명세(인터페이스). 구현체가 아님 |
| Spring Data JPA | JPA 위에 레포지토리 추상화를 얹은 계층 |
| Hibernate | JPA 명세의 사실상 표준 구현체. Spring Boot 기본값 |
| Dialect | DB별 SQL 문법 차이를 Hibernate가 추상화한 것 |
| Hibernate 6.x | Spring Boot 3.x 기준. `jakarta.persistence`, `fetchResults()` Deprecated 등 주요 변경 |

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1 Spec: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate 6 User Guide: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html>
- 공식문서 - Hibernate 6 Migration Guide: <https://docs.jboss.org/hibernate/orm/6.0/migration-guide/migration-guide.html>
- 공식문서 - Spring Data JPA: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/>
