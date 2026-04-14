---
title: "페이징과 정렬 — Page, Slice, Sort 완전 정복"
date: 2026-04-14 09:30:00 +0900
categories: [JPA, 리포지토리]
tags: [JPA, 리포지토리, Pageable, Page, Slice, Sort, 페이징, SpringDataJPA]
order: 4
---

## 1. 개요

---

목록 조회에서 전체 데이터를 한 번에 가져오면 메모리가 터진다. 페이징은 이를 조각 단위로 잘라서 가져오는 방식이다. Spring Data JPA는 `Pageable`, `Page`, `Slice` 등의 추상화로 페이징 처리를 단순하게 만들어준다.

이 글에서는 `PageRequest` 생성 방법, `Page`와 `Slice`의 차이, COUNT 쿼리 분리 최적화, 동적 정렬까지 다룬다.

| 주제 | 내용 |
|---|---|
| Pageable / PageRequest | 페이지 번호, 크기, 정렬 설정 |
| Page vs Slice | COUNT 쿼리 유무, 무한 스크롤 vs 페이지 네비게이션 |
| countQuery 분리 | JOIN 포함 시 COUNT 쿼리 최적화 |
| 동적 정렬 | Sort 파라미터로 런타임 정렬 변경 |

---

## 2. Pageable과 PageRequest

---

### 📌 PageRequest 생성

```java
// PageRequest.of(페이지 번호, 페이지 크기) — 정렬 없음
Pageable pageable = PageRequest.of(0, 10);

// PageRequest.of(페이지 번호, 페이지 크기, Sort)
Pageable pageable = PageRequest.of(0, 10, Sort.by("publishedDate").descending());

// 복합 정렬
Pageable pageable = PageRequest.of(0, 10,
    Sort.by(Sort.Order.desc("publishedDate"), Sort.Order.asc("title"))
);
```

> 💡 페이지 번호는 **0부터** 시작한다. 클라이언트에서 1 기반으로 받아서 `-1`해야 하는 경우가 많다.

```java
// 컨트롤러에서의 일반적인 패턴
@GetMapping("/books")
public Page<BookDto> getBooks(
    @RequestParam(defaultValue = "0") int page,
    @RequestParam(defaultValue = "20") int size,
    @RequestParam(defaultValue = "publishedDate") String sortBy,
    @RequestParam(defaultValue = "desc") String direction
) {
    Sort.Direction dir = Sort.Direction.fromString(direction);
    Pageable pageable = PageRequest.of(page, size, Sort.by(dir, sortBy));
    return bookRepository.findAll(pageable).map(BookDto::from);
}
```

---

## 3. Page — 전체 건수 포함

---

### 📌 Page 사용

```java
Page<Book> page = bookRepository.findAll(pageable);
```

`Page` 객체가 제공하는 정보:

```java
page.getContent();           // 현재 페이지 데이터 List<Book>
page.getTotalElements();     // 전체 데이터 건수 (COUNT 쿼리 결과)
page.getTotalPages();        // 전체 페이지 수 (Math.ceil(totalElements / pageSize))
page.getNumber();            // 현재 페이지 번호 (0부터)
page.getSize();              // 페이지 크기
page.getNumberOfElements();  // 현재 페이지에 있는 데이터 수
page.hasNext();              // 다음 페이지 존재 여부
page.hasPrevious();          // 이전 페이지 존재 여부
page.isFirst();              // 첫 번째 페이지 여부
page.isLast();               // 마지막 페이지 여부
page.nextPageable();         // 다음 페이지의 Pageable
page.previousPageable();     // 이전 페이지의 Pageable
```

### 📌 Page 내부에서 실행되는 쿼리

```sql
-- 1. 데이터 조회 쿼리
SELECT b.*
FROM book b
WHERE b.category = 'IT'
ORDER BY b.published_date DESC
LIMIT 10 OFFSET 0;

-- 2. COUNT 쿼리 (전체 건수 파악)
SELECT COUNT(b.id)
FROM book b
WHERE b.category = 'IT';
```

쿼리가 2번 나간다. COUNT 쿼리가 비용이 클 수 있어서, JOIN이 포함된 경우 최적화가 필요하다.

### 📌 Page를 DTO로 변환

```java
// map()으로 타입 변환 — Page<Book> → Page<BookDto>
Page<BookDto> result = bookRepository.findAll(pageable)
    .map(book -> new BookDto(book.getTitle(), book.getPrice()));
```

---

## 4. Slice — COUNT 없는 경량 페이징

---

### 📌 Page vs Slice 비교

| 구분 | Page | Slice |
|---|---|---|
| COUNT 쿼리 | 실행 | 실행 안 함 |
| 전체 건수 | 알 수 있음 | 알 수 없음 |
| 전체 페이지 수 | 알 수 있음 | 알 수 없음 |
| hasNext() | 지원 | 지원 |
| 다음 데이터 존재 여부 | 지원 | 지원 |
| 적합한 UI | 페이지 네비게이션 (1, 2, 3...) | 무한 스크롤, 더보기 버튼 |
| 성능 | COUNT 비용 있음 | 상대적으로 빠름 |

### 📌 Slice 사용

```java
// 반환 타입을 Slice로 선언
Slice<Book> findByCategory(String category, Pageable pageable);

// 사용
Slice<Book> slice = bookRepository.findByCategory("IT", PageRequest.of(0, 10));
slice.getContent();     // 현재 페이지 데이터
slice.hasNext();        // 다음 데이터가 있는지 (size+1 로 확인하는 방식)
slice.isFirst();
slice.isLast();
```

Slice는 내부적으로 `size + 1`개를 조회해서 다음 데이터가 있는지 확인한다. COUNT 쿼리 없이 `hasNext()`를 구현하는 방식이다.

```sql
-- Slice의 실제 쿼리 (size=10이면 11개를 조회)
SELECT b.* FROM book b WHERE b.category = 'IT' LIMIT 11 OFFSET 0;
-- 11개가 나오면 hasNext = true, 10개 이하면 hasNext = false
```

---

## 5. countQuery 분리 — JOIN 포함 시 최적화

---

### 📌 문제 상황

JOIN이 포함된 `@Query`에 `Pageable`을 적용하면, Spring Data JPA가 자동으로 COUNT 쿼리를 생성하는데 이 때 불필요한 JOIN이 그대로 포함된다.

```java
@Query("""
    SELECT b FROM Book b
    JOIN FETCH b.author a
    JOIN b.loans l
    WHERE a.name = :authorName
    """)
Page<Book> findByAuthorName(@Param("authorName") String authorName, Pageable pageable);
```

자동 생성된 COUNT 쿼리:
```sql
-- JOIN이 그대로 포함되어 불필요하게 무거움
SELECT COUNT(b.id)
FROM book b
INNER JOIN author a ON b.author_id = a.id
INNER JOIN loan_record l ON l.book_id = b.id
WHERE a.name = 'kim';
```

### 📌 countQuery 분리로 해결

```java
/**
 * countQuery를 직접 작성해서 COUNT에 불필요한 JOIN을 제거한다.
 * COUNT에 영향을 주지 않는 JOIN은 제외해서 쿼리를 단순화한다.
 */
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

---

## 6. 동적 정렬

---

### 📌 Sort 파라미터

```java
// 리포지토리에서 Sort 파라미터 선언
List<Book> findByCategory(String category, Sort sort);

// 호출 — 런타임에 정렬 방식 결정
List<Book> books = bookRepository.findByCategory("IT",
    Sort.by(Sort.Order.desc("publishedDate"), Sort.Order.asc("price"))
);
```

### 📌 JpaSort — 함수 기반 정렬

```java
// 일반 Sort는 보안상 외부 입력값을 그대로 쓸 수 없음
// JpaSort는 JPQL 함수를 포함한 정렬 표현 가능
Sort sort = JpaSort.unsafe("LENGTH(b.title)");   // 제목 길이로 정렬

// 주의: unsafe는 SQL injection 가능성이 있으므로 외부 입력값에 직접 사용 금지
```

### 📌 외부 입력값으로 정렬 필드를 받을 때의 안전 처리

```java
// 허용된 정렬 필드를 화이트리스트로 관리
private static final Set<String> ALLOWED_SORT_FIELDS = Set.of(
    "title", "price", "publishedDate", "createdAt"
);

public Page<Book> search(String category, String sortBy, String direction, int page) {
    // 허용 목록에 없으면 기본값 사용
    String safeSortBy = ALLOWED_SORT_FIELDS.contains(sortBy) ? sortBy : "createdAt";
    Sort.Direction dir = "asc".equalsIgnoreCase(direction)
        ? Sort.Direction.ASC : Sort.Direction.DESC;

    Pageable pageable = PageRequest.of(page, 20, Sort.by(dir, safeSortBy));
    return bookRepository.findByCategory(category, pageable);
}
```

---

## 7. 페이징 성능 최적화 팁

---

### 📌 오프셋 페이징의 한계 — 깊은 페이지 문제

LIMIT/OFFSET 방식은 뒤 페이지로 갈수록 느려진다.

```sql
-- page=1000, size=20이면 DB는 20001개를 읽고 앞 20000개를 버린다
SELECT * FROM book ORDER BY created_at DESC LIMIT 20 OFFSET 20000;
```

대량 데이터에서는 커서 기반 페이징(Keyset Pagination)이 대안이다.

```java
// 커서 기반 — 마지막으로 받은 id보다 작은 것을 조회
@Query("SELECT b FROM Book b WHERE b.id < :lastId ORDER BY b.id DESC")
List<Book> findNextPage(@Param("lastId") Long lastId, Pageable pageable);
```

### 📌 N+1 주의

페이징 조회에서 연관 엔티티 접근 시 N+1이 발생할 수 있다.

```java
// fetch join + 페이징을 컬렉션에 쓰면 하이버네이트 경고 발생
// HHH90003004: firstResult/maxResults specified with collection fetch
@Query("SELECT b FROM Book b JOIN FETCH b.tags WHERE b.category = :category")
Page<Book> findWithTags(@Param("category") String category, Pageable pageable);
// → IN Memory 페이징 발생 (전체 조회 후 메모리에서 페이징) — 위험

// 올바른 해결책: @BatchSize 또는 default_batch_fetch_size 사용 (Phase 6에서 다룸)
```

---

## 8. 정리

---

- `PageRequest.of(page, size, sort)`로 페이징 옵션을 만든다. 페이지 번호는 0부터 시작한다
- `Page`는 COUNT 쿼리를 포함해 전체 건수와 페이지 수를 제공한다. 게시판 네비게이션에 적합하다
- `Slice`는 COUNT 없이 `hasNext()`만 제공한다. 무한 스크롤, 더보기에 적합하고 상대적으로 빠르다
- JOIN이 있는 경우 `countQuery`를 직접 지정해서 COUNT 쿼리를 단순화해야 한다
- 외부 입력값 기반 정렬은 화이트리스트로 검증해서 SQL injection을 방지한다
- 깊은 페이지 조회에는 커서 기반 페이징이 오프셋 방식보다 성능이 좋다

---

## 참고

- 출처: Claude Desktop 대화 (2026-04-14)
- [Spring Data JPA — Paging and Sorting](https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#repositories.special-parameters)
