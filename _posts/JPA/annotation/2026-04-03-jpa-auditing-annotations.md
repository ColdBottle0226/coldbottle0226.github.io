---
title: Auditing 어노테이션
date: 2026-04-03 09:50:00 +0900
categories: [JPA, 엔티티 어노테이션]
order: 4
tags: [JPA, 엔티티 어노테이션, Auditing, CreatedDate, LastModifiedDate, CreatedBy, EnableJpaAuditing, AuditorAware]
---

## 📗 1. Auditing이란

---

엔티티가 생성되거나 수정된 시간, 그 주체를 자동으로 기록하는 것이 Auditing(감사)이다. 모든 테이블에 `created_at`, `updated_at`을 넣는 것은 운영 시 문제 추적을 위해 실무에서 거의 필수로 사용된다. Spring Data JPA의 Auditing 기능을 사용하면 이를 자동으로 처리할 수 있다.

---

## 📗 2. 기본 설정

---

### 📌 @EnableJpaAuditing 활성화

```java
// JpaStudyApplication.java
@SpringBootApplication
@EnableJpaAuditing  // 반드시 추가해야 Auditing이 동작함
public class JpaStudyApplication {
    public static void main(String[] args) {
        SpringApplication.run(JpaStudyApplication.class, args);
    }
}
```

`@EnableJpaAuditing`이 없으면 `@CreatedDate`, `@LastModifiedDate`가 붙은 필드에 값이 채워지지 않는다.

> 💡 `@SpringBootApplication`이 붙은 메인 클래스에 `@EnableJpaAuditing`을 붙이면, `@WebMvcTest` 같은 슬라이스 테스트에서 JPA 관련 빈을 로딩하지 않아 오류가 발생할 수 있다. 이를 피하려면 별도의 `@Configuration` 클래스에 `@EnableJpaAuditing`을 분리하는 것이 좋다.

```java
// global/config/JpaAuditingConfig.java
@Configuration
@EnableJpaAuditing
public class JpaAuditingConfig {
}
```

### 📌 BaseEntity 작성

```java
// global/entity/BaseEntity.java
@Getter
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class) // JPA 이벤트 감지
public abstract class BaseEntity {

    @CreatedDate
    @Column(updatable = false)  // 최초 저장 이후 변경 불가
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime updatedAt;
}
```

`@EntityListeners(AuditingEntityListener.class)`가 JPA 이벤트(persist, merge 등)를 감지해서 시간을 자동으로 채워준다. 엔티티가 최초 저장될 때 `createdAt`과 `updatedAt`이 모두 설정되고, 이후 수정될 때는 `updatedAt`만 갱신된다.

---

## 📗 3. @CreatedDate / @LastModifiedDate 동작 원리

---

Spring Data JPA의 `AuditingEntityListener`가 JPA의 콜백 어노테이션(`@PrePersist`, `@PreUpdate`)을 내부적으로 활용한다.

- 엔티티가 처음 저장될 때 (`@PrePersist` 호출 시점): `createdAt`과 `updatedAt`을 현재 시간으로 설정
- 엔티티가 수정될 때 (`@PreUpdate` 호출 시점): `updatedAt`만 현재 시간으로 갱신

`@Column(updatable = false)`를 `createdAt`에 붙이는 이유는 Hibernate가 생성하는 UPDATE SQL에 `created_at` 컬럼이 포함되지 않도록 막기 위해서다.

---

## 📗 4. @CreatedBy / @LastModifiedBy

---

누가 생성하고 수정했는지도 자동으로 기록할 수 있다. 현재 로그인한 사용자 정보를 JPA에 제공하는 `AuditorAware` 구현체가 필요하다.

### 📌 AuditorAware 구현

```java
// global/config/AuditConfig.java
@Configuration
@EnableJpaAuditing(auditorAwareRef = "auditorProvider")
public class AuditConfig {

    @Bean
    public AuditorAware<String> auditorProvider() {
        // Spring Security를 사용하는 경우
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
// Spring Security 없이 ThreadLocal로 구현하는 예시
@Component
public class ThreadLocalAuditorAware implements AuditorAware<String> {

    private static final ThreadLocal<String> currentUser = new ThreadLocal<>();

    public static void setCurrentUser(String userId) {
        currentUser.set(userId);
    }

    public static void clear() {
        currentUser.remove();
    }

    @Override
    public Optional<String> getCurrentAuditor() {
        return Optional.ofNullable(currentUser.get());
    }
}
```

### 📌 BaseEntity에 추가

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
    private String createdBy;   // 생성한 사용자 ID

    @LastModifiedBy
    @Column(length = 50)
    private String lastModifiedBy; // 마지막으로 수정한 사용자 ID
}
```

---

## 📗 5. JPA 콜백 어노테이션 — @PrePersist, @PostLoad 등

---

Auditing 외에도 JPA가 제공하는 콜백 어노테이션을 직접 활용할 수 있다. AuditingEntityListener를 쓰지 않고 직접 시간을 채우거나, 엔티티 저장 전후 특정 로직을 실행할 때 사용한다.

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
// AuditingEntityListener 없이 직접 콜백 사용하는 예시
@Entity
public class Member extends BaseEntity {
    ...

    @PrePersist
    public void prePersist() {
        // em.persist() 직전에 실행됨
        // createdAt, updatedAt을 직접 세팅하거나
        // 저장 전 유효성 검증 등에 활용
        System.out.println("Member persist 직전 실행");
    }

    @PostLoad
    public void postLoad() {
        // DB에서 로딩된 직후 실행
        // @Transient 필드 초기화 등에 활용
        this.displayLabel = "[" + this.name + "]"; // @Transient 필드
    }
}
```

---

## 📗 6. Auditing 적용 확인

---

```java
@SpringBootTest
@Transactional
class AuditingTest {

    @Autowired
    private MemberRepository memberRepository;

    @Test
    @DisplayName("저장 시 createdAt, updatedAt 자동 채워짐")
    void auditingTest() throws InterruptedException {
        // 저장
        Member member = new Member("홍길동", 30, "hong@test.com");
        memberRepository.save(member);

        assertThat(member.getCreatedAt()).isNotNull();
        assertThat(member.getUpdatedAt()).isNotNull();
        System.out.println("createdAt: " + member.getCreatedAt());
        System.out.println("updatedAt: " + member.getUpdatedAt());

        LocalDateTime beforeUpdate = member.getUpdatedAt();

        Thread.sleep(100); // 시간 차이를 주기 위해

        // 수정
        member.updateName("김철수");
        memberRepository.saveAndFlush(member);

        // updatedAt만 변경됨
        assertThat(member.getCreatedAt()).isEqualTo(member.getCreatedAt()); // 변경 없음
        assertThat(member.getUpdatedAt()).isAfter(beforeUpdate);             // updatedAt 갱신됨
        System.out.println("수정 후 updatedAt: " + member.getUpdatedAt());
    }
}
```

---

## 참고 자료

- 공식문서 - Spring Data JPA Auditing: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#auditing>
- 공식문서 - Hibernate Entity Listeners: <https://docs.jboss.org/hibernate/orm/6.0/userguide/html_single/Hibernate_User_Guide.html#events-jpa-callbacks>
