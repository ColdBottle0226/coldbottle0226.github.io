---
title: 타입 변환 어노테이션
date: 2026-04-03 09:20:00 +0900
categories: [JPA, 엔티티 어노테이션]
order: 1
tags: [JPA, 엔티티 어노테이션, Enumerated, Temporal, Lob, Convert, Converter]
---

##  1. @Enumerated

---

자바의 `enum` 타입을 DB 컬럼에 매핑한다. 두 가지 방식이 있으며 **반드시 `STRING` 방식을 사용해야 한다.**

```java
public enum MemberStatus {
    ACTIVE, INACTIVE, BANNED
}
```

**ORDINAL 방식 — 절대 사용하지 말 것**

```java
@Enumerated(EnumType.ORDINAL)
private MemberStatus status;
// DB에 0, 1, 2 같은 순서 정수로 저장됨
```

ORDINAL의 위험성은 다음과 같다. `ACTIVE(0), INACTIVE(1), BANNED(2)`로 데이터가 저장된 상태에서 중간에 `PENDING`을 추가해서 `ACTIVE(0), PENDING(1), INACTIVE(2), BANNED(3)`이 되면, 기존 DB에 `1`로 저장된 INACTIVE 데이터가 이제 PENDING으로 읽힌다. 운영 중인 서비스에서 이 버그가 발생하면 전체 데이터가 잘못된 값으로 읽히는 심각한 장애로 이어진다.

**STRING 방식 — 항상 이것을 사용**

```java
@Enumerated(EnumType.STRING)
private MemberStatus status;
// DB에 "ACTIVE", "INACTIVE", "BANNED" 문자열로 저장됨
// 중간에 enum 항목을 추가해도 기존 데이터에 영향 없음
```

> 💡 STRING 방식은 저장 공간을 조금 더 쓰지만 안전하다. 실무에서 ORDINAL은 절대 사용하지 않는다.

---

##  2. @Temporal

---

자바의 날짜/시간 타입을 DB에 매핑한다. Java 8 이전의 `java.util.Date`, `java.util.Calendar` 타입에 사용했다.

```java
// Java 8 이전 방식 — @Temporal 필요
@Temporal(TemporalType.DATE)      // DB: DATE (날짜만)
private Date birthDate;

@Temporal(TemporalType.TIME)      // DB: TIME (시간만)
private Date loginTime;

@Temporal(TemporalType.TIMESTAMP) // DB: DATETIME/TIMESTAMP
private Date createdAt;
```

**Spring Boot 3.x (Hibernate 6.x)에서는 @Temporal이 필요 없다.**

`LocalDate`, `LocalDateTime`, `LocalTime`, `Instant`, `ZonedDateTime` 등 Java 8 날짜/시간 타입을 별도 설정 없이 바로 사용할 수 있다. 신규 개발에서는 Java 8 타입을 사용한다.

```java
// Java 8+ 방식 — @Temporal 불필요
private LocalDate birthDate;       // DB: DATE
private LocalTime loginTime;       // DB: TIME
private LocalDateTime createdAt;   // DB: DATETIME
private Instant eventAt;           // DB: TIMESTAMP (타임존 정보 포함)
```

---

##  3. @Lob

---

대용량 데이터를 저장할 때 사용한다. 필드 타입에 따라 자동으로 CLOB 또는 BLOB으로 매핑된다.

```java
@Lob
private String content;        // String → CLOB (대용량 텍스트)

@Lob
private byte[] thumbnailImage; // byte[] → BLOB (바이너리 데이터)
```

- `CLOB` (Character Large Object): 수십 KB~수십 MB의 텍스트. 게시글 본문, HTML 내용 등에 사용.
- `BLOB` (Binary Large Object): 이미지, 파일 바이너리 등.

> 💡 실무에서는 이미지나 파일을 DB에 직접 저장하는 것보다 S3 같은 외부 스토리지에 저장하고 URL을 DB에 저장하는 방식이 더 일반적이다. `@Lob`은 실제로 대용량이어야 할 때만 사용하고, 남용하면 성능과 DB 용량에 문제가 생긴다.

---

##  4. @Convert / @Converter

---

JPA의 기본 타입 변환으로 처리할 수 없는 경우 커스텀 변환 로직을 작성할 수 있다. `AttributeConverter`를 구현해서 자바 타입 ↔ DB 타입 간 변환을 정의한다.

활용 예시로는 Boolean → "Y"/"N" 변환, List → JSON 문자열 변환, 암호화된 값 저장/복원 등이 있다.

```java
// Boolean → "Y"/"N" 변환기
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

// 엔티티에 적용
@Convert(converter = BooleanToYNConverter.class)
private Boolean isActive; // DB에는 "Y"/"N"으로 저장됨
```

`@Converter(autoApply = true)`를 설정하면 해당 타입의 모든 필드에 자동으로 적용된다. 매 필드마다 `@Convert`를 붙이지 않아도 된다.

---

##  5. 전체 적용 예시

---

```java
@Entity
@Table(name = "product")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Product extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "product_id")
    private Long id;

    @Column(nullable = false, length = 100)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ProductStatus status; // DB: "SALE", "SOLD_OUT", "DISCONTINUED"

    @Lob
    private String description;   // DB: CLOB (대용량 상품 설명)

    private LocalDate releaseDate; // @Temporal 불필요 (Hibernate 6.x)

    @Convert(converter = BooleanToYNConverter.class)
    private Boolean isDisplayed;   // DB: "Y" or "N"

    public Product(String name, ProductStatus status, String description) {
        this.name = name;
        this.status = status;
        this.description = description;
    }
}
```

---

## 참고 자료

- 공식문서 - Jakarta Persistence 3.1: <https://jakarta.ee/specifications/persistence/3.1/>
- 공식문서 - Hibernate AttributeConverter: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#basic-jpa-convert>
