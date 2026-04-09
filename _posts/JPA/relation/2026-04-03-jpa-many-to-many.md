---
title: 다대다 관계
date: 2026-04-03 11:20:00 +0900
categories: [JPA, 연관관계 매핑]
tags: [JPA, 연관관계 매핑, ManyToMany, 중간엔티티, JoinTable]
---

##  1. @ManyToMany를 사용하면 안 되는 이유

---

`Member`와 `Book`은 다대다(M:N) 관계다. 한 회원이 여러 책을 빌릴 수 있고, 한 책이 여러 회원에게 빌려질 수 있다. JPA는 `@ManyToMany`로 이 관계를 표현할 수 있지만 실무에서는 절대 사용하지 않는다.

```java
// @ManyToMany — 사용 금지
@Entity
public class Member {
    @ManyToMany
    @JoinTable(
        name = "member_book",
        joinColumns = @JoinColumn(name = "member_id"),
        inverseJoinColumns = @JoinColumn(name = "book_id")
    )
    private List<Book> books;
}
```

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

실무에서는 중간 테이블에 `대출일`, `반납일`, `상태` 같은 비즈니스 속성이 반드시 필요하다. `@ManyToMany`로는 이를 표현할 수 없다. 또한 중간 테이블을 엔티티로 다룰 수 없어서 직접 쿼리하기도 어렵고, 예상치 못한 SQL이 발생하기도 한다.

---

##  2. 중간 엔티티로 대체 (권장)

---

해결 방법은 중간 테이블을 엔티티로 격상하고 `@ManyToOne` 두 개로 연결하는 것이다.

```
@ManyToMany 방식:
Member ←──────────────────────────────→ Book

중간 엔티티 방식:
Member ←── @ManyToOne ── LoanRecord ── @ManyToOne ──→ Book
```

```java
// 중간 엔티티 — LoanRecord
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

---

##  3. @ManyToMany가 허용되는 유일한 경우

---

두 엔티티의 다대다 관계가 **순수하게 연결 관계만** 표현하고 추가 속성이 절대 필요 없을 때다. 예를 들어 태그(Tag) ↔ 게시글(Post) 관계에서 태그를 달았다는 사실만 표현하고 태그를 언제 달았는지, 어떤 상태인지 같은 속성이 필요 없다면 `@ManyToMany`를 쓸 수 있다.

하지만 서비스가 발전하면 결국 추가 속성이 필요해지는 경우가 대부분이기 때문에, 처음부터 중간 엔티티를 사용하는 것을 권장한다.

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate ManyToMany: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#associations-many-to-many>
