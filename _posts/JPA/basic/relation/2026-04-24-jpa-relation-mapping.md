---
title: JPA 연관관계 매핑
date: 2026-04-24 09:20:00 +0900
categories: [JPA, 기본 개념]
order: 3
tags: [JPA, 연관관계 매핑, ManyToOne, OneToOne, JoinColumn, FetchType, LAZY, 양방향, 연관관계주인, mappedBy, 편의메서드, toString, ManyToMany, 중간엔티티, JoinTable, CascadeType, orphanRemoval, 영속성전이, 고아객체]
---

##  1. 연관관계 매핑이 필요한 이유

---

연관관계 매핑을 이해하려면 항상 세 가지 개념을 함께 생각해야 한다.

- **방향**: 단방향(한쪽만 참조), 양방향(서로 참조)
- **다중성**: @OneToOne / @OneToMany / @ManyToOne / @ManyToMany
- **연관관계 주인**: 양방향일 때 FK를 실제로 관리하는 쪽

---

##  2. @ManyToOne — 다대일 단방향

---

가장 많이 쓰이는 연관관계 매핑이다. `LoanRecord`(대출 기록) 입장에서 하나의 `Member`에 속하고(N:1), `Member` 입장에서는 여러 `LoanRecord`를 가진다(1:N).

```java
@Entity
@Table(name = "loan_record")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class LoanRecord extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "loan_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)  // 지연 로딩 명시 필수
    @JoinColumn(name = "member_id",
                nullable = false,
                foreignKey = @ForeignKey(name = "fk_loan_record_member"))
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "book_id",
                nullable = false,
                foreignKey = @ForeignKey(name = "fk_loan_record_book"))
    private Book book;
}
```

> 💡 `@ManyToOne`의 기본 FetchType은 `EAGER`다. 실무에서는 반드시 `FetchType.LAZY`로 명시해야 한다. EAGER는 조회 시마다 연관 엔티티를 즉시 로딩해서 N+1 문제를 유발한다.

---

##  3. @JoinColumn 상세 옵션

---

```java
@ManyToOne(fetch = FetchType.LAZY)
@JoinColumn(
    name = "member_id",
    referencedColumnName = "member_id",
    nullable = false,
    insertable = true,
    updatable = true,
    foreignKey = @ForeignKey(name = "fk_loan_record_member")
)
private Member member;
```

FK 이름을 `@ForeignKey(name = "...")`로 명시하면 DB에서 관리할 때 의미를 바로 파악할 수 있다. `insertable = false, updatable = false` 조합은 읽기 전용 FK 컬럼에 사용한다.

---

##  4. @OneToOne — 일대일 단방향

---

일대일 관계는 양쪽 중 어느 테이블에 FK를 둘지 선택해야 한다. 주로 접근이 더 빈번한 쪽에 FK를 둔다.

```java
@Entity
public class MemberProfile extends BaseEntity {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "profile_id")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id",
                unique = true,          // unique=true가 핵심 (1:1 보장)
                nullable = false)
    private Member member;

    private String bio;
    private String profileImageUrl;
}
```

> 💡 `@JoinColumn(unique = true)`를 반드시 붙여야 한다. 없으면 1:1이 아닌 N:1이 된다.

---

##  5. 단방향 @OneToMany — 사용하지 않는 것을 권장

---

`Member`가 `LoanRecord` 목록을 직접 참조하되, `LoanRecord`는 `Member`를 참조하지 않는 구조다. 이 방향은 실무에서 성능 문제를 일으키므로 사용하지 않는 것이 좋다.

```java
@Entity
public class Member {
    @OneToMany
    @JoinColumn(name = "member_id")
    private List<LoanRecord> loanRecords = new ArrayList<>();
}
```

이 구조의 문제는 `LoanRecord`를 저장할 때 UPDATE SQL이 추가로 발생한다는 점이다.

```sql
-- 단방향 @OneToMany로 LoanRecord 저장 시 발생하는 SQL
INSERT INTO loan_record (...) VALUES (...);   -- member_id 없이 INSERT
UPDATE loan_record SET member_id=? WHERE loan_id=?;  -- 별도 UPDATE로 FK 세팅
```

단방향 `@OneToMany`보다 양방향 매핑(`@ManyToOne` + `@OneToMany`)을 사용하는 것이 훨씬 낫다.

---

##  6. 연관관계 주인 개념

---

객체 세계에서 양방향 매핑은 사실 **단방향 매핑 두 개**다. `Member`가 `LoanRecord`를 참조하고, `LoanRecord`도 `Member`를 참조한다.

그런데 DB에서 FK는 하나다. 두 객체 중 어느 쪽의 참조가 변경될 때 이 FK를 갱신할지 결정해야 한다. JPA는 이 문제를 **연관관계 주인(Owner)** 개념으로 해결한다.

- **연관관계 주인**: FK를 실제로 관리하는 쪽. `@JoinColumn`이 있는 쪽. INSERT/UPDATE 시 FK를 반영한다.
- **비주인**: `mappedBy`가 있는 쪽. 읽기 전용. 여기서 값을 변경해도 DB에 반영되지 않는다.

**주인을 정하는 원칙**: FK가 있는 테이블의 엔티티가 주인이 되어야 한다. `loan_record` 테이블에 `member_id` FK가 있으므로 `LoanRecord`가 주인이다.

---

##  7. 양방향 매핑 코드

---

### 📌 연관관계 주인 — LoanRecord

```java
@Entity
public class LoanRecord extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "book_id", nullable = false)
    private Book book;
}
```

### 📌 비주인 — Member

```java
@Entity
public class Member extends BaseEntity {

    @OneToMany(mappedBy = "member",
               cascade = CascadeType.ALL,
               orphanRemoval = true)
    private List<LoanRecord> loanRecords = new ArrayList<>();
}
```

`mappedBy = "member"`는 `LoanRecord` 클래스의 `member` 필드가 연관관계 주인임을 선언하는 것이다. 여기에 값을 추가/삭제해도 DB에 반영되지 않는다.

---

##  8. 양방향 편의 메서드 — 반드시 필요한 이유

---

이것이 양방향 매핑에서 가장 중요하고 실수가 많은 부분이다.

```java
Member member = em.find(Member.class, 1L);
Book book = em.find(Book.class, 1L);

// 연관관계 주인(LoanRecord)에만 설정
LoanRecord record = new LoanRecord(member, book);
em.persist(record);

// DB에는 member_id FK가 정상 저장됨 — OK
// 하지만 같은 트랜잭션 내 1차 캐시에서 확인하면:
int count = member.getLoanRecords().size();
System.out.println(count); // 0 !!! — 1차 캐시 불일치
```

양방향 편의 메서드로 양쪽을 동시에 설정해야 한다.

```java
// LoanRecord의 정적 팩토리 메서드 — 양방향 편의 메서드 포함
public static LoanRecord create(Member member, Book book) {
    LoanRecord record = new LoanRecord();

    record.member = member;
    record.book = book;

    // 편의 메서드 — 반대쪽도 동시에 설정
    member.addLoanRecord(record);
    book.addLoanRecord(record);

    book.loan();
    record.status = LoanStatus.ACTIVE;
    record.loanDate = LocalDate.now();
    record.dueDate = LocalDate.now().plusWeeks(2);
    return record;
}

// Member의 편의 메서드
public void addLoanRecord(LoanRecord record) {
    this.loanRecords.add(record);
}
```

---

##  9. toString / equals / hashCode 주의점

---

양방향 매핑에서 Lombok의 `@ToString`을 무심코 사용하면 **무한 루프(StackOverflowError)**가 발생한다.

```java
// 위험한 패턴
@Entity
@ToString // ← 위험!
public class Member {
    @OneToMany(mappedBy = "member")
    private List<LoanRecord> loanRecords;
    // toString() → loanRecords.toString() → LoanRecord.toString()
    //           → member.toString() → 무한루프
}
```

해결 방법:

```java
// 방법 1 — exclude로 컬렉션 제외
@ToString(exclude = "loanRecords")
public class Member { ... }

// 방법 2 — 직접 작성
@Override
public String toString() {
    return "Member{id=" + id + ", name=" + name + "}";
}

// 방법 3 — 필요한 필드만 지정
@ToString(of = {"id", "status", "loanDate"})
public class LoanRecord { ... }
```

`equals()`와 `hashCode()`도 마찬가지다. 연관관계 필드를 포함하면 순환 참조가 발생한다. PK 기반으로만 구현하거나 연관관계 필드를 제외해야 한다.

---

##  10. 비주인에서 값 변경 시 반영 안 되는 실수

---

실무에서 자주 발생하는 실수다. `mappedBy`가 있는 쪽(비주인)에서 값을 변경하면 DB에 반영되지 않는다.

```java
// 잘못된 코드 — 비주인에서 설정
member.getLoanRecords().add(record); // 비주인에서 추가 → DB 반영 안 됨

// 올바른 코드 — 연관관계 주인에서 설정
record.setMember(member); // 주인에서 설정 → DB 반영됨
```

---

##  11. @ManyToMany를 사용하면 안 되는 이유

---

`@ManyToMany`의 근본적인 문제는 중간 테이블에 **두 FK 컬럼 외에 추가 컬럼을 넣을 수 없다**는 것이다.

```sql
-- @ManyToMany가 자동 생성하는 중간 테이블
CREATE TABLE member_book (
    member_id BIGINT NOT NULL,
    book_id   BIGINT NOT NULL,
    PRIMARY KEY (member_id, book_id)
    -- loan_date, return_date, status 같은 비즈니스 컬럼 추가 불가!
);
```

실무에서는 중간 테이블에 `대출일`, `반납일`, `상태` 같은 비즈니스 속성이 반드시 필요하다. `@ManyToMany`로는 이를 표현할 수 없다.

---

##  12. 중간 엔티티로 대체 (권장)

---

해결 방법은 중간 테이블을 엔티티로 격상하고 `@ManyToOne` 두 개로 연결하는 것이다.

```
@ManyToMany 방식:
Member ←──────────────────────────────→ Book

중간 엔티티 방식:
Member ←── @ManyToOne ── LoanRecord ── @ManyToOne ──→ Book
```

```java
@Entity
@Table(name = "loan_record")
public class LoanRecord extends BaseEntity {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "loan_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "book_id", nullable = false)
    private Book book;

    // 추가 컬럼 자유롭게 — @ManyToMany에서는 불가능
    @Enumerated(EnumType.STRING)
    private LoanStatus status;

    private LocalDate loanDate;
    private LocalDate dueDate;
    private LocalDate returnDate;
}
```

중간 엔티티를 사용하면 추가 컬럼을 자유롭게 넣을 수 있고, JPQL로 직접 조회할 수 있으며, cascade와 orphanRemoval도 적용할 수 있다.

### 📌 @ManyToMany가 허용되는 유일한 경우

두 엔티티의 다대다 관계가 **순수하게 연결 관계만** 표현하고 추가 속성이 절대 필요 없을 때다. 하지만 서비스가 발전하면 결국 추가 속성이 필요해지는 경우가 대부분이기 때문에, 처음부터 중간 엔티티를 사용하는 것을 권장한다.

---

##  13. 영속성 전이 (Cascade)

---

영속성 전이는 부모 엔티티에 특정 작업을 수행할 때 자식 엔티티에도 자동으로 같은 작업이 전파되는 기능이다.

```java
// cascade 없을 때 — 각각 persist 필요
em.persist(member);
em.persist(record); // em.persist(record)를 빠뜨리면 TransientPropertyValueException 발생

// cascade = PERSIST 적용 후 — member persist 시 record도 자동 영속화
em.persist(member);
```

### 📌 CascadeType 종류

| 타입 | 동작 |
|---|---|
| `PERSIST` | 부모 저장 시 자식도 자동 저장 |
| `REMOVE` | 부모 삭제 시 자식도 자동 삭제 |
| `MERGE` | 부모 merge 시 자식도 자동 merge |
| `REFRESH` | 부모 refresh 시 자식도 자동 refresh |
| `DETACH` | 부모 detach 시 자식도 자동 detach |
| `ALL` | 위 모든 타입 포함 |

### 📌 cascade 적용 조건 — 두 가지 모두 충족해야 함

**조건 1 — 라이프사이클을 함께 관리해야 함**

`Member`가 삭제되면 그 `Member`의 `LoanRecord`도 함께 삭제되어야 하는 경우 `CASCADE.REMOVE` 또는 `CASCADE.ALL`을 적용한다. 반면 `Book`은 `Member`와 무관하게 존재해야 하므로 `Book`에 `CASCADE.REMOVE`를 걸면 안 된다.

**조건 2 — 자식의 소유자가 하나여야 함**

`LoanRecord`가 `Member` 하나에만 속한다면 cascade를 걸어도 안전하다. 하지만 `LoanRecord`가 여러 부모에게 공유된다면 한 부모의 cascade가 다른 부모의 자식까지 삭제할 수 있어 위험하다.

> 💡 `@ManyToOne` 쪽에는 cascade를 거의 사용하지 않는다. cascade는 주로 `@OneToMany` 쪽, 부모에서 자식 방향으로만 적용한다.

### 📌 cascade 잘못 사용하는 흔한 실수

```java
// 잘못된 예 — Book에 cascade를 걸면 안 됨
@ManyToOne(fetch = FetchType.LAZY,
           cascade = CascadeType.REMOVE) // ← 위험!
@JoinColumn(name = "book_id")
private Book book;

// Member 삭제 시 cascade.ALL로 LoanRecord 삭제
// LoanRecord 삭제 시 cascade.REMOVE로 Book까지 삭제됨 → 의도치 않은 도서 삭제!
em.remove(member);
```

---

##  14. 고아 객체 제거 (orphanRemoval)

---

`orphanRemoval = true`는 부모 컬렉션에서 자식이 제거될 때 해당 자식 엔티티를 자동으로 삭제한다.

```java
@OneToMany(mappedBy = "member", cascade = CascadeType.ALL, orphanRemoval = true)
private List<LoanRecord> loanRecords = new ArrayList<>();

// 사용 예
Member member = em.find(Member.class, 1L);
LoanRecord record = member.getLoanRecords().get(0);

member.getLoanRecords().remove(record);
// flush 시 DELETE FROM loan_record WHERE loan_id=? 자동 실행
// em.remove(record) 없어도 됨
```

### 📌 orphanRemoval vs CascadeType.REMOVE 차이

| 구분 | orphanRemoval = true | CascadeType.REMOVE |
|---|---|---|
| 부모 `em.remove()` 시 | 자식도 삭제됨 | 자식도 삭제됨 |
| 컬렉션에서 제거(`remove()`) 시 | 자식 자동 DELETE | 자식 삭제 안 됨 |

`orphanRemoval`은 컬렉션에서 제거됐을 때도 자동 삭제한다는 점이 `REMOVE`와 다르다.

---

##  15. cascade + orphanRemoval 조합

---

`cascade = CascadeType.ALL`과 `orphanRemoval = true`를 함께 설정하면 부모가 자식의 생명주기를 완전히 제어한다.

이 조합은 자식이 **절대 부모 없이 존재할 수 없을 때**만 사용해야 한다.

```java
// 부모 저장 → 자식도 저장
em.persist(member);

// 컬렉션에서 제거 → 자식 자동 삭제
member.getLoanRecords().remove(record);

// 부모 삭제 → 자식 모두 삭제
em.remove(member);
```

> 💡 `cascade = ALL, orphanRemoval = true` 조합은 DDD의 Aggregate Root 패턴과 유사하다. Member가 LoanRecord의 생명주기를 완전히 소유하고 관리한다.

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate Associations: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#associations>
- 공식문서 - Hibernate Bidirectional: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#associations-many-to-one>
- 공식문서 - Hibernate ManyToMany: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#associations-many-to-many>
- 공식문서 - Hibernate Cascade: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#pc-cascade>
