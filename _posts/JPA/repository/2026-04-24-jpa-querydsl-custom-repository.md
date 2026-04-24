---
title: "QueryDSL과 커스텀 Repository"
date: 2026-04-24 14:00:00 +0900
categories: [JPA, 기본 개념]
order: 5
tags: [JPA, QueryDSL, 커스텀Repository, JPAQueryFactory, Q클래스, BooleanExpression, JpaRepository, Impl, 동적쿼리, N+1]
---

##  1. QueryDSL과 커스텀 Repository

---

```
JpaRepository만으로는 뭐가 부족한가?
    ↓
커스텀 Repository 패턴이란 무엇인가?
    ↓
동적 쿼리를 직접 짜면 왜 힘든가?
    ↓
QueryDSL이 그 문제를 어떻게 해결하는가?
    ↓
커스텀 Repository + QueryDSL = 완성된 전체 그림
```

---

##  2. JpaRepository만으로 부족한 경우

---

`JpaRepository`의 메서드 이름 쿼리와 `@Query`는 조건이 **고정**되어 있을 때 편리하다.

```java
// 고정 조건 — 항상 category가 있고 항상 price 조건이 있음
List<Book> findByCategoryAndPriceLessThan(String category, int price);
```

하지만 검색 화면처럼 **조건이 선택적**인 경우에는 이 방식이 한계에 부딪힌다.

```
사용자가 검색할 수 있는 조건:
  - 제목 키워드 (없을 수도 있음)
  - 카테고리 (없을 수도 있음)
  - 최소 가격 (없을 수도 있음)
  - 최대 가격 (없을 수도 있음)

가능한 조합의 수: 2^4 = 16가지
```

16가지 조합마다 메서드를 만들 수는 없다. 이것이 **동적 쿼리(Dynamic Query)** 가 필요한 이유다.

---

##  3. 동적 쿼리를 직접 짜면 왜 힘든가

---

동적 쿼리를 가장 원시적인 방법으로 짜면 이렇게 된다.

```java
// JPQL을 문자열로 조합 — 실제로 이렇게 짜야 한다
public List<Book> searchBooks(String keyword, String category,
                               Integer minPrice, Integer maxPrice) {
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

    // 파라미터 바인딩도 또 조건 분기
    if (keyword != null && !keyword.isBlank()) {
        query.setParameter("keyword", "%" + keyword + "%");
    }
    if (category != null) {
        query.setParameter("category", category);
    }
    // ...
}
```

문제가 3가지 있다.

**문제 1 — 조건 분기가 두 번 나온다.** 문자열 조합 때 한 번, 파라미터 바인딩 때 또 한 번. 조건이 10개가 되면 20개의 if 블록이 생긴다.

**문제 2 — 오타를 컴파일 타임에 잡을 수 없다.** `"b.titel"` 이라고 써도 컴파일은 된다. 런타임에 실행해봐야 오류를 알 수 있다.

**문제 3 — 리팩토링이 어렵다.** `Book.title` 필드명이 `name`으로 바뀌면 이 문자열을 직접 찾아가서 고쳐야 한다. IDE의 "모든 참조 찾기"가 동작하지 않는다.

이 문제들을 해결하기 위해 QueryDSL이 등장한다.

---

##  4. QueryDSL이 해결하는 방식

---

QueryDSL은 **자바 코드로 쿼리를 작성**한다. 문자열이 아니라 객체다.

### 📌 Q클래스 — 엔티티를 자바 객체로 표현한 것

QueryDSL을 설정하면 APT(Annotation Processing Tool)가 `@Entity` 클래스를 분석해서 `Q접두사`가 붙은 클래스를 자동으로 생성한다.

```java
// 원본 엔티티
@Entity
public class Book {
    private String title;
    private int price;
    private String category;
    private LocalDateTime deletedAt;
}

// APT가 자동 생성하는 Q클래스 (src/main/generated 폴더에 생성됨)
public class QBook extends EntityPathBase<Book> {

    public static final QBook book = new QBook("book"); // 기본 인스턴스

    public final StringPath title = createString("title");
    public final NumberPath<Integer> price = createNumber("price", Integer.class);
    public final StringPath category = createString("category");
    public final DateTimePath<LocalDateTime> deletedAt = ...;
}
```

`QBook.book`은 `Book` 엔티티를 자바 객체로 표현한 것이다. `book.title`, `book.price`는 단순한 문자열이 아니라 타입 정보를 가진 객체다. `book.title.eq("스프링")`이라고 쓰면 IDE가 자동완성을 제공하고, `title` 필드가 없으면 컴파일 오류가 난다.

### 📌 문자열 조합 vs QueryDSL 비교

```java
// 문자열 조합 방식 — 같은 조건을 두 번 분기, 오타 위험
if (keyword != null) jpql.append(" AND b.title LIKE :keyword");
// ...
if (keyword != null) query.setParameter("keyword", "%" + keyword + "%");

// QueryDSL 방식 — 조건 하나가 하나의 메서드로 완결
private BooleanExpression keywordContains(String keyword) {
    return StringUtils.hasText(keyword)
        ? book.title.contains(keyword)  // LIKE '%keyword%' 자동 생성
        : null;                          // null이면 이 조건 전체가 무시됨
}
```

`null`을 반환하면 QueryDSL이 해당 조건을 `where()`에서 자동으로 제외한다. 이것이 `BooleanExpression` 패턴의 핵심이다.

---

##  5. 그런데 QueryDSL 코드를 어디에 써야 하는가?

---

여기서 커스텀 Repository 패턴이 필요해진다.

`JpaRepository`는 인터페이스다. 인터페이스에 QueryDSL 코드를 직접 쓸 수 없다. QueryDSL은 `JPAQueryFactory` 객체를 사용하는 **구현 코드**이기 때문이다.

```java
// 이렇게 할 수 없다 — 인터페이스에 구현 코드 불가
public interface BookRepository extends JpaRepository<Book, Long> {
    // QueryDSL 코드를 여기에? → 불가능
    List<Book> searchBooks(...) {
        return queryFactory.selectFrom(book)... // 인터페이스에 구현 불가
    }
}
```

해결 방법은 **구현체를 별도로 만들고 Spring이 이를 자동으로 연결하도록** 하는 것이다. 이것이 커스텀 Repository 패턴이다.

---

##  6. 커스텀 Repository + QueryDSL 전체 구조

---

```
┌─────────────────────────────────────────────────────────────────┐
│  서비스 계층                                                     │
│  private final BookRepository bookRepository;                   │
│  → bookRepository 하나로 기본 CRUD + QueryDSL 검색 모두 사용    │
└───────────────────────────┬─────────────────────────────────────┘
                            │ 주입
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  BookRepository (인터페이스)                                     │
│  extends JpaRepository<Book, Long>    ← 기본 CRUD               │
│  extends BookRepositoryCustom         ← 커스텀 메서드 선언       │
└───────────┬─────────────────────┬───────────────────────────────┘
            │ Spring이 자동 연결   │
            ▼                     ▼
┌───────────────────┐   ┌─────────────────────────────────────────┐
│ SimpleJpaRepo...  │   │  BookRepositoryImpl (구현체)             │
│ (기본 CRUD 구현)  │   │  implements BookRepositoryCustom         │
│ - save()          │   │  private final JPAQueryFactory qf;       │
│ - findById()      │   │  → QueryDSL 코드가 여기에 작성됨         │
│ - delete()        │   └─────────────────────────────────────────┘
└───────────────────┘
```

핵심은 **Spring이 런타임에 `BookRepositoryImpl`을 자동으로 찾아서 `BookRepository`에 결합**한다는 것이다. 이게 되려면 명명 규칙을 지켜야 한다. **최종 Repository 인터페이스명 + `Impl`.**

---

##  7. 코드로 완성하기 — 단계별 구현

---

### 📌 Step 0 — JPAQueryFactory Bean 등록

QueryDSL을 쓰려면 `JPAQueryFactory`가 Spring Bean으로 등록되어 있어야 한다. 딱 한 번만 설정한다.

```java
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

`JPAQueryFactory`는 내부적으로 `EntityManager`를 사용한다. 2장에서 배운 것처럼 `EntityManager`는 ThreadLocal 프록시로 주입되므로 싱글톤 Bean으로 등록해도 스레드 안전하다.

### 📌 Step 1 — 커스텀 인터페이스 선언

QueryDSL로 구현할 메서드 시그니처만 선언한다. 구현은 Impl에서 한다.

```java
// BookRepositoryCustom.java
public interface BookRepositoryCustom {

    // 검색 조건이 선택적 → 동적 쿼리가 필요 → QueryDSL로 구현할 것
    List<Book> searchBooks(String keyword, String category,
                           Integer minPrice, Integer maxPrice);

    Page<BookSummaryDto> searchBooksPaged(BookSearchCondition condition,
                                          Pageable pageable);
}
```

### 📌 Step 2 — 최종 Repository에 상속 추가

```java
// BookRepository.java
public interface BookRepository
        extends JpaRepository<Book, Long>,   // 기본 CRUD
                BookRepositoryCustom {        // 커스텀 메서드

    // 고정 조건 → 메서드 이름 쿼리로 해결
    Optional<Book> findByIsbn(String isbn);

    // 복잡한 고정 쿼리 → @Query로 해결
    @Query("SELECT b FROM Book b JOIN FETCH b.author WHERE b.id = :id")
    Optional<Book> findWithAuthorById(@Param("id") Long id);

    // 동적 조건 → BookRepositoryCustom에 선언, Impl에서 QueryDSL로 구현
}
```

### 📌 Step 3 — BookRepositoryImpl 작성 (QueryDSL 코드가 여기에)

```java
// BookRepositoryImpl.java
// 명명 규칙: BookRepository + Impl
@RequiredArgsConstructor
public class BookRepositoryImpl implements BookRepositoryCustom {

    private final JPAQueryFactory queryFactory;  // Bean 주입

    // Q클래스 — 타입 안전한 쿼리 작성의 시작점
    private final QBook book = QBook.book;
    private final QAuthor author = QAuthor.author;

    @Override
    public List<Book> searchBooks(String keyword, String category,
                                   Integer minPrice, Integer maxPrice) {
        return queryFactory
            .selectFrom(book)
            .leftJoin(book.author, author).fetchJoin() // N+1 방지
            .where(
                keywordContains(keyword),   // null이면 이 조건 무시
                categoryEq(category),       // null이면 이 조건 무시
                priceGoe(minPrice),         // null이면 이 조건 무시
                priceLoe(maxPrice),         // null이면 이 조건 무시
                book.deletedAt.isNull()     // 소프트 딜리트 제외 (항상 적용)
            )
            .orderBy(book.publishedDate.desc())
            .fetch();
    }

    @Override
    public Page<BookSummaryDto> searchBooksPaged(
            BookSearchCondition condition, Pageable pageable) {

        // 데이터 조회
        List<BookSummaryDto> content = queryFactory
            .select(new QBookSummaryDto(
                book.title,
                book.price,
                author.name))
            .from(book)
            .leftJoin(book.author, author)
            .where(
                keywordContains(condition.getKeyword()),
                categoryEq(condition.getCategory()),
                priceGoe(condition.getMinPrice()),
                priceLoe(condition.getMaxPrice()),
                book.deletedAt.isNull()
            )
            .orderBy(book.publishedDate.desc())
            .offset(pageable.getOffset())
            .limit(pageable.getPageSize())
            .fetch();

        // COUNT 쿼리 별도 작성 (fetchResults() Deprecated 대응)
        Long total = queryFactory
            .select(book.count())
            .from(book)
            .leftJoin(book.author, author)
            .where(
                keywordContains(condition.getKeyword()),
                categoryEq(condition.getCategory()),
                priceGoe(condition.getMinPrice()),
                priceLoe(condition.getMaxPrice()),
                book.deletedAt.isNull()
            )
            .fetchOne();

        return new PageImpl<>(content, pageable, total != null ? total : 0L);
    }

    // ──────────────────────────────────────────────────────────
    // BooleanExpression 조건 메서드
    // null을 반환하면 QueryDSL이 where()에서 해당 조건을 자동으로 제외
    // ──────────────────────────────────────────────────────────

    private BooleanExpression keywordContains(String keyword) {
        return StringUtils.hasText(keyword)
            ? book.title.contains(keyword)  // LIKE '%keyword%'
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

### 📌 Step 4 — 서비스에서 사용

서비스는 `BookRepository` 하나만 주입받는다. 기본 CRUD도, QueryDSL 검색도 같은 객체로 호출한다.

```java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BookService {

    private final BookRepository bookRepository; // 하나로 다 됨

    // 기본 CRUD — SimpleJpaRepository가 처리
    public Optional<Book> findById(Long id) {
        return bookRepository.findById(id);
    }

    // @Query — BookRepository 인터페이스가 처리
    public Optional<Book> findWithAuthor(Long id) {
        return bookRepository.findWithAuthorById(id);
    }

    // QueryDSL 동적 검색 — BookRepositoryImpl이 처리
    public List<BookResponse> search(String keyword, String category,
                                      Integer minPrice, Integer maxPrice) {
        return bookRepository.searchBooks(keyword, category, minPrice, maxPrice)
            .stream()
            .map(BookResponse::from)
            .toList();
    }
}
```

---

##  8. 동작 원리 — Spring은 Impl을 어떻게 찾는가

---

Spring Data JPA는 애플리케이션 시작 시점에 `BookRepository` 인터페이스를 분석한다. `BookRepositoryCustom`을 상속하고 있으므로 해당 메서드를 구현한 Bean이 필요하다는 것을 안다. 그때 **클래스패스에서 `BookRepository` + `Impl` = `BookRepositoryImpl`이라는 이름의 클래스를 찾는다.** 있으면 자동으로 결합한다.

```
Spring이 BookRepository Bean을 만들 때:

1. BookRepository가 BookRepositoryCustom을 상속함을 확인
2. 클래스패스에서 "BookRepositoryImpl" 검색
3. 발견 → Bean 등록 후 BookRepository에 결합
4. bookRepository.searchBooks() 호출 → BookRepositoryImpl.searchBooks()로 위임
```

`BookRepositoryImpl`에 `@Repository`를 붙이지 않아도 되는 이유가 이 때문이다. Spring이 직접 찾아서 연결하므로 명시적인 Bean 등록이 필요 없다.

---

##  9. 문자열 JPQL vs QueryDSL 최종 비교

---

3장에서 문자열로 짰던 동적 쿼리와 QueryDSL 버전을 나란히 비교한다.

```java
// ❌ 문자열 JPQL — 조건 분기 두 번, 오타 위험, 리팩토링 어려움
public List<Book> searchBooks(String keyword, String category,
                               Integer minPrice, Integer maxPrice) {
    StringBuilder jpql = new StringBuilder("SELECT b FROM Book b WHERE 1=1");
    if (keyword != null) jpql.append(" AND b.title LIKE :keyword");
    if (category != null) jpql.append(" AND b.category = :category");
    if (minPrice != null) jpql.append(" AND b.price >= :minPrice");
    if (maxPrice != null) jpql.append(" AND b.price <= :maxPrice");

    TypedQuery<Book> query = em.createQuery(jpql.toString(), Book.class);
    if (keyword != null) query.setParameter("keyword", "%" + keyword + "%");
    if (category != null) query.setParameter("category", category);
    if (minPrice != null) query.setParameter("minPrice", minPrice);
    if (maxPrice != null) query.setParameter("maxPrice", maxPrice);

    return query.getResultList();
}

// ✅ QueryDSL — 조건 분기 한 번, 컴파일 타임 타입 체크, 자동완성 지원
public List<Book> searchBooks(String keyword, String category,
                               Integer minPrice, Integer maxPrice) {
    return queryFactory
        .selectFrom(book)
        .where(
            keywordContains(keyword),
            categoryEq(category),
            priceGoe(minPrice),
            priceLoe(maxPrice)
        )
        .fetch();
}
// 각 조건은 독립 메서드로 분리 — 재사용, 테스트, 변경이 모두 쉬움
```

---

##  10. 정리 — 전체 흐름 한 장으로

---

```
동적 쿼리가 필요한 이유
  └→ 검색 조건이 선택적 → JpaRepository 메서드 이름 쿼리로 불가

문자열 JPQL로 직접 짜면
  └→ 조건 분기 두 번, 오타 위험, 리팩토링 어려움

QueryDSL이 해결하는 방법
  └→ Q클래스: 엔티티 필드를 타입 안전한 객체로 표현
  └→ BooleanExpression: null 반환 시 조건 자동 무시

QueryDSL 코드를 어디에 두는가?
  └→ JpaRepository는 인터페이스 → 구현 코드를 쓸 수 없음
  └→ 커스텀 Repository Impl에 작성

커스텀 Repository 패턴
  └→ BookRepositoryCustom (인터페이스) : 메서드 시그니처 선언
  └→ BookRepositoryImpl (구현체) : QueryDSL 코드 작성
  └→ BookRepository : JpaRepository + Custom 동시 상속
  └→ Spring이 Impl을 자동으로 찾아 결합 (명명 규칙: ~Impl)

서비스에서는
  └→ BookRepository 하나만 주입 → 기본 CRUD + QueryDSL 검색 모두 사용
```

---

## 참고 자료

- 공식문서 - Spring Data JPA Custom Repository: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#repositories.custom-implementations>
- 공식문서 - QueryDSL 5.x: <http://querydsl.com/static/querydsl/5.0.0/reference/html_single/>
