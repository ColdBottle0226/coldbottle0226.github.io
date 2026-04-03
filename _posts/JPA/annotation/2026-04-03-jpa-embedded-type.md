---
title: 임베디드 타입
date: 2026-04-03 09:30:00 +0900
categories: [JPA, 엔티티 어노테이션]
order: 2
tags: [JPA, 엔티티 어노테이션, Embeddable, Embedded, AttributeOverride, 값타입]
---

## 📗 1. 왜 임베디드 타입이 필요한가

---

엔티티를 설계하다 보면 특정 필드들이 논리적으로 하나의 개념을 나타내는 경우가 있다. 주소를 예로 들면 `city`, `street`, `zipcode`는 각각의 필드이지만 이 셋이 합쳐야 "주소"라는 개념이 된다.

이 필드들을 엔티티 안에 모두 나열하면 엔티티가 비대해지고 재사용도 어렵다.

```java
// 나쁜 예 — 모든 필드를 엔티티에 직접 나열
@Entity
public class Member extends BaseEntity {
    private Long id;
    private String name;

    // 집 주소
    private String homeCity;
    private String homeStreet;
    private String homeZipcode;

    // 직장 주소
    private String workCity;
    private String workStreet;
    private String workZipcode;

    // 주소 관련 메서드가 Member에 몰림
    public String getHomeFullAddress() {
        return homeCity + " " + homeStreet + " (" + homeZipcode + ")";
    }
}
```

임베디드 타입을 사용하면 이 개념들을 별도의 클래스로 응집시키고, 엔티티는 그 타입을 포함하는 형태로 만들 수 있다.

---

## 📗 2. @Embeddable / @Embedded

---

### 📌 임베디드 타입 선언

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

    // 주소 관련 비즈니스 로직을 여기에 응집
    public String getFullAddress() {
        return city + " " + street + " (" + zipcode + ")";
    }
}
```

### 📌 엔티티에 적용

```java
@Entity
public class Member extends BaseEntity {
    ...

    @Embedded
    private Address homeAddress;   // DB: city, street, zipcode 컬럼으로 펼쳐짐
}
```

임베디드 타입은 자바 코드에서는 별도 클래스이지만 DB에서는 엔티티 테이블의 컬럼으로 펼쳐진다. `member` 테이블에 `city`, `street`, `zipcode` 컬럼이 그대로 들어간다.

생성되는 DDL을 확인하면 다음과 같다.

```sql
CREATE TABLE member (
    member_id  BIGINT NOT NULL AUTO_INCREMENT,
    name       VARCHAR(50) NOT NULL,
    city       VARCHAR(50) NOT NULL,
    street     VARCHAR(100) NOT NULL,
    zipcode    VARCHAR(10) NOT NULL,
    ...
    PRIMARY KEY (member_id)
);
```

---

## 📗 3. @AttributeOverride — 같은 임베디드 타입을 두 번 쓸 때

---

같은 임베디드 타입을 하나의 엔티티에서 두 번 사용하면 컬럼명이 중복된다. `@AttributeOverride`로 컬럼명을 재정의한다.

```java
@Entity
public class Member extends BaseEntity {
    ...

    @Embedded
    private Address homeAddress;    // city, street, zipcode 컬럼 사용

    @Embedded
    @AttributeOverrides({           // 컬럼명 재정의
        @AttributeOverride(name = "city",    column = @Column(name = "work_city")),
        @AttributeOverride(name = "street",  column = @Column(name = "work_street")),
        @AttributeOverride(name = "zipcode", column = @Column(name = "work_zipcode"))
    })
    private Address workAddress;    // work_city, work_street, work_zipcode 컬럼 사용
}
```

생성되는 DDL:

```sql
CREATE TABLE member (
    member_id   BIGINT NOT NULL AUTO_INCREMENT,
    city        VARCHAR(50) NOT NULL,    -- homeAddress
    street      VARCHAR(100) NOT NULL,
    zipcode     VARCHAR(10) NOT NULL,
    work_city   VARCHAR(50) NOT NULL,    -- workAddress
    work_street VARCHAR(100) NOT NULL,
    work_zipcode VARCHAR(10) NOT NULL,
    ...
);
```

---

## 📗 4. 임베디드 타입의 특성과 주의사항

---

### 📌 값 타입이다 — 공유하면 위험하다

임베디드 타입은 엔티티처럼 독립적인 생명주기를 갖지 않는다. 엔티티에 종속된 **값 타입**이다.

임베디드 타입 인스턴스를 여러 엔티티에서 공유하면 한쪽에서 수정할 때 다른 쪽도 영향을 받는 부작용(Side Effect)이 생긴다.

```java
Address address = new Address("서울", "종로 1가", "03154");

Member member1 = new Member("홍길동", 30, "hong@test.com");
Member member2 = new Member("김철수", 25, "kim@test.com");

member1.setHomeAddress(address); // 같은 인스턴스 공유
member2.setHomeAddress(address); // 같은 인스턴스 공유

// member1의 city를 변경하면
address.setCity("부산");
// member2의 homeAddress.city도 "부산"으로 바뀐다 → 버그!
```

이를 방지하려면 불변(Immutable)으로 설계하거나, 공유 시 반드시 복사본을 사용해야 한다.

```java
// 올바른 방법 — 새 인스턴스를 생성해서 전달
member1.setHomeAddress(new Address("서울", "종로 1가", "03154"));
member2.setHomeAddress(new Address("서울", "종로 1가", "03154")); // 별도 인스턴스
```

가장 안전한 방법은 setter를 없애고 **불변 객체**로 만드는 것이다. 수정이 필요하면 새 인스턴스를 생성해서 교체한다.

```java
@Embeddable
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Address {
    private String city;
    private String street;
    private String zipcode;

    // 생성자로만 값 설정. setter 없음 → 불변 객체
    public Address(String city, String street, String zipcode) {
        this.city = city;
        this.street = street;
        this.zipcode = zipcode;
    }

    // 수정이 필요하면 새 인스턴스 반환
    public Address withCity(String city) {
        return new Address(city, this.street, this.zipcode);
    }
}

// 엔티티에서 사용
member.changeHomeAddress(homeAddress.withCity("부산")); // 새 인스턴스로 교체
```

### 📌 null 처리

임베디드 타입 자체가 null이면 매핑된 모든 컬럼이 null로 저장된다.

```java
member.setHomeAddress(null);
// member 테이블의 city, street, zipcode 모두 null로 저장됨
```

---

## 📗 5. 임베디드 타입의 장점

---

**비즈니스 로직 응집**: `Address` 클래스 안에 주소와 관련된 메서드를 모을 수 있다. `getFullAddress()`, `isSameCity()` 등을 Member가 아닌 Address에 두면 응집도가 높아진다.

**재사용성**: `Member`, `Store`, `DeliveryInfo` 등 여러 엔티티에서 `Address` 임베디드 타입을 공유할 수 있다.

**명확한 의미 표현**: `homeCity`, `homeStreet` 같이 접두어로 구분하는 것보다 `homeAddress.city`, `homeAddress.street`처럼 접근하는 것이 더 의미가 명확하다.

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1 Embeddable: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate Embeddable: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#embeddables>
