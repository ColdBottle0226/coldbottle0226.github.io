---
title: "JPA 실전 패턴"
date: 2026-04-24 13:30:00 +0900
categories: [JPA, 심화 개념]
tags: [JPA, 낙관적잠금, 비관적잠금, Version, OptimisticLockException, PESSIMISTIC_WRITE, SoftDelete, SQLDelete, Where, 도메인이벤트, DomainEvents, AbstractAggregateRoot, DataJpaTest, Testcontainers, 테스트전략]
---

##  1. 동시성 제어 — 낙관적·비관적 잠금

---

### 📌 낙관적 잠금 (Optimistic Lock) — @Version

낙관적 잠금은 "대부분의 트랜잭션에서 충돌이 없을 것"이라고 낙관적으로 가정하고, 실제 충돌이 발생한 시점에 예외를 던지는 방식이다.

```java
@Entity
public class Book extends BaseEntity {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String title;
    private int stock;  // 재고

    @Version  // 낙관적 잠금 버전 컬럼
    private Long version;

    public void decreaseStock(int quantity) {
        if (this.stock < quantity) {
            throw new IllegalStateException("재고 부족");
        }
        this.stock -= quantity;
    }
}
```

`@Version` 필드가 있으면 Hibernate가 UPDATE SQL에 자동으로 버전 조건을 추가한다.

```sql
-- @Version이 있을 때 생성되는 UPDATE SQL
UPDATE book
SET stock = ?, title = ?, version = version + 1
WHERE book_id = ? AND version = ?;  -- 조회 시점의 버전과 같을 때만 UPDATE

-- version이 이미 증가했으면 영향받은 행 수 = 0
-- → Hibernate가 OptimisticLockException 발생
```

### 📌 OptimisticLockException 처리

```java
@Transactional
public void purchaseBook(Long bookId, int quantity) {
    try {
        Book book = bookRepository.findById(bookId).orElseThrow();
        book.decreaseStock(quantity);
        // 트랜잭션 커밋 시 version 충돌이면 OptimisticLockException 발생
    } catch (ObjectOptimisticLockingFailureException e) {
        // Spring이 OptimisticLockException을 래핑
        throw new StockConflictException("다른 사용자가 먼저 구매했습니다. 다시 시도해주세요.");
    }
}
```

Spring Data JPA를 사용할 때는 `OptimisticLockException`이 `ObjectOptimisticLockingFailureException`으로 래핑된다.

**재고 차감 실전 시나리오:**

```java
// 낙관적 잠금 + 재시도 패턴
@Service
public class BookPurchaseService {

    private static final int MAX_RETRY = 3;

    @Retryable(value = ObjectOptimisticLockingFailureException.class, maxAttempts = MAX_RETRY)
    @Transactional
    public void purchase(Long bookId, int quantity) {
        Book book = bookRepository.findById(bookId).orElseThrow();
        book.decreaseStock(quantity);
    }

    @Recover
    public void recover(ObjectOptimisticLockingFailureException e, Long bookId, int quantity) {
        throw new PurchaseFailException("재고 처리에 실패했습니다. 잠시 후 다시 시도해주세요.");
    }
}
```

---

### 📌 비관적 잠금 (Pessimistic Lock) — PESSIMISTIC_WRITE

비관적 잠금은 "충돌이 자주 발생할 것"이라고 비관적으로 가정하고, 데이터를 조회하는 시점에 즉시 DB 락을 획득하는 방식이다.

```java
// Spring Data JPA에서 비관적 잠금
@Lock(LockModeType.PESSIMISTIC_WRITE)
@Query("SELECT b FROM Book b WHERE b.id = :id")
Optional<Book> findByIdWithLock(@Param("id") Long id);

// 사용
Book book = bookRepository.findByIdWithLock(bookId).orElseThrow();
// → SELECT * FROM book WHERE book_id = ? FOR UPDATE; (MySQL 기준)
// 다른 트랜잭션은 이 레코드를 수정하려면 락이 해제될 때까지 대기
book.decreaseStock(quantity);
```

비관적 잠금 모드 종류:

| LockModeType | SQL | 설명 |
|---|---|---|
| `PESSIMISTIC_READ` | `SELECT ... FOR SHARE` | 읽기 락. 다른 읽기는 허용, 쓰기는 대기 |
| `PESSIMISTIC_WRITE` | `SELECT ... FOR UPDATE` | 쓰기 락. 다른 읽기/쓰기 모두 대기 |
| `PESSIMISTIC_FORCE_INCREMENT` | `SELECT ... FOR UPDATE` + 버전 증가 | 비관적 잠금 + 버전 증가 |

### 📌 낙관적 vs 비관적 잠금 선택 기준

| 항목 | 낙관적 잠금 | 비관적 잠금 |
|---|---|---|
| 가정 | 충돌이 드물다 | 충돌이 자주 발생한다 |
| 락 시점 | 커밋 시 충돌 감지 | 조회 시점 즉시 락 |
| 성능 | 충돌이 없으면 빠름 | 락 대기로 처리량 감소 |
| 사용자 경험 | 실패 시 재시도 필요 | 대기 후 성공 |
| 적합한 상황 | 읽기 많고 쓰기 충돌 적은 경우 | 재고 차감, 잔액 변경 등 충돌 빈번한 경우 |

---

##  2. Soft Delete (논리 삭제)

---

물리 삭제(`DELETE SQL`)는 데이터를 영구 삭제한다. 실무에서는 데이터를 실제로 삭제하지 않고 삭제 플래그만 세우는 논리 삭제(Soft Delete)를 많이 사용한다.

### 📌 @SQLDelete / @SQLRestriction

```java
@Entity
@SQLDelete(sql = "UPDATE book SET deleted_at = NOW() WHERE book_id = ?")
@SQLRestriction("deleted_at IS NULL")  // Hibernate 6.x — 구버전은 @Where
public class Book extends BaseEntity {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String title;

    private LocalDateTime deletedAt;  // null이면 활성, 값이 있으면 삭제됨
}
```

`@SQLDelete`: `em.remove(book)` 또는 `bookRepository.delete(book)` 호출 시 실제 DELETE 대신 이 SQL이 실행된다.

`@SQLRestriction` (Hibernate 6.x): 이 엔티티를 조회하는 모든 쿼리에 자동으로 `WHERE deleted_at IS NULL` 조건이 추가된다.

```java
// 자동으로 deleted_at IS NULL 조건이 추가됨
bookRepository.findAll();
// → SELECT * FROM book WHERE deleted_at IS NULL;

bookRepository.findById(1L);
// → SELECT * FROM book WHERE book_id = 1 AND deleted_at IS NULL;
```

### 📌 QueryDSL에서 Soft Delete 조건 처리

`@SQLRestriction`은 JPQL에는 자동 적용되지만 QueryDSL에서는 적용 여부가 환경에 따라 다를 수 있다. 명시적으로 조건을 추가하는 것이 안전하다.

```java
// QueryDSL에서 명시적으로 deletedAt 조건 추가
queryFactory
    .selectFrom(book)
    .where(
        book.deletedAt.isNull(),  // soft delete 조건 명시
        book.category.eq("IT")
    )
    .fetch();
```

### 📌 물리 삭제 vs 논리 삭제 선택 기준

| 항목 | 물리 삭제 | 논리 삭제 |
|---|---|---|
| DB 용량 | 줄어듦 | 계속 증가 |
| 데이터 복구 | 불가 (백업 필요) | 가능 |
| 조회 성능 | 좋음 | deleted_at 인덱스 필요 |
| 감사 추적 | 어려움 | 삭제 이력 보존 |
| 참조 무결성 | FK 제약으로 보장 | 수동 처리 필요 |

실무에서는 회원 탈퇴, 주문 취소, 게시글 삭제 등 이력 보존이 필요한 경우 논리 삭제를 많이 사용한다. 다만 `deleted_at` 컬럼에 인덱스를 추가하고, 주기적으로 오래된 삭제 데이터를 아카이브 테이블로 이동하는 전략을 함께 고려해야 한다.

---

##  3. 도메인 이벤트

---

도메인 이벤트는 비즈니스 로직에서 발생한 중요한 사건을 이벤트로 발행하고, 관심 있는 컴포넌트가 비동기로 처리하는 패턴이다. JPA와 Spring의 이벤트 메커니즘을 결합해서 트랜잭션과 연동할 수 있다.

### 📌 AbstractAggregateRoot 패턴

Spring Data가 제공하는 `AbstractAggregateRoot`를 상속하면 도메인 이벤트를 손쉽게 발행할 수 있다.

```java
// 이벤트 클래스
public class BookLoanedEvent {
    private final Long bookId;
    private final Long memberId;
    private final LocalDate loanDate;

    public BookLoanedEvent(Long bookId, Long memberId, LocalDate loanDate) {
        this.bookId = bookId;
        this.memberId = memberId;
        this.loanDate = loanDate;
    }
    // getter 생략
}

// 도메인 엔티티 — AbstractAggregateRoot 상속
@Entity
public class Book extends AbstractAggregateRoot<Book> {

    @Id @GeneratedValue
    private Long id;

    private String title;
    private int stock;

    public void loan(Long memberId) {
        if (this.stock <= 0) throw new IllegalStateException("재고 없음");
        this.stock--;
        // 이벤트 등록 — 트랜잭션 커밋 후 발행
        registerEvent(new BookLoanedEvent(this.id, memberId, LocalDate.now()));
    }
}
```

### 📌 @DomainEvents / @AfterDomainEventsPublication

`AbstractAggregateRoot`를 쓸 수 없는 경우 직접 구현한다.

```java
@Entity
public class Book {

    @Transient  // DB에 저장하지 않음
    private List<Object> domainEvents = new ArrayList<>();

    @DomainEvents
    public List<Object> domainEvents() {
        return Collections.unmodifiableList(domainEvents);
    }

    @AfterDomainEventsPublication
    public void clearDomainEvents() {
        domainEvents.clear();
    }

    public void loan(Long memberId) {
        this.stock--;
        domainEvents.add(new BookLoanedEvent(this.id, memberId, LocalDate.now()));
    }
}
```

### 📌 ApplicationEventPublisher + JPA 통합

`AbstractAggregateRoot`를 사용하지 않고 직접 이벤트를 발행할 수 있다.

```java
@Service
@RequiredArgsConstructor
public class LoanService {

    private final BookRepository bookRepository;
    private final ApplicationEventPublisher eventPublisher;

    @Transactional
    public void loanBook(Long bookId, Long memberId) {
        Book book = bookRepository.findById(bookId).orElseThrow();
        book.decreaseStock(1);

        // 이벤트 발행 — 같은 트랜잭션 내에서 실행
        eventPublisher.publishEvent(new BookLoanedEvent(bookId, memberId, LocalDate.now()));
    }
}
```

### 📌 트랜잭션 이벤트 리스너

이벤트를 처리하는 타이밍을 트랜잭션 단계에 맞게 제어할 수 있다.

```java
@Component
public class BookLoanedEventHandler {

    // 트랜잭션 커밋 이후에 실행 (기본 동작)
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handleBookLoaned(BookLoanedEvent event) {
        // 알림 발송, 통계 집계 등 부수 효과 처리
        // 트랜잭션이 커밋된 후 실행되므로 DB 저장이 보장됨
        System.out.println("도서 대출 완료: " + event.getBookId());
    }

    // 트랜잭션 내에서 실행 (같은 트랜잭션 참여)
    @TransactionalEventListener(phase = TransactionPhase.BEFORE_COMMIT)
    public void handleBeforeCommit(BookLoanedEvent event) {
        // 커밋 전 추가 검증 등
    }
}
```

| Phase | 설명 |
|---|---|
| `BEFORE_COMMIT` | 커밋 직전 (같은 트랜잭션) |
| `AFTER_COMMIT` | 커밋 완료 후 (기본값) |
| `AFTER_ROLLBACK` | 롤백 후 |
| `AFTER_COMPLETION` | 커밋/롤백 관계없이 완료 후 |

---

##  4. 테스트 전략

---

### 📌 @DataJpaTest — 슬라이스 테스트

`@DataJpaTest`는 JPA 관련 빈만 로딩하는 슬라이스 테스트다. `@Service`, `@Controller` 등 다른 계층은 로딩하지 않아 테스트가 빠르다.

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE) // 실제 DB 사용 시
class MemberRepositoryTest {

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private TestEntityManager em;

    @Test
    @DisplayName("이메일로 회원 조회")
    void findByEmailTest() {
        // given
        Member member = new Member("홍길동", 30, "hong@test.com");
        em.persistAndFlush(member);
        em.clear(); // 1차 캐시 비워서 DB에서 조회되도록

        // when
        Optional<Member> found = memberRepository.findByEmail("hong@test.com");

        // then
        assertThat(found).isPresent();
        assertThat(found.get().getName()).isEqualTo("홍길동");
    }
}
```

`@DataJpaTest`의 기본값:
- 인메모리 DB(H2) 사용
- 각 테스트 메서드 후 롤백
- `TestEntityManager` 자동 주입 가능

### 📌 Testcontainers + MySQL 실제 DB 테스트

인메모리 DB와 실제 MySQL의 동작 차이가 문제가 되는 경우 Testcontainers로 실제 MySQL 컨테이너를 띄워 테스트한다.

```kotlin
// build.gradle.kts
testImplementation("org.springframework.boot:spring-boot-testcontainers")
testImplementation("org.testcontainers:junit-jupiter")
testImplementation("org.testcontainers:mysql")
```

```java
@DataJpaTest
@Testcontainers
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class BookRepositoryIntegrationTest {

    @Container
    static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");

    @DynamicPropertySource
    static void overrideProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", mysql::getJdbcUrl);
        registry.add("spring.datasource.username", mysql::getUsername);
        registry.add("spring.datasource.password", mysql::getPassword);
    }

    @Autowired
    private BookRepository bookRepository;

    @Test
    @DisplayName("MySQL 전용 함수를 사용하는 nativeQuery 테스트")
    void nativeQueryTest() {
        // MySQL 전용 문법을 사용하는 쿼리 테스트 가능
        List<Book> books = bookRepository.findByCategoryNative("IT", 10);
        assertThat(books).isNotNull();
    }
}
```

### 📌 @Rollback(false), flush/clear 패턴으로 1차 캐시 제어

```java
@DataJpaTest
@Transactional
class MemberRepositoryTest {

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private TestEntityManager em;

    @Test
    @Rollback(false)  // 실제로 커밋해서 DB에 저장 확인 (주의: 테스트 데이터가 남음)
    void saveAndVerifyInDB() {
        Member member = new Member("홍길동", 30, "hong@test.com");
        memberRepository.save(member);
        // 커밋 후 실제 DB에서 확인
    }

    @Test
    @DisplayName("더티 체킹 테스트 — flush/clear 패턴")
    void dirtyCheckingTest() {
        // given
        Member member = new Member("홍길동", 30, "hong@test.com");
        em.persistAndFlush(member);

        // 1차 캐시 비우기 — 이후 조회는 DB에서 실제로 가져옴
        em.clear();

        // when
        Member found = memberRepository.findById(member.getId()).orElseThrow();
        found.updateName("김철수");

        em.flush(); // 변경 감지 → UPDATE 실행
        em.clear(); // 1차 캐시 비우기

        // then — DB에서 다시 조회해서 변경 확인
        Member updated = memberRepository.findById(member.getId()).orElseThrow();
        assertThat(updated.getName()).isEqualTo("김철수");
    }

    @Test
    @DisplayName("N+1 문제 확인 테스트")
    void nPlusOneDetectionTest() {
        // given — 회원 3명, 각자 대출 기록 5개
        // ...setup...

        em.flush();
        em.clear();

        // when — 카운터로 쿼리 수 측정
        // (실제로는 p6spy나 Hibernate Statistics로 확인)
        List<Member> members = memberRepository.findAll();
        members.forEach(m -> m.getLoanRecords().size()); // N+1 발생 지점

        // then — 로그에서 쿼리 수 확인
    }
}
```

### 📌 테스트 픽스처 패턴 — @TestConfiguration

```java
@TestConfiguration
public class TestDataFactory {

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private BookRepository bookRepository;

    public Member createMember(String name) {
        return memberRepository.save(new Member(name, 25, name + "@test.com"));
    }

    public Book createBook(String title, String category, int price) {
        return bookRepository.save(new Book(title, category, price, 10));
    }
}

// 테스트에서 사용
@DataJpaTest
@Import(TestDataFactory.class)
class LoanRecordRepositoryTest {

    @Autowired
    private TestDataFactory factory;

    @Test
    void loanTest() {
        Member member = factory.createMember("홍길동");
        Book book = factory.createBook("스프링 부트", "IT", 25000);
        // ...
    }
}
```

---

##  5. 정리

---

| 개념 | 핵심 요약 |
|---|---|
| 낙관적 잠금 | @Version 필드. 커밋 시 버전 충돌 감지 → OptimisticLockException |
| 비관적 잠금 | PESSIMISTIC_WRITE. 조회 시점에 FOR UPDATE 락 획득 |
| Soft Delete | @SQLDelete + @SQLRestriction. deletedAt 컬럼 기반 논리 삭제 |
| 도메인 이벤트 | AbstractAggregateRoot 또는 직접 구현. @TransactionalEventListener로 처리 타이밍 제어 |
| @DataJpaTest | JPA 슬라이스 테스트. 인메모리 DB + 자동 롤백 |
| Testcontainers | 실제 DB(MySQL 등)를 컨테이너로 띄워 통합 테스트 |
| flush/clear 패턴 | 1차 캐시 제어로 더티 체킹, 저장 결과를 DB에서 직접 검증 |

---

## 참고 자료

- 공식문서 - Hibernate 6 Locking: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#locking>
- 공식문서 - Spring Data JPA Domain Events: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#core.domain-events>
- 공식문서 - Spring @DataJpaTest: <https://docs.spring.io/spring-boot/docs/current/reference/html/test-auto-configuration.html#appendix.test-auto-configuration>
- Testcontainers 공식문서: <https://www.testcontainers.org/modules/databases/mysql/>
