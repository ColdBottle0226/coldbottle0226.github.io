---
title: Spring Boot 설정 값 주입 완전 정리
date: 2026-04-12 09:00:00 +0900
categories: [Spring, SpringBoot]
tags: [SpringBoot, Configuration, ConfigurationProperties, Value, YAML, 설정주입]
---

Spring Boot 애플리케이션을 만들다 보면 `@Configuration`, `@Value`, `@ConfigurationProperties` 등 설정 관련 어노테이션이 한가득 등장한다. 각각이 무슨 역할인지, 언제 어떤 것을 써야 하는지, 그리고 실제로 값이 주입되는 시점이 언제인지 정리한다.

---

## 1. 개요

### 📌 핵심 원칙

Spring Boot의 설정 시스템은 크게 세 레이어로 나뉜다.

| 레이어 | 구성 요소 | 역할 |
|---|---|---|
| 설정 소스 | `application.yml`, 환경 변수, 커맨드라인 | 값의 원천(Source) |
| 통합 계층 | `Environment` (PropertySource) | 소스들을 우선순위 순으로 통합 |
| 주입 방식 | `@Value`, `@ConfigurationProperties`, `Environment API` | Environment에서 값을 꺼내 빈에 주입 |

`@Configuration`은 이 흐름에서 "빈 정의 컨테이너" 역할을 한다. 설정 값을 직접 읽는 것이 아니라, 주입 방식을 통해 받은 값으로 빈을 조립한다.

---

## 2. 어노테이션별 역할과 관계

아래 다이어그램은 설정 소스부터 최종 ApplicationContext까지 전체 흐름을 보여준다.

![어노테이션 관계도](/assets/images/spring-config/annotation-map.svg)

### 📌 @Configuration은 설정 소스가 아니다

가장 흔히 헷갈리는 부분이다. `@Configuration`은 `application.yml`에서 값을 읽어오는 역할이 아니다.

| 어노테이션 | 역할 |
|---|---|
| `application.yml` | 설정 값의 원천(source) |
| `@Configuration` | 빈(Bean) 정의를 담는 컨테이너 |
| `@Bean` | 빈 인스턴스를 생성하는 팩토리 메서드 |
| `@Value` | Environment에서 단일 값을 꺼내 주입 |
| `@ConfigurationProperties` | 프리픽스 기준으로 값을 묶어서 바인딩 |

---

## 3. PropertySource 우선순위

Spring Boot는 여러 소스에서 설정을 읽을 때 명확한 우선순위를 따른다. 나중에 적용될수록 우선순위가 높아 이전 값을 덮어쓴다.

```
낮음 ─────────────────────────────── 높음
SpringApplication.setDefaultProperties()
  └─ application.yml (jar 내부)
      └─ application-{profile}.yml (jar 내부)
          └─ application.yml (jar 외부)
              └─ application-{profile}.yml (jar 외부)
                  └─ OS 환경 변수
                      └─ Java System properties
                          └─ 커맨드라인 인자  ← 가장 높음
```

> 💡 `application-{profile}.yml`은 항상 `application.yml`보다 높은 우선순위를 가진다. 같은 키가 있으면 프로파일 파일의 값이 이긴다.

---

## 4. application.yml vs application.properties

Spring Boot는 시작 시 다음 위치를 자동 탐색한다.

```
classpath 루트         (src/main/resources/)
classpath /config/
현재 디렉토리
현재 디렉토리 /config/
```

/** YAML이 .properties보다 권장되는 이유: 계층 구조 표현이 직관적이다 */

```yaml
# application.yml — 권장
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/mydb
    username: root
server:
  port: 8080
```

```properties
# application.properties — 동등하지만 가독성이 낮다
spring.datasource.url=jdbc:mysql://localhost:3306/mydb
spring.datasource.username=root
server.port=8080
```

> 💡 **주의:** YAML 파일은 `@PropertySource` 어노테이션으로 로드할 수 없다. 커스텀 파일 로드가 필요하면 반드시 `.properties` 형식을 사용해야 한다.

---

## 5. 프로파일별 설정

### 📌 방법 1: 파일 분리

```
resources/
├── application.yml          # 공통 기본값
├── application-local.yml    # 로컬 개발
├── application-dev.yml      # 개발 서버
└── application-prod.yml     # 운영 서버
```

### 📌 방법 2: 단일 파일 내 분리 (`---` 구분자)

```yaml
server:
  port: 9000  # 기본값

---
spring:
  config:
    activate:
      on-profile: "development"
server:
  port: 9001

---
spring:
  config:
    activate:
      on-profile: "production"
server:
  port: 0
```

프로파일 활성화 방법은 다음과 같다.

```bash
# 커맨드라인
java -jar myapp.jar --spring.profiles.active=prod

# 환경 변수
SPRING_PROFILES_ACTIVE=prod java -jar myapp.jar
```

---

## 6. @Value — 단일 값 주입

가장 단순한 주입 방식이다. Spring Expression Language(SpEL)를 지원한다.

```yaml
# application.yml
app:
  name: MyApp
  timeout: 5000
```

/** @Value는 단순 값 하나를 꺼낼 때 쓴다. SpEL로 계산식도 가능하다 */

```java
@Component
public class AppInfo {

    // 기본 주입
    @Value("${app.name}")
    private String appName;

    // 기본값 지정 (프로퍼티 없을 때 사용)
    @Value("${app.timeout:5000}")
    private int timeout;

    // SpEL 활용 — 계산식
    @Value("#{${app.timeout} * 2}")
    private int doubleTimeout;
}
```

**@Value 한계:** 여러 관련 값을 다루거나 계층 구조가 복잡해지면 다루기 불편하다. 이때 `@ConfigurationProperties`를 사용한다.

---

## 7. @ConfigurationProperties — 타입-안전 바인딩 (권장)

관련된 설정 그룹을 하나의 객체에 바인딩한다. 규모 있는 애플리케이션에서 권장하는 방식이다.

### 📌 Setter Binding (기본 방식)

```yaml
# application.yml
mail:
  host: smtp.gmail.com
  port: 587
  from: noreply@example.com
  credentials:
    username: user
    password: secret
```

/** Setter 방식: 기본값으로 많이 쓰인다. 단, 값이 변경 가능한 mutable 객체가 된다 */

```java
@ConfigurationProperties(prefix = "mail")
public class MailProperties {

    private String host;
    private int port;
    private String from;
    private Credentials credentials;

    // Getter / Setter 필수
    public static class Credentials {
        private String username;
        private String password;
        // Getter / Setter
    }
}
```

### 📌 Constructor Binding (Spring Boot 2.2+, 권장)

/** 생성자 바인딩: 불변(immutable) 객체로 만들 수 있다. Spring Boot 3에서는 @ConstructorBinding 생략 가능 */

```java
@ConfigurationProperties(prefix = "mail")
public class MailProperties {

    private final String host;
    private final int port;
    private final String from;

    // Spring Boot 3: 생성자가 하나면 @ConstructorBinding 생략 가능
    public MailProperties(String host, int port, String from) {
        this.host = host;
        this.port = port;
        this.from = from;
    }

    // Getter만 필요 (Setter 불필요)
}
```

### 📌 Java Record 활용 (Spring Boot 3 + Java 17, 최신 권장)

/** Record: 불변 + 간결함. 보일러플레이트(getter, setter, 생성자)가 모두 제거된다 */

```java
@ConfigurationProperties(prefix = "mail")
public record MailProperties(
    String host,
    int port,
    String from
) {}
```

### 📌 빈 등록 방법

```java
// 방법 1: @ConfigurationPropertiesScan — 가장 권장
@SpringBootApplication
@ConfigurationPropertiesScan
public class MyApp { ... }

// 방법 2: 특정 클래스를 명시적으로 등록
@EnableConfigurationProperties(MailProperties.class)

// 방법 3: 클래스에 @Component 직접 추가 (간단하지만 덜 권장)
@Component
@ConfigurationProperties(prefix = "mail")
public class MailProperties { ... }
```

### 📌 다른 빈에서 주입하여 사용

/** ConfigurationProperties 빈은 일반 빈처럼 생성자 주입으로 사용한다 */

```java
@Service
public class MailService {

    private final MailProperties mailProperties;

    public MailService(MailProperties mailProperties) {
        this.mailProperties = mailProperties;
    }

    public void send() {
        // Record의 경우 메서드 참조 방식
        String host = mailProperties.host();
        // ...
    }
}
```

---

## 8. @Configuration과 설정 주입의 연관성

### 📌 @Configuration 안에서 설정 값을 쓰는 실제 패턴

/** @Configuration은 빈 정의 클래스다. @Value나 @ConfigurationProperties를 통해 Environment에서 값을 꺼내 빈을 조립한다 */

```java
@Configuration
public class DataSourceConfig {

    // 패턴 1: @Value로 단일 값 주입
    @Value("${spring.datasource.url}")
    private String url;

    @Bean
    public DataSource dataSource() {
        HikariDataSource ds = new HikariDataSource();
        ds.setJdbcUrl(url);
        return ds;
    }

    // 패턴 2: @Bean 메서드에 @ConfigurationProperties 적용
    // 서드파티 라이브러리(HikariConfig)에 yml 값을 직접 바인딩
    @Bean
    @ConfigurationProperties(prefix = "spring.datasource.hikari")
    public HikariConfig hikariConfig() {
        return new HikariConfig(); // Setter를 통해 자동으로 값이 채워진다
    }
}
```

/** ConfigurationProperties 빈을 @Configuration에서 주입받아 사용하는 패턴 */

```java
@Configuration
public class MailConfig {

    private final MailProperties mailProperties;

    // MailProperties는 별도로 @ConfigurationProperties로 등록된 빈
    public MailConfig(MailProperties mailProperties) {
        this.mailProperties = mailProperties;
    }

    @Bean
    public JavaMailSender mailSender() {
        JavaMailSenderImpl sender = new JavaMailSenderImpl();
        sender.setHost(mailProperties.host());
        sender.setPort(mailProperties.port());
        return sender;
    }
}
```

> 💡 공식 문서는 `@ConfigurationProperties`가 Environment만 다루도록 권장한다. 설정 값을 담는 클래스(`MailProperties`)와 빈을 조립하는 클래스(`@Configuration`)를 명확히 분리하는 것이 베스트 프랙티스다.

---

## 9. 설정 값 주입 순서 — 전체 흐름

아래 다이어그램은 `SpringApplication.run()`부터 빈이 완전히 초기화되기까지의 순서를 보여준다.

![설정 값 주입 순서](/assets/images/spring-config/injection-order.svg)

### 📌 Phase별 핵심 정리

**Phase 1 — Environment 구성 (빈 생성 전):**
모든 PropertySource(yml, 환경변수, 커맨드라인)가 통합되고 프로파일이 결정된다. 프로파일이 결정되면 `application-{profile}.yml`이 추가로 로드된다.

**Phase 2 — ApplicationContext 생성:**
컴포넌트 스캔으로 `@Configuration`, `@Component` 등이 `BeanDefinition`으로 등록된다. 이 시점에는 아직 인스턴스가 생성되지 않는다.

**Phase 3 — BeanPostProcessor 등록:**
`ConfigurationClassPostProcessor`가 `@Configuration`을 파싱하고, `ConfigurationPropertiesBinder`가 바인딩 준비를 한다.

**Phase 4 — 값이 실제로 주입되는 시점:**
싱글톤 빈 인스턴스가 생성되고 `@Value`, `@ConfigurationProperties` 바인딩이 실행된다. `yml` 값이 실제로 들어오는 것이 이 단계다.

---

## 10. 자주 발생하는 문제

### 📌 생성자에서 @Value가 null인 문제

/** 필드 주입 방식에서 생성자 호출 시점에는 @Value가 아직 주입되지 않는다 */

```java
// 잘못된 패턴 — 생성자에서 null 발생
@Component
public class WrongUsage {

    @Value("${app.url}")
    private String url;

    public WrongUsage() {
        System.out.println(url); // null!
    }
}

// 올바른 패턴 1 — 생성자 주입 (추천)
@Component
public class CorrectUsage {

    private final String url;

    public CorrectUsage(@Value("${app.url}") String url) {
        this.url = url;
        System.out.println(url); // 정상
    }
}

// 올바른 패턴 2 — @PostConstruct 사용 (필드 주입 방식 유지 시)
@Component
public class CorrectUsage2 {

    @Value("${app.url}")
    private String url;

    @PostConstruct
    public void init() {
        System.out.println(url); // 주입 완료 후 호출되므로 정상
    }
}
```

### 📌 @PropertySource의 제약 — 초기 설정에 사용 불가

```java
// 주의: @PropertySource는 ApplicationContext refresh 중에 처리된다.
// logging.* 이나 spring.main.* 같이 refresh 전에 읽히는 값에는 영향이 없다.
@Configuration
@PropertySource("classpath:custom.properties") // 일반 빈에서는 동작
public class MyConfig {
    // logging.level.* 변경이 목적이라면 application.properties를 사용해야 한다
}
```

---

## 11. @Value vs @ConfigurationProperties 비교

| 항목 | `@Value` | `@ConfigurationProperties` |
|---|---|---|
| 적합한 용도 | 단일 값, 단순 주입 | 관련 설정 그룹 |
| SpEL 지원 | ✅ | ❌ |
| 타입 안전성 | ❌ (문자열 기반) | ✅ |
| 유효성 검증 | ❌ | ✅ (`@Validated`) |
| 불변 객체 | ❌ | ✅ (Constructor Binding / Record) |
| 계층 구조 지원 | 불편 | ✅ |
| IDE 자동완성 | 제한적 | ✅ (메타데이터 생성 시) |

---

## 12. 정리

- `application.yml`의 값은 Spring이 기동 시 `Environment`에 통합한다. 이 시점은 빈 생성 전이다.
- `@Configuration`은 빈 정의 컨테이너다. 설정 값을 읽지 않는다. `@Value`나 `@ConfigurationProperties`를 통해 받은 값으로 빈을 조립한다.
- 실제 값 주입(`@Value` 바인딩, `@ConfigurationProperties` 바인딩)은 싱글톤 빈 인스턴스 생성 시점(Phase 4)에 이루어진다.
- Spring Boot 3 + Java 17 환경에서는 `@ConfigurationProperties` + `record`가 가장 간결하고 안전한 방법이다.
- 커맨드라인 인자가 가장 높은 우선순위를 가지므로, 배포 환경에서 특정 값만 오버라이드할 때 유용하다.

---

## 참고 자료

- [Spring Boot 공식 문서 — Externalized Configuration](https://docs.spring.io/spring-boot/reference/features/external-config.html)
- [Spring Boot 공식 문서 — External Application Properties](https://docs.spring.io/spring-boot/reference/features/external-config.html#features.external-config.files)
- [Spring Framework 공식 문서 — Bean Lifecycle](https://docs.spring.io/spring-framework/reference/core/beans/factory-nature.html)
- [Baeldung — Guide to @ConfigurationProperties](https://www.baeldung.com/configuration-properties-in-spring-boot)
- [Baeldung — Properties with Spring](https://www.baeldung.com/properties-with-spring)
