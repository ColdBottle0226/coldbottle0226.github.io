---
title: "Projection — 필요한 필드만 조회하는 방법"
date: 2026-04-14 09:40:00 +0900
categories: []
tags: [JPA, 리포지토리, Projection, DTO, 인터페이스Projection, QueryProjection, SpringDataJPA]
order: 5
---

## 1. 개요

---

엔티티 전체를 조회하면 필요 없는 컬럼까지 DB에서 읽어온다. 목록 조회에서 제목과 가격만 필요한데 `SELECT *`를 날리는 셈이다. Projection은 필요한 필드만 선택적으로 조회해서 데이터 전송량과 메모리 사용을 줄이는 기법이다.

Spring Data JPA는 인터페이스 기반, 클래스(DTO) 기반, 동적 Projection 세 가지 방식을 지원한다.

| 방식 | 특징 | 권장 상황 |
|---|---|---|
| 인터페이스 기반 | 프록시 객체 생성, SpEL 지원 | 빠른 선언, 간단한 가공 |
| DTO(클래스) 기반 | 실제 객체 생성, 명시적 | 일반적인 DTO 변환 |
| 동적 Projection | 런타임에 타입 결정 | 다양한 반환 타입이 필요한 경우 |
| @QueryProjection | 컴파일 타임 타입 안전 | QueryDSL과 연동 시 |

---

## 2. 인터페이스 기반 Projection

---

### 📌 기본 사용

```java
/**
 * 인터페이스에 getter 메서드만 선언하면 Spring이 프록시를 만들어 처리한다.
 * 메서드명이 엔티티 필드명과 일치해야 한다 (get + 필드명 대문자 시작)
 */
public interface BookSummary {
    String getTitle();
    int getPrice();
}

// 리포지토리에 선언
List<BookSummary> findByCategory(String category);
```

실행 쿼리:
```sql
-- 선언한 필드만 SELECT
SELECT b.title, b.price FROM book b WHERE b.category = 'IT';
```

### 📌 연관 엔티티 필드 접근

```java
public interface BookWithAuthor {
    String getTitle();
    int getPrice();

    /**
     * 중첩 Projection: Author 엔티티의 필드도 접근 가능
     * 단, 실제로는 SELECT *로 조회 후 매핑하므로 성능 이점이 없을 수 있다
     */
    AuthorInfo getAuthor();

    interface AuthorInfo {
        String getName();
        String getEmail();
    }
}
```

```java
List<BookWithAuthor> findByCategory(String category);

// 사용
for (BookWithAuthor book : books) {
    System.out.println(book.getTitle());
    System.out.println(book.getAuthor().getName()); // 중첩 접근
}
```

### 📌 SpEL 표현식으로 가공

```java
public interface BookDisplay {
    String getTitle();
    int getPrice();

    /**
     * @Value 어노테이션으로 SpEL 표현식 사용 가능
     * target은 엔티티 객체를 가리킨다
     * 단, SpEL이 있으면 최적화 SELECT가 동작하지 않고 전체 엔티티를 로드한다
     */
    @Value("#{target.title + ' (' + target.price + '원)'}")
    String getTitleWithPrice();

    @Value("#{target.price > 20000 ? '고가' : '일반'}")
    String getPriceGrade();
}
```

> 💡 SpEL(`@Value`)이 포함되면 Spring이 필드를 추려서 SELECT할 수 없다. 전체 엔티티를 로드하고 SpEL을 적용하는 방식으로 동작한다. SpEL이 필요하면 DTO 기반 Projection에서 변환 로직을 넣는 게 낫다.

---

## 3. DTO 기반 Projection — 권장

---

### 📌 @Query + new 키워드

```java
// DTO 클래스 정의 (record 사용 권장)
public record BookSummaryDto(String title, int price, String authorName) {}

// @Query에서 new 키워드로 직접 생성자 호출
@Query("""
    SELECT new com.example.dto.BookSummaryDto(b.title, b.price, a.name)
    FROM Book b
    JOIN b.author a
    WHERE b.category = :category
    """)
List<BookSummaryDto> findSummaryByCategory(@Param("category") String category);
```

실행 쿼리:
```sql
SELECT b.title, b.price, a.name
FROM book b
INNER JOIN author a ON b.author_id = a.id
WHERE b.category = 'IT';
```

인터페이스 기반과 달리 실제 객체를 직접 생성하므로 프록시 오버헤드가 없다.

### 📌 생성자 규칙

```java
/**
 * new 표현식에 들어가는 생성자 파라미터 순서와
 * DTO 생성자 파라미터 순서가 반드시 일치해야 한다.
 * record는 선언 순서대로 생성자가 자동 생성되므로 편리하다.
 */
public class BookSummaryDto {
    private final String title;
    private final int price;
    private final String authorName;

    // 이 생성자가 JPQL new 표현과 매핑됨
    public BookSummaryDto(String title, int price, String authorName) {
        this.title = title;
        this.price = price;
        this.authorName = authorName;
    }
}
```

### 📌 인터페이스 기반 vs DTO 기반 비교

| 항목 | 인터페이스 기반 | DTO 기반 |
|---|---|---|
| 선언 방식 | 인터페이스 getter | 클래스 생성자 |
| 생성 객체 | 프록시 | 실제 DTO 인스턴스 |
| 중첩 접근 | 지원 (AuthorInfo 등) | @Query로 직접 처리 |
| SpEL 가공 | 지원 | 생성자 또는 팩터리 메서드에서 처리 |
| 컴파일 타임 검증 | 부분적 | @QueryProjection으로 완전 지원 |
| 일반 권장도 | 빠른 선언에 유리 | 실무 일반 권장 |

---

## 4. 동적 Projection

---

### 📌 제네릭 반환 타입

```java
/**
 * 반환 타입을 제네릭으로 선언하면 호출 시 타입을 결정할 수 있다.
 * 하나의 메서드로 여러 Projection 타입을 처리한다.
 */
<T> List<T> findByCategory(String category, Class<T> type);

// 사용
List<BookSummary> summaries = bookRepository.findByCategory("IT", BookSummary.class);
List<Book> books = bookRepository.findByCategory("IT", Book.class);
List<BookSummaryDto> dtos = bookRepository.findByCategory("IT", BookSummaryDto.class);
```

---

## 5. @QueryProjection — QueryDSL과 통합 시 타입 안전 Projection

---

QueryDSL을 사용할 경우 `@QueryProjection`으로 컴파일 타임 타입 안전성을 확보한다. Phase 9에서 상세히 다루지만, 개념만 미리 살펴본다.

```java
/**
 * DTO 생성자에 @QueryProjection을 붙이면
 * Q클래스 생성 시 QBookSummaryDto가 함께 만들어진다.
 */
public class BookSummaryDto {

    @QueryProjection
    public BookSummaryDto(String title, int price, String authorName) {
        this.title = title;
        this.price = price;
        this.authorName = authorName;
    }
}

// QueryDSL에서 사용 (Phase 9에서 상세 설명)
List<BookSummaryDto> result = queryFactory
    .select(new QBookSummaryDto(book.title, book.price, author.name))
    .from(book)
    .join(book.author, author)
    .where(book.category.eq("IT"))
    .fetch();
```

---

## 6. 실전 패턴 — 엔티티 → DTO 변환

---

### 📌 서비스 계층에서 변환

```java
// 서비스에서 엔티티를 DTO로 변환하는 일반 패턴
@Service
@RequiredArgsConstructor
public class BookService {

    private final BookRepository bookRepository;

    public List<BookSummaryDto> getBookSummaries(String category) {
        // 방법 1: @Query + new 표현 (DB 레벨 변환)
        return bookRepository.findSummaryByCategory(category);

        // 방법 2: 전체 엔티티 조회 후 스트림 변환 (작은 데이터)
        // return bookRepository.findByCategory(category)
        //     .stream()
        //     .map(b -> new BookSummaryDto(b.getTitle(), b.getPrice(), b.getAuthor().getName()))
        //     .toList();
    }
}
```

방법 1은 SELECT할 컬럼을 줄여 성능이 낫고, 방법 2는 유연성이 높지만 불필요한 컬럼까지 읽는다. 대량 데이터에서는 방법 1을 선택한다.

---

## 7. 정리

---

- Projection은 필요한 컬럼만 선택 조회해서 성능을 개선하는 기법이다
- 인터페이스 기반은 프록시를 만들어 빠르게 선언하고, SpEL로 가공이 가능하다. 단, SpEL이 있으면 전체 로드된다
- DTO 기반(`new` 생성자)은 실제 객체를 직접 생성하며, 실무 일반 권장 방식이다
- 동적 Projection은 `Class<T>` 파라미터로 런타임에 반환 타입을 결정한다
- QueryDSL과 함께 쓸 때는 `@QueryProjection`으로 컴파일 타임 타입 안전성을 확보한다

---

## 참고

- 출처: Claude Desktop 대화 (2026-04-14)
- [Spring Data JPA — Projections](https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#projections)
