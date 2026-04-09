---
title: 단방향 매핑
date: 2026-04-03 11:00:00 +0900
categories: [JPA, 연관관계 매핑]
tags: [JPA, 연관관계 매핑, ManyToOne, OneToOne, JoinColumn, FetchType, LAZY]
---

##  1. 연관관계 매핑이 필요한 이유

---

Phase 1에서 다뤘던 JDBC의 패러다임 불일치 중 하나가 연관관계였다. 객체는 참조로 다른 객체를 가리키지만, DB는 FK(외래 키)로 연관을 표현한다. JPA의 연관관계 매핑은 이 불일치를 해결한다.

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

    // @ManyToOne — 다대일 단방향
    // DB에 member_id FK 컬럼이 생성됨
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

> 💡 `@ManyToOne`의 기본 FetchType은 `EAGER`다. 실무에서는 반드시 `FetchType.LAZY`로 명시해야 한다. EAGER는 조회 시마다 연관 엔티티를 즉시 로딩해서 N+1 문제를 유발한다. Phase 6에서 상세히 다룬다.

---

##  3. @JoinColumn 상세 옵션

---

```java
@ManyToOne(fetch = FetchType.LAZY)
@JoinColumn(
    name = "member_id",                    // FK 컬럼명. 기본값: 필드명_참조엔티티PK명
    referencedColumnName = "member_id",    // 참조하는 컬럼명. 기본값: 참조 엔티티 PK
    nullable = false,                      // FK NOT NULL 제약
    insertable = true,                     // INSERT SQL에 포함 여부
    updatable = true,                      // UPDATE SQL에 포함 여부
    foreignKey = @ForeignKey(name = "fk_loan_record_member") // FK 이름 명시 권장
)
private Member member;
```

FK 이름을 `@ForeignKey(name = "...")`로 명시하면 DB에서 관리할 때 의미를 바로 파악할 수 있다. 명시하지 않으면 Hibernate가 자동으로 알아보기 어려운 이름을 생성한다.

`insertable = false, updatable = false` 조합은 읽기 전용 FK 컬럼에 사용한다.

---

##  4. @OneToOne — 일대일 단방향

---

일대일 관계는 양쪽 중 어느 테이블에 FK를 둘지 선택해야 한다. 주로 접근이 더 빈번한 쪽에 FK를 둔다.

```java
// MemberProfile — FK를 MemberProfile 쪽에 두는 경우
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
    @JoinColumn(name = "member_id") // 없으면 중간 조인 테이블 자동 생성
    private List<LoanRecord> loanRecords = new ArrayList<>();
}
```

이 구조의 문제는 `LoanRecord`를 저장할 때 UPDATE SQL이 추가로 발생한다는 점이다.

```sql
-- 단방향 @OneToMany로 LoanRecord 저장 시 발생하는 SQL
INSERT INTO loan_record (...) VALUES (...);   -- member_id 없이 INSERT
UPDATE loan_record SET member_id=? WHERE loan_id=?;  -- 별도 UPDATE로 FK 세팅
```

이 현상이 발생하는 이유는 `Member` 엔티티가 `loan_record` 테이블의 FK를 관리하는데, `LoanRecord` 테이블에 먼저 INSERT가 일어난 뒤 FK를 나중에 UPDATE하기 때문이다.

단방향 `@OneToMany`보다 양방향 매핑(`@ManyToOne` + `@OneToMany`)을 사용하는 것이 훨씬 낫다.

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate Associations: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#associations>
