---
title: 상속 매핑과 공통 필드
date: 2026-04-03 09:40:00 +0900
categories: [JPA, 엔티티 어노테이션]
tags: [JPA, 엔티티 어노테이션, Inheritance, MappedSuperclass, DiscriminatorColumn, SingleTable, Joined]
---

## 📗 1. 왜 상속 매핑이 필요한가

---

객체지향에서는 상속이 자연스러운 개념이다. 그런데 RDB에는 상속 개념이 없다. JPA는 이 불일치를 3가지 전략으로 해결한다.

```java
// 객체 모델
abstract class Item { Long id; String name; int price; }
class Album extends Item { String artist; }
class Movie extends Item { String director; }
class Book extends Item { String author; }
```

이 구조를 RDB에 어떻게 저장할 것인가가 상속 매핑 전략의 핵심 결정이다.

---

## 📗 2. SINGLE_TABLE — 단일 테이블 전략

---

부모와 모든 자식 클래스의 필드를 하나의 테이블에 모두 넣는다. `dtype` 같은 구분 컬럼(Discriminator)으로 타입을 구분한다.

```java
@Entity
@Inheritance(strategy = InheritanceType.SINGLE_TABLE) // 기본값
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
@DiscriminatorValue("A") // dtype 컬럼에 저장될 값
public class Album extends Item {
    private String artist;

    public Album(String name, int price, String artist) {
        super(name, price);
        this.artist = artist;
    }
}

@Entity
@DiscriminatorValue("M")
public class Movie extends Item {
    private String director;
    private String actor;
}

@Entity
@DiscriminatorValue("B")
public class Book extends Item {
    private String author;
    private String isbn;
}
```

생성되는 DDL:

```sql
CREATE TABLE item (
    dtype    VARCHAR(31) NOT NULL,  -- 구분 컬럼
    item_id  BIGINT NOT NULL AUTO_INCREMENT,
    name     VARCHAR(100) NOT NULL,
    price    INT,
    artist   VARCHAR(255),          -- Album용. 다른 타입에서는 NULL
    director VARCHAR(255),          -- Movie용
    actor    VARCHAR(255),          -- Movie용
    author   VARCHAR(255),          -- Book용
    isbn     VARCHAR(255),          -- Book용
    ...
    PRIMARY KEY (item_id)
);
```

**장점**

- 조회 성능이 가장 좋다. JOIN이 없고 단일 테이블 SELECT만으로 처리된다.
- 쿼리가 단순하다.

**단점**

- 다른 타입의 컬럼에 NULL이 허용되어야 한다. NOT NULL 제약을 걸 수 없다.
- 자식 타입이 늘어날수록 테이블이 비대해진다.
- NULL 컬럼이 많으면 저장 공간이 낭비된다.

---

## 📗 3. JOINED — 조인 테이블 전략

---

부모 테이블과 자식 테이블을 분리한다. 공통 필드는 부모 테이블에, 자식만의 필드는 자식 테이블에 저장한다. 조회 시 JOIN이 필요하다.

```java
@Entity
@Inheritance(strategy = InheritanceType.JOINED)
@DiscriminatorColumn(name = "dtype")
public abstract class Item extends BaseEntity { ... }

@Entity
@DiscriminatorValue("A")
public class Album extends Item {
    private String artist;
}
```

생성되는 DDL:

```sql
CREATE TABLE item (
    dtype   VARCHAR(31) NOT NULL,
    item_id BIGINT NOT NULL AUTO_INCREMENT,
    name    VARCHAR(100) NOT NULL,
    price   INT,
    ...
    PRIMARY KEY (item_id)
);

CREATE TABLE album (
    item_id BIGINT NOT NULL,  -- item 테이블의 PK를 FK로 공유
    artist  VARCHAR(255),
    PRIMARY KEY (item_id),
    FOREIGN KEY (item_id) REFERENCES item(item_id)
);
```

Album 저장 시 item 테이블과 album 테이블에 각각 INSERT가 실행된다.

```sql
INSERT INTO item (dtype, name, price, ...) VALUES ('A', '보헤미안 랩소디', 15000, ...);
INSERT INTO album (item_id, artist) VALUES (1, '퀸');
```

Album 조회 시 JOIN이 발생한다.

```sql
SELECT i.*, a.artist
FROM item i
INNER JOIN album a ON i.item_id = a.item_id
WHERE i.item_id = 1;
```

**장점**

- 정규화된 테이블 구조를 유지한다.
- NOT NULL 제약을 자식 테이블 컬럼에 걸 수 있다.
- 외래 키 참조 무결성을 활용할 수 있다.

**단점**

- 저장 시 INSERT가 두 번 실행된다.
- 조회 시 JOIN이 필요하다.
- 쿼리가 복잡해진다.

> 💡 실무에서는 데이터 무결성이 중요하고 상속 구조가 복잡하지 않다면 JOINED 전략이 일반적으로 더 나은 선택이다. 상속 구조가 단순하고 데이터 양이 많다면 SINGLE_TABLE도 좋은 선택이다.

---

## 📗 4. TABLE_PER_CLASS — 구체 테이블 전략

---

각 자식 클래스마다 독립적인 테이블을 만들고, 부모 클래스의 필드를 모두 포함한다. **사용을 권장하지 않는다.**

```java
@Entity
@Inheritance(strategy = InheritanceType.TABLE_PER_CLASS)
public abstract class Item extends BaseEntity { ... }
```

```sql
-- Album, Movie, Book 각각 독립 테이블. 부모 필드 포함
CREATE TABLE album  (item_id, name, price, artist, ...);
CREATE TABLE movie  (item_id, name, price, director, actor, ...);
CREATE TABLE book   (item_id, name, price, author, isbn, ...);
```

부모 타입(`Item`)으로 조회할 때 모든 자식 테이블에 UNION ALL이 발생해서 성능이 매우 나쁘다.

```sql
-- Item 전체 조회 시
SELECT * FROM album
UNION ALL
SELECT * FROM movie
UNION ALL
SELECT * FROM book;
```

상속 구조를 이용한 다형성 조회가 많다면 이 전략은 피해야 한다.

---

## 📗 5. @MappedSuperclass — 공통 필드 상속

---

`@MappedSuperclass`는 상속과 다른 개념이다. 이 클래스 자체는 테이블로 만들지 않고, 공통 필드와 매핑 정보만 자식 엔티티 테이블에 물려준다.

가장 대표적인 사용 사례가 모든 테이블에 공통으로 필요한 `createdAt`, `updatedAt` 같은 감사(Auditing) 필드다.

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

@Entity
public class Member extends BaseEntity {
    // member 테이블에 created_at, updated_at 컬럼이 자동 포함됨
}

@Entity
public class Order extends BaseEntity {
    // orders 테이블에 created_at, updated_at 컬럼이 자동 포함됨
}
```

**`@MappedSuperclass`와 `@Inheritance`의 차이**

| 구분 | @MappedSuperclass | @Inheritance |
|---|---|---|
| 테이블 생성 | 부모 클래스는 테이블 없음 | 테이블 생성 전략에 따라 다름 |
| 목적 | 공통 필드/매핑 정보 공유 | 상속 구조를 DB에 표현 |
| em.find() 대상 | 불가 (엔티티 아님) | 가능 |
| 다형성 쿼리 | 불가 | 가능 |

`@MappedSuperclass`가 붙은 클래스는 `em.find()` 같은 JPA 메서드의 파라미터로 직접 사용할 수 없다. JPA가 관리하는 엔티티가 아니기 때문이다. 추상 클래스(`abstract`)로 만들어서 직접 인스턴스 생성을 막는 것이 좋다.

---

## 📗 6. 전략 선택 가이드

---

| 상황 | 권장 전략 |
|---|---|
| 단순하고 성능이 중요 | SINGLE_TABLE |
| 데이터 무결성이 중요, 정규화 필요 | JOINED |
| 다형성 조회가 많음 | SINGLE_TABLE 또는 JOINED |
| 공통 필드 공유만 필요 | @MappedSuperclass |
| TABLE_PER_CLASS | 거의 사용 안 함 |

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1 Inheritance: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate Inheritance: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#entity-inheritance>
