---
title: 기본 어노테이션
date: 2026-04-03 09:10:00 +0900
categories: [JPA, 엔티티 어노테이션]
order: 0
tags: [JPA, 엔티티 어노테이션, Entity, Table, Id, GeneratedValue, Column, Transient]
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
@NoArgsConstructor(access = AccessLevel.PROTECTED) // protected 기본 생성자 자동 생성
public class Member {
    ...
    // 의미 있는 생성자는 별도로 작성
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

`allocationSize = 50`이 중요한 성능 최적화 포인트다. 시퀀스를 1씩 증가시키면 엔티티를 저장할 때마다 DB에 시퀀스 조회 요청이 발생한다. `allocationSize = 50`으로 설정하면 한 번의 시퀀스 조회로 50개의 PK를 미리 확보해서 메모리에서 사용한다. DB 왕복을 50분의 1로 줄이는 효과가 있다.

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

`insertable = false, updatable = false` 조합은 읽기 전용 컬럼에 사용한다. 예를 들어 다른 테이블의 컬럼을 읽기만 하는 경우에 활용한다.

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

##  6. 전체 적용 예시

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

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate 6 Annotations: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#annotations>
