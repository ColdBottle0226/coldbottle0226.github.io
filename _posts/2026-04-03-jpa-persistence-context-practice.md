---
title: 02. 영속성 컨텍스트 실습 — 도서 대출 시스템
date: 2026-04-03 10:00:00 +0900
categories: [JPA, 실습]
tags: [JPA, 영속성 컨텍스트, 실습, 더티체킹, 1차캐시, 쓰기지연, OSIV, EntityManager]
---

## 📗 1. 실습 도메인 소개

---

이론으로 배운 영속성 컨텍스트 개념을 실제 코드로 확인하는 실습이다. 도메인은 **도서 대출 시스템**으로, `Book` 엔티티 하나로 생명주기 · 1차 캐시 · 쓰기 지연 · 더티 체킹 전체를 단계별로 체험한다.

```
Step 1. Book 엔티티 작성           ← @Entity, @Column, @Enumerated 적용
Step 2. 생명주기 상태 확인          ← persist, detach, merge, contains
Step 3. 1차 캐시와 동일성 보장 확인  ← 같은 PK 재조회 시 SQL 미실행
Step 4. 더티 체킹 확인             ← 수정만 해도 UPDATE 자동 실행
Step 5. JPQL 자동 flush 확인      ← JPQL 실행 직전 자동 flush
Step 6. OSIV OFF DTO 변환 패턴    ← Service에서 DTO 변환 후 반환
```

---

## 📗 2. Book 엔티티

---

```java
// book/Book.java
@Entity
@Table(
    name = "book",
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_book_isbn", columnNames = {"isbn"})
    }
)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Book extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "book_id")
    private Long id;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(nullable = false, length = 100)
    private String author;

    @Column(nullable = false, length = 20)
    private String isbn;

    @Enumerated(EnumType.STRING)   // STRING 방식 필수 (ORDINAL 금지)
    @Column(nullable = false, length = 20)
    private BookStatus status;

    @Column(nullable = false)
    private int stock;

    public Book(String title, String author, String isbn, int stock) {
        this.title = title;
        this.author = author;
        this.isbn = isbn;
        this.stock = stock;
        this.status = BookStatus.AVAILABLE;
    }

    // 도메인 메서드 — setter 대신 의미 있는 메서드로 상태 변경
    public void loan() {
        if (this.stock <= 0) throw new IllegalStateException("대출 가능한 재고가 없습니다.");
        this.stock--;
        if (this.stock == 0) this.status = BookStatus.UNAVAILABLE;
    }

    public void returnBook() {
        this.stock++;
        this.status = BookStatus.AVAILABLE;
    }

    public void updateTitle(String title) { this.title = title; }
}
```

```java
// book/BookStatus.java
public enum BookStatus {
    AVAILABLE,    // 대출 가능
    UNAVAILABLE   // 대출 불가 (재고 소진)
}
```

---

## 📗 3. Step 2 — 생명주기 상태 확인

---

`em.contains()`로 현재 엔티티의 영속 상태를 직접 확인한다. `persist()`, `detach()`, `merge()`를 순서대로 호출하면서 상태 변화를 관찰한다.

```java
@SpringBootTest
@Transactional
class PersistenceContextBasicTest {

    @PersistenceContext
    private EntityManager em;

    @Test
    @DisplayName("비영속 → 영속 → 준영속 → merge 상태 전환 확인")
    void entityLifecycleTest() {
        // 1. 비영속
        Book book = new Book("JPA 프로그래밍", "김영한", "978-89-562-3935-0", 5);
        assertThat(em.contains(book)).isFalse();
        System.out.println("[비영속] em.contains: " + em.contains(book)); // false

        // 2. 영속 (IDENTITY 전략 → persist 시 즉시 INSERT, PK 채워짐)
        em.persist(book);
        assertThat(em.contains(book)).isTrue();
        assertThat(book.getId()).isNotNull();
        System.out.println("[영속] em.contains: " + em.contains(book));     // true
        System.out.println("[영속] book.getId: " + book.getId());           // PK 값

        // 3. 준영속 — 수정해도 DB 반영 안 됨
        em.detach(book);
        assertThat(em.contains(book)).isFalse();
        book.updateTitle("수정해도 반영 안 됨");
        em.flush();
        em.clear();
        Book check = em.find(Book.class, book.getId());
        assertThat(check.getTitle()).isEqualTo("JPA 프로그래밍"); // 원래 제목 그대로

        // 4. merge() — 반환값이 영속, 원본은 준영속 그대로
        em.detach(check);
        Book merged = em.merge(check);
        assertThat(em.contains(check)).isFalse();  // 원본은 여전히 준영속
        assertThat(em.contains(merged)).isTrue();  // 반환값이 영속
        System.out.println("[merge 원본] em.contains: " + em.contains(check));  // false
        System.out.println("[merge 반환] em.contains: " + em.contains(merged)); // true
    }
}
```

**확인 포인트**: `merge()`는 파라미터 객체가 아닌 반환값이 영속 상태임을 `em.contains()`로 직접 확인할 수 있다.

---

## 📗 4. Step 3 — 1차 캐시와 동일성 보장

---

같은 PK로 `find()`를 두 번 호출했을 때 SELECT SQL이 한 번만 실행되는지, 두 결과가 같은 인스턴스인지 확인한다.

```java
@Test
@DisplayName("1차 캐시 HIT — 두 번째 find에서 SQL 미실행, 동일 인스턴스 보장")
void firstLevelCacheTest() {
    Book book = new Book("클린 코드", "로버트 마틴", "978-89-7914-190-5", 3);
    em.persist(book);
    em.flush();
    em.clear(); // 1차 캐시 비움

    System.out.println("=== 첫 번째 find — DB SELECT 실행 예상 ===");
    Book b1 = em.find(Book.class, book.getId());
    // 로그: Hibernate: select b1_0.book_id, ... from book b1_0 where b1_0.book_id=?

    System.out.println("=== 두 번째 find — 캐시에서 반환, SQL 없음 예상 ===");
    Book b2 = em.find(Book.class, book.getId());
    // 로그: (SQL 없음)

    assertThat(b1).isSameAs(b2);
    System.out.println("동일 인스턴스(==): " + (b1 == b2)); // true
}
```

로그에서 SELECT SQL이 한 번만 출력되는 것을 확인할 수 있다. `b1 == b2`가 `true`인 것은 JDBC와 달리 매번 새 인스턴스를 만들지 않고 1차 캐시에서 동일 인스턴스를 반환하기 때문이다.

---

## 📗 5. Step 4 — 더티 체킹 확인

---

영속 상태의 엔티티를 수정하면 `em.update()` 없이도 트랜잭션 종료 시 UPDATE SQL이 자동 실행된다.

```java
@Test
@DisplayName("더티 체킹 — loan() 호출만 해도 stock, status UPDATE 자동 실행")
void dirtyCheckingTest() {
    Book book = new Book("JPA 프로그래밍", "김영한", "978-89-562-3935-0", 5);
    em.persist(book);
    em.flush();
    em.clear();

    // 영속 상태로 조회 (스냅샷 저장됨)
    Book found = em.find(Book.class, book.getId());
    System.out.println("조회 직후 stock: " + found.getStock()); // 5

    // 수정 — em.update() 없음
    found.loan(); // stock--, status 변경
    System.out.println("loan() 후 stock: " + found.getStock()); // 4

    System.out.println("=== flush — UPDATE SQL 실행 예상 ===");
    em.flush(); // 스냅샷 비교 → stock, status 변경 감지 → UPDATE 실행

    em.clear();
    Book updated = em.find(Book.class, book.getId());
    assertThat(updated.getStock()).isEqualTo(4);
    System.out.println("DB 재조회 stock: " + updated.getStock()); // 4
}

@Test
@DisplayName("재고 소진 시 status UNAVAILABLE 자동 변경 후 반납 시 복구")
void stockExhaustAndReturnTest() {
    Book book = new Book("희귀 도서", "저자", "123-456", 1);
    em.persist(book);
    em.flush();
    em.clear();

    // 대출 — 재고 0이 되면 status → UNAVAILABLE
    Book found = em.find(Book.class, book.getId());
    found.loan();
    assertThat(found.getStock()).isEqualTo(0);
    assertThat(found.getStatus()).isEqualTo(BookStatus.UNAVAILABLE);
    em.flush();
    em.clear();

    Book result = em.find(Book.class, book.getId());
    assertThat(result.getStatus()).isEqualTo(BookStatus.UNAVAILABLE);
    System.out.println("재고 소진 후 status: " + result.getStatus()); // UNAVAILABLE

    // 반납 — stock++, status → AVAILABLE
    result.returnBook();
    em.flush();
    em.clear();

    Book returned = em.find(Book.class, book.getId());
    assertThat(returned.getStatus()).isEqualTo(BookStatus.AVAILABLE);
    System.out.println("반납 후 status: " + returned.getStatus()); // AVAILABLE
}
```

---

## 📗 6. Step 5 — JPQL 실행 전 자동 flush

---

UPDATE가 쓰기 지연 저장소에 쌓인 상태에서 JPQL을 실행하면, JPQL 직전에 자동 flush가 일어나 변경이 DB에 반영된 후 JPQL이 실행된다.

```java
@Test
@DisplayName("JPQL 실행 직전 자동 flush — 수정된 제목으로 조회됨")
void jpqlAutoFlushTest() {
    Book book = new Book("스프링 부트", "작가A", "111-222", 3);
    em.persist(book);
    em.flush();
    em.clear();

    Book found = em.find(Book.class, book.getId());
    found.updateTitle("스프링 부트 3.x");
    // 이 시점에 UPDATE SQL은 쓰기 지연 저장소에만 있음

    System.out.println("=== JPQL 실행 직전 자동 flush → UPDATE → JPQL 실행 ===");
    Book result = em.createQuery(
            "select b from Book b where b.title = :title", Book.class)
        .setParameter("title", "스프링 부트 3.x")
        .getSingleResult();

    // 자동 flush 덕분에 수정된 제목으로 조회됨
    assertThat(result.getTitle()).isEqualTo("스프링 부트 3.x");
    System.out.println("JPQL 조회 결과: " + result.getTitle()); // 스프링 부트 3.x
}
```

---

## 📗 7. Step 6 — OSIV OFF DTO 변환 패턴

---

`application.yml`에 `spring.jpa.open-in-view: false`로 설정한 상태에서 Service 계층에서 DTO로 변환해 반환하는 패턴을 적용한다.

```java
// book/dto/BookResponse.java
@Getter
public class BookResponse {
    private Long id;
    private String title;
    private String author;
    private BookStatus status;
    private int stock;
    private LocalDateTime createdAt;

    public BookResponse(Book book) {
        this.id = book.getId();
        this.title = book.getTitle();
        this.author = book.getAuthor();
        this.status = book.getStatus();
        this.stock = book.getStock();
        this.createdAt = book.getCreatedAt();
    }
}
```

```java
// book/BookService.java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BookService {

    private final BookRepository bookRepository;

    @Transactional
    public Long register(String title, String author, String isbn, int stock) {
        return bookRepository.save(new Book(title, author, isbn, stock)).getId();
    }

    // OSIV OFF: 트랜잭션 내에서 DTO 변환 후 반환
    public BookResponse findById(Long id) {
        Book book = bookRepository.findById(id)
            .orElseThrow(() -> new IllegalArgumentException("도서가 없습니다: " + id));
        return new BookResponse(book);
        // 메서드 종료 → 트랜잭션·영속성 컨텍스트 종료
        // BookResponse는 순수 자바 객체 → Controller에서 자유롭게 사용 가능
    }

    // 더티 체킹으로 UPDATE 자동 실행 — save() 불필요
    @Transactional
    public void loan(Long bookId) {
        bookRepository.findById(bookId)
            .orElseThrow(() -> new IllegalArgumentException("도서가 없습니다: " + bookId))
            .loan();
    }

    @Transactional
    public void updateTitle(Long bookId, String newTitle) {
        bookRepository.findById(bookId)
            .orElseThrow(() -> new IllegalArgumentException("도서가 없습니다: " + bookId))
            .updateTitle(newTitle);
        // bookRepository.save() 불필요 — 더티 체킹으로 처리됨
    }
}
```

---

## 📗 8. 실습 확인 체크리스트

---

| 확인 항목 | 확인 방법 |
|---|---|
| persist 후 영속 상태 | `em.contains()` = true |
| detach 후 수정 무효 | flush해도 UPDATE SQL 없음 |
| merge() 반환값이 영속 | 원본 `em.contains()` = false, 반환값 = true |
| 1차 캐시 HIT | 같은 PK 두 번 find 시 SELECT SQL 1번만 출력 |
| 더티 체킹 동작 | `loan()` 호출만으로 flush 시 UPDATE SQL 출력 |
| JPQL 자동 flush | UPDATE 쌓인 상태에서 JPQL 실행 시 UPDATE 먼저 출력 |
| OSIV OFF DTO 패턴 | Controller에서 BookResponse 정상 반환 |

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate 6 User Guide: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html>
