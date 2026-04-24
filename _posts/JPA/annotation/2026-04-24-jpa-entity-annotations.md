---
title: JPA 엔티티 어노테이션
date: 2026-04-24 09:00:00 +0900
categories: [JPA, 엔티티 어노테이션]
order: 2
tags: [JPA, 엔티티 어노테이션, Entity, Table, Id, GeneratedValue, Column, Transient, Enumerated, Temporal, Lob, Convert, Converter, Embeddable, Embedded, AttributeOverride, 값타입, Inheritance, MappedSuperclass, DiscriminatorColumn, SingleTable, Joined, Auditing, CreatedDate, LastModifiedDate, CreatedBy, EnableJpaAuditing, AuditorAware]
---

##  1. @Entity

---

`@Entity`는 해당 클래스가 JPA가 관리하는 엔티티임을 선언하는 어노테이션이다. 이 어노테이션이 붙어야만 JPA가 이 클래스를 인식하고 DB 테이블과 매핑한다.

### 📌 반드시 지켜야 할 제약

**기본 생성자가 필수다.**

JPA는 DB에서 조회한 결과를 엔티티 객체로 변환할 때 내부적으로 리플렉션(Reflection)을 사용한다. 이 과정에서 기본 생성자(인자 없는 생성자)로 객체를 먼저 만들고, 그 다음에 필드에 값을 채워넣는다. 기본 생성자가 없으면 JPA가 객체를 생성할 수 없어 예외가 발생한다. `public` 또는 `protected`이어야 한다.

`protected`를 권장하는 이유는 외부에서 기본 생성자로 엔티티를 만드는 것을 막기 위해서다. 엔티티는 의미 있는 값을 가진 상태로 생성되어야 한다. Lombok의 `@NoArgsConstructor(access = AccessLevel.PROTECTED)`를 사용하면 편리하다.

```java
@Entity
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Member {
    ...
    public Member(String name, int age, String email) {
        this.name = name;
        this.age = age;
        this.email = email;
    }
}
```

**`final`, `enum`, `interface`, `inner class`에는 `@Entity`를 붙일 수 없다.**

Hibernate가 프록시 객체를 만들기 위해 엔티티를 상속하는데, `final` 클래스는 상속이 불가능하기 때문이다. 저장할 필드에도 `final`을 사용하면 안 된다.

> 💡 name 속성으로 엔티티 이름을 변경할 수 있다. `@Entity(name = "Member")`. 기본값은 클래스명이다. 엔티티 이름은 JPQL에서 사용되므로 혼동을 피하기 위해 기본값을 그대로 쓰는 것이 좋다.

---

##  2. @Table

---

`@Table`은 엔티티가 매핑될 테이블을 지정한다. 생략하면 클래스 이름이 테이블 이름으로 사용된다.

```java
@Entity
@Table(
    name = "member",
    schema = "public",
    uniqueConstraints = {
        @UniqueConstraint(
            name = "uk_member_email",
            columnNames = {"email"}
        ),
        @UniqueConstraint(
            name = "uk_member_name_age",
            columnNames = {"name", "age"}
        )
    },
    indexes = {
        @Index(name = "idx_member_name", columnList = "name"),
        @Index(name = "idx_member_created", columnList = "created_at DESC")
    }
)
public class Member extends BaseEntity { ... }
```

`@Column(unique = true)`로도 유니크 제약을 줄 수 있지만 이 방식은 제약조건 이름이 자동 생성되어 알아보기 어렵다. `@Table`의 `uniqueConstraints`로 이름을 명시하는 것이 DB 관리 측면에서 훨씬 좋다.

---

##  3. @Id와 @GeneratedValue

---

`@Id`는 PK 필드를 지정한다. `@GeneratedValue`는 PK 생성 전략을 설정한다.

### 📌 전략 4가지 비교

| 전략 | 동작 방식 | 쓰기 지연 | 적합한 DB |
|---|---|---|---|
| IDENTITY | DB의 auto_increment 사용. persist 시 즉시 INSERT | 불가 | MySQL, MariaDB |
| SEQUENCE | DB 시퀀스 객체에서 PK 채번 후 INSERT | 가능 | Oracle, PostgreSQL |
| TABLE | PK 전용 테이블로 채번. Lock 발생 위험 | 가능 | 모든 DB (비권장) |
| AUTO | DB 방언에 따라 자동 선택 | DB에 따라 다름 | 기본값 |

**IDENTITY 전략** — MySQL 환경에서 가장 많이 사용한다.

```java
@Id
@GeneratedValue(strategy = GenerationType.IDENTITY)
@Column(name = "member_id")
private Long id;
```

> 💡 IDENTITY 전략은 DB가 INSERT 후 PK를 생성하므로, JPA가 PK를 알려면 INSERT가 실행되어야 한다. 이 때문에 `em.persist()` 시점에 즉시 INSERT SQL이 실행된다. 쓰기 지연이 적용되지 않는다.

**SEQUENCE 전략** — PostgreSQL, Oracle 환경에서 사용한다. 배치 INSERT 시 성능 최적화에 유리하다.

```java
@Entity
@SequenceGenerator(
    name = "member_seq_generator",
    sequenceName = "member_seq",
    initialValue = 1,
    allocationSize = 50        // 한 번에 50개씩 채번 (성능 최적화)
)
public class Member {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE,
                    generator = "member_seq_generator")
    private Long id;
}
```

`allocationSize = 50`이 중요한 성능 최적화 포인트다. 한 번의 시퀀스 조회로 50개의 PK를 미리 확보해서 메모리에서 사용한다. DB 왕복을 50분의 1로 줄이는 효과가 있다.

---

##  4. @Column

---

`@Column`은 필드를 테이블 컬럼에 매핑하는 어노테이션이다. 생략하면 필드명이 컬럼명으로 사용된다.

```java
@Column(
    name = "member_name",
    nullable = false,              // NOT NULL 제약. 기본값: true (nullable)
    length = 50,                   // VARCHAR 길이. 기본값: 255
    unique = false,                // 유니크 제약 (이름 지정 안 됨 → @Table 권장)
    insertable = true,             // INSERT SQL에 포함 여부
    updatable = true,              // UPDATE SQL에 포함 여부
    columnDefinition = "VARCHAR(50) DEFAULT '이름없음'",
    precision = 10,                // 숫자 전체 자릿수 (BigDecimal 등)
    scale = 2                      // 소수점 이하 자릿수
)
private String name;
```

`insertable = false, updatable = false` 조합은 읽기 전용 컬럼에 사용한다.

---

##  5. @Transient

---

`@Transient`가 붙은 필드는 DB 컬럼과 매핑되지 않는다. 엔티티에 임시로 값을 보관해야 할 때, 계산된 값을 갖는 필드가 필요할 때 사용한다.

```java
@Transient
private String tempDisplayName; // DB 저장 안 함. 비즈니스 로직에서만 사용

@Transient
private boolean isSelected;     // 화면 표시용 임시 상태
```

> 💡 `@Transient` 필드는 영속성 컨텍스트 입장에서 아예 존재하지 않는 필드다. 더티 체킹 대상도 아니고, 스냅샷에도 포함되지 않는다.

---

##  6. 전체 기본 어노테이션 적용 예시

---

```java
@Entity
@Table(
    name = "member",
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_member_email", columnNames = {"email"})
    }
)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Member extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "member_id")
    private Long id;

    @Column(name = "member_name", nullable = false, length = 50)
    private String name;

    @Column(nullable = false)
    private int age;

    @Column(nullable = false, length = 100)
    private String email;

    @Transient
    private String displayLabel; // 화면 표시용, DB 저장 안 함

    public Member(String name, int age, String email) {
        this.name = name;
        this.age = age;
        this.email = email;
    }

    public void updateName(String name) { this.name = name; }
    public void updateAge(int age) { this.age = age; }
}
```

---

##  7. @Enumerated

---

자바의 `enum` 타입을 DB 컬럼에 매핑한다. 두 가지 방식이 있으며 **반드시 `STRING` 방식을 사용해야 한다.**

**ORDINAL 방식 — 절대 사용하지 말 것**

```java
@Enumerated(EnumType.ORDINAL)
private MemberStatus status;
// DB에 0, 1, 2 같은 순서 정수로 저장됨
```

ORDINAL의 위험성: `ACTIVE(0), INACTIVE(1), BANNED(2)`로 데이터가 저장된 상태에서 중간에 `PENDING`을 추가해서 `ACTIVE(0), PENDING(1), INACTIVE(2), BANNED(3)`이 되면, 기존 DB에 `1`로 저장된 INACTIVE 데이터가 이제 PENDING으로 읽힌다. 운영 중인 서비스에서 이 버그가 발생하면 전체 데이터가 잘못된 값으로 읽히는 심각한 장애로 이어진다.

**STRING 방식 — 항상 이것을 사용**

```java
@Enumerated(EnumType.STRING)
private MemberStatus status;
// DB에 "ACTIVE", "INACTIVE", "BANNED" 문자열로 저장됨
// 중간에 enum 항목을 추가해도 기존 데이터에 영향 없음
```

> 💡 STRING 방식은 저장 공간을 조금 더 쓰지만 안전하다. 실무에서 ORDINAL은 절대 사용하지 않는다.

---

##  8. @Temporal

---

Java 8 이전의 `java.util.Date`, `java.util.Calendar` 타입에 사용했다. **Spring Boot 3.x (Hibernate 6.x)에서는 @Temporal이 필요 없다.** `LocalDate`, `LocalDateTime`, `LocalTime`, `Instant`, `ZonedDateTime` 등 Java 8 날짜/시간 타입을 별도 설정 없이 바로 사용할 수 있다.

```java
// Java 8+ 방식 — @Temporal 불필요
private LocalDate birthDate;       // DB: DATE
private LocalTime loginTime;       // DB: TIME
private LocalDateTime createdAt;   // DB: DATETIME
private Instant eventAt;           // DB: TIMESTAMP (타임존 정보 포함)
```

---

##  9. @Lob

---

대용량 데이터를 저장할 때 사용한다. 필드 타입에 따라 자동으로 CLOB 또는 BLOB으로 매핑된다.

```java
@Lob
private String content;        // String → CLOB (대용량 텍스트)

@Lob
private byte[] thumbnailImage; // byte[] → BLOB (바이너리 데이터)
```

> 💡 실무에서는 이미지나 파일을 DB에 직접 저장하는 것보다 S3 같은 외부 스토리지에 저장하고 URL을 DB에 저장하는 방식이 더 일반적이다. `@Lob`은 실제로 대용량이어야 할 때만 사용하고, 남용하면 성능과 DB 용량에 문제가 생긴다.

---

##  10. @Convert / @Converter

---

JPA의 기본 타입 변환으로 처리할 수 없는 경우 커스텀 변환 로직을 작성할 수 있다. `AttributeConverter`를 구현해서 자바 타입 ↔ DB 타입 간 변환을 정의한다.

활용 예시: Boolean → "Y"/"N" 변환, List → JSON 문자열 변환, 암호화된 값 저장/복원 등.

```java
@Converter
public class BooleanToYNConverter implements AttributeConverter<Boolean, String> {

    @Override
    public String convertToDatabaseColumn(Boolean attribute) {
        return (attribute != null && attribute) ? "Y" : "N";
    }

    @Override
    public Boolean convertToEntityAttribute(String dbData) {
        return "Y".equalsIgnoreCase(dbData);
    }
}

@Convert(converter = BooleanToYNConverter.class)
private Boolean isActive; // DB에는 "Y"/"N"으로 저장됨
```

`@Converter(autoApply = true)`를 설정하면 해당 타입의 모든 필드에 자동으로 적용된다.

---

##  11. 임베디드 타입 — @Embeddable / @Embedded

---

### 📌 왜 임베디드 타입이 필요한가

특정 필드들이 논리적으로 하나의 개념을 나타내는 경우가 있다. 주소를 예로 들면 `city`, `street`, `zipcode`는 각각의 필드이지만 이 셋이 합쳐야 "주소"라는 개념이 된다. 임베디드 타입을 사용하면 이 개념들을 별도의 클래스로 응집시킬 수 있다.

```java
@Embeddable
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Address {

    @Column(nullable = false, length = 50)
    private String city;

    @Column(nullable = false, length = 100)
    private String street;

    @Column(nullable = false, length = 10)
    private String zipcode;

    public Address(String city, String street, String zipcode) {
        this.city = city;
        this.street = street;
        this.zipcode = zipcode;
    }

    public String getFullAddress() {
        return city + " " + street + " (" + zipcode + ")";
    }
}

@Entity
public class Member extends BaseEntity {
    @Embedded
    private Address homeAddress;   // DB: city, street, zipcode 컬럼으로 펼쳐짐
}
```

임베디드 타입은 자바 코드에서는 별도 클래스이지만 DB에서는 엔티티 테이블의 컬럼으로 펼쳐진다.

### 📌 @AttributeOverride — 같은 임베디드 타입을 두 번 쓸 때

같은 임베디드 타입을 하나의 엔티티에서 두 번 사용하면 컬럼명이 중복된다. `@AttributeOverride`로 컬럼명을 재정의한다.

```java
@Entity
public class Member extends BaseEntity {

    @Embedded
    private Address homeAddress;

    @Embedded
    @AttributeOverrides({
        @AttributeOverride(name = "city",    column = @Column(name = "work_city")),
        @AttributeOverride(name = "street",  column = @Column(name = "work_street")),
        @AttributeOverride(name = "zipcode", column = @Column(name = "work_zipcode"))
    })
    private Address workAddress;
}
```

### 📌 임베디드 타입의 특성과 주의사항

임베디드 타입은 엔티티에 종속된 **값 타입**이다. 같은 인스턴스를 여러 엔티티에서 공유하면 한쪽에서 수정할 때 다른 쪽도 영향을 받는 부작용(Side Effect)이 생긴다.

가장 안전한 방법은 setter를 없애고 **불변 객체**로 만드는 것이다. 수정이 필요하면 새 인스턴스를 생성해서 교체한다.

```java
// 수정이 필요하면 새 인스턴스 반환
public Address withCity(String city) {
    return new Address(city, this.street, this.zipcode);
}
```

임베디드 타입의 장점은 비즈니스 로직 응집, 재사용성, 명확한 의미 표현이다.

---

##  12. 상속 매핑 — SINGLE_TABLE / JOINED / TABLE_PER_CLASS

---

### 📌 SINGLE_TABLE — 단일 테이블 전략

부모와 모든 자식 클래스의 필드를 하나의 테이블에 모두 넣는다. `dtype` 같은 구분 컬럼(Discriminator)으로 타입을 구분한다.

```java
@Entity
@Inheritance(strategy = InheritanceType.SINGLE_TABLE)
@DiscriminatorColumn(name = "dtype")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public abstract class Item extends BaseEntity {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "item_id")
    private Long id;

    @Column(nullable = false, length = 100)
    private String name;

    private int price;

    protected Item(String name, int price) {
        this.name = name;
        this.price = price;
    }
}

@Entity
@DiscriminatorValue("A")
public class Album extends Item {
    private String artist;

    public Album(String name, int price, String artist) {
        super(name, price);
        this.artist = artist;
    }
}
```

**장점**: 조회 성능이 가장 좋다. JOIN이 없고 단일 테이블 SELECT만으로 처리된다.

**단점**: 다른 타입의 컬럼에 NULL이 허용되어야 한다. 자식 타입이 늘어날수록 테이블이 비대해진다.

### 📌 JOINED — 조인 테이블 전략

부모 테이블과 자식 테이블을 분리한다. 공통 필드는 부모 테이블에, 자식만의 필드는 자식 테이블에 저장한다.

```java
@Entity
@Inheritance(strategy = InheritanceType.JOINED)
@DiscriminatorColumn(name = "dtype")
public abstract class Item extends BaseEntity { ... }
```

Album 저장 시 item 테이블과 album 테이블에 각각 INSERT가 실행된다.

**장점**: 정규화된 테이블 구조를 유지한다. NOT NULL 제약을 자식 테이블 컬럼에 걸 수 있다.

**단점**: 저장 시 INSERT가 두 번 실행된다. 조회 시 JOIN이 필요하다.

> 💡 데이터 무결성이 중요하고 상속 구조가 복잡하지 않다면 JOINED 전략이 일반적으로 더 나은 선택이다.

### 📌 TABLE_PER_CLASS — 구체 테이블 전략 (비권장)

각 자식 클래스마다 독립적인 테이블을 만들고 부모 클래스의 필드를 모두 포함한다. 부모 타입(`Item`)으로 조회할 때 모든 자식 테이블에 UNION ALL이 발생해서 성능이 매우 나쁘다. 사용을 권장하지 않는다.

### 📌 전략 선택 가이드

| 상황 | 권장 전략 |
|---|---|
| 단순하고 성능이 중요 | SINGLE_TABLE |
| 데이터 무결성이 중요, 정규화 필요 | JOINED |
| 공통 필드 공유만 필요 | @MappedSuperclass |
| TABLE_PER_CLASS | 거의 사용 안 함 |

---

##  13. @MappedSuperclass — 공통 필드 상속

---

`@MappedSuperclass`는 상속과 다른 개념이다. 이 클래스 자체는 테이블로 만들지 않고, 공통 필드와 매핑 정보만 자식 엔티티 테이블에 물려준다. 가장 대표적인 사용 사례가 `createdAt`, `updatedAt` 같은 Auditing 필드다.

```java
@Getter
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime updatedAt;
}
```

`@MappedSuperclass`가 붙은 클래스는 `em.find()` 같은 JPA 메서드의 파라미터로 직접 사용할 수 없다. JPA가 관리하는 엔티티가 아니기 때문이다.

| 구분 | @MappedSuperclass | @Inheritance |
|---|---|---|
| 테이블 생성 | 부모 클래스는 테이블 없음 | 전략에 따라 다름 |
| 목적 | 공통 필드/매핑 정보 공유 | 상속 구조를 DB에 표현 |
| em.find() 대상 | 불가 (엔티티 아님) | 가능 |
| 다형성 쿼리 | 불가 | 가능 |

---

##  14. Auditing 어노테이션

---

### 📌 @EnableJpaAuditing 활성화

```java
// @SpringBootApplication 클래스에 직접 붙이면 @WebMvcTest에서 오류 발생 가능
// 별도 @Configuration 클래스로 분리하는 것이 좋다
@Configuration
@EnableJpaAuditing
public class JpaAuditingConfig {
}
```

### 📌 BaseEntity 작성

```java
@Getter
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime updatedAt;
}
```

`@EntityListeners(AuditingEntityListener.class)`가 JPA 이벤트(persist, merge 등)를 감지해서 시간을 자동으로 채워준다.

### 📌 @CreatedDate / @LastModifiedDate 동작 원리

Spring Data JPA의 `AuditingEntityListener`가 JPA의 콜백 어노테이션(`@PrePersist`, `@PreUpdate`)을 내부적으로 활용한다.

- 엔티티가 처음 저장될 때: `createdAt`과 `updatedAt`을 현재 시간으로 설정
- 엔티티가 수정될 때: `updatedAt`만 현재 시간으로 갱신

`@Column(updatable = false)`를 `createdAt`에 붙이는 이유는 Hibernate가 생성하는 UPDATE SQL에 `created_at` 컬럼이 포함되지 않도록 막기 위해서다.

### 📌 @CreatedBy / @LastModifiedBy

누가 생성하고 수정했는지도 자동으로 기록할 수 있다. 현재 로그인한 사용자 정보를 JPA에 제공하는 `AuditorAware` 구현체가 필요하다.

```java
@Configuration
@EnableJpaAuditing(auditorAwareRef = "auditorProvider")
public class AuditConfig {

    @Bean
    public AuditorAware<String> auditorProvider() {
        return () -> Optional.ofNullable(SecurityContextHolder.getContext()
                .getAuthentication())
            .filter(Authentication::isAuthenticated)
            .filter(auth -> !(auth instanceof AnonymousAuthenticationToken))
            .map(Authentication::getName);
    }
}
```

Spring Security를 사용하지 않는 경우는 ThreadLocal에 현재 사용자를 저장하고 꺼내는 방식으로 구현한다.

```java
@Component
public class ThreadLocalAuditorAware implements AuditorAware<String> {

    private static final ThreadLocal<String> currentUser = new ThreadLocal<>();

    public static void setCurrentUser(String userId) { currentUser.set(userId); }
    public static void clear() { currentUser.remove(); }

    @Override
    public Optional<String> getCurrentAuditor() {
        return Optional.ofNullable(currentUser.get());
    }
}
```

BaseEntity에 `@CreatedBy`, `@LastModifiedBy`를 추가한다.

```java
@Getter
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime updatedAt;

    @CreatedBy
    @Column(updatable = false, length = 50)
    private String createdBy;

    @LastModifiedBy
    @Column(length = 50)
    private String lastModifiedBy;
}
```

### 📌 JPA 콜백 어노테이션 — @PrePersist, @PostLoad 등

Auditing 외에도 JPA가 제공하는 콜백 어노테이션을 직접 활용할 수 있다.

| 어노테이션 | 실행 시점 |
|---|---|
| `@PrePersist` | `em.persist()` 호출 직전 |
| `@PostPersist` | `em.persist()` 완료 직후 (flush 후) |
| `@PreUpdate` | UPDATE SQL 실행 직전 |
| `@PostUpdate` | UPDATE SQL 실행 직후 |
| `@PreRemove` | `em.remove()` 호출 직전 |
| `@PostRemove` | `em.remove()` 완료 직후 |
| `@PostLoad` | 엔티티가 1차 캐시 또는 DB에서 로딩된 직후 |

```java
@Entity
public class Member extends BaseEntity {

    @PrePersist
    public void prePersist() {
        System.out.println("Member persist 직전 실행");
    }

    @PostLoad
    public void postLoad() {
        // DB에서 로딩된 직후 실행
        // @Transient 필드 초기화 등에 활용
        this.displayLabel = "[" + this.name + "]";
    }
}
```

### 📌 Auditing 적용 확인

```java
@SpringBootTest
@Transactional
class AuditingTest {

    @Autowired
    private MemberRepository memberRepository;

    @Test
    @DisplayName("저장 시 createdAt, updatedAt 자동 채워짐")
    void auditingTest() throws InterruptedException {
        Member member = new Member("홍길동", 30, "hong@test.com");
        memberRepository.save(member);

        assertThat(member.getCreatedAt()).isNotNull();
        assertThat(member.getUpdatedAt()).isNotNull();

        LocalDateTime beforeUpdate = member.getUpdatedAt();
        Thread.sleep(100);

        member.updateName("김철수");
        memberRepository.saveAndFlush(member);

        assertThat(member.getCreatedAt()).isEqualTo(member.getCreatedAt());
        assertThat(member.getUpdatedAt()).isAfter(beforeUpdate);
    }
}
```

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate 6 Annotations: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#annotations>
- 공식문서 - Hibernate Embeddable: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#embeddables>
- 공식문서 - Hibernate Inheritance: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#entity-inheritance>
- 공식문서 - Spring Data JPA Auditing: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#auditing>
- 공식문서 - Hibernate AttributeConverter: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#basic-jpa-convert>
