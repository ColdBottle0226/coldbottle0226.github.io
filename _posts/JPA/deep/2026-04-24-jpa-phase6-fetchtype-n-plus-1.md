---
title: "FetchType과 N+1 문제"
date: 2026-04-24 11:00:00 +0900
categories: [JPA, 심화 개념]
order: 0
tags: [JPA, FetchType, EAGER, LAZY, N+1, 프록시, fetchJoin, EntityGraph, BatchSize, LazyInitializationException, default_batch_fetch_size]
---

##  1. 즉시 로딩(EAGER)과 지연 로딩(LAZY)

---

### 📌 FetchType 기본값 정리

JPA 연관관계 어노테이션의 기본 FetchType은 다음과 같다.

| 어노테이션 | 기본 FetchType |
|---|---|
| `@ManyToOne` | **EAGER** |
| `@OneToOne` | **EAGER** |
| `@OneToMany` | **LAZY** |
| `@ManyToMany` | **LAZY** |

`@ManyToOne`과 `@OneToOne`의 기본값이 `EAGER`라는 점이 중요하다. 아무것도 설정하지 않으면 즉시 로딩이 동작해서 N+1 문제를 유발한다. **실무에서는 모든 연관관계에 반드시 `FetchType.LAZY`를 명시해야 한다.**

```java
// 잘못된 예 — 기본값 EAGER 그대로 사용
@ManyToOne
@JoinColumn(name = "member_id")
private Member member; // EAGER — 조회 시마다 member SELECT 발생

// 올바른 예 — 항상 LAZY 명시
@ManyToOne(fetch = FetchType.LAZY)
@JoinColumn(name = "member_id")
private Member member;
```

---

### 📌 EAGER 동작 원리와 N+1 유발 메커니즘

EAGER로 설정하면 엔티티를 조회할 때 연관된 엔티티도 **즉시 함께 로딩**된다.

단건 조회(`em.find()`)에서는 Hibernate가 자동으로 JOIN을 사용한다.

```sql
-- LoanRecord 단건 조회 시 EAGER면 JOIN 자동 생성
SELECT lr.*, m.*, b.*
FROM loan_record lr
JOIN member m ON lr.member_id = m.member_id
JOIN book b ON lr.book_id = b.book_id
WHERE lr.loan_id = 1;
```

그런데 **JPQL이나 Spring Data JPA의 메서드 이름 쿼리**를 사용하면 문제가 달라진다. JPQL은 SQL을 직접 제어하지 않고 엔티티 중심으로 작성된다. Hibernate가 JPQL을 실행한 뒤 EAGER 연관관계를 추가 조회한다.

```java
// JPQL로 LoanRecord 목록 조회
List<LoanRecord> records = em.createQuery(
    "SELECT lr FROM LoanRecord lr", LoanRecord.class
).getResultList();
```

실제 실행되는 SQL:
```sql
-- 1번: JPQL → LoanRecord 전체 조회
SELECT lr.* FROM loan_record lr;

-- LoanRecord가 10건이면, member EAGER로 인해 10번 추가 실행
SELECT * FROM member WHERE member_id = 1;
SELECT * FROM member WHERE member_id = 2;
SELECT * FROM member WHERE member_id = 3;
-- ... (N개)
```

이것이 N+1 문제다. 1번의 쿼리 결과로 N건이 나왔을 때, 각 건에 대해 추가 쿼리가 N번 더 실행되는 현상이다.

---

### 📌 LAZY 프록시 객체 생성 원리

LAZY로 설정하면 연관 엔티티 자리에 즉시 SQL을 실행하지 않고 **프록시(Proxy) 객체**를 끼워 넣는다.

```java
LoanRecord record = em.find(LoanRecord.class, 1L);
// 실행 SQL: SELECT * FROM loan_record WHERE loan_id = 1;
// record.member 자리에는 프록시 객체가 들어있음

Member member = record.getMember();
// 아직 SQL 실행 안 됨. member는 프록시 객체

String name = member.getName(); // 실제 필드 접근 시점에 SQL 실행
// 실행 SQL: SELECT * FROM member WHERE member_id = ?;
```

프록시 객체는 실제 `Member` 클래스를 상속한 Hibernate가 런타임에 동적으로 생성한 가짜 객체다. 내부에 실제 데이터 없이 id 값만 가지고 있다가, 실제 필드(name, age 등)에 접근하는 순간 SQL을 실행해서 데이터를 채운다.

```
record.getMember()        → 프록시 객체 반환 (SQL 없음)
                             Member$HibernateProxyXXX {id: 1, name: null, ...}
                                          ↓
record.getMember().getName() → 프록시 초기화 (SQL 실행)
                             SELECT * FROM member WHERE member_id = 1;
                             Member {id: 1, name: "홍길동", age: 30, ...}
```

### 📌 LazyInitializationException — LAZY의 핵심 주의사항

영속성 컨텍스트(Session)가 닫힌 후 프록시를 초기화하려 하면 `LazyInitializationException`이 발생한다.

```java
// OSIV OFF 환경 시나리오
@Transactional(readOnly = true)
public LoanRecord findRecord(Long id) {
    return loanRecordRepository.findById(id).orElseThrow();
    // 반환 시 트랜잭션 종료 → 영속성 컨텍스트 닫힘
}

// Controller (트랜잭션 없음)
LoanRecord record = service.findRecord(1L); // 준영속 상태
String name = record.getMember().getName(); // → LazyInitializationException!
```

해결 방법은 다음 섹션에서 다루는 fetch join, @EntityGraph, @BatchSize다.

---

##  2. N+1 문제 완전 정복

---

### 📌 N+1 발생 시나리오

**시나리오 1 — JPQL에서 EAGER 연관관계**

위에서 설명한 케이스. JPQL은 SQL에 JOIN을 자동 추가하지 않고, 이후 EAGER 설정에 따라 추가 쿼리를 실행한다.

**시나리오 2 — Spring Data JPA 메서드 이름 쿼리 + LAZY**

```java
List<LoanRecord> records = loanRecordRepository.findAll();
// SELECT * FROM loan_record; (1번)

for (LoanRecord record : records) {
    System.out.println(record.getMember().getName());
    // 각 record마다 SELECT * FROM member WHERE member_id = ?; (N번)
}
```

LAZY 설정도 N+1에서 자유롭지 않다. 루프 안에서 연관 엔티티에 접근하면 건당 추가 쿼리가 발생한다.

### 📌 Hibernate 쿼리 로그로 문제 확인

```yaml
spring:
  jpa:
    show-sql: true
    properties:
      hibernate:
        format_sql: true
logging:
  level:
    org.hibernate.SQL: DEBUG
    org.hibernate.orm.jdbc.bind: TRACE   # 파라미터 바인딩 로그 (Hibernate 6.x)
```

쿼리 로그를 확인했을 때 같은 테이블에 대한 SELECT가 반복적으로 나타나면 N+1을 의심해야 한다.

---

### 📌 해결 전략 1 — JPQL Fetch Join

Fetch Join은 JPQL에서 연관 엔티티를 한 번의 JOIN으로 함께 조회하는 방법이다. 가장 직접적이고 확실한 해결 방법이다.

```java
// N+1 발생 쿼리
@Query("SELECT lr FROM LoanRecord lr")
List<LoanRecord> findAll();

// Fetch Join으로 해결
@Query("SELECT lr FROM LoanRecord lr JOIN FETCH lr.member JOIN FETCH lr.book")
List<LoanRecord> findAllWithMemberAndBook();
```

실행 SQL:
```sql
SELECT lr.*, m.*, b.*
FROM loan_record lr
INNER JOIN member m ON lr.member_id = m.member_id
INNER JOIN book b ON lr.book_id = b.book_id;
```

한 번의 쿼리로 모든 데이터를 가져온다.

**컬렉션 Fetch Join 주의점**

```java
// 컬렉션(OneToMany) fetch join — 데이터 중복 발생
@Query("SELECT m FROM Member m JOIN FETCH m.loanRecords")
List<Member> findAllWithLoanRecords();
```

OneToMany 관계에서 fetch join을 사용하면 member가 대출 기록 수만큼 중복되어 반환된다. `DISTINCT`로 중복을 제거해야 한다.

```java
@Query("SELECT DISTINCT m FROM Member m JOIN FETCH m.loanRecords")
List<Member> findAllWithLoanRecords();
```

**컬렉션 Fetch Join + 페이징 불가 문제**

컬렉션에 fetch join을 사용하면 페이징을 적용할 수 없다. Hibernate는 경고를 출력하고 전체 데이터를 메모리로 가져온 뒤 메모리에서 페이징(HHH90003004)한다. 이는 매우 위험한 동작이다.

```java
// 위험한 패턴 — In Memory 페이징 발생
@Query("SELECT m FROM Member m JOIN FETCH m.loanRecords")
Page<Member> findAllWithLoanRecords(Pageable pageable); // ← 절대 안 됨
```

컬렉션 + 페이징이 동시에 필요하면 `@BatchSize` 또는 `default_batch_fetch_size` 설정을 사용한다.

---

### 📌 해결 전략 2 — @EntityGraph

`@EntityGraph`는 JPQL을 직접 작성하지 않고 어노테이션으로 fetch join을 지정하는 방법이다.

```java
// 방법 1 — @EntityGraph 어노테이션
@EntityGraph(attributePaths = {"member", "book"})
@Query("SELECT lr FROM LoanRecord lr")
List<LoanRecord> findAllWithMemberAndBook();

// 방법 2 — 메서드 이름 쿼리에 적용
@EntityGraph(attributePaths = {"member"})
List<LoanRecord> findByStatus(LoanStatus status);

// 방법 3 — findAll에 적용
@EntityGraph(attributePaths = {"member", "book"})
@Override
List<LoanRecord> findAll();
```

생성되는 SQL은 fetch join과 동일하게 LEFT OUTER JOIN을 사용한다.

```sql
SELECT lr.*, m.*, b.*
FROM loan_record lr
LEFT OUTER JOIN member m ON lr.member_id = m.member_id
LEFT OUTER JOIN book b ON lr.book_id = b.book_id;
```

**fetch join vs @EntityGraph 차이**

| 항목 | JPQL fetch join | @EntityGraph |
|---|---|---|
| JOIN 방식 | INNER JOIN (기본) | LEFT OUTER JOIN |
| 선언 위치 | @Query 안 JPQL | 어노테이션 |
| 복잡한 조건 | 가능 | 제한적 |
| 가독성 | JPQL 직접 작성 | 어노테이션으로 간결 |

---

### 📌 해결 전략 3 — @BatchSize / default_batch_fetch_size

`@BatchSize`는 N+1을 "1+1"이 아닌 "1+소수의 쿼리"로 완화하는 방법이다. N번의 개별 쿼리 대신 IN 절로 묶어서 조회한다.

```java
// 엔티티 클래스에 적용
@Entity
@BatchSize(size = 100)
public class Member { ... }

// 컬렉션 필드에 적용
@OneToMany(mappedBy = "member")
@BatchSize(size = 100)
private List<LoanRecord> loanRecords = new ArrayList<>();
```

**애플리케이션 전역 설정 (권장)**

```yaml
spring:
  jpa:
    properties:
      hibernate:
        default_batch_fetch_size: 100
```

이 설정 하나로 모든 지연 로딩 컬렉션과 단일 연관관계에 IN 절 배치 조회가 적용된다.

동작 원리:

```sql
-- N+1 (원래 방식)
SELECT * FROM member WHERE member_id = 1;
SELECT * FROM member WHERE member_id = 2;
SELECT * FROM member WHERE member_id = 3;
-- ... 100번

-- @BatchSize(size=100) 적용 후
SELECT * FROM member WHERE member_id IN (1, 2, 3, ..., 100);
-- 1번으로 줄어듦 (100건 기준)
```

**컬렉션 fetch join + 페이징 시 필수 대안**

```java
// fetch join 대신 batch size로 해결
@Query("SELECT m FROM Member m") // fetch join 없음
Page<Member> findAll(Pageable pageable); // 페이징 정상 동작

// application.yml에 default_batch_fetch_size 설정
// → 루프에서 loanRecords 접근 시 IN 절로 일괄 조회
```

---

### 📌 해결 전략 선택 기준

| 상황 | 권장 해결책 |
|---|---|
| 단건 또는 소량 조회, 단순 연관관계 | JPQL Fetch Join |
| 메서드 이름 쿼리에 fetch join 추가 | @EntityGraph |
| 컬렉션 + 페이징 동시 필요 | default_batch_fetch_size |
| 전체 애플리케이션 기본 최적화 | default_batch_fetch_size 전역 설정 |
| 복잡한 동적 쿼리 | QueryDSL fetchJoin() (Phase 9) |

> 💡 실무에서는 `default_batch_fetch_size: 100`을 기본으로 설정하고, 성능이 중요한 조회에는 Fetch Join을 추가로 적용하는 방식이 가장 일반적이다.

---

##  3. 정리

---

| 개념 | 핵심 요약 |
|---|---|
| EAGER | 연관 엔티티를 즉시 함께 로딩. `@ManyToOne`, `@OneToOne`의 기본값. JPQL에서 N+1 유발 |
| LAZY | 프록시를 끼워두고 실제 접근 시점에 SQL 실행. 실무에서 모든 연관관계에 명시 권장 |
| 프록시 | Hibernate가 동적 생성한 가짜 객체. 필드 접근 시 초기화(SQL 실행) |
| LazyInitializationException | 영속성 컨텍스트 닫힌 후 프록시 초기화 시도 시 발생 |
| N+1 문제 | 1번 쿼리 결과로 N건이 나왔을 때 추가 쿼리가 N번 발생하는 현상 |
| Fetch Join | JPQL에서 JOIN FETCH로 한 번에 로딩. 가장 명시적인 해결 방법 |
| @EntityGraph | 어노테이션으로 fetch join 지정. LEFT OUTER JOIN 사용 |
| @BatchSize | IN 절로 묶어서 배치 조회. 컬렉션 + 페이징 조합에 필수 |
| default_batch_fetch_size | 전역 배치 크기 설정. 실무에서 기본으로 적용 권장 |

---

## 참고 자료

- 공식문서 - Hibernate 6 — Fetching: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#fetching>
- 공식문서 - Hibernate 6 — Batch Fetching: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#fetching-batch>
- 공식문서 - Spring Data JPA — @EntityGraph: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#jpa.entity-graph>
