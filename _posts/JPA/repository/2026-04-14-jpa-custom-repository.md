---
title: "커스텀 Repository — QueryDSL 연동을 위한 확장 패턴"
date: 2026-04-14 09:50:00 +0900
categories: [JPA, 리포지토리]
tags: [JPA, 리포지토리, 커스텀Repository, RepositoryImpl, QueryDSL, EntityManager, SpringDataJPA]
order: 6
---

## 1. 개요

---

`JpaRepository`의 메서드 이름 쿼리와 `@Query`로 해결할 수 없는 경우가 있다. 동적 조건이 많거나, QueryDSL 같은 외부 라이브러리를 써야 하거나, 복잡한 집계 쿼리가 필요한 경우다. 이때 커스텀 Repository 패턴을 사용한다.

이 글에서는 커스텀 Repository의 구조, 명명 규칙, EntityManager 직접 사용, 그리고 QueryDSL 연동을 위한 기본 뼈대까지 다룬다.

| 주제 | 내용 |
|---|---|
| 패턴 구조 | 커스텀 인터페이스 + Impl 구현체 + 최종 Repository |
| 명명 규칙 | 인터페이스명 + Impl (Spring이 자동 탐지) |
| EntityManager | Impl 내에서 JPQL/Criteria 직접 실행 |
| QueryDSL 연동 | JPAQueryFactory 주입 패턴 (뼈대) |

---

## 2. 언제 커스텀 Repository가 필요한가

---

| 상황 | 해결책 |
|---|---|
| 단순 조건 조회 | 메서드 이름 쿼리 |
| 복잡한 고정 쿼리, JOIN | @Query |
| 동적 조건 (조건이 있을 수도 없을 수도) | 커스텀 Repository + QueryDSL |
| 통계, 집계, 복잡한 서브쿼리 | 커스텀 Repository + JPQL / nativeQuery |
| 외부 라이브러리 연동 (QueryDSL 등) | 커스텀 Repository |

---

## 3. 커스텀 Repository 구조

---

### 📌 전체 구조

```
BookRepository                    ← 개발자가 주입받아 사용하는 최종 인터페이스
├── extends JpaRepository         ← 기본 CRUD + 페이징
└── extends BookRepositoryCustom  ← 커스텀 메서드 선언 (인터페이스)
                                        ↑ implements
                                  BookRepositoryImpl  ← 실제 구현체 (Impl 명명 규칙)
```

Spring Data JPA가 `BookRepository`의 Bean을 만들 때, `BookRepositoryImpl`을 찾아서 자동으로 결합한다.

---

## 4. 구현 코드

---

### 📌 Step 1 — 커스텀 인터페이스 선언

```java
/**
 * 커스텀 메서드를 선언하는 인터페이스
 * @NoRepositoryBean을 붙이지 않아도 되는 이유:
 * 이 인터페이스는 Repository를 상속하지 않으므로 Spring이 Bean으로 만들려 하지 않는다.
 */
public interface BookRepositoryCustom {

    List<Book> searchBooks(String keyword, String category, Integer minPrice, Integer maxPrice);

    Page<Book> searchBooksPaged(BookSearchCondition condition, Pageable pageable);

    Map<String, Long> countByCategory();
}
```

### 📌 Step 2 — 최종 Repository에 상속 추가

```java
/**
 * 최종 Repository 인터페이스.
 * JpaRepository와 BookRepositoryCustom을 동시에 상속한다.
 * 사용하는 쪽에서는 이 인터페이스 하나만 주입받아 모든 메서드를 사용한다.
 */
public interface BookRepository
        extends JpaRepository<Book, Long>, BookRepositoryCustom {

    // 메서드 이름 쿼리와 @Query는 여기에 선언
    List<Book> findByAuthor_Name(String authorName);

    @Query("SELECT b FROM Book b WHERE b.isbn = :isbn AND b.deletedAt IS NULL")
    Optional<Book> findByIsbnActive(@Param("isbn") String isbn);
}
```

### 📌 Step 3 — Impl 구현체 작성

```java
/**
 * 명명 규칙: 최종 Repository 인터페이스명 + "Impl"
 *   BookRepository + Impl = BookRepositoryImpl
 *
 * 또는 커스텀 인터페이스명 + "Impl"도 허용:
 *   BookRepositoryCustom + Impl = BookRepositoryCustomImpl
 *
 * Spring Data JPA가 이 명명 규칙으로 자동 탐지한다.
 * @Repository를 붙이지 않아도 자동으로 Bean 등록된다.
 */
@RequiredArgsConstructor
public class BookRepositoryImpl implements BookRepositoryCustom {

    private final EntityManager em;

    @Override
    public List<Book> searchBooks(
            String keyword, String category, Integer minPrice, Integer maxPrice) {

        StringBuilder jpql = new StringBuilder(
            "SELECT b FROM Book b WHERE b.deletedAt IS NULL"
        );

        if (keyword != null && !keyword.isBlank()) {
            jpql.append(" AND b.title LIKE :keyword");
        }
        if (category != null) {
            jpql.append(" AND b.category = :category");
        }
        if (minPrice != null) {
            jpql.append(" AND b.price >= :minPrice");
        }
        if (maxPrice != null) {
            jpql.append(" AND b.price <= :maxPrice");
        }
        jpql.append(" ORDER BY b.publishedDate DESC");

        TypedQuery<Book> query = em.createQuery(jpql.toString(), Book.class);

        if (keyword != null && !keyword.isBlank()) {
            query.setParameter("keyword", "%" + keyword + "%");
        }
        if (category != null) {
            query.setParameter("category", category);
        }
        if (minPrice != null) {
            query.setParameter("minPrice", minPrice);
        }
        if (maxPrice != null) {
            query.setParameter("maxPrice", maxPrice);
        }

        return query.getResultList();
    }

    @Override
    public Map<String, Long> countByCategory() {
        List<Object[]> results = em.createQuery(
            "SELECT b.category, COUNT(b) FROM Book b GROUP BY b.category",
            Object[].class
        ).getResultList();

        return results.stream()
            .collect(Collectors.toMap(
                row -> (String) row[0],
                row -> (Long) row[1]
            ));
    }
}
```

> 💡 위 `searchBooks` 처럼 `StringBuilder`로 JPQL을 조합하는 방식은 동적 쿼리 처리가 가능하지만, 조건이 많아질수록 코드가 복잡해진다. 실무에서는 이 패턴을 QueryDSL로 대체한다 (Phase 9에서 상세 설명).

---

## 5. QueryDSL 연동을 위한 Impl 뼈대

---

Phase 9에서 상세히 다루지만, 커스텀 Repository가 QueryDSL과 어떻게 연결되는지 구조를 미리 파악한다.

```java
/**
 * QueryDSL을 사용하는 Impl 패턴
 * JPAQueryFactory를 주입받아 사용한다.
 * EntityManager 직접 JPQL 대신 타입 안전한 DSL로 쿼리를 작성한다.
 */
@RequiredArgsConstructor
public class BookRepositoryImpl implements BookRepositoryCustom {

    private final JPAQueryFactory queryFactory;  // Bean으로 등록된 JPAQueryFactory 주입

    QBook book = QBook.book;
    QAuthor author = QAuthor.author;

    @Override
    public List<Book> searchBooks(
            String keyword, String category, Integer minPrice, Integer maxPrice) {

        return queryFactory
            .selectFrom(book)
            .leftJoin(book.author, author).fetchJoin()
            .where(
                keywordContains(keyword),    // null이면 조건 자체가 무시됨
                categoryEq(category),
                priceGoe(minPrice),
                priceLoe(maxPrice),
                book.deletedAt.isNull()
            )
            .orderBy(book.publishedDate.desc())
            .fetch();
    }

    // BooleanExpression 반환 — null이면 해당 조건 무시 (동적 쿼리 핵심)
    private BooleanExpression keywordContains(String keyword) {
        return (keyword != null && !keyword.isBlank())
            ? book.title.contains(keyword)
            : null;
    }

    private BooleanExpression categoryEq(String category) {
        return category != null ? book.category.eq(category) : null;
    }

    private BooleanExpression priceGoe(Integer minPrice) {
        return minPrice != null ? book.price.goe(minPrice) : null;
    }

    private BooleanExpression priceLoe(Integer maxPrice) {
        return maxPrice != null ? book.price.loe(maxPrice) : null;
    }
}
```

이 패턴에서 `BooleanExpression`이 `null`을 반환하면 QueryDSL이 해당 조건을 자동으로 무시한다. StringBuilder로 조합하는 것보다 훨씬 깔끔하다.

---

## 6. JPAQueryFactory Bean 등록

---

```java
/**
 * QueryDSL JPAQueryFactory를 Spring Bean으로 등록한다.
 * EntityManager를 주입받아 생성한다.
 */
@Configuration
public class QueryDslConfig {

    @PersistenceContext
    private EntityManager entityManager;

    @Bean
    public JPAQueryFactory jpaQueryFactory() {
        return new JPAQueryFactory(entityManager);
    }
}
```

---

## 7. 명명 규칙 커스터마이징

---

```java
/**
 * 기본 접미사 "Impl" 대신 다른 이름을 사용하고 싶으면 설정 변경
 * Spring Boot에서는 @EnableJpaRepositories를 직접 선언해야 한다
 */
@EnableJpaRepositories(
    basePackages = "com.example.repository",
    repositoryImplementationPostfix = "Impl"  // 기본값이 "Impl"이므로 변경 시에만 설정
)
@Configuration
public class JpaConfig { }
```

---

## 8. 서비스에서의 사용

---

```java
@Service
@RequiredArgsConstructor
public class BookService {

    // BookRepository 하나만 주입받으면 JpaRepository + Custom 메서드 모두 사용 가능
    private final BookRepository bookRepository;

    public List<BookSummaryDto> search(BookSearchCondition condition) {
        List<Book> books = bookRepository.searchBooks(
            condition.getKeyword(),
            condition.getCategory(),
            condition.getMinPrice(),
            condition.getMaxPrice()
        );
        return books.stream()
            .map(BookSummaryDto::from)
            .toList();
    }

    public Optional<Book> findActive(String isbn) {
        // @Query 메서드 — 같은 Repository에서 함께 사용
        return bookRepository.findByIsbnActive(isbn);
    }
}
```

---

## 9. 정리

---

- 커스텀 Repository는 `커스텀 인터페이스` + `Impl 구현체` + `최종 Repository 상속`의 세 요소로 구성된다
- 명명 규칙: 최종 Repository 인터페이스명 + `Impl`. Spring Data JPA가 자동으로 탐지하고 결합한다
- `Impl` 내부에서 `EntityManager`를 직접 주입받아 JPQL을 실행하거나, `JPAQueryFactory`로 QueryDSL을 사용한다
- 동적 조건이 많은 경우 EntityManager + StringBuilder JPQL보다 QueryDSL의 `BooleanExpression` 패턴이 훨씬 깔끔하다
- 사용하는 쪽(서비스)은 최종 Repository 하나만 주입받으면 기본 CRUD와 커스텀 메서드 모두 사용할 수 있다

---

## 참고

- 출처: Claude Desktop 대화 (2026-04-14)
- [Spring Data JPA — Custom Repository](https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#repositories.custom-implementations)
