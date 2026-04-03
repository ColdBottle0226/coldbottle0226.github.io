---
title: 연관관계 매핑 실습 — 도서 대출 시스템 확장
date: 2026-04-03 12:00:00 +0900
categories: [JPA, 연관관계 매핑]
tags: [JPA, 연관관계 매핑, 실습, ManyToOne, OneToMany, cascade, orphanRemoval, 편의메서드]
---

## 📗 1. 실습 구조

---

기존 `Member`와 `Book`에 `LoanRecord`(대출 기록)를 추가해서 연관관계 매핑 전체를 단계별로 실습한다.

```
Step 1. Book에 @OneToMany 양방향 추가
Step 2. Member에 @OneToMany + cascade + orphanRemoval 추가
Step 3. LoanRecord 엔티티 작성 (연관관계 주인)
Step 4. LoanService 작성
Step 5. 테스트로 각 개념 확인
   ├── @ManyToOne FK 저장 확인
   ├── 양방향 편의 메서드 1차 캐시 일관성 확인
   ├── 더티 체킹 — 반납 시 UPDATE 자동 실행 확인
   ├── orphanRemoval — 컬렉션 제거 시 DELETE 확인
   └── CascadeType.REMOVE — 부모 삭제 시 자식 삭제 확인
```

---

## 📗 2. Step 1 — Book 양방향 추가

---

```java
// book/Book.java
@Entity
@Table(name = "book",
    uniqueConstraints = @UniqueConstraint(name = "uk_book_isbn", columnNames = {"isbn"}))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Book extends BaseEntity {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "book_id")
    private Long id;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(nullable = false, length = 100)
    private String author;

    @Column(nullable = false, length = 20)
    private String isbn;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private BookStatus status;

    @Column(nullable = false)
    private int stock;

    // Book(1) ↔ LoanRecord(N) 양방향
    // cascade 없음 — Book 삭제 시 LoanRecord는 유지 (대출 이력 보존)
    @OneToMany(mappedBy = "book")
    private List<LoanRecord> loanRecords = new ArrayList<>();

    public Book(String title, String author, String isbn, int stock) {
        this.title = title;
        this.author = author;
        this.isbn = isbn;
        this.stock = stock;
        this.status = BookStatus.AVAILABLE;
    }

    // 양방향 편의 메서드
    public void addLoanRecord(LoanRecord record) {
        this.loanRecords.add(record);
    }

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

---

## 📗 3. Step 2 — Member 양방향 + cascade + orphanRemoval

---

```java
// member/Member.java
@Entity
@Table(name = "member",
    uniqueConstraints = @UniqueConstraint(name = "uk_member_email", columnNames = {"email"}))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Member extends BaseEntity {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "member_id")
    private Long id;

    @Column(nullable = false, length = 50)
    private String name;

    private int age;

    @Column(length = 100)
    private String email;

    // Member(1) ↔ LoanRecord(N) 양방향
    // cascade = ALL: Member 저장/삭제 시 LoanRecord도 함께 처리
    // orphanRemoval: loanRecords 컬렉션에서 제거 시 LoanRecord 자동 DELETE
    @OneToMany(mappedBy = "member", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<LoanRecord> loanRecords = new ArrayList<>();

    public Member(String name, int age, String email) {
        this.name = name;
        this.age = age;
        this.email = email;
    }

    // 양방향 편의 메서드 — 1차 캐시 일관성을 위해 반드시 필요
    public void addLoanRecord(LoanRecord record) {
        this.loanRecords.add(record);
    }

    public void removeLoanRecord(LoanRecord record) {
        this.loanRecords.remove(record);
        // orphanRemoval = true이므로 flush 시 DELETE 자동 실행
    }

    public void updateName(String name) { this.name = name; }
    public void updateAge(int age) { this.age = age; }
}
```

---

## 📗 4. Step 3 — LoanRecord 엔티티 (연관관계 주인)

---

```java
// loan/LoanRecord.java
@Entity
@Table(name = "loan_record")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class LoanRecord extends BaseEntity {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "loan_id")
    private Long id;

    // 연관관계 주인 — FK를 직접 관리
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false,
                foreignKey = @ForeignKey(name = "fk_loan_record_member"))
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "book_id", nullable = false,
                foreignKey = @ForeignKey(name = "fk_loan_record_book"))
    private Book book;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private LoanStatus status;

    @Column(nullable = false)
    private LocalDate loanDate;

    @Column(nullable = false)
    private LocalDate dueDate;

    private LocalDate returnDate;

    // 정적 팩토리 메서드 — 양방향 편의 메서드 포함
    public static LoanRecord create(Member member, Book book) {
        LoanRecord record = new LoanRecord();

        // 연관관계 주인 쪽 설정
        record.member = member;
        record.book = book;

        // 반대쪽 동시 설정 (1차 캐시 일관성 보장)
        member.addLoanRecord(record);
        book.addLoanRecord(record);

        book.loan(); // 재고 감소

        record.status = LoanStatus.ACTIVE;
        record.loanDate = LocalDate.now();
        record.dueDate = LocalDate.now().plusWeeks(2);
        return record;
    }

    // 반납 처리
    public void returnLoan() {
        if (this.status == LoanStatus.RETURNED) {
            throw new IllegalStateException("이미 반납된 대출 기록입니다.");
        }
        this.status = LoanStatus.RETURNED;
        this.returnDate = LocalDate.now();
        this.book.returnBook(); // 재고 복구
    }

    public boolean isOverdue() {
        if (this.status == LoanStatus.RETURNED) return false;
        return LocalDate.now().isAfter(this.dueDate);
    }
}
```

```java
// loan/LoanStatus.java
public enum LoanStatus {
    ACTIVE,   // 대출 중
    RETURNED  // 반납 완료
}
```

```java
// loan/LoanRepository.java
public interface LoanRepository extends JpaRepository<LoanRecord, Long> {

    @Query("select lr from LoanRecord lr " +
           "join fetch lr.member m " +
           "join fetch lr.book b " +
           "where m.id = :memberId and lr.status = 'ACTIVE'")
    List<LoanRecord> findActiveLoansByMemberId(@Param("memberId") Long memberId);
}
```

---

## 📗 5. Step 4 — LoanService

---

```java
// loan/LoanService.java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class LoanService {

    private final MemberRepository memberRepository;
    private final BookRepository bookRepository;
    private final LoanRepository loanRepository;

    // 대출
    @Transactional
    public Long loan(Long memberId, Long bookId) {
        Member member = memberRepository.findById(memberId)
            .orElseThrow(() -> new IllegalArgumentException("회원이 없습니다: " + memberId));
        Book book = bookRepository.findById(bookId)
            .orElseThrow(() -> new IllegalArgumentException("도서가 없습니다: " + bookId));

        // 정적 팩토리 메서드 내에서 양방향 편의 메서드 호출됨
        LoanRecord record = LoanRecord.create(member, book);
        loanRepository.save(record);
        return record.getId();
    }

    // 반납 — 더티 체킹으로 UPDATE 자동 실행
    @Transactional
    public void returnLoan(Long loanId) {
        LoanRecord record = loanRepository.findById(loanId)
            .orElseThrow(() -> new IllegalArgumentException("대출 기록이 없습니다: " + loanId));
        record.returnLoan(); // status 변경 + book.returnBook()
        // em.update() 없음. 트랜잭션 종료 시 더티 체킹으로 UPDATE 자동 실행
    }

    // 대출 취소 — orphanRemoval 동작
    @Transactional
    public void cancelLoan(Long memberId, Long loanId) {
        Member member = memberRepository.findById(memberId)
            .orElseThrow(() -> new IllegalArgumentException("회원이 없습니다: " + memberId));
        LoanRecord target = member.getLoanRecords().stream()
            .filter(r -> r.getId().equals(loanId))
            .findFirst()
            .orElseThrow(() -> new IllegalArgumentException("대출 기록이 없습니다: " + loanId));

        member.removeLoanRecord(target);
        // orphanRemoval = true → flush 시 DELETE 자동 실행
        // loanRepository.delete(target) 없어도 됨
    }

    public List<LoanRecord> findActiveLoans(Long memberId) {
        return loanRepository.findActiveLoansByMemberId(memberId);
    }
}
```

---

## 📗 6. Step 5 — 연관관계 실습 테스트

---

```java
// test/.../loan/RelationshipTest.java
@SpringBootTest
@Transactional
class RelationshipTest {

    @PersistenceContext EntityManager em;
    @Autowired MemberRepository memberRepository;
    @Autowired BookRepository bookRepository;
    @Autowired LoanRepository loanRepository;
    @Autowired LoanService loanService;

    Member member;
    Book book;

    @BeforeEach
    void setUp() {
        member = memberRepository.save(new Member("홍길동", 30, "hong@test.com"));
        book = bookRepository.save(new Book("JPA 프로그래밍", "김영한", "978-89-562-3935", 3));
        em.flush();
        em.clear();
    }

    @Test
    @DisplayName("@ManyToOne — LoanRecord 저장 시 member_id FK 자동 반영")
    void manyToOneTest() {
        Member findMember = memberRepository.findById(member.getId()).orElseThrow();
        Book findBook = bookRepository.findById(book.getId()).orElseThrow();

        LoanRecord record = LoanRecord.create(findMember, findBook);
        loanRepository.save(record);
        em.flush();
        em.clear();

        LoanRecord found = loanRepository.findById(record.getId()).orElseThrow();
        assertThat(found.getMember().getId()).isEqualTo(member.getId());
        assertThat(found.getBook().getId()).isEqualTo(book.getId());
        assertThat(found.getStatus()).isEqualTo(LoanStatus.ACTIVE);
        System.out.println("대출 기록 저장 확인: member=" + found.getMember().getName()
                + ", book=" + found.getBook().getTitle());
    }

    @Test
    @DisplayName("양방향 편의 메서드 — flush 없이도 1차 캐시에서 일관성 보장")
    void bidirectionalConsistencyTest() {
        Member findMember = memberRepository.findById(member.getId()).orElseThrow();
        Book findBook = bookRepository.findById(book.getId()).orElseThrow();

        LoanRecord record = LoanRecord.create(findMember, findBook);
        loanRepository.save(record);

        // flush/clear 없이 1차 캐시에서 확인 — 편의 메서드 없었다면 0
        assertThat(findMember.getLoanRecords()).hasSize(1);
        assertThat(findBook.getLoanRecords()).hasSize(1);
        System.out.println("편의 메서드 후 member.loanRecords 크기: "
                + findMember.getLoanRecords().size()); // 1
    }

    @Test
    @DisplayName("더티 체킹 — 반납 시 LoanRecord, Book 모두 UPDATE 자동 실행")
    void returnLoanDirtyCheckingTest() {
        Long loanId = loanService.loan(member.getId(), book.getId());
        em.flush();
        em.clear();

        loanService.returnLoan(loanId); // 더티 체킹으로 UPDATE
        em.flush();
        em.clear();

        LoanRecord returned = loanRepository.findById(loanId).orElseThrow();
        assertThat(returned.getStatus()).isEqualTo(LoanStatus.RETURNED);
        assertThat(returned.getReturnDate()).isEqualTo(LocalDate.now());

        Book updatedBook = bookRepository.findById(book.getId()).orElseThrow();
        assertThat(updatedBook.getStock()).isEqualTo(3); // 원래 3권으로 복구
        System.out.println("반납 후 재고: " + updatedBook.getStock()); // 3
    }

    @Test
    @DisplayName("orphanRemoval — loanRecords 컬렉션에서 제거 시 DELETE 자동 실행")
    void orphanRemovalTest() {
        Long loanId = loanService.loan(member.getId(), book.getId());
        em.flush();
        em.clear();

        loanService.cancelLoan(member.getId(), loanId);
        em.flush();
        em.clear();

        assertThat(loanRepository.findById(loanId)).isEmpty();
        System.out.println("orphanRemoval: LoanRecord 자동 삭제 확인");
    }

    @Test
    @DisplayName("CascadeType.REMOVE — Member 삭제 시 LoanRecord도 함께 삭제")
    void cascadeRemoveTest() {
        Long loanId = loanService.loan(member.getId(), book.getId());
        em.flush();
        em.clear();

        memberRepository.deleteById(member.getId()); // cascade = ALL
        em.flush();
        em.clear();

        assertThat(loanRepository.findById(loanId)).isEmpty();
        System.out.println("cascade REMOVE: Member 삭제 시 LoanRecord도 삭제됨");

        assertThat(bookRepository.findById(book.getId())).isPresent();
        System.out.println("Book은 cascade 없으므로 삭제 안 됨");
    }

    @Test
    @DisplayName("FetchType.LAZY — member 접근 시점에 SELECT 실행")
    void lazyLoadingTest() {
        Long loanId = loanService.loan(member.getId(), book.getId());
        em.flush();
        em.clear();

        System.out.println("=== LoanRecord 조회 (member 아직 로딩 안 됨) ===");
        LoanRecord record = loanRepository.findById(loanId).orElseThrow();

        System.out.println("=== member.getName() 호출 시점에 SELECT 실행 ===");
        String memberName = record.getMember().getName();
        assertThat(memberName).isEqualTo("홍길동");
        System.out.println("회원 이름: " + memberName);
    }
}
```

---

## 📗 7. 최종 패키지 구조

---

```
src/main/java/com/study/jpa/
│
├── global/
│   ├── config/JpaConfig.java
│   └── entity/BaseEntity.java
│
├── member/
│   ├── Member.java              ← @OneToMany(cascade=ALL, orphanRemoval=true)
│   ├── MemberRepository.java
│   └── MemberService.java
│
├── book/
│   ├── Book.java                ← @OneToMany(mappedBy="book")
│   ├── BookStatus.java
│   └── BookRepository.java
│
└── loan/
    ├── LoanRecord.java          ← 연관관계 주인 (@ManyToOne × 2)
    ├── LoanStatus.java
    ├── LoanRepository.java
    └── LoanService.java
```

---

## 📗 8. 실습 확인 체크리스트

---

| 확인 항목 | 확인 방법 |
|---|---|
| @ManyToOne FK 저장 | LoanRecord 저장 후 member_id, book_id 컬럼 확인 |
| 연관관계 주인 | LoanRecord.member 변경 시 UPDATE. Member.loanRecords만 변경 시 UPDATE 없음 |
| 양방향 편의 메서드 | flush 없이 member.getLoanRecords().size() = 1 |
| 더티 체킹 | returnLoan() 호출만으로 UPDATE SQL 자동 실행 |
| orphanRemoval | removeLoanRecord() 후 flush 시 DELETE 자동 실행 |
| cascade REMOVE | Member 삭제 시 LoanRecord 삭제. Book은 유지 |
| LAZY 로딩 | LoanRecord 조회 시 member SELECT 없음. getName() 호출 시 SELECT |

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate Associations: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#associations>
- 공식문서 - Hibernate Cascade: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#pc-cascade>
