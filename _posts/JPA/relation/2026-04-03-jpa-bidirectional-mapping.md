---
title: 양방향 매핑
date: 2026-04-03 11:10:00 +0900
categories: [JPA, 연관관계 매핑]
tags: [JPA, 연관관계 매핑, 양방향, 연관관계주인, mappedBy, 편의메서드, toString]
---

##  1. 연관관계 주인 개념

---

객체 세계에서 양방향 매핑은 사실 **단방향 매핑 두 개**다. `Member`가 `LoanRecord`를 참조하고, `LoanRecord`도 `Member`를 참조한다.

그런데 DB에서 FK는 하나다. `loan_record` 테이블의 `member_id` 컬럼 하나가 양쪽의 관계를 표현한다. 두 객체 중 어느 쪽의 참조가 변경될 때 이 FK를 갱신할지 결정해야 한다. JPA는 이 문제를 **연관관계 주인(Owner)** 개념으로 해결한다.

- **연관관계 주인**: FK를 실제로 관리하는 쪽. `@JoinColumn`이 있는 쪽. INSERT/UPDATE 시 FK를 반영한다.
- **비주인**: `mappedBy`가 있는 쪽. 읽기 전용. 여기서 값을 변경해도 DB에 반영되지 않는다.

**주인을 정하는 원칙**: FK가 있는 테이블의 엔티티가 주인이 되어야 한다. `loan_record` 테이블에 `member_id` FK가 있으므로 `LoanRecord`가 주인이다. FK가 있는 쪽을 주인으로 정하면 성능이 좋고 직관적이다.

---

##  2. 양방향 매핑 코드

---

### 📌 연관관계 주인 — LoanRecord

```java
@Entity
public class LoanRecord extends BaseEntity {

    // 연관관계 주인 — FK를 직접 관리
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

    // 비주인 — mappedBy로 주인 필드명 선언. 읽기 전용.
    @OneToMany(mappedBy = "member",
               cascade = CascadeType.ALL,
               orphanRemoval = true)
    private List<LoanRecord> loanRecords = new ArrayList<>();
}
```

`mappedBy = "member"`는 `LoanRecord` 클래스의 `member` 필드가 연관관계 주인임을 선언하는 것이다. 여기에 값을 추가/삭제해도 DB에 반영되지 않는다.

---

##  3. 양방향 편의 메서드 — 반드시 필요한 이유

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

`LoanRecord.member` 필드에만 설정했기 때문에 DB flush 전에는 `member.getLoanRecords()`가 빈 리스트를 반환한다. 1차 캐시의 `Member` 객체는 이 `LoanRecord`를 모르기 때문이다.

양방향 편의 메서드로 양쪽을 동시에 설정해야 한다.

```java
// LoanRecord의 정적 팩토리 메서드 — 양방향 편의 메서드 포함
public static LoanRecord create(Member member, Book book) {
    LoanRecord record = new LoanRecord();

    // 연관관계 주인 쪽 설정
    record.member = member;
    record.book = book;

    // 반대쪽도 동시에 설정 (편의 메서드)
    member.addLoanRecord(record);   // Member.loanRecords에 추가
    book.addLoanRecord(record);     // Book.loanRecords에 추가

    book.loan(); // 재고 감소
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

이제 `member.getLoanRecords().size()`를 호출하면 1차 캐시에서도 올바른 결과를 반환한다.

---

##  4. toString / equals / hashCode 주의점

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
    //           → member.toString() → loanRecords.toString() → 무한루프
}
```

해결 방법은 다음과 같다.

```java
// 방법 1 — exclude로 컬렉션 제외
@ToString(exclude = "loanRecords")
public class Member { ... }

// 방법 2 — 직접 작성 (연관관계 필드 포함 안 함)
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

##  5. 비주인에서 값 변경 시 반영 안 되는 실수

---

실무에서 자주 발생하는 실수다. `mappedBy`가 있는 쪽(비주인)에서 값을 변경하면 DB에 반영되지 않는다.

```java
// 잘못된 코드 — 비주인에서 설정
Member member = em.find(Member.class, 1L);
LoanRecord record = em.find(LoanRecord.class, 1L);

member.getLoanRecords().add(record); // 비주인에서 추가 → DB 반영 안 됨

em.flush(); // UPDATE/INSERT 실행 안 됨

// 올바른 코드 — 연관관계 주인에서 설정
record.setMember(member); // 주인에서 설정 → DB 반영됨
em.flush(); // UPDATE loan_record SET member_id=? WHERE loan_id=? 실행
```

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate Bidirectional: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#associations-many-to-one>
