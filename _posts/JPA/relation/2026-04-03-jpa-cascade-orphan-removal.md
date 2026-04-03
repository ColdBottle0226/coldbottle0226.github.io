---
title: 영속성 전이와 고아 객체
date: 2026-04-03 11:30:00 +0900
categories: [JPA, 연관관계 매핑]
tags: [JPA, 연관관계 매핑, CascadeType, orphanRemoval, 영속성전이, 고아객체]
---

## 📗 1. 영속성 전이 (Cascade)

---

영속성 전이는 부모 엔티티에 특정 작업을 수행할 때 자식 엔티티에도 자동으로 같은 작업이 전파되는 기능이다. 연관관계 매핑과는 별개의 기능이고, `@OneToMany` / `@ManyToOne` 어노테이션의 `cascade` 속성으로 설정한다.

```java
// cascade 없을 때 — 각각 persist 필요
Member member = new Member("홍길동", 30, "hong@test.com");
LoanRecord record = LoanRecord.create(member, book);

em.persist(member); // member만 영속화
em.persist(record); // record를 별도로 영속화해야 함
// em.persist(record)를 빠뜨리면 TransientPropertyValueException 발생

// cascade = PERSIST 적용 후 — member persist 시 record도 자동 영속화
em.persist(member);
```

---

### 📌 CascadeType 종류

| 타입 | 동작 |
|---|---|
| `PERSIST` | 부모 저장 시 자식도 자동 저장 |
| `REMOVE` | 부모 삭제 시 자식도 자동 삭제 |
| `MERGE` | 부모 merge 시 자식도 자동 merge |
| `REFRESH` | 부모 refresh 시 자식도 자동 refresh |
| `DETACH` | 부모 detach 시 자식도 자동 detach |
| `ALL` | 위 모든 타입 포함 |

```java
// Member에 cascade = ALL 적용
@OneToMany(mappedBy = "member", cascade = CascadeType.ALL, orphanRemoval = true)
private List<LoanRecord> loanRecords = new ArrayList<>();
```

---

### 📌 cascade 적용 조건 — 두 가지 모두 충족해야 함

**조건 1 — 라이프사이클을 함께 관리해야 함**

`Member`가 삭제되면 그 `Member`의 `LoanRecord`도 함께 삭제되어야 하는 경우 `CASCADE.REMOVE` 또는 `CASCADE.ALL`을 적용한다.

반면 `Book`은 `Member`와 무관하게 존재해야 하므로 `Book`에 `CASCADE.REMOVE`를 걸면 안 된다. 회원이 탈퇴해도 도서는 남아 있어야 하기 때문이다.

**조건 2 — 자식의 소유자가 하나여야 함**

`LoanRecord`가 `Member` 하나에만 속한다면 cascade를 걸어도 안전하다. 하지만 `LoanRecord`가 여러 부모에게 공유된다면 한 부모의 cascade가 다른 부모의 자식까지 삭제할 수 있어 위험하다.

> 💡 이 두 가지 조건을 모두 만족하지 않는데 cascade를 남발하면 의도치 않은 데이터 삭제가 발생한다.

---

## 📗 2. 고아 객체 제거 (orphanRemoval)

---

`orphanRemoval = true`는 부모 컬렉션에서 자식이 제거될 때 해당 자식 엔티티를 자동으로 삭제한다.

```java
@OneToMany(mappedBy = "member", cascade = CascadeType.ALL, orphanRemoval = true)
private List<LoanRecord> loanRecords = new ArrayList<>();

// 사용 예
Member member = em.find(Member.class, 1L);
LoanRecord record = member.getLoanRecords().get(0);

member.getLoanRecords().remove(record); // 컬렉션에서 제거
// flush 시 DELETE FROM loan_record WHERE loan_id=? 자동 실행
// em.remove(record) 없어도 됨
```

---

### 📌 orphanRemoval vs CascadeType.REMOVE 차이

| 구분 | orphanRemoval = true | CascadeType.REMOVE |
|---|---|---|
| 부모 `em.remove()` 시 | 자식도 삭제됨 | 자식도 삭제됨 |
| 컬렉션에서 제거(`remove()`) 시 | 자식 자동 DELETE | 자식 삭제 안 됨 |

`orphanRemoval`은 컬렉션에서 제거됐을 때도 자동 삭제한다는 점이 `REMOVE`와 다르다.

---

## 📗 3. cascade + orphanRemoval 조합

---

`cascade = CascadeType.ALL`과 `orphanRemoval = true`를 함께 설정하면 부모가 자식의 생명주기를 완전히 제어한다.

```java
// Member가 LoanRecord의 생명주기를 완전히 제어
@OneToMany(mappedBy = "member", cascade = CascadeType.ALL, orphanRemoval = true)
private List<LoanRecord> loanRecords = new ArrayList<>();
```

이 조합은 자식이 **절대 부모 없이 존재할 수 없을 때**만 사용해야 한다.

```java
// 부모 저장 → 자식도 저장
em.persist(member);           // loanRecords에 있는 record들 자동 persist

// 컬렉션에서 제거 → 자식 자동 삭제
member.getLoanRecords().remove(record); // flush 시 DELETE

// 부모 삭제 → 자식 모두 삭제
em.remove(member);            // loanRecords 전체 DELETE
```

> 💡 `cascade = ALL, orphanRemoval = true` 조합은 마치 DDD의 Aggregate Root 패턴과 유사하다. Member가 LoanRecord의 생명주기를 완전히 소유하고 관리한다.

---

## 📗 4. cascade 잘못 사용하는 흔한 실수

---

`Book`에도 cascade를 걸어서 회원 삭제 시 도서까지 삭제되는 경우다.

```java
// 잘못된 예 — Book에 cascade를 걸면 안 됨
@Entity
public class LoanRecord {
    @ManyToOne(fetch = FetchType.LAZY,
               cascade = CascadeType.REMOVE) // ← 위험!
    @JoinColumn(name = "book_id")
    private Book book;
}

// Member 삭제 시 cascade.ALL로 LoanRecord 삭제
// LoanRecord 삭제 시 cascade.REMOVE로 Book까지 삭제됨 → 의도치 않은 도서 삭제!
em.remove(member);
```

`@ManyToOne` 쪽에는 cascade를 거의 사용하지 않는다. cascade는 주로 `@OneToMany` 쪽, 즉 부모에서 자식 방향으로만 적용한다.

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1 Cascade: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate Cascade: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#pc-cascade>
