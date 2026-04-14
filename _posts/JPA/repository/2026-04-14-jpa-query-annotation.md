---
title: "@Query 어노테이션 — JPQL과 벌크 연산 완전 정복"
date: 2026-04-14 09:20:00 +0900
categories: [JPA, 리포지토리]
tags: [JPA, 리포지토리, Query, JPQL, Modifying, 벌크연산, nativeQuery, SpringDataJPA]
order: 3
---

## 1. 개요

---

메서드 이름 쿼리는 단순 조건에서 강점을 보이지만, 조건이 복잡하거나 JOIN이 필요하면 한계에 부딪힌다. `@Query`는 JPQL 또는 SQL을 직접 작성해서 이 한계를 극복한다.

이 글에서는 `@Query`의 기본 사용법, 파라미터 바인딩 방식, 네이티브 쿼리, 그리고 UPDATE/DELETE 벌크 연산 처리까지 다룬다.

| 주제 | 내용 |
|---|---|
| @Query 기본 | JPQL 기반 커스텀 쿼리 선언 |
| 파라미터 바인딩 | :param 이름 바인딩, ?1 위치 바인딩 |
| nativeQuery | DB 전용 SQL 직접 사용 |
| @Modifying | UPDATE / DELETE 벌크 연산 |

---

## 2. @Query 기본 사용법

---

### 📌 JPQL 기반 쿼리

```java
public interface BookRepository extends JpaRepository<Book, Long> {

    /**
     * JPQL은 테이블명/컬럼명이 아닌 엔티티명/필드명을 기준으로 작성한다.
     * - Book: 클래스명 (테이블명 book이 아님)
     * - b.title: 필드명 (컬럼명 title과 다를 수 있음)
     */
    @Query("SELECT b FROM Book b WHERE b.title LIKE %:keyword% AND b.deletedAt IS NULL")
    List<Book> searchByKeyword(@Param("keyword") String keyword);

    // JOIN 포함 쿼리
    @Query("""
            SELECT b FROM Book b
            JOIN b.author a
            WHERE a.name = :authorName
            AND b.price BETWEEN :minPrice AND :maxPrice
            ORDER BY b.publishedDate DESC
            """)
    List<Book> findByAuthorAndPriceRange(
            @Param("authorName") String authorName,
            @Param("minPrice") int minPrice,
            @Param("maxPrice") int maxPrice
    );
}
```

### 📌 파라미터 바인딩 방식 비교

**이름 기반 바인딩 (:param) — 권장**

```java
@Query("SELECT b FROM Book b WHERE b.category = :category AND b.price <= :maxPrice")
List<Book> findByCategoryAndMaxPrice(
    @Param("category") String category,
    @Param("maxPrice") int maxPrice
);
```

**위치 기반 바인딩 (?1, ?2) — 비권장**

```java
// ?1은 첫 번째 파라미터, ?2는 두 번째 파라미터
// 파라미터 순서가 바뀌면 버그가 생기므로 이름 기반을 쓰는 게 낫다
@Query("SELECT b FROM Book b WHERE b.category = ?1 AND b.price <= ?2")
List<Book> findByCategoryAndMaxPrice(String category, int maxPrice);
```

> 💡 `@Param` 어노테이션이 없어도 최신 스프링에서는 파라미터 이름을 자동으로 인식하지만, 명시적으로 붙이는 것이 코드를 읽기 쉽고 컴파일 설정에 덜 의존적이다.

---

## 3. 반환 타입

---

```java
// 단건 반환 — 결과가 없으면 null, 2건 이상이면 IncorrectResultSizeDataAccessException
@Query("SELECT b FROM Book b WHERE b.isbn = :isbn")
Book findByIsbnQuery(@Param("isbn") String isbn);

// Optional — 없으면 Optional.empty()
@Query("SELECT b FROM Book b WHERE b.isbn = :isbn")
Optional<Book> findByIsbnOptional(@Param("isbn") String isbn);

// 컬렉션 — 없으면 빈 리스트 (null 아님)
@Query("SELECT b FROM Book b WHERE b.category = :category")
List<Book> findByCategoryQuery(@Param("category") String category);

// 페이징과 함께 사용
@Query("SELECT b FROM Book b WHERE b.category = :category ORDER BY b.publishedDate DESC")
Page<Book> findByCategoryPaged(@Param("category") String category, Pageable pageable);

// DTO로 직접 반환 (new 키워드 사용)
@Query("SELECT new com.example.dto.BookSummaryDto(b.title, b.price, a.name) " +
       "FROM Book b JOIN b.author a WHERE b.category = :category")
List<BookSummaryDto> findSummaryByCategory(@Param("category") String category);
```

---

## 4. nativeQuery

---

### 📌 기본 사용

```java
/**
 * nativeQuery = true면 JPQL이 아닌 실제 DB SQL을 쓴다.
 * 엔티티명 대신 테이블명, 필드명 대신 컬럼명을 써야 한다.
 */
@Query(
    value = "SELECT * FROM book WHERE category = :category AND deleted_at IS NULL LIMIT :limit",
    nativeQuery = true
)
List<Book> findByCategoryNative(@Param("category") String category, @Param("limit") int limit);
```

### 📌 네이티브 쿼리의 페이징

```java
/**
 * 네이티브 쿼리에서 Pageable을 쓰려면 countQuery를 반드시 명시해야 한다.
 * Spring Data JPA가 자동 COUNT 쿼리를 생성하지 못하기 때문이다.
 */
@Query(
    value = "SELECT * FROM book WHERE category = :category AND deleted_at IS NULL",
    countQuery = "SELECT COUNT(*) FROM book WHERE category = :category AND deleted_at IS NULL",
    nativeQuery = true
)
Page<Book> findByCategoryNativePaged(@Param("category") String category, Pageable pageable);
```

### 📌 nativeQuery 사용 기준

| 사용해야 하는 경우 | 피해야 하는 경우 |
|---|---|
| 전문 검색 (MATCH AGAINST 등 DB 전용 함수) | 단순 조건 조회 |
| 쿼리 힌트 (USE INDEX, FORCE INDEX 등) | JOIN을 포함하는 일반 조회 |
| DB 전용 문법이 반드시 필요한 경우 | JPQL로 대체 가능한 경우 |
| 레거시 SQL 재사용 | DB 이식성이 중요한 경우 |

> 💡 nativeQuery는 DB에 종속된다. MySQL에서 쓴 쿼리가 PostgreSQL에서 안 될 수 있다. 이식성이 중요하면 JPQL을 쓰고, 꼭 필요한 경우에만 nativeQuery를 선택한다.

---

## 5. @Modifying — 벌크 연산

---

### 📌 왜 @Modifying이 필요한가

`@Query`로 SELECT가 아닌 UPDATE/DELETE를 실행하면 예외가 발생한다. JPA는 기본적으로 JPQL을 SELECT 쿼리로 처리하는데, 쓰기 연산임을 명시하는 게 `@Modifying`이다.

```java
// @Modifying 없이 UPDATE 실행 → InvalidDataAccessApiUsageException 발생
@Query("UPDATE Book b SET b.price = b.price * :rate WHERE b.category = :category")
int bulkUpdatePrice(@Param("rate") double rate, @Param("category") String category);
// → org.springframework.dao.InvalidDataAccessApiUsageException
```

### 📌 @Modifying 기본 사용

```java
/**
 * @Modifying: UPDATE/DELETE 쿼리임을 선언
 * @Transactional: 쓰기 트랜잭션 (SimpleJpaRepository 기본이 readOnly=true이므로)
 * 반환 타입 int: 영향받은 행(row) 수
 */
@Modifying
@Transactional
@Query("UPDATE Book b SET b.price = b.price * :rate WHERE b.category = :category")
int bulkUpdatePrice(@Param("rate") double rate, @Param("category") String category);

@Modifying
@Transactional
@Query("DELETE FROM Book b WHERE b.deletedAt < :cutoff")
int deleteOldRecords(@Param("cutoff") LocalDateTime cutoff);
```

### 📌 clearAutomatically — 영속성 컨텍스트 동기화

벌크 연산의 핵심 함정이다.

```java
// 문제 시나리오
Book book = bookRepository.findById(1L).get();
// book.price = 10000 (1차 캐시에 캐싱된 상태)

bookRepository.bulkUpdatePrice(1.1, "IT");
// DB에서 price = 11000 으로 변경되었지만
// 1차 캐시의 book.price는 여전히 10000

book = bookRepository.findById(1L).get();
// 1차 캐시에서 가져오므로 price = 10000 (DB와 불일치!)
```

`clearAutomatically = true`로 해결한다.

```java
/**
 * clearAutomatically = true:
 * 벌크 연산 실행 후 영속성 컨텍스트를 자동으로 clear한다.
 * 1차 캐시가 비워지므로 이후 조회 시 DB에서 최신 데이터를 가져온다.
 *
 * flushAutomatically = true (기본 false):
 * 벌크 연산 전에 flush를 수행한다.
 * 미처 flush되지 않은 변경사항이 있을 때 데이터 정합성을 보장한다.
 */
@Modifying(clearAutomatically = true, flushAutomatically = true)
@Transactional
@Query("UPDATE Book b SET b.price = b.price * :rate WHERE b.category = :category")
int bulkUpdatePrice(@Param("rate") double rate, @Param("category") String category);
```

### 📌 실전 벌크 연산 패턴

```java
// 소프트 딜리트 (논리 삭제)
@Modifying(clearAutomatically = true)
@Transactional
@Query("UPDATE Book b SET b.deletedAt = :now WHERE b.id IN :ids")
int softDeleteByIds(@Param("ids") List<Long> ids, @Param("now") LocalDateTime now);

// 만료된 세션 일괄 정리
@Modifying(clearAutomatically = true)
@Transactional
@Query("DELETE FROM UserSession s WHERE s.expiredAt < :now")
int deleteExpiredSessions(@Param("now") LocalDateTime now);

// 특정 조건 엔티티 상태 일괄 변경
@Modifying(clearAutomatically = true)
@Transactional
@Query("UPDATE LoanRecord lr SET lr.status = 'OVERDUE' " +
       "WHERE lr.dueDate < :today AND lr.status = 'ACTIVE'")
int markOverdueLoans(@Param("today") LocalDate today);
```

---

## 6. @Query vs 메서드 이름 쿼리 선택 기준

---

| 상황 | 선택 |
|---|---|
| 단순 조건 1~2개, 조인 없음 | 메서드 이름 쿼리 |
| 조건 3개 이상 | @Query |
| JOIN 포함 | @Query |
| UPDATE / DELETE | @Query + @Modifying |
| 동적 조건 (있을 수도 없을 수도) | QueryDSL |
| DB 전용 함수 필요 | @Query(nativeQuery=true) |

---

## 7. 정리

---

- `@Query`는 JPQL 또는 SQL을 직접 작성해서 복잡한 조건을 처리한다
- 파라미터 바인딩은 `:param` 이름 기반이 가독성과 안정성 면에서 권장된다
- `nativeQuery = true`는 DB 전용 기능이 필요할 때만 쓰고, 이식성을 고려한다
- `@Modifying`은 UPDATE/DELETE 쿼리에 반드시 붙여야 한다
- 벌크 연산 후 영속성 컨텍스트 불일치를 `clearAutomatically = true`로 해결한다
- `flushAutomatically = true`는 벌크 연산 전 미반영 변경사항을 DB에 먼저 내보낸다

---

## 참고

- 출처: Claude Desktop 대화 (2026-04-14)
- [Spring Data JPA — @Query](https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#jpa.query-methods.at-query)
- [Spring Data JPA — Modifying Queries](https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#jpa.modifying-queries)
