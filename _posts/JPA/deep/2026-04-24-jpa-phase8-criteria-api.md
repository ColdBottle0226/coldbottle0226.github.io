---
title: "Criteria API와 Specification 패턴"
date: 2026-04-24 12:00:00 +0900
categories: [JPA, 심화 개념]
tags: [JPA, CriteriaAPI, CriteriaBuilder, CriteriaQuery, Predicate, Specification, JpaSpecificationExecutor, 동적쿼리, QueryDSL]
---

##  1. Criteria API란

---

Criteria API는 **자바 코드로 타입 안전하게 동적 쿼리를 작성**하는 JPA 표준 API다. JPQL이 문자열 기반이라 오타나 필드명 변경 시 런타임에야 오류를 발견하는 반면, Criteria API는 컴파일 타임에 타입 오류를 잡을 수 있다.

```java
// JPQL — 문자열 기반. 오타가 있어도 컴파일 타임에 모름
"SELECT m FROM Member m WHERE m.naem = :name"  // naem 오타 → 런타임 오류

// Criteria API — 자바 코드 기반. 컴파일 타임에 오류 감지
root.get("naem")  // 또는 메타모델 사용 시 컴파일 오류
```

---

##  2. CriteriaBuilder / CriteriaQuery 구조

---

```java
// 1. EntityManager에서 CriteriaBuilder 획득
CriteriaBuilder cb = em.getCriteriaBuilder();

// 2. CriteriaQuery 생성 — 반환 타입 지정
CriteriaQuery<Member> cq = cb.createQuery(Member.class);

// 3. FROM 절 — Root 설정
Root<Member> root = cq.from(Member.class);

// 4. SELECT 절 설정
cq.select(root);

// 5. WHERE 절 설정
cq.where(cb.equal(root.get("name"), "홍길동"));

// 6. 쿼리 실행
List<Member> members = em.createQuery(cq).getResultList();
```

### 📌 주요 컴포넌트 역할

| 컴포넌트 | 역할 |
|---|---|
| `CriteriaBuilder` | 쿼리의 각 요소(조건, 연산, 정렬 등)를 만드는 팩토리 |
| `CriteriaQuery<T>` | 최종 쿼리 객체. SELECT / FROM / WHERE / ORDER BY 조합 |
| `Root<T>` | FROM 절의 엔티티. `root.get("fieldName")`으로 필드 접근 |
| `Path<T>` | 엔티티 내 필드 경로. `root.get("address").get("city")` |
| `Join<X, Y>` | JOIN 표현 |
| `Predicate` | WHERE 절의 조건 표현 |

---

##  3. Predicate 조합으로 동적 쿼리 구성

---

Criteria API의 핵심 장점은 조건을 `Predicate` 객체로 분리해서 동적으로 조합할 수 있다는 점이다.

```java
public List<Member> searchMembers(String name, Integer minAge, Integer maxAge) {
    CriteriaBuilder cb = em.getCriteriaBuilder();
    CriteriaQuery<Member> cq = cb.createQuery(Member.class);
    Root<Member> root = cq.from(Member.class);

    // Predicate 목록을 동적으로 쌓음
    List<Predicate> predicates = new ArrayList<>();

    if (name != null && !name.isBlank()) {
        predicates.add(cb.like(root.get("name"), "%" + name + "%"));
    }
    if (minAge != null) {
        predicates.add(cb.greaterThanOrEqualTo(root.get("age"), minAge));
    }
    if (maxAge != null) {
        predicates.add(cb.lessThanOrEqualTo(root.get("age"), maxAge));
    }

    // AND로 조합
    cq.where(cb.and(predicates.toArray(new Predicate[0])));
    cq.orderBy(cb.desc(root.get("createdAt")));

    return em.createQuery(cq).getResultList();
}
```

### 📌 주요 Predicate 생성 메서드

```java
// 동등 비교
cb.equal(root.get("name"), "홍길동")            // name = '홍길동'
cb.notEqual(root.get("status"), "BANNED")       // status != 'BANNED'

// 범위 비교
cb.greaterThan(root.get("age"), 20)             // age > 20
cb.greaterThanOrEqualTo(root.get("age"), 20)    // age >= 20
cb.lessThan(root.get("age"), 65)                // age < 65
cb.between(root.get("age"), 20, 30)             // age BETWEEN 20 AND 30

// 문자열
cb.like(root.get("name"), "홍%")                // name LIKE '홍%'
cb.like(root.get("name"), "%길%")               // name LIKE '%길%'

// NULL 체크
cb.isNull(root.get("deletedAt"))                // deleted_at IS NULL
cb.isNotNull(root.get("email"))                 // email IS NOT NULL

// 논리 연산
cb.and(p1, p2)                                  // p1 AND p2
cb.or(p1, p2)                                   // p1 OR p2
cb.not(p1)                                      // NOT p1

// IN
root.get("category").in("IT", "Science")        // category IN ('IT', 'Science')
```

### 📌 JOIN

```java
// INNER JOIN
Join<Member, LoanRecord> loanJoin = root.join("loanRecords", JoinType.INNER);
predicates.add(cb.equal(loanJoin.get("status"), "ACTIVE"));

// LEFT OUTER JOIN
Join<Member, LoanRecord> loanJoin = root.join("loanRecords", JoinType.LEFT);

// Fetch Join
root.fetch("loanRecords", JoinType.LEFT);
```

### 📌 정렬

```java
cq.orderBy(
    cb.desc(root.get("createdAt")),   // created_at DESC
    cb.asc(root.get("name"))          // name ASC
);
```

---

##  4. Root, Join, Path 사용법 상세

---

```java
// 단일 필드 접근
Path<String> namePath = root.get("name");
Path<Integer> agePath = root.get("age");

// 연관 엔티티 필드 접근 (JOIN 없이)
// 묵시적 JOIN이 발생 — 명시적 JOIN을 권장
Path<String> bookTitle = root.get("loanRecords").get("book").get("title");

// 명시적 JOIN으로 접근 (권장)
Join<Member, LoanRecord> loanJoin = root.join("loanRecords");
Join<LoanRecord, Book> bookJoin = loanJoin.join("book");
Path<String> bookTitle = bookJoin.get("title");

// 임베디드 타입 접근
Path<String> city = root.get("homeAddress").get("city");
```

---

##  5. Specification 패턴

---

Spring Data JPA의 `JpaSpecificationExecutor`는 Criteria API를 더 편리하게 사용할 수 있도록 `Specification` 인터페이스를 제공한다.

### 📌 JpaSpecificationExecutor 활용

```java
// Repository에 JpaSpecificationExecutor 추가
public interface MemberRepository
        extends JpaRepository<Member, Long>,
                JpaSpecificationExecutor<Member> {
}
```

`JpaSpecificationExecutor`가 제공하는 메서드:

```java
Optional<T> findOne(Specification<T> spec);
List<T> findAll(Specification<T> spec);
Page<T> findAll(Specification<T> spec, Pageable pageable);
List<T> findAll(Specification<T> spec, Sort sort);
long count(Specification<T> spec);
```

### 📌 Specification 구현

```java
// Specification 구현체
public class MemberSpec {

    // 이름으로 검색
    public static Specification<Member> nameLike(String name) {
        return (root, query, cb) -> {
            if (name == null || name.isBlank()) return null;
            return cb.like(root.get("name"), "%" + name + "%");
        };
    }

    // 나이 범위 검색
    public static Specification<Member> ageBetween(Integer min, Integer max) {
        return (root, query, cb) -> {
            if (min == null && max == null) return null;
            if (min == null) return cb.lessThanOrEqualTo(root.get("age"), max);
            if (max == null) return cb.greaterThanOrEqualTo(root.get("age"), min);
            return cb.between(root.get("age"), min, max);
        };
    }

    // 활성 회원 (삭제되지 않은)
    public static Specification<Member> isActive() {
        return (root, query, cb) -> cb.isNull(root.get("deletedAt"));
    }
}
```

### 📌 Specification 조합 (and, or, not)

```java
// 서비스에서 조합하여 사용
public List<Member> search(String name, Integer minAge, Integer maxAge) {
    Specification<Member> spec = Specification
        .where(MemberSpec.isActive())        // deletedAt IS NULL
        .and(MemberSpec.nameLike(name))      // name LIKE '%홍%'
        .and(MemberSpec.ageBetween(minAge, maxAge));  // age BETWEEN 20 AND 30

    return memberRepository.findAll(spec);
}

// 페이징과 함께 사용
public Page<Member> searchPaged(String name, Integer minAge, Pageable pageable) {
    Specification<Member> spec = Specification
        .where(MemberSpec.isActive())
        .and(MemberSpec.nameLike(name))
        .and(MemberSpec.ageBetween(minAge, null));

    return memberRepository.findAll(spec, pageable);
}
```

---

##  6. Criteria API의 가독성 문제와 QueryDSL 전환 이유

---

Criteria API는 타입 안전성을 제공하지만 코드가 매우 장황하다.

```java
// Criteria API — 단순한 조건임에도 코드가 복잡함
CriteriaBuilder cb = em.getCriteriaBuilder();
CriteriaQuery<Book> cq = cb.createQuery(Book.class);
Root<Book> root = cq.from(Book.class);
Join<Book, Author> authorJoin = root.join("author", JoinType.LEFT);
List<Predicate> predicates = new ArrayList<>();
if (keyword != null) predicates.add(cb.like(root.get("title"), "%" + keyword + "%"));
if (category != null) predicates.add(cb.equal(root.get("category"), category));
if (authorName != null) predicates.add(cb.equal(authorJoin.get("name"), authorName));
cq.where(cb.and(predicates.toArray(new Predicate[0])));
cq.orderBy(cb.desc(root.get("publishedDate")));
List<Book> result = em.createQuery(cq).setMaxResults(10).getResultList();
```

```java
// QueryDSL — 같은 쿼리를 훨씬 간결하게 표현
List<Book> result = queryFactory
    .selectFrom(book)
    .leftJoin(book.author, author)
    .where(
        keywordContains(keyword),
        categoryEq(category),
        authorNameEq(authorName)
    )
    .orderBy(book.publishedDate.desc())
    .limit(10)
    .fetch();
```

QueryDSL이 Criteria API 대비 나은 점:

| 항목 | Criteria API | QueryDSL |
|---|---|---|
| 가독성 | 낮음 (장황한 코드) | 높음 (SQL과 유사한 DSL) |
| 타입 안전성 | 있음 (메타모델 필요) | 있음 (Q클래스 자동 생성) |
| 동적 쿼리 | 가능 (Predicate 조합) | 가능 (BooleanExpression null 처리) |
| 학습 곡선 | 높음 | 중간 |
| 외부 의존성 | 없음 (JPA 표준) | 있음 (QueryDSL 라이브러리) |

**Criteria API를 배우는 이유**는 QueryDSL이 내부적으로 Criteria API를 기반으로 동작하기 때문이다. Criteria API를 이해하면 QueryDSL의 동작 원리를 더 깊이 이해할 수 있다. 또한 외부 의존성 없이 JPA 표준만으로 타입 안전한 동적 쿼리가 필요한 경우에 사용한다.

---

##  7. 정리

---

| 개념 | 핵심 요약 |
|---|---|
| Criteria API | 자바 코드 기반 타입 안전 쿼리. 컴파일 타임 오류 감지 |
| CriteriaBuilder | 조건, 연산, 정렬 등 쿼리 요소 생성 팩토리 |
| Predicate | WHERE 조건 표현. `and()`, `or()`, `not()`으로 조합 |
| Root / Join / Path | FROM 절, JOIN 절, 필드 경로 표현 |
| Specification | Spring Data JPA의 Criteria 래퍼. `and()`, `or()` 조합 |
| JpaSpecificationExecutor | Specification 기반 조회 메서드 제공 |
| QueryDSL 전환 이유 | Criteria API보다 훨씬 간결하고 가독성이 좋음 |

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1 Criteria API: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Spring Data JPA Specifications: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#specifications>
- 공식문서 - Hibernate 6 Criteria: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#criteria>
