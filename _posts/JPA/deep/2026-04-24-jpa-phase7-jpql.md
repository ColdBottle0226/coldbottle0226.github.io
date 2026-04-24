---
title: "JPQL 개념 및 활용"
date: 2026-04-24 11:30:00 +0900
categories: [JPA, 심화 개념]
tags: [JPA, JPQL, TypedQuery, Query, NamedQuery, fetchJoin, 서브쿼리, 집합함수, CASE WHEN, COALESCE, 파라미터바인딩]
---

##  1. JPQL 기초

---

### 📌 SQL vs JPQL

JPQL(Jakarta Persistence Query Language)은 **테이블과 컬럼이 아닌 엔티티와 필드를 기준으로 작성하는 객체 지향 쿼리 언어**다.

```sql
-- SQL — 테이블명, 컬럼명 기준
SELECT m.member_id, m.member_name, m.age
FROM member m
WHERE m.member_name = '홍길동'
```

```java
// JPQL — 엔티티명, 필드명 기준
SELECT m FROM Member m WHERE m.name = '홍길동'
```

핵심 차이점:

| 항목 | SQL | JPQL |
|---|---|---|
| 조회 기준 | 테이블 / 컬럼 | 엔티티 / 필드 |
| 결과 타입 | Row (데이터 집합) | 엔티티 또는 값 |
| DB 종속성 | 있음 | 없음 (Dialect가 변환) |
| 별칭(alias) | 선택 | 필수 (`FROM Member m` — m 필수) |

### 📌 TypedQuery vs Query

```java
// TypedQuery — 반환 타입이 명확한 경우 (권장)
TypedQuery<Member> query = em.createQuery(
    "SELECT m FROM Member m WHERE m.name = :name", Member.class
);
query.setParameter("name", "홍길동");
List<Member> members = query.getResultList();

// Query — 반환 타입이 불명확한 경우 (스칼라 혼합 등)
Query query = em.createQuery(
    "SELECT m.name, m.age FROM Member m"
);
List<Object[]> results = query.getResultList();
for (Object[] row : results) {
    String name = (String) row[0];
    int age = (int) row[1];
}
```

가능하면 `TypedQuery`를 사용한다. 컴파일 타임에 타입 오류를 잡을 수 있고 캐스팅이 불필요하다.

### 📌 파라미터 바인딩

```java
// 이름 기반 바인딩 — :param (권장)
TypedQuery<Member> query = em.createQuery(
    "SELECT m FROM Member m WHERE m.name = :name AND m.age > :age",
    Member.class
);
query.setParameter("name", "홍길동");
query.setParameter("age", 20);

// 위치 기반 바인딩 — ?1, ?2 (비권장)
TypedQuery<Member> query = em.createQuery(
    "SELECT m FROM Member m WHERE m.name = ?1 AND m.age > ?2",
    Member.class
);
query.setParameter(1, "홍길동");
query.setParameter(2, 20);
```

이름 기반 바인딩이 위치 기반보다 가독성이 좋고, 파라미터 순서 변경 시 버그가 없다.

### 📌 결과 조회 메서드

```java
// getResultList() — 결과가 없으면 빈 리스트 반환 (null 아님)
List<Member> members = query.getResultList();

// getSingleResult() — 정확히 1건이어야 함
// 0건이면 NoResultException, 2건 이상이면 NonUniqueResultException
Member member = query.getSingleResult();

// 실무에서는 Optional로 감싸서 사용
Optional<Member> member = query.getResultStream().findFirst();
```

### 📌 @NamedQuery

컴파일 타임에 쿼리 문법을 검증할 수 있는 정적 쿼리 선언 방식이다. 애플리케이션 로딩 시점에 JPQL을 파싱·검증한다.

```java
@Entity
@NamedQuery(
    name = "Member.findByName",
    query = "SELECT m FROM Member m WHERE m.name = :name"
)
public class Member { ... }

// 사용
TypedQuery<Member> query = em.createNamedQuery("Member.findByName", Member.class);
query.setParameter("name", "홍길동");
```

Spring Data JPA에서는 `@Query`가 더 편리하므로 `@NamedQuery`는 잘 사용하지 않는다.

---

##  2. 프로젝션과 조인

---

### 📌 엔티티 프로젝션

```java
// 엔티티 전체 조회 — 결과가 영속 상태로 관리됨
List<Member> members = em.createQuery(
    "SELECT m FROM Member m", Member.class
).getResultList();
```

### 📌 임베디드 타입 프로젝션

```java
// @Embeddable 타입 직접 조회
List<Address> addresses = em.createQuery(
    "SELECT m.homeAddress FROM Member m", Address.class
).getResultList();
```

임베디드 타입은 영속성 컨텍스트가 관리하지 않는 값 타입이므로, 변경해도 DB에 반영되지 않는다.

### 📌 스칼라 프로젝션

```java
// 특정 필드만 조회 — Object[] 반환
List<Object[]> results = em.createQuery(
    "SELECT m.name, m.age FROM Member m"
).getResultList();

// new 표현으로 DTO 직접 생성
List<MemberDto> dtos = em.createQuery(
    "SELECT new com.example.dto.MemberDto(m.name, m.age) FROM Member m",
    MemberDto.class
).getResultList();
```

`new` 표현을 사용할 때는 패키지명을 포함한 전체 클래스명을 써야 한다. 생성자 파라미터 순서가 JPQL의 SELECT 순서와 일치해야 한다.

### 📌 INNER JOIN / OUTER JOIN

```java
// INNER JOIN — 연관관계 없으면 결과 제외
List<LoanRecord> records = em.createQuery(
    "SELECT lr FROM LoanRecord lr JOIN lr.member m WHERE m.name = :name",
    LoanRecord.class
).setParameter("name", "홍길동")
 .getResultList();

// LEFT OUTER JOIN — 연관관계 없어도 결과 포함
List<Member> members = em.createQuery(
    "SELECT m FROM Member m LEFT JOIN m.loanRecords lr WHERE lr IS NULL",
    Member.class
).getResultList();

// ON 절 추가 — JOIN 조건 명시 (JPA 2.1+)
List<Member> members = em.createQuery(
    "SELECT m FROM Member m LEFT JOIN m.loanRecords lr ON lr.status = 'ACTIVE'",
    Member.class
).getResultList();
```

### 📌 Fetch Join

Fetch Join은 JPQL의 성능 최적화 기능이다. 연관된 엔티티나 컬렉션을 SQL 한 번에 함께 조회한다.

```java
// 일반 JOIN — member만 조회, loanRecords는 지연 로딩
"SELECT m FROM Member m JOIN m.loanRecords lr"

// FETCH JOIN — member와 loanRecords를 한 번에 조회
"SELECT m FROM Member m JOIN FETCH m.loanRecords lr"
```

Fetch join은 별칭(alias)을 사용할 수 없다. fetch join 대상에 WHERE 조건을 거는 것은 의도치 않은 데이터 누락을 일으킬 수 있어 피해야 한다.

```java
// 잘못된 예 — fetch join 대상에 WHERE 조건
"SELECT m FROM Member m JOIN FETCH m.loanRecords lr WHERE lr.status = 'ACTIVE'"
// 활성 대출만 가져와서 전체 대출 수를 카운트하면 잘못된 결과가 나올 수 있음

// 올바른 예 — 조건은 일반 JOIN에, 로딩은 fetch join에
"SELECT m FROM Member m JOIN FETCH m.loanRecords WHERE m.id = :id"
```

### 📌 세타 조인 (Theta Join)

연관관계가 없는 두 엔티티를 WHERE 절의 조건으로 조인한다.

```java
// 회원 이름과 책 제목이 같은 경우 (억지 예시이지만 세타 조인 개념 설명용)
List<Object[]> results = em.createQuery(
    "SELECT m, b FROM Member m, Book b WHERE m.name = b.title"
).getResultList();
```

---

##  3. 서브쿼리와 집합 함수

---

### 📌 WHERE 절 서브쿼리

```java
// 나이가 평균보다 많은 회원 조회
List<Member> members = em.createQuery(
    "SELECT m FROM Member m WHERE m.age > (SELECT AVG(m2.age) FROM Member m2)",
    Member.class
).getResultList();

// 대출 기록이 있는 회원 조회 — EXISTS
List<Member> members = em.createQuery(
    "SELECT m FROM Member m WHERE EXISTS " +
    "(SELECT lr FROM LoanRecord lr WHERE lr.member = m)",
    Member.class
).getResultList();

// 특정 상태의 대출이 모두 있는 경우 — ALL
List<Member> members = em.createQuery(
    "SELECT m FROM Member m WHERE m.age > ALL " +
    "(SELECT lr.book.price FROM LoanRecord lr WHERE lr.status = 'ACTIVE')",
    Member.class
).getResultList();

// IN 서브쿼리
List<Member> members = em.createQuery(
    "SELECT m FROM Member m WHERE m.id IN " +
    "(SELECT lr.member.id FROM LoanRecord lr WHERE lr.book.id = :bookId)",
    Member.class
).setParameter("bookId", 1L)
 .getResultList();
```

### 📌 HAVING 서브쿼리

```java
// 대출 기록이 3건 이상인 회원 조회
List<Object[]> results = em.createQuery(
    "SELECT m.name, COUNT(lr) FROM Member m JOIN m.loanRecords lr " +
    "GROUP BY m.name HAVING COUNT(lr) >= 3"
).getResultList();
```

### 📌 집합 함수 — GROUP BY / HAVING

```java
// 카테고리별 도서 평균 가격
List<Object[]> results = em.createQuery(
    "SELECT b.category, COUNT(b), AVG(b.price), MIN(b.price), MAX(b.price) " +
    "FROM Book b GROUP BY b.category"
).getResultList();

// 평균 가격이 20000원 이상인 카테고리만
List<Object[]> results = em.createQuery(
    "SELECT b.category, AVG(b.price) " +
    "FROM Book b GROUP BY b.category HAVING AVG(b.price) >= 20000"
).getResultList();
```

| 집합 함수 | 설명 |
|---|---|
| `COUNT(m)` | 건수 반환. NULL 제외 |
| `SUM(m.price)` | 합계. NULL은 무시 |
| `AVG(m.age)` | 평균. NULL은 무시. Double 반환 |
| `MAX(m.age)` | 최댓값 |
| `MIN(m.age)` | 최솟값 |

---

##  4. 조건식과 함수

---

### 📌 CASE WHEN

```java
// 기본 CASE
List<String> results = em.createQuery(
    "SELECT CASE m.age " +
    "  WHEN 10 THEN '10대' " +
    "  WHEN 20 THEN '20대' " +
    "  ELSE '기타' END " +
    "FROM Member m"
).getResultList();

// 조건 CASE (검색 CASE)
List<String> results = em.createQuery(
    "SELECT CASE " +
    "  WHEN m.age < 20 THEN '미성년자' " +
    "  WHEN m.age < 65 THEN '성인' " +
    "  ELSE '시니어' END " +
    "FROM Member m"
).getResultList();
```

### 📌 COALESCE / NULLIF

```java
// COALESCE — 첫 번째 non-null 값 반환
List<String> results = em.createQuery(
    "SELECT COALESCE(m.email, '이메일 없음') FROM Member m"
).getResultList();

// NULLIF — 두 값이 같으면 null, 다르면 첫 번째 값 반환
List<String> results = em.createQuery(
    "SELECT NULLIF(m.name, '관리자') FROM Member m"
).getResultList();
// m.name이 '관리자'이면 null, 아니면 m.name 반환
```

### 📌 문자열 함수

```java
// CONCAT — 문자열 연결
"SELECT CONCAT(m.name, ' (', m.email, ')') FROM Member m"

// SUBSTRING — 부분 문자열
"SELECT SUBSTRING(m.name, 1, 3) FROM Member m"

// TRIM — 공백 제거
"SELECT TRIM(m.name) FROM Member m"

// LOWER / UPPER — 대소문자 변환
"SELECT LOWER(m.email) FROM Member m"

// LENGTH — 문자열 길이
"SELECT m.name FROM Member m WHERE LENGTH(m.name) > 3"

// LIKE 와일드카드
"SELECT m FROM Member m WHERE m.name LIKE '홍%'"        -- 홍으로 시작
"SELECT m FROM Member m WHERE m.name LIKE '%길%'"       -- 길 포함
"SELECT m FROM Member m WHERE m.email LIKE '%@gmail.com'" -- gmail 이메일
```

### 📌 숫자 함수

```java
"SELECT ABS(b.price - 10000) FROM Book b"             // 절댓값
"SELECT SQRT(b.price) FROM Book b"                    // 제곱근
"SELECT MOD(b.price, 1000) FROM Book b"               // 나머지
"SELECT SIZE(m.loanRecords) FROM Member m"            // 컬렉션 크기
"SELECT INDEX(lr) FROM Member m JOIN m.loanRecords lr" // 컬렉션 인덱스
```

### 📌 날짜 함수

```java
// 현재 날짜/시간
"SELECT CURRENT_DATE FROM Member m"
"SELECT CURRENT_TIME FROM Member m"
"SELECT CURRENT_TIMESTAMP FROM Member m"

// 실제 활용 예
"SELECT lr FROM LoanRecord lr WHERE lr.dueDate < CURRENT_DATE AND lr.status = 'ACTIVE'"
```

---

##  5. 페이징 및 기타 활용

---

### 📌 페이징

```java
List<Member> members = em.createQuery(
    "SELECT m FROM Member m ORDER BY m.age DESC",
    Member.class
)
.setFirstResult(0)   // 시작 위치 (0-based)
.setMaxResults(10)   // 조회 개수
.getResultList();
```

Hibernate가 DB 방언(Dialect)에 맞는 페이징 SQL을 자동 생성한다.

```sql
-- MySQL
SELECT m.* FROM member m ORDER BY m.age DESC LIMIT 10 OFFSET 0;

-- Oracle
SELECT * FROM (SELECT ROW_NUMBER() OVER(...) rn, m.* FROM member m) WHERE rn BETWEEN 1 AND 10;
```

### 📌 DISTINCT

```java
// 중복 제거
List<Member> members = em.createQuery(
    "SELECT DISTINCT m FROM Member m JOIN m.loanRecords lr",
    Member.class
).getResultList();
```

---

##  6. 정리

---

| 개념 | 핵심 요약 |
|---|---|
| JPQL | 엔티티/필드 기준 객체 지향 쿼리. SQL과 구조 유사하지만 대상이 다름 |
| TypedQuery | 반환 타입 명시. 컴파일 타임 타입 안전 |
| 파라미터 바인딩 | `:param` 이름 기반 권장. SQL injection 방지 |
| Fetch Join | JPQL에서 한 번에 연관 엔티티 로딩. N+1 해결의 핵심 |
| 스칼라 프로젝션 | 특정 필드만 조회. `new` 표현으로 DTO 직접 생성 가능 |
| 서브쿼리 | WHERE/HAVING 절 지원. EXISTS / ALL / ANY / IN |
| 집합 함수 | COUNT / SUM / AVG / MAX / MIN. GROUP BY / HAVING과 함께 사용 |
| CASE WHEN | 조건부 결과 분기. COALESCE / NULLIF로 NULL 처리 |

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1 JPQL: <https://jakarta.ee/specifications/persistence/3.1/jakarta-persistence-spec-3.1.html#a4665>
- 공식문서 - Hibernate 6 HQL: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#hql>
