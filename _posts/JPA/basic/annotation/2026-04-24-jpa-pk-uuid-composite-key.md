---
title: "JPA PK 전략 완전 정복 — UUID · 복합키 · @EmbeddedId"
date: 2026-04-24 10:00:00 +0900
categories: []
tags: [JPA, 엔티티 어노테이션, GeneratedValue, UUID, IdClass, EmbeddedId, 복합키, Persistable]
---

##  1. UUID PK — Hibernate 6.x 공식 지원

---

Spring Boot 3.x (Hibernate 6.x)부터 UUID를 PK로 사용하는 것이 공식 지원된다.

```java
@Entity
public class Book extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "book_id", updatable = false, nullable = false)
    private UUID id;
}
```

UUID 전략은 DB가 아닌 **애플리케이션 레벨**에서 PK를 생성한다. 덕분에 `em.persist()` 직전에 UUID를 미리 알 수 있어 IDENTITY 전략과 달리 **쓰기 지연(Batch INSERT)이 가능**하다.

### 📌 UUID vs IDENTITY 비교

| 항목 | IDENTITY | UUID |
|---|---|---|
| PK 생성 주체 | DB (auto_increment) | 애플리케이션 (UUID 생성기) |
| 쓰기 지연 (Batch) | 불가 | 가능 |
| 저장 공간 | 8 bytes (BIGINT) | 16 bytes (BINARY(16)) |
| 인덱스 단편화 | 없음 (순차) | 있음 (랜덤) → UUID v7로 완화 가능 |
| 분산 환경 | PK 충돌 위험 | 충돌 없음 |
| 가독성 | 좋음 | 낮음 |

대량 INSERT가 빈번한 경우나 MSA 분산 환경에서는 UUID가 유리하다. 단일 서버 + 순차 조회 중심이라면 IDENTITY가 여전히 좋은 선택이다.

### 📌 UUID를 String으로 저장하는 경우

```java
// Hibernate 6.x — UUID 타입 그대로 사용 (권장)
@Id
@GeneratedValue(strategy = GenerationType.UUID)
private UUID id;

// String으로 받고 싶은 경우
@Id
@UuidGenerator
@Column(columnDefinition = "VARCHAR(36)")
private String id;
```

DB에 저장되는 형태는 Hibernate의 `ImplicitNamingStrategy` 및 `ColumnDefinition`에 따라 `BINARY(16)` 또는 `VARCHAR(36)`이 된다. 조회 성능을 위해 `BINARY(16)` 저장이 권장된다.

### 📌 Persistable과 isNew() — UUID PK의 함정

UUID처럼 PK를 직접 할당하는 경우 `SimpleJpaRepository.save()`의 `isNew()` 판단이 항상 `false`가 되어 `persist` 대신 `merge`가 호출된다. merge는 내부에서 불필요한 SELECT를 먼저 실행하므로 성능 낭비가 생긴다.

`Persistable` 인터페이스를 구현해서 해결한다.

```java
@Entity
@EntityListeners(AuditingEntityListener.class)
public class Book implements Persistable<UUID> {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @Override
    public UUID getId() { return id; }

    // createdAt이 null이면 신규 엔티티로 판단
    @Override
    public boolean isNew() { return createdAt == null; }
}
```

---

##  2. 복합키 — @IdClass

---

복합키(Composite Key)는 두 개 이상의 컬럼이 합쳐져 PK를 이루는 경우다. JPA는 `@IdClass`와 `@EmbeddedId` 두 가지 방식을 지원한다.

`@IdClass`는 복합키 클래스를 엔티티 외부에 별도로 정의하고, 엔티티에는 각 PK 필드를 `@Id`로 선언하는 방식이다.

### 📌 복합키 클래스 제약 조건

- `Serializable` 구현 필수
- 기본 생성자 필수
- `equals()`, `hashCode()` 구현 필수
- PK 클래스가 `public`이어야 함

### 📌 @IdClass 코드 예시

```java
// 1. 복합키 클래스 (PK 식별자 역할)
public class LoanRecordId implements Serializable {

    private Long memberId;
    private Long bookId;

    public LoanRecordId() {}

    public LoanRecordId(Long memberId, Long bookId) {
        this.memberId = memberId;
        this.bookId = bookId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof LoanRecordId)) return false;
        LoanRecordId that = (LoanRecordId) o;
        return Objects.equals(memberId, that.memberId)
            && Objects.equals(bookId, that.bookId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(memberId, bookId);
    }
}

// 2. 엔티티 — @IdClass 선언 + 각 PK 필드에 @Id
@Entity
@IdClass(LoanRecordId.class)
@Table(name = "loan_record")
public class LoanRecord extends BaseEntity {

    @Id
    @Column(name = "member_id")
    private Long memberId;

    @Id
    @Column(name = "book_id")
    private Long bookId;

    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    private LoanStatus status;

    private LocalDate loanDate;
    private LocalDate dueDate;
}
```

### 📌 @IdClass 조회 방법

```java
// 복합키로 조회
LoanRecordId id = new LoanRecordId(1L, 2L);
LoanRecord record = em.find(LoanRecord.class, id);

// Spring Data JPA Repository
public interface LoanRecordRepository extends JpaRepository<LoanRecord, LoanRecordId> {
    List<LoanRecord> findByMemberId(Long memberId);
}
```

---

##  3. 복합키 — @EmbeddedId

---

`@EmbeddedId`는 복합키를 `@Embeddable` 클래스로 캡슐화하고, 엔티티에 하나의 필드로 포함시키는 방식이다.

```java
// 1. 복합키 클래스 — @Embeddable
@Embeddable
@Getter
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode
public class LoanRecordId implements Serializable {

    @Column(name = "member_id")
    private Long memberId;

    @Column(name = "book_id")
    private Long bookId;
}

// 2. 엔티티 — @EmbeddedId 사용
@Entity
@Table(name = "loan_record")
public class LoanRecord extends BaseEntity {

    @EmbeddedId
    private LoanRecordId id;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("memberId")   // EmbeddedId의 memberId 필드와 FK를 연결
    @JoinColumn(name = "member_id")
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("bookId")     // EmbeddedId의 bookId 필드와 FK를 연결
    @JoinColumn(name = "book_id")
    private Book book;

    @Enumerated(EnumType.STRING)
    private LoanStatus status;

    private LocalDate loanDate;
}
```

`@MapsId`는 `@EmbeddedId` 내부의 특정 필드를 연관관계 FK와 연결해주는 어노테이션이다. 이 설정이 없으면 `member_id` 컬럼이 중복으로 생성되는 문제가 발생한다.

### 📌 @EmbeddedId 조회 방법

```java
// 복합키로 조회
LoanRecordId id = new LoanRecordId(1L, 2L);
LoanRecord record = em.find(LoanRecord.class, id);

// JPQL에서 사용 — 내부 필드로 접근
List<LoanRecord> records = em.createQuery(
    "SELECT lr FROM LoanRecord lr WHERE lr.id.memberId = :memberId",
    LoanRecord.class)
    .setParameter("memberId", 1L)
    .getResultList();
```

---

##  4. @IdClass vs @EmbeddedId 비교

---

| 항목 | @IdClass | @EmbeddedId |
|---|---|---|
| PK 클래스 위치 | 엔티티 외부 별도 클래스 | @Embeddable 클래스 |
| 엔티티 필드 선언 | 각 PK 필드에 @Id 반복 | @EmbeddedId 하나 |
| JPQL 접근 | `lr.memberId` | `lr.id.memberId` |
| @MapsId 필요 여부 | 불필요 | 연관관계와 함께 쓸 때 필요 |
| 코드 직관성 | 각 필드를 직접 선언하므로 명시적 | 복합키가 하나로 캡슐화되어 응집도 높음 |
| 실무 선호도 | 단순한 경우 선호 | 비즈니스 의미가 있는 복합키에 선호 |

> 💡 실무에서는 복합키보다 **Surrogate Key(대리키) — IDENTITY 또는 UUID 단일 PK**를 사용하는 것이 훨씬 일반적이다. 복합키는 레거시 DB를 그대로 매핑해야 하거나, 관계 테이블(N:M 중간 테이블)에서 두 FK를 PK로 쓰는 경우에 주로 사용된다.

---

##  5. 정리

---

| 주제 | 핵심 요약 |
|---|---|
| UUID PK | Hibernate 6.x 공식 지원. `GenerationType.UUID`. 쓰기 지연 가능. Persistable로 isNew() 보완 필요 |
| @IdClass | 복합키 클래스 외부 정의. 엔티티에 각 @Id 필드 반복 선언. 단순한 복합키에 적합 |
| @EmbeddedId | 복합키를 @Embeddable로 캡슐화. @MapsId로 연관관계 FK와 연결. 비즈니스 의미 있는 복합키에 적합 |
| 실무 권장 | 복합키보다 단일 Surrogate Key(IDENTITY/UUID) 사용이 훨씬 일반적 |

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1 — Composite Keys: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate 6 — UUID Generator: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#identifiers-generators-uuid>
- 공식문서 - Hibernate 6 — Composite Identifiers: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#identifiers-composite>
