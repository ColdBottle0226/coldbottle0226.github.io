---
title: "메서드 이름 쿼리 — 이름만으로 JPQL을 만드는 방법"
date: 2026-04-14 09:10:00 +0900
categories: []
tags: [JPA, 리포지토리, 메서드이름쿼리, DerivedQuery, SpringDataJPA, QueryMethod]
order: 2
---

## 1. 개요

---

Spring Data JPA는 메서드 이름을 파싱해서 JPQL을 자동으로 생성한다. `findByTitle`이라고 선언하면 `SELECT b FROM Book b WHERE b.title = :title` 쿼리가 만들어진다. 별도 SQL 없이 메서드 선언 하나로 쿼리가 완성되는 구조다.

이 방식을 **파생 쿼리(Derived Query)** 또는 **메서드 이름 쿼리(Query Method)**라고 한다.

| 주제 | 내용 |
|---|---|
| 동작 원리 | 메서드명 파싱 → JPQL 자동 생성 |
| 지원 키워드 | And, Or, Between, Like, In, IsNull, True/False 등 |
| 조회 수 제한 | First, Top, Distinct |
| 한계 | 조건 3개 이상, JOIN, 동적 조건 → @Query 전환 |

---

## 2. 동작 원리

---

### 📌 파싱 흐름

```
메서드명: findByTitleAndCategory

Step 1. 접두사 파싱
  find    → SELECT 쿼리
  (다른 접두사: count, exists, delete)

Step 2. By 이후 조건 파싱
  Title   → Book.title 필드
  And     → AND 조건
  Category → Book.category 필드

Step 3. JPQL 생성
  SELECT b FROM Book b
  WHERE b.title = :title
  AND b.category = :category
```

Spring Data JPA가 애플리케이션 시작 시점에 인터페이스 메서드를 전부 파싱해서 쿼리를 검증한다. 필드명이 잘못되었거나 타입이 맞지 않으면 **애플리케이션 구동 실패**로 즉시 오류를 알 수 있다.

```java
// 필드명 오류 → 구동 시 예외 발생
List<Book> findByTitlee(String title);  // Book에 titlee 필드가 없음
// No property 'titlee' found for type 'Book'
```

---

## 3. 접두사 키워드

---

### 📌 조회 — find / read / get / query / search

```java
List<Book> findByCategory(String category);     // 일반 조회
List<Book> readByCategory(String category);     // 동일 동작
List<Book> getByCategory(String category);      // 동일 동작

// Optional 반환 — 단건 조회
Optional<Book> findByIsbn(String isbn);

// 컬렉션 반환이 아닌 단건 — 결과가 2건 이상이면 예외
Book findFirstByCategory(String category);
```

### 📌 카운트 — count

```java
long countByCategory(String category);
long countByPriceGreaterThan(int price);
```

### 📌 존재 여부 — exists

```java
boolean existsByIsbn(String isbn);
boolean existsByTitleAndCategory(String title, String category);
```

### 📌 삭제 — delete / remove

```java
void deleteByIsbn(String isbn);
long deleteByCategory(String category);  // 삭제된 건수 반환

// 주의: deleteBy는 내부적으로 SELECT 후 하나씩 DELETE한다
// 대량 삭제는 @Modifying + @Query가 훨씬 효율적이다
```

---

## 4. 조건 키워드

---

### 📌 비교 조건

```java
// 동등
List<Book> findByCategory(String category);                  // category = ?
List<Book> findByCategoryNot(String category);               // category != ?

// 범위
List<Book> findByPriceBetween(int min, int max);             // price BETWEEN ? AND ?
List<Book> findByPriceLessThan(int price);                   // price < ?
List<Book> findByPriceLessThanEqual(int price);              // price <= ?
List<Book> findByPriceGreaterThan(int price);                // price > ?
List<Book> findByPriceGreaterThanEqual(int price);           // price >= ?

// null 체크
List<Book> findByDeletedAtIsNull();                          // deleted_at IS NULL
List<Book> findByDeletedAtIsNotNull();                       // deleted_at IS NOT NULL

// boolean
List<Book> findByActiveTrue();                               // active = true
List<Book> findByActiveFalse();                              // active = false
```

### 📌 문자열 조건

```java
// Like — 와일드카드를 직접 붙여야 함
List<Book> findByTitleLike(String pattern);                  // title LIKE ?
// 호출: findByTitleLike("%스프링%")

// Containing — 자동으로 양쪽 %를 붙여줌
List<Book> findByTitleContaining(String keyword);            // title LIKE %?%
// 호출: findByTitleContaining("스프링")

// StartingWith / EndingWith
List<Book> findByTitleStartingWith(String prefix);           // title LIKE ?%
List<Book> findByTitleEndingWith(String suffix);             // title LIKE %?

// IgnoreCase — 대소문자 무시
List<Book> findByTitleContainingIgnoreCase(String keyword);  // LOWER(title) LIKE %?%
```

### 📌 컬렉션 조건

```java
// In
List<Book> findByCategoryIn(List<String> categories);        // category IN (?)
List<Book> findByCategoryNotIn(List<String> categories);     // category NOT IN (?)

// 실제 사용 예
List<Book> findByCategoryIn(Arrays.asList("IT", "Science", "Math"));
```

### 📌 복합 조건

```java
// And / Or
List<Book> findByTitleAndCategory(String title, String category);
List<Book> findByTitleOrCategory(String title, String category);

// 혼합
List<Book> findByTitleContainingAndCategoryAndPriceGreaterThan(
    String keyword, String category, int minPrice
);
```

---

## 5. 정렬과 조회 수 제한

---

### 📌 정렬

```java
// 메서드명에 OrderBy 포함
List<Book> findByAuthorOrderByPublishedDateDesc(String author);
List<Book> findByCategoryOrderByPriceAscTitleDesc(String category);

// Sort 파라미터 — 동적 정렬
List<Book> findByCategory(String category, Sort sort);

// 호출
bookRepository.findByCategory("IT",
    Sort.by(Sort.Order.desc("publishedDate"), Sort.Order.asc("title"))
);
```

### 📌 조회 수 제한 — First / Top

```java
// 최신 1건
Optional<Book> findFirstByOrderByPublishedDateDesc();

// 상위 N건
List<Book> findTop3ByCategoryOrderByPriceAsc(String category);
List<Book> findFirst5ByActiveTrueOrderByCreatedAtDesc();
```

### 📌 중복 제거

```java
List<Book> findDistinctByCategory(String category);
// SELECT DISTINCT b FROM Book b WHERE b.category = :category
```

---

## 6. 파라미터 타입과 반환 타입

---

### 📌 반환 타입

```java
List<Book>                findByCategory(String category);       // 리스트 (없으면 빈 리스트)
Optional<Book>            findByIsbn(String isbn);               // Optional (단건)
Book                      findFirstByCategory(String category);  // 단건 (없으면 null)
Page<Book>                findByCategory(String category, Pageable pageable); // 페이징
Slice<Book>               findByCategory(String category, Pageable pageable); // 슬라이스
Stream<Book>              findByCategory(String category);       // 스트림 (try-with-resources)
long                      countByCategory(String category);
boolean                   existsByIsbn(String isbn);
```

### 📌 비동기 반환

```java
@Async
Future<List<Book>> findByCategory(String category);

@Async
CompletableFuture<List<Book>> findByCategoryAndActive(String category, boolean active);
```

---

## 7. 한계와 전환 기준

---

### 📌 메서드명이 길어지는 문제

```java
// 조건이 많아질수록 메서드명이 비현실적으로 길어진다
List<Book> findByTitleContainingAndCategoryAndPriceBetweenAndDeletedAtIsNullOrderByPublishedDateDesc(
    String title, String category, int minPrice, int maxPrice
);
```

### 📌 @Query로 전환해야 하는 시점

| 상황 | 이유 |
|---|---|
| 조건이 3개 이상 | 메서드명 가독성 붕괴 |
| JOIN이 필요한 경우 | 메서드 이름으로 JOIN 표현 불가 |
| 동적 조건 (조건이 있을 수도 없을 수도) | 고정된 메서드명으로 동적 처리 불가 |
| 서브쿼리, 집계 함수 | 지원 안 됨 |
| 복잡한 정렬 / 그룹핑 | 지원 안 됨 |

동적 조건이 필요하면 `@Query` + JPQL, 더 복잡하면 QueryDSL로 간다.

---

## 8. 정리

---

- 메서드 이름 쿼리는 파싱 → JPQL 자동 생성 방식이다. 구동 시점에 검증되므로 오류를 빨리 잡을 수 있다
- `findBy`, `countBy`, `existsBy`, `deleteBy` 접두사로 시작하며 조건을 이름으로 표현한다
- `Containing`, `Between`, `In`, `IsNull`, `True/False` 등 다양한 키워드를 조합할 수 있다
- `First` / `Top N`으로 조회 수를 제한하고, `Sort` 파라미터로 동적 정렬을 적용한다
- 조건이 3개 이상이거나 JOIN이 필요하면 `@Query` 또는 QueryDSL로 전환한다

---

## 참고

- 출처: Claude Desktop 대화 (2026-04-14)
- [Spring Data JPA — Query Methods](https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#jpa.query-methods)
