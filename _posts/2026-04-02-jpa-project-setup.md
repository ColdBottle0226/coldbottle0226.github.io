---
title: JPA 실습 프로젝트 생성 및 환경 설정
date: 2026-04-02 09:00:00 +0900
categories: [JPA, 실습 프로젝트 생성 및 환경설정]
tags: [JPA, 실습 프로젝트 생성 및 환경설정, Spring Boot, Hibernate, QueryDSL, Docker, MySQL, H2]
---

## 📗 1. 프로젝트 생성

---

### 📌 Spring Initializr 설정 (3.x)

[start.spring.io](https://start.spring.io)에서 프로젝트를 생성할 때 선택해야 할 항목은 다음과 같다.

| 항목 | 선택값 | 이유 |
|---|---|---|
| Project | Gradle - Kotlin | Kotlin DSL 기준으로 진행. Groovy보다 타입 안전하고 IDE 자동완성이 좋음 |
| Language | Java | |
| Spring Boot | 3.x 최신 안정 버전 | Jakarta EE 기반, Hibernate 6.x 적용 |
| Packaging | Jar | |
| Java | 17 이상 | Spring Boot 3.x 최소 요구사항 |

의존성 선택은 아래와 같다.

- Spring Web
- Spring Data JPA
- H2 Database (인메모리 DB, 개발/테스트용)
- MySQL Driver (실제 환경 연결용)
- Lombok
- Validation (@NotNull, @Size 등 Bean Validation)

QueryDSL은 Initializr에서 직접 선택할 수 없으므로 프로젝트 생성 후 `build.gradle.kts`에 수동으로 추가해야 한다.

---

### 📌 Gradle Kotlin DSL 구성

Spring Boot 3.x + Java + QueryDSL 조합의 `build.gradle.kts` 전체 구성이다.

```kotlin
plugins {
    java
    id("org.springframework.boot") version "3.2.5"
    id("io.spring.dependency-management") version "1.1.4"
}

group = "com.example"
version = "0.0.1-SNAPSHOT"

java {
    sourceCompatibility = JavaVersion.VERSION_17
}

configurations {
    compileOnly {
        extendsFrom(configurations.annotationProcessor.get())
    }
}

repositories {
    mavenCentral()
}

dependencies {
    // Spring
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-validation")

    // DB
    runtimeOnly("com.h2database:h2")
    runtimeOnly("com.mysql:mysql-connector-j")

    // Lombok
    compileOnly("org.projectlombok:lombok")
    annotationProcessor("org.projectlombok:lombok")

    // QueryDSL
    implementation("com.querydsl:querydsl-jpa:5.0.0:jakarta")
    annotationProcessor("com.querydsl:querydsl-apt:5.0.0:jakarta")
    annotationProcessor("jakarta.annotation:jakarta.annotation-api")
    annotationProcessor("jakarta.persistence:jakarta.persistence-api")

    // Test
    testImplementation("org.springframework.boot:spring-boot-starter-test")
}

// QueryDSL Q클래스 생성 경로 설정
val querydslDir = "src/main/generated"

sourceSets {
    main {
        java {
            srcDirs(querydslDir)
        }
    }
}

tasks.withType<JavaCompile> {
    options.generatedSourceOutputDirectory = file(querydslDir)
}

tasks.named("clean") {
    doLast {
        file(querydslDir).deleteRecursively()
    }
}
```

QueryDSL 의존성 포인트 두 가지를 반드시 이해해야 한다.

첫 번째, `querydsl-jpa:5.0.0:jakarta`에서 뒤에 붙는 `:jakarta`는 분류자(classifier)다. Spring Boot 3.x는 `jakarta.persistence` 패키지를 사용하는데, 이를 지원하는 빌드임을 명시하는 것이다. `:jakarta`가 없으면 구버전 `javax.persistence` 기반으로 빌드되어 런타임에 오류가 발생한다.

두 번째, `annotationProcessor`로 등록된 `querydsl-apt`가 컴파일 시점에 `@Entity`가 붙은 클래스를 스캔해서 Q클래스를 자동 생성한다. 예를 들어 `Member` 엔티티가 있으면 `QMember` 클래스가 생성된다. 이 Q클래스는 QueryDSL로 타입 안전한 쿼리를 작성할 때 사용한다.

---

## 📗 2. 데이터소스 설정

---

### 📌 H2 인메모리 데이터베이스 (개발용)

H2는 JVM 위에서 동작하는 인메모리 관계형 데이터베이스다. 별도의 DB 서버 없이 동작하기 때문에 개발 초기 단계나 단위 테스트에서 주로 사용한다. 애플리케이션이 종료되면 데이터가 사라지는 특성이 있다.

```yaml
# src/main/resources/application.yml (H2 개발 환경)
spring:
  datasource:
    url: jdbc:h2:mem:jpadb
    driver-class-name: org.h2.Driver
    username: sa
    password:

  h2:
    console:
      enabled: true
      path: /h2-console

  jpa:
    database-platform: org.hibernate.dialect.H2Dialect
    hibernate:
      ddl-auto: create-drop
    show-sql: true
    properties:
      hibernate:
        format_sql: true
```

---

### 📌 Docker MySQL 연동

별도 MySQL 설치 없이 Docker로 개발용 MySQL을 띄울 수 있다. `docker-compose.yml` 파일을 프로젝트 루트에 생성한다.

```yaml
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: jpa-mysql
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: jpa_study
      MYSQL_USER: jpa_user
      MYSQL_PASSWORD: jpa_pass
    volumes:
      - jpa-mysql-data:/var/lib/mysql
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-ppassword"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  jpa-mysql-data:
```

```bash
# 컨테이너 시작 (백그라운드)
docker-compose up -d

# 컨테이너 중지 (데이터는 volume에 보존)
docker-compose down

# 데이터까지 완전 삭제
docker-compose down -v
```

`allowPublicKeyRetrieval=true` 옵션은 MySQL 8.0의 기본 인증 플러그인(`caching_sha2_password`) 사용 시 공개 키 교환을 허용하는 설정이다. 로컬 Docker 환경에서 SSL 없이 접속할 때 이 옵션이 없으면 인증 오류가 발생할 수 있다.

---

### 📌 application.yml 전체 구조 (멀티 프로파일)

```yaml
spring:
  profiles:
    active: h2

---
spring:
  config:
    activate:
      on-profile: h2
  datasource:
    url: jdbc:h2:mem:jpadb
    driver-class-name: org.h2.Driver
    username: sa
    password:
  h2:
    console:
      enabled: true
  jpa:
    database-platform: org.hibernate.dialect.H2Dialect
    hibernate:
      ddl-auto: create-drop
    show-sql: true
    properties:
      hibernate:
        format_sql: true
        use_sql_comments: true

---
spring:
  config:
    activate:
      on-profile: mysql
  datasource:
    url: jdbc:mysql://localhost:3306/jpa_study?useSSL=false&serverTimezone=Asia/Seoul&characterEncoding=UTF-8&allowPublicKeyRetrieval=true
    driver-class-name: com.mysql.cj.jdbc.Driver
    username: jpa_user
    password: jpa_pass
  jpa:
    database-platform: org.hibernate.dialect.MySQL8Dialect
    hibernate:
      ddl-auto: create
    show-sql: true
    properties:
      hibernate:
        format_sql: true
        use_sql_comments: true
```

---

### 📌 ddl-auto 전략

| 값 | 동작 | 권장 환경 |
|---|---|---|
| `create` | 시작 시 기존 테이블 드롭 후 재생성 | 개발 초기 |
| `create-drop` | create + 종료 시 테이블 드롭 | 테스트 |
| `update` | 엔티티 변경 사항을 스키마에 반영 (컬럼 추가만, 삭제 안 함) | 개발 중반 (주의) |
| `validate` | 엔티티와 실제 테이블 스키마 일치 여부 검증. 불일치 시 시작 실패 | 스테이징, 운영 |
| `none` | 아무 것도 하지 않음 | 운영 |

> 💡 `update`는 운영에서 절대 사용하면 안 된다. 컬럼 삭제나 타입 변경 같은 파괴적 변경을 감지하지 못하고, 예상치 못한 스키마 불일치가 생길 수 있다. 운영 환경에서는 `validate` 또는 `none`을 사용하고, 스키마 변경은 Flyway나 Liquibase 같은 마이그레이션 툴로 관리해야 한다.

---

### 📌 Hibernate SQL 로깅 설정

`show-sql: true` 만으로도 SQL을 볼 수 있지만, `System.out`으로 출력되기 때문에 로그 레벨 제어가 안 된다. 로거로 제어하려면 `application.yml`의 logging 설정을 사용한다.

```yaml
logging:
  level:
    org.hibernate.SQL: DEBUG
    org.hibernate.orm.jdbc.bind: TRACE   # Hibernate 6.x (Spring Boot 3.x)
```

> 💡 Hibernate 5.x에서는 `org.hibernate.type.descriptor.sql: TRACE`였지만, Hibernate 6.x(Spring Boot 3.x)에서는 `org.hibernate.orm.jdbc.bind: TRACE`로 패키지가 변경됐다. Spring Boot 3.x 환경이라면 반드시 새 패키지명을 사용해야 한다.

---

## 📗 3. 패키지 구조 설계

---

### 📌 도메인 중심 패키지 구조

레이어 기준이 아닌 도메인 기준으로 패키지를 구성하는 것을 권장한다. 레이어 기준 구조(controller / service / repository 폴더 분리)는 규모가 커질수록 응집도가 낮아지고, 하나의 도메인을 수정할 때 여러 폴더를 오가야 한다.

```
src/main/java/com/example/jpastudy/
│
├── JpaStudyApplication.java
│
├── member/
│   ├── Member.java
│   ├── MemberRepository.java
│   ├── MemberService.java
│   ├── MemberController.java
│   └── dto/
│       ├── MemberCreateRequest.java
│       └── MemberResponse.java
│
├── order/
│   ├── Order.java
│   ├── OrderItem.java
│   ├── OrderRepository.java
│   ├── OrderService.java
│   └── dto/
│
├── product/
│   ├── Product.java
│   ├── ProductRepository.java
│   └── ...
│
└── global/
    ├── config/
    │   ├── JpaConfig.java
    │   └── P6spyConfig.java
    ├── entity/
    │   └── BaseEntity.java
    └── exception/
        └── GlobalExceptionHandler.java

src/main/generated/
    └── com/example/jpastudy/
        ├── member/QMember.java
        └── order/QOrder.java
```

---

### 📌 QueryDSL JPAQueryFactory Bean 등록

QueryDSL을 사용하려면 `JPAQueryFactory`를 스프링 빈으로 등록해야 한다.

```java
@Configuration
public class JpaConfig {

    @PersistenceContext
    private EntityManager entityManager;

    @Bean
    public JPAQueryFactory jpaQueryFactory() {
        return new JPAQueryFactory(entityManager);
    }
}
```

`@PersistenceContext`는 스프링이 관리하는 EntityManager를 주입받는 어노테이션이다. 스프링의 EntityManager는 실제로는 프록시 객체이고, 요청마다(트랜잭션마다) 실제 EntityManager를 연결해주는 방식으로 동작한다. 그래서 싱글톤 빈에 주입해도 스레드 안전하게 동작한다.

---

### 📌 BaseEntity 공통 필드 (Auditing 사전 설정)

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

```java
@SpringBootApplication
@EnableJpaAuditing
public class JpaStudyApplication {
    public static void main(String[] args) {
        SpringApplication.run(JpaStudyApplication.class, args);
    }
}
```

`@MappedSuperclass`는 이 클래스 자체는 테이블로 만들지 않고, 자식 엔티티 테이블에 필드만 물려주는 어노테이션이다. `@EntityListeners(AuditingEntityListener.class)`는 JPA 이벤트 리스너를 등록해서 엔티티 저장/수정 시 자동으로 시간을 채워준다.

---

## 참고 자료

- 공식문서 - Spring Initializr: <https://start.spring.io>
- 공식문서 - Spring Data JPA: <https://docs.spring.io/spring-data/jpa/docs/current/reference/html/>
- 공식문서 - QueryDSL: <https://querydsl.com/static/querydsl/5.0.0/reference/html_single/>
- 공식문서 - Hibernate 6 Migration Guide: <https://docs.jboss.org/hibernate/orm/6.0/migration-guide/migration-guide.html>
