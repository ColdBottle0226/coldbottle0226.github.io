---
title: "QueryDSL"
date: 2026-04-24 12:30:00 +0900
categories: [JPA, 심화 개념]
tags: [JPA, QueryDSL, JPAQueryFactory, Q클래스, BooleanBuilder, BooleanExpression, fetchJoin, Projections, QueryProjection, 동적쿼리, 커스텀Repository]
---

##  1. QueryDSL 설정

---

### 📌 의존성 및 Q클래스 생성 설정 (Spring Boot 3.x / Gradle Kotlin DSL)

```kotlin
// build.gradle.kts
plugins {
    kotlin("jvm") version "..."
    kotlin("plugin.spring") version "..."
    id("com.ewerk.gradle.plugins.querydsl") version "1.0.10"
}

dependencies {
    implementation("com.querydsl:querydsl-jpa:5.0.0:jakarta")
    annotationProcessor("com.querydsl:querydsl-apt:5.0.0:jakarta")
    annotationProcessor("jakarta.annotation:jakarta.annotation-api")
    annotationProcessor("jakarta.persistence:jakarta.persistence-api")
}

// Q클래스 생성 경로 설정
val generated = "src/main/generated"

tasks.withType<JavaCompile> {
    options.generatedSourceOutputDirectory.set(file(generated))
}

sourceSets {
    main {
        java.srcDirs(generated)
    }
}

tasks.named("clean") {
    doLast {
        file(generated).deleteRecursively()
    }
}
```

> 💡 Spring Boot 3.x는 `jakarta` 분류자를 사용해야 한다. `querydsl-jpa:5.0.0:jakarta`에서 `:jakarta`가 핵심이다. `javax` 분류자를 사용하면 `@Entity`를 인식하지 못한다.

### 📌 Q클래스란

`@Entity`가 붙은 클래스에 대해 APT(Annotation Processing Tool)가 컴파일 시점에 `Q접두사`가 붙은 클래스를 자동 생성한다.

```java
// 원본 엔티티
@Entity
public class Book { ... }

// 자동 생성되는 Q클래스
public class QBook extends EntityPathBase<Book> {
    public static final QBook book = new QBook("book");
    public final StringPath title = createString("title");
    public final NumberPath<Integer> price = createNumber("price", Integer.class);
    public final QAuthor author = ...;
    // ...
}
```

Q클래스를 통해 타입 안전한 쿼리 작성이 가능해진다.

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

---

##  2. 기본 쿼리 작성

---

```java
@Repository
@RequiredArgsConstructor
public class BookQueryRepository {

    private final JPAQueryFactory queryFactory;

    QBook book = QBook.book;
    QAuthor author = QAuthor.author;

    // SELECT * FROM book WHERE category = 'IT'
    public List<Book> findByCategory(String category) {
        return queryFactory
            .selectFrom(book)
            .where(book.category.eq(category))
            .fetch();
    }

    // SELECT * FROM book ORDER BY published_date DESC LIMIT 10 OFFSET 0
    public List<Book> findLatest(int page, int size) {
        return queryFactory
            .selectFrom(book)
            .orderBy(book.publishedDate.desc())
            .offset((long) page * size)
            .limit(size)
            .fetch();
    }
}
```

### 📌 결과 조회 메서드

```java
queryFactory.selectFrom(book).fetch();           // List 반환. 없으면 빈 리스트
queryFactory.selectFrom(book).fetchOne();        // 단건. 없으면 null, 2건+ 이면 예외
queryFactory.selectFrom(book).fetchFirst();      // LIMIT 1로 첫 번째 결과
queryFactory.selectFrom(book).fetchCount();      // COUNT 쿼리 (Deprecated in 5.x)
```

> 💡 `fetchResults()`와 `fetchCount()`는 Hibernate 6.x에서 Deprecated됐다. COUNT 쿼리는 별도로 작성해야 한다.

### 📌 WHERE 조건 표현

```java
// 동등 비교
book.title.eq("스프링 부트")        // title = '스프링 부트'
book.title.ne("스프링 부트")        // title != '스프링 부트'
book.price.gt(10000)               // price > 10000
book.price.goe(10000)              // price >= 10000
book.price.lt(30000)               // price < 30000
book.price.loe(30000)              // price <= 30000
book.price.between(10000, 30000)   // price BETWEEN 10000 AND 30000

// 문자열
book.title.contains("스프링")      // title LIKE '%스프링%'
book.title.startsWith("스프링")    // title LIKE '스프링%'
book.title.endsWith("입문")        // title LIKE '%입문'
book.title.like("%스프링%")        // title LIKE '%스프링%'

// NULL 체크
book.deletedAt.isNull()            // deleted_at IS NULL
book.deletedAt.isNotNull()         // deleted_at IS NOT NULL

// IN
book.category.in("IT", "Science")  // category IN ('IT', 'Science')
book.id.notIn(1L, 2L, 3L)          // id NOT IN (1, 2, 3)

// AND / OR
book.category.eq("IT").and(book.price.lt(20000))
book.category.eq("IT").or(book.category.eq("Science"))
```

---

##  3. 동적 쿼리

---

QueryDSL에서 동적 쿼리를 작성하는 방법은 두 가지다.

### 📌 방법 1 — BooleanBuilder

```java
public List<Book> search(String keyword, String category, Integer minPrice, Integer maxPrice) {
    BooleanBuilder builder = new BooleanBuilder();

    if (keyword != null && !keyword.isBlank()) {
        builder.and(book.title.contains(keyword));
    }
    if (category != null) {
        builder.and(book.category.eq(category));
    }
    if (minPrice != null) {
        builder.and(book.price.goe(minPrice));
    }
    if (maxPrice != null) {
        builder.and(book.price.loe(maxPrice));
    }

    return queryFactory
        .selectFrom(book)
        .where(builder)
        .fetch();
}
```

### 📌 방법 2 — BooleanExpression (권장)

`BooleanExpression`을 반환하는 메서드로 조건을 분리한다. null을 반환하면 QueryDSL이 해당 조건을 자동으로 무시한다.

```java
public List<Book> search(String keyword, String category, Integer minPrice, Integer maxPrice) {
    return queryFactory
        .selectFrom(book)
        .where(
            keywordContains(keyword),
            categoryEq(category),
            priceGoe(minPrice),
            priceLoe(maxPrice),
            book.deletedAt.isNull()
        )
        .fetch();
}

private BooleanExpression keywordContains(String keyword) {
    return (keyword != null && !keyword.isBlank())
        ? book.title.contains(keyword)
        : null;  // null이면 조건 무시
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
```

BooleanExpression 방식이 BooleanBuilder보다 나은 이유:
- 각 조건이 독립적인 메서드로 분리되어 재사용 가능
- 코드가 더 선언적이고 읽기 쉬움
- 조건 조합이 `where()` 안에서 명확하게 드러남

### 📌 Null-safe 조건 메서드 분리 패턴

```java
// 조건 메서드를 별도 클래스로 분리 — 여러 Repository에서 재사용
public class BookConditions {

    public static BooleanExpression titleContains(String title) {
        return StringUtils.hasText(title) ? QBook.book.title.contains(title) : null;
    }

    public static BooleanExpression priceRange(Integer min, Integer max) {
        if (min != null && max != null) return QBook.book.price.between(min, max);
        if (min != null) return QBook.book.price.goe(min);
        if (max != null) return QBook.book.price.loe(max);
        return null;
    }

    public static BooleanExpression notDeleted() {
        return QBook.book.deletedAt.isNull();
    }
}
```

---

##  4. 조인과 서브쿼리

---

### 📌 JOIN

```java
// INNER JOIN
queryFactory
    .selectFrom(book)
    .join(book.author, author)
    .where(author.name.eq("김저자"))
    .fetch();

// LEFT JOIN
queryFactory
    .selectFrom(book)
    .leftJoin(book.author, author)
    .fetch();

// FETCH JOIN — 영속성 컨텍스트에 연관 엔티티까지 로딩
queryFactory
    .selectFrom(book)
    .join(book.author, author).fetchJoin()
    .where(book.category.eq("IT"))
    .fetch();

// ON 절 추가
queryFactory
    .selectFrom(book)
    .leftJoin(book.author, author).on(author.name.eq("김저자"))
    .fetch();
```

### 📌 서브쿼리 — JPAExpressions

```java
QBook bookSub = new QBook("bookSub");

// 평균 가격 이상인 도서 조회
queryFactory
    .selectFrom(book)
    .where(book.price.gt(
        JPAExpressions
            .select(bookSub.price.avg())
            .from(bookSub)
    ))
    .fetch();

// 특정 저자의 도서 중 최고가 도서
queryFactory
    .selectFrom(book)
    .where(book.price.eq(
        JPAExpressions
            .select(bookSub.price.max())
            .from(bookSub)
            .where(bookSub.author.name.eq("김저자"))
    ))
    .fetch();
```

> 💡 JPQL과 마찬가지로 FROM 절 서브쿼리는 지원하지 않는다. FROM 절 서브쿼리가 필요하면 Native Query 또는 별도 조회 후 애플리케이션에서 조합하는 방식을 사용한다.

---

##  5. DTO 조회

---

### 📌 Projections.constructor

```java
public record BookSummaryDto(String title, int price, String authorName) {}

List<BookSummaryDto> result = queryFactory
    .select(Projections.constructor(BookSummaryDto.class,
        book.title,
        book.price,
        author.name))
    .from(book)
    .join(book.author, author)
    .fetch();
```

생성자 파라미터 순서와 select 순서가 일치해야 한다.

### 📌 Projections.fields

```java
// 필드명으로 매핑 (setter 없이 reflection 사용)
List<BookSummaryDto> result = queryFactory
    .select(Projections.fields(BookSummaryDto.class,
        book.title,
        book.price,
        author.name.as("authorName")))  // 필드명이 다르면 as()로 별칭 지정
    .from(book)
    .join(book.author, author)
    .fetch();
```

### 📌 Projections.bean

```java
// setter 기반 매핑
List<BookSummaryDto> result = queryFactory
    .select(Projections.bean(BookSummaryDto.class,
        book.title,
        book.price,
        author.name.as("authorName")))
    .from(book)
    .join(book.author, author)
    .fetch();
```

### 📌 @QueryProjection (권장)

DTO 생성자에 `@QueryProjection`을 붙이면 APT가 `QBookSummaryDto` 클래스를 생성한다. 가장 타입 안전한 방법이다.

```java
public class BookSummaryDto {

    private String title;
    private int price;
    private String authorName;

    @QueryProjection  // Q클래스 생성
    public BookSummaryDto(String title, int price, String authorName) {
        this.title = title;
        this.price = price;
        this.authorName = authorName;
    }
}

// 사용 — 컴파일 타임에 타입 오류 감지
List<BookSummaryDto> result = queryFactory
    .select(new QBookSummaryDto(
        book.title,
        book.price,
        author.name))
    .from(book)
    .join(book.author, author)
    .fetch();
```

---

##  6. 커스텀 Repository 완성

---

### 📌 Impl 패턴 + JPAQueryFactory 최종 통합

```java
@RequiredArgsConstructor
public class BookRepositoryImpl implements BookRepositoryCustom {

    private final JPAQueryFactory queryFactory;

    QBook book = QBook.book;
    QAuthor author = QAuthor.author;

    @Override
    public Page<BookSummaryDto> searchBooksPaged(
            BookSearchCondition condition, Pageable pageable) {

        List<BookSummaryDto> content = queryFactory
            .select(new QBookSummaryDto(book.title, book.price, author.name))
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

        // fetchResults() Deprecated 대체 — COUNT 쿼리 별도 작성
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

        return new PageImpl<>(content, pageable, total != null ? total : 0);
    }

    private BooleanExpression keywordContains(String keyword) {
        return StringUtils.hasText(keyword) ? book.title.contains(keyword) : null;
    }
    private BooleanExpression categoryEq(String category) {
        return category != null ? book.category.eq(category) : null;
    }
    private BooleanExpression priceGoe(Integer min) {
        return min != null ? book.price.goe(min) : null;
    }
    private BooleanExpression priceLoe(Integer max) {
        return max != null ? book.price.loe(max) : null;
    }
}
```

### 📌 Slice 커서 기반 페이징

```java
public Slice<BookSummaryDto> searchSlice(Long lastId, int size, String category) {
    List<BookSummaryDto> content = queryFactory
        .select(new QBookSummaryDto(book.title, book.price, author.name))
        .from(book)
        .leftJoin(book.author, author)
        .where(
            lastId != null ? book.id.lt(lastId) : null,  // 커서 조건
            categoryEq(category),
            book.deletedAt.isNull()
        )
        .orderBy(book.id.desc())
        .limit(size + 1)  // size + 1로 hasNext 판단
        .fetch();

    boolean hasNext = content.size() > size;
    if (hasNext) content.remove(content.size() - 1);

    return new SliceImpl<>(content, PageRequest.of(0, size), hasNext);
}
```

---

##  7. 정리

---

| 개념 | 핵심 요약 |
|---|---|
| Q클래스 | APT가 @Entity 기반으로 자동 생성. 타입 안전 쿼리의 기반 |
| JPAQueryFactory | QueryDSL 쿼리 실행의 시작점. EntityManager 기반 Bean 등록 |
| BooleanExpression | null 반환 시 조건 자동 무시. 동적 쿼리의 핵심 |
| fetchJoin() | LAZY 연관 엔티티를 한 번에 로딩. N+1 해결 |
| @QueryProjection | DTO 생성자에 붙여 Q클래스 생성. 가장 타입 안전한 Projection |
| COUNT 별도 작성 | fetchResults() Deprecated 대응. 데이터 조회와 COUNT 분리 |
| 커서 기반 Slice | 오프셋 페이징 대안. id 기반 커서로 IN Memory 페이징 방지 |

---

## 참고 자료

- 공식문서 - QueryDSL 5.x: <http://querydsl.com/static/querydsl/5.0.0/reference/html_single/>
- QueryDSL GitHub: <https://github.com/querydsl/querydsl>
- Spring Data JPA + QueryDSL 연동: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#core.extensions.querydsl>
