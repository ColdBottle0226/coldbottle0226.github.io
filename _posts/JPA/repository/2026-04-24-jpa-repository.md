---
title: JPA Repository
date: 2026-04-24 09:30:00 +0900
categories: [JPA, 기본 개념]
order: 4
tags: [JPA, 리포지토리, JpaRepository, CrudRepository, SimpleJpaRepository, SpringDataJPA, 메서드이름쿼리, DerivedQuery, QueryMethod, Query, JPQL, Modifying, 벌크연산, nativeQuery, Pageable, Page, Slice, Sort, 페이징, Projection, DTO, 인터페이스Projection, QueryProjection, 커스텀Repository, RepositoryImpl, QueryDSL, EntityManager]
---

##  1. Repository 계층 구조

---

### 📌 인터페이스 상속 다이어그램

```
«interface»
Repository<T, ID>
    │  마커 인터페이스 — 메서드 없음. Spring이 스캔 대상을 식별하는 용도
    │
«interface»
CrudRepository<T, ID>
    │  기본 CRUD 제공 (save, findById, delete 등)
    │
«interface»
PagingAndSortingRepository<T, ID>
    │  페이징 + 정렬 추가
    │
«interface»
JpaRepository<T, ID>
    │  JPA 특화 기능 추가 (flush, saveAll, getReferenceById 등)
    │
«class»
SimpleJpaRepository<T, ID>    ← Spring이 런타임에 생성하는 실제 구현체
```

개발자는 `JpaRepository`를 상속하는 인터페이스만 선언하면 된다.

```java
public interface BookRepository extends JpaRepository<Book, Long> {
}
```

### 📌 각 계층이 제공하는 메서드

**CrudRepository**

```java
<S extends T> S save(S entity);           // 저장 (신규 persist / 기존 merge)
<S extends T> Iterable<S> saveAll(Iterable<S> entities);
Optional<T> findById(ID id);
boolean existsById(ID id);
Iterable<T> findAll();
Iterable<T> findAllById(Iterable<ID> ids);
long count();
void deleteById(ID id);
void delete(T entity);
void deleteAll(Iterable<T> entities);
void deleteAll();
```

**PagingAndSortingRepository** (CrudRepository에 추가)

```java
Iterable<T> findAll(Sort sort);
Page<T> findAll(Pageable pageable);
```

**JpaRepository** (위 모두에 추가)

```java
List<T> findAll();
List<T> findAll(Sort sort);
List<T> findAllById(Iterable<ID> ids);
<S extends T> List<S> saveAll(Iterable<S> entities);
void flush();
<S extends T> S saveAndFlush(S entity);
<S extends T> List<S> saveAllAndFlush(Iterable<S> entities);
T getReferenceById(ID id);
void deleteAllInBatch(Iterable<T> entities);
void deleteAllByIdInBatch(Iterable<ID> ids);
void deleteAllInBatch();
```

> 💡 `deleteAll()`은 엔티티를 하나씩 SELECT 후 DELETE한다. 100건이면 SELECT 100번 + DELETE 100번이다. `deleteAllInBatch()`는 `DELETE FROM book` 단일 쿼리 한 방이다. 대량 삭제 시 반드시 `InBatch` 버전을 써야 한다.

### 📌 SimpleJpaRepository — 실제 구현체

```java
@Repository
@Transactional(readOnly = true)   // 클래스 레벨: 모든 메서드 기본이 읽기 전용
public class SimpleJpaRepository<T, ID> implements JpaRepositoryImplementation<T, ID> {

    @Override
    @Transactional  // 쓰기 메서드만 readOnly=false로 재선언
    public <S extends T> S save(S entity) {
        if (entityInformation.isNew(entity)) {
            em.persist(entity);
            return entity;
        } else {
            return em.merge(entity);
        }
    }
}
```

읽기 전용 트랜잭션은 Hibernate의 Dirty Checking 스냅샷을 생성하지 않고, 트랜잭션 종료 시 flush를 skip하므로 성능이 좋다.

### 📌 save()의 isNew() 판단 기준

| 상황 | isNew() 결과 | 동작 |
|---|---|---|
| `@Id` 필드가 null | true | persist |
| `@Id` 필드에 값이 있음 | false | merge |
| `@Version` 필드가 null | true | persist |
| `Persistable` 인터페이스 구현 | 직접 정의 | 커스텀 |

PK를 직접 할당하는 경우 `isNew()`가 항상 false → merge 호출 문제가 발생한다. `Persistable`을 구현해서 해결한다.

```java
@Entity
public class Book implements Persistable<String> {

    @Id
    private String isbn;

    @CreatedDate
    private LocalDateTime createdAt;

    @Override
    public String getId() { return isbn; }

    @Override
    public boolean isNew() {
        return createdAt == null;  // createdAt이 null이면 신규로 판단
    }
}
```

### 📌 @NoRepositoryBean

중간 계층 공통 인터페이스를 만들 때 사용한다.

```java
@NoRepositoryBean
public interface BaseRepository<T, ID> extends JpaRepository<T, ID> {
    List<T> findByDeletedAtIsNull();   // 소프트 딜리트 공통 메서드
}

public interface BookRepository extends BaseRepository<Book, Long> { }
public interface MemberRepository extends BaseRepository<Member, Long> { }
```

---

##  2. 메서드 이름 쿼리 (Derived Query)

---

Spring Data JPA는 메서드 이름을 파싱해서 JPQL을 자동으로 생성한다. `findByTitle`이라고 선언하면 `SELECT b FROM Book b WHERE b.title = :title` 쿼리가 만들어진다.

Spring Data JPA가 애플리케이션 시작 시점에 인터페이스 메서드를 전부 파싱해서 쿼리를 검증한다. 필드명이 잘못되었거나 타입이 맞지 않으면 **애플리케이션 구동 실패**로 즉시 오류를 알 수 있다.

### 📌 접두사 키워드

```java
List<Book> findByCategory(String category);       // 일반 조회
Optional<Book> findByIsbn(String isbn);           // Optional — 단건 조회
long countByCategory(String category);            // 카운트
boolean existsByIsbn(String isbn);                // 존재 여부
void deleteByIsbn(String isbn);                   // 삭제
long deleteByCategory(String category);           // 삭제된 건수 반환
```

> 💡 `deleteBy`는 내부적으로 SELECT 후 하나씩 DELETE한다. 대량 삭제는 `@Modifying + @Query`가 훨씬 효율적이다.

### 📌 조건 키워드

```java
// 비교
List<Book> findByCategoryNot(String category);               // category != ?
List<Book> findByPriceBetween(int min, int max);             // price BETWEEN ? AND ?
List<Book> findByPriceLessThan(int price);                   // price < ?
List<Book> findByPriceGreaterThanEqual(int price);           // price >= ?
List<Book> findByDeletedAtIsNull();                          // deleted_at IS NULL
List<Book> findByActiveTrue();                               // active = true

// 문자열
List<Book> findByTitleLike(String pattern);                  // title LIKE ?
List<Book> findByTitleContaining(String keyword);            // title LIKE %?%
List<Book> findByTitleStartingWith(String prefix);           // title LIKE ?%
List<Book> findByTitleContainingIgnoreCase(String keyword);  // 대소문자 무시

// 컬렉션
List<Book> findByCategoryIn(List<String> categories);        // category IN (?)
List<Book> findByCategoryNotIn(List<String> categories);     // category NOT IN (?)

// 복합 조건
List<Book> findByTitleAndCategory(String title, String category);
List<Book> findByTitleOrCategory(String title, String category);
```

### 📌 정렬과 조회 수 제한

```java
// 메서드명에 OrderBy 포함
List<Book> findByAuthorOrderByPublishedDateDesc(String author);

// Sort 파라미터 — 동적 정렬
List<Book> findByCategory(String category, Sort sort);

// 조회 수 제한
Optional<Book> findFirstByOrderByPublishedDateDesc();
List<Book> findTop3ByCategoryOrderByPriceAsc(String category);

// 중복 제거
List<Book> findDistinctByCategory(String category);
```

### 📌 반환 타입

```java
List<Book>          findByCategory(String category);
Optional<Book>      findByIsbn(String isbn);
Page<Book>          findByCategory(String category, Pageable pageable);
Slice<Book>         findByCategory(String category, Pageable pageable);
long                countByCategory(String category);
boolean             existsByIsbn(String isbn);
```

### 📌 한계와 전환 기준

| 상황 | 이유 |
|---|---|
| 조건이 3개 이상 | 메서드명 가독성 붕괴 |
| JOIN이 필요한 경우 | 메서드 이름으로 JOIN 표현 불가 |
| 동적 조건 | 고정된 메서드명으로 동적 처리 불가 |
| 서브쿼리, 집계 함수 | 지원 안 됨 |

동적 조건이 필요하면 `@Query` + JPQL, 더 복잡하면 QueryDSL로 간다.

---

##  3. @Query 어노테이션 — JPQL과 벌크 연산

---

### 📌 @Query 기본 사용법

```java
// JPQL은 테이블명/컬럼명이 아닌 엔티티명/필드명을 기준으로 작성한다
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
```

파라미터 바인딩은 `:param` 이름 기반이 권장된다. `?1`, `?2` 위치 기반은 파라미터 순서가 바뀌면 버그가 생기므로 사용하지 않는 것이 낫다.

### 📌 nativeQuery

```java
@Query(
    value = "SELECT * FROM book WHERE category = :category AND deleted_at IS NULL LIMIT :limit",
    nativeQuery = true
)
List<Book> findByCategoryNative(@Param("category") String category, @Param("limit") int limit);
```

네이티브 쿼리에서 Pageable을 쓰려면 `countQuery`를 반드시 명시해야 한다.

```java
@Query(
    value = "SELECT * FROM book WHERE category = :category AND deleted_at IS NULL",
    countQuery = "SELECT COUNT(*) FROM book WHERE category = :category AND deleted_at IS NULL",
    nativeQuery = true
)
Page<Book> findByCategoryNativePaged(@Param("category") String category, Pageable pageable);
```

nativeQuery는 DB에 종속된다. 이식성이 중요하면 JPQL을 쓰고, DB 전용 함수(MATCH AGAINST, 쿼리 힌트 등)가 꼭 필요한 경우에만 선택한다.

### 📌 @Modifying — 벌크 연산

`@Query`로 UPDATE/DELETE를 실행하면 `@Modifying`이 없으면 `InvalidDataAccessApiUsageException`이 발생한다.

```java
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

벌크 연산의 핵심 함정이다. 벌크 연산은 영속성 컨텍스트를 거치지 않고 DB에 직접 반영된다. 이후 1차 캐시에서 조회하면 변경 전 값을 반환하는 불일치 문제가 생긴다.

```java
@Modifying(clearAutomatically = true, flushAutomatically = true)
@Transactional
@Query("UPDATE Book b SET b.price = b.price * :rate WHERE b.category = :category")
int bulkUpdatePrice(@Param("rate") double rate, @Param("category") String category);
```

- `clearAutomatically = true`: 벌크 연산 실행 후 영속성 컨텍스트를 자동으로 clear한다.
- `flushAutomatically = true`: 벌크 연산 전에 flush를 수행해서 미반영 변경사항을 먼저 DB에 내보낸다.

### 📌 실전 벌크 연산 패턴

```java
// 소프트 딜리트
@Modifying(clearAutomatically = true)
@Transactional
@Query("UPDATE Book b SET b.deletedAt = :now WHERE b.id IN :ids")
int softDeleteByIds(@Param("ids") List<Long> ids, @Param("now") LocalDateTime now);

// 상태 일괄 변경
@Modifying(clearAutomatically = true)
@Transactional
@Query("UPDATE LoanRecord lr SET lr.status = 'OVERDUE' " +
       "WHERE lr.dueDate < :today AND lr.status = 'ACTIVE'")
int markOverdueLoans(@Param("today") LocalDate today);
```

### 📌 @Query vs 메서드 이름 쿼리 선택 기준

| 상황 | 선택 |
|---|---|
| 단순 조건 1~2개, 조인 없음 | 메서드 이름 쿼리 |
| 조건 3개 이상 | @Query |
| JOIN 포함 | @Query |
| UPDATE / DELETE | @Query + @Modifying |
| 동적 조건 | QueryDSL |
| DB 전용 함수 필요 | @Query(nativeQuery=true) |

---

##  4. 페이징과 정렬

---

### 📌 Pageable과 PageRequest

```java
Pageable pageable = PageRequest.of(0, 10);  // 페이지 번호는 0부터 시작

Pageable pageable = PageRequest.of(0, 10, Sort.by("publishedDate").descending());

Pageable pageable = PageRequest.of(0, 10,
    Sort.by(Sort.Order.desc("publishedDate"), Sort.Order.asc("title"))
);
```

> 💡 페이지 번호는 **0부터** 시작한다. 클라이언트에서 1 기반으로 받아서 `-1`해야 하는 경우가 많다.

### 📌 Page — 전체 건수 포함

`Page` 객체가 제공하는 정보:

```java
page.getContent();           // 현재 페이지 데이터 List<Book>
page.getTotalElements();     // 전체 데이터 건수 (COUNT 쿼리 결과)
page.getTotalPages();        // 전체 페이지 수
page.getNumber();            // 현재 페이지 번호 (0부터)
page.getSize();              // 페이지 크기
page.getNumberOfElements();  // 현재 페이지에 있는 데이터 수
page.hasNext();              // 다음 페이지 존재 여부
page.hasPrevious();          // 이전 페이지 존재 여부
page.isFirst();
page.isLast();
```

`Page`는 내부에서 데이터 조회 쿼리와 COUNT 쿼리 2번이 실행된다.

```java
// map()으로 타입 변환 — Page<Book> → Page<BookDto>
Page<BookDto> result = bookRepository.findAll(pageable)
    .map(book -> new BookDto(book.getTitle(), book.getPrice()));
```

### 📌 Slice — COUNT 없는 경량 페이징

| 구분 | Page | Slice |
|---|---|---|
| COUNT 쿼리 | 실행 | 실행 안 함 |
| 전체 건수 | 알 수 있음 | 알 수 없음 |
| hasNext() | 지원 | 지원 |
| 적합한 UI | 페이지 네비게이션 | 무한 스크롤, 더보기 |

Slice는 내부적으로 `size + 1`개를 조회해서 다음 데이터가 있는지 확인한다. COUNT 쿼리 없이 `hasNext()`를 구현하는 방식이다.

### 📌 countQuery 분리 — JOIN 포함 시 최적화

JOIN이 포함된 `@Query`에 `Pageable`을 적용하면 자동 COUNT 쿼리에 불필요한 JOIN이 포함된다.

```java
@Query(
    value = """
            SELECT b FROM Book b
            JOIN FETCH b.author a
            WHERE a.name = :authorName
            """,
    countQuery = """
            SELECT COUNT(b) FROM Book b
            JOIN b.author a
            WHERE a.name = :authorName
            """
)
Page<Book> findByAuthorName(@Param("authorName") String authorName, Pageable pageable);
```

### 📌 동적 정렬

```java
List<Book> findByCategory(String category, Sort sort);

List<Book> books = bookRepository.findByCategory("IT",
    Sort.by(Sort.Order.desc("publishedDate"), Sort.Order.asc("price"))
);
```

외부 입력값으로 정렬 필드를 받을 때는 화이트리스트로 검증해서 SQL injection을 방지한다.

```java
private static final Set<String> ALLOWED_SORT_FIELDS = Set.of(
    "title", "price", "publishedDate", "createdAt"
);

String safeSortBy = ALLOWED_SORT_FIELDS.contains(sortBy) ? sortBy : "createdAt";
```

### 📌 페이징 성능 최적화 팁

오프셋 페이징은 뒤 페이지로 갈수록 느려진다. `LIMIT 20 OFFSET 20000`이면 DB는 20001개를 읽고 앞 20000개를 버린다. 대량 데이터에서는 커서 기반 페이징이 대안이다.

```java
@Query("SELECT b FROM Book b WHERE b.id < :lastId ORDER BY b.id DESC")
List<Book> findNextPage(@Param("lastId") Long lastId, Pageable pageable);
```

페이징 조회에서 컬렉션 fetch join + 페이징을 함께 쓰면 Hibernate가 In Memory 페이징(전체 조회 후 메모리에서 페이징)을 수행한다. `@BatchSize` 또는 `default_batch_fetch_size` 사용으로 해결한다.

---

##  5. Projection — 필요한 필드만 조회

---

Projection은 필요한 필드만 선택적으로 조회해서 데이터 전송량과 메모리 사용을 줄이는 기법이다.

| 방식 | 특징 | 권장 상황 |
|---|---|---|
| 인터페이스 기반 | 프록시 객체 생성, SpEL 지원 | 빠른 선언, 간단한 가공 |
| DTO(클래스) 기반 | 실제 객체 생성, 명시적 | 일반적인 DTO 변환 (권장) |
| 동적 Projection | 런타임에 타입 결정 | 다양한 반환 타입이 필요한 경우 |
| @QueryProjection | 컴파일 타임 타입 안전 | QueryDSL과 연동 시 |

### 📌 인터페이스 기반 Projection

```java
public interface BookSummary {
    String getTitle();
    int getPrice();
}

List<BookSummary> findByCategory(String category);
```

실행 쿼리: `SELECT b.title, b.price FROM book b WHERE b.category = 'IT';`

중첩 Projection으로 연관 엔티티 필드도 접근할 수 있다.

```java
public interface BookWithAuthor {
    String getTitle();
    int getPrice();
    AuthorInfo getAuthor();

    interface AuthorInfo {
        String getName();
        String getEmail();
    }
}
```

`@Value` 어노테이션으로 SpEL 표현식을 사용할 수 있지만, SpEL이 있으면 최적화 SELECT가 동작하지 않고 전체 엔티티를 로드한다.

### 📌 DTO 기반 Projection — 권장

```java
// record 사용 권장
public record BookSummaryDto(String title, int price, String authorName) {}

@Query("""
    SELECT new com.example.dto.BookSummaryDto(b.title, b.price, a.name)
    FROM Book b
    JOIN b.author a
    WHERE b.category = :category
    """)
List<BookSummaryDto> findSummaryByCategory(@Param("category") String category);
```

인터페이스 기반과 달리 실제 객체를 직접 생성하므로 프록시 오버헤드가 없다. new 표현식에 들어가는 생성자 파라미터 순서와 DTO 생성자 파라미터 순서가 반드시 일치해야 한다.

### 📌 동적 Projection

```java
<T> List<T> findByCategory(String category, Class<T> type);

List<BookSummary> summaries = bookRepository.findByCategory("IT", BookSummary.class);
List<Book> books = bookRepository.findByCategory("IT", Book.class);
```

### 📌 @QueryProjection — QueryDSL과 통합 시 타입 안전 Projection

```java
public class BookSummaryDto {
    @QueryProjection
    public BookSummaryDto(String title, int price, String authorName) {
        this.title = title;
        this.price = price;
        this.authorName = authorName;
    }
}

// QueryDSL에서 사용
List<BookSummaryDto> result = queryFactory
    .select(new QBookSummaryDto(book.title, book.price, author.name))
    .from(book)
    .join(book.author, author)
    .where(book.category.eq("IT"))
    .fetch();
```

---

##  6. 커스텀 Repository — QueryDSL 연동을 위한 확장 패턴

---

`JpaRepository`의 메서드 이름 쿼리와 `@Query`로 해결할 수 없는 경우 — 동적 조건이 많거나, QueryDSL 같은 외부 라이브러리를 써야 하거나, 복잡한 집계 쿼리가 필요한 경우 — 커스텀 Repository 패턴을 사용한다.

### 📌 전체 구조

```
BookRepository                    ← 개발자가 주입받아 사용하는 최종 인터페이스
├── extends JpaRepository         ← 기본 CRUD + 페이징
└── extends BookRepositoryCustom  ← 커스텀 메서드 선언 (인터페이스)
                                        ↑ implements
                                  BookRepositoryImpl  ← 실제 구현체 (Impl 명명 규칙)
```

Spring Data JPA가 `BookRepository`의 Bean을 만들 때, `BookRepositoryImpl`을 찾아서 자동으로 결합한다.

### 📌 Step 1 — 커스텀 인터페이스 선언

```java
public interface BookRepositoryCustom {
    List<Book> searchBooks(String keyword, String category, Integer minPrice, Integer maxPrice);
    Page<Book> searchBooksPaged(BookSearchCondition condition, Pageable pageable);
    Map<String, Long> countByCategory();
}
```

### 📌 Step 2 — 최종 Repository에 상속 추가

```java
public interface BookRepository
        extends JpaRepository<Book, Long>, BookRepositoryCustom {

    List<Book> findByAuthor_Name(String authorName);

    @Query("SELECT b FROM Book b WHERE b.isbn = :isbn AND b.deletedAt IS NULL")
    Optional<Book> findByIsbnActive(@Param("isbn") String isbn);
}
```

### 📌 Step 3 — Impl 구현체 작성

명명 규칙: 최종 Repository 인터페이스명 + `"Impl"`. Spring Data JPA가 이 명명 규칙으로 자동 탐지하고 결합한다. `@Repository`를 붙이지 않아도 자동으로 Bean 등록된다.

```java
@RequiredArgsConstructor
public class BookRepositoryImpl implements BookRepositoryCustom {

    private final EntityManager em;

    @Override
    public List<Book> searchBooks(
            String keyword, String category, Integer minPrice, Integer maxPrice) {

        StringBuilder jpql = new StringBuilder(
            "SELECT b FROM Book b WHERE b.deletedAt IS NULL"
        );

        if (keyword != null && !keyword.isBlank()) jpql.append(" AND b.title LIKE :keyword");
        if (category != null)                       jpql.append(" AND b.category = :category");
        if (minPrice != null)                       jpql.append(" AND b.price >= :minPrice");
        if (maxPrice != null)                       jpql.append(" AND b.price <= :maxPrice");
        jpql.append(" ORDER BY b.publishedDate DESC");

        TypedQuery<Book> query = em.createQuery(jpql.toString(), Book.class);

        if (keyword != null && !keyword.isBlank()) query.setParameter("keyword", "%" + keyword + "%");
        if (category != null)                       query.setParameter("category", category);
        if (minPrice != null)                       query.setParameter("minPrice", minPrice);
        if (maxPrice != null)                       query.setParameter("maxPrice", maxPrice);

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

> 💡 `StringBuilder`로 JPQL을 조합하는 방식은 조건이 많아질수록 코드가 복잡해진다. 실무에서는 이 패턴을 QueryDSL로 대체한다.

### 📌 QueryDSL 연동을 위한 Impl 뼈대

```java
@RequiredArgsConstructor
public class BookRepositoryImpl implements BookRepositoryCustom {

    private final JPAQueryFactory queryFactory;

    QBook book = QBook.book;
    QAuthor author = QAuthor.author;

    @Override
    public List<Book> searchBooks(
            String keyword, String category, Integer minPrice, Integer maxPrice) {

        return queryFactory
            .selectFrom(book)
            .leftJoin(book.author, author).fetchJoin()
            .where(
                keywordContains(keyword),
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
        return (keyword != null && !keyword.isBlank()) ? book.title.contains(keyword) : null;
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

`BooleanExpression`이 `null`을 반환하면 QueryDSL이 해당 조건을 자동으로 무시한다. StringBuilder로 조합하는 것보다 훨씬 깔끔하다.

### 📌 JPAQueryFactory Bean 등록

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

### 📌 서비스에서의 사용

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
}
```

---

## 참고 자료

- 공식문서 - Spring Data JPA: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/>
- 공식문서 - Spring Data JPA Query Methods: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#jpa.query-methods>
- 공식문서 - Spring Data JPA @Query: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#jpa.query-methods.at-query>
- 공식문서 - Spring Data JPA Modifying Queries: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#jpa.modifying-queries>
- 공식문서 - Spring Data JPA Paging and Sorting: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#repositories.special-parameters>
- 공식문서 - Spring Data JPA Projections: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#projections>
- 공식문서 - Spring Data JPA Custom Repository: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#repositories.custom-implementations>
- 공식문서 - SimpleJpaRepository 소스: <https://github.com/spring-projects/spring-data-jpa/blob/main/spring-data-jpa/src/main/java/org/springframework/data/jpa/repository/support/SimpleJpaRepository.java>
