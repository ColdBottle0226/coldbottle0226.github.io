---
title: Spring 기초 개념 (IoC, DI, AOP, Bean 생명주기)
date: 2026-04-21 09:00:00 +0900
categories: [Spring, SpringBoot]
tags: [SpringBoot, IoC, DI, AOP, Bean, 스프링기초]
---

## 1. 개요

스프링 부트를 처음 배울 때 가장 먼저 마주치는 개념들이 있다. IoC, DI, AOP, Bean. 이 개념들이 어떻게 연결되고 내부적으로 어떻게 동작하는지를 코드 레벨에서 정리한다.

| 파트 | 내용 |
|------|------|
| 스프링 vs 스프링 부트 | 두 프레임워크의 관계와 차이 |
| IoC 컨테이너 | ApplicationContext 계층 구조 |
| Bean 등록 | 컴포넌트 스캔, @Bean, XML |
| DI | 생성자 / 세터 / 필드 주입 비교 |
| AOP | 프록시 구조 및 Advice 종류 |
| @SpringBootApplication | 어노테이션 내부 해부 |
| Bean 생명주기 | 8단계 흐름 및 콜백 코드 |

---

## 2. 스프링 vs 스프링 부트

### 📌 관계 정리

Spring Framework는 IoC 컨테이너, AOP, 트랜잭션, MVC 등 핵심 기능을 제공하는 종합 프레임워크다. 그러나 설정이 복잡하고(XML 수백 줄), 내장 서버가 없으며, 의존성 버전 충돌 문제가 있었다.

Spring Boot는 이 복잡함을 해결하기 위해 만들어진 도구로, 스프링 위에 올라탄 레이어다.

> 💡 Spring Boot 공식 문서: "Spring Boot makes it easy to create stand-alone, production-grade Spring based Applications that you can just run."

| 항목 | Spring Framework | Spring Boot |
|------|-----------------|-------------|
| 설정 | XML / Java Config 직접 작성 | Auto-configuration |
| 서버 | 외장 WAS 별도 필요 | Tomcat 내장 |
| 의존성 관리 | 버전 직접 관리 | Starter로 자동 관리 |
| 실행 | WAR 배포 | 실행 가능한 JAR |

---

## 3. IoC 컨테이너

### 📌 제어의 역전이란

일반적인 코드에서는 개발자가 직접 객체를 생성한다. IoC는 이 제어권을 컨테이너에게 넘긴다.

```java
// 기존 방식 — 개발자가 직접 제어
public class OrderService {
    private final PaymentService paymentService = new PaymentService(); // 직접 생성
}
```

```java
// IoC 방식 — 컨테이너가 생성해서 주입
@Service
public class OrderService {
    private final PaymentService paymentService; // 컨테이너가 주입

    public OrderService(PaymentService paymentService) {
        this.paymentService = paymentService;
    }
}
```

### 📌 ApplicationContext 계층 구조

```
BeanFactory (최상위 — 지연 로딩)
  └─ ApplicationContext (즉시 로딩 + 부가 기능)
       ├─ AnnotationConfigApplicationContext       (순수 스프링, 어노테이션 기반)
       ├─ ClassPathXmlApplicationContext           (XML 기반, 레거시)
       └─ AnnotationConfigServletWebServerApplicationContext  (스프링 부트 웹)
```

스프링 부트 실행 시 `AnnotationConfigServletWebServerApplicationContext`가 생성되어 내장 Tomcat을 띄우고 모든 Bean을 관리한다.

---

## 4. Bean 등록 방법

### 📌 컴포넌트 스캔 (가장 일반적)

```java
@Component   // 일반 컴포넌트
@Service     // 서비스 레이어 (의미론적 구분)
@Repository  // 데이터 접근 레이어 (예외 변환 기능 포함)
@Controller  // 웹 컨트롤러
@RestController // @Controller + @ResponseBody 합성
```

이 어노테이션들은 모두 내부적으로 `@Component`를 포함하는 메타 어노테이션 구조다. `@Service` 실제 소스를 보면 다음과 같다.

```java
// Spring Framework 소스 코드 (단순화)
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Component  // ← @Component를 포함
public @interface Service {
    @AliasFor(annotation = Component.class)
    String value() default "";
}
```

### 📌 @Configuration + @Bean (외부 라이브러리 등록)

외부 라이브러리처럼 소스 코드를 직접 수정할 수 없는 클래스를 Bean으로 등록할 때 사용한다.

```java
@Configuration
public class AppConfig {

    /**
     * ObjectMapper를 Bean으로 등록.
     * null 값은 JSON 직렬화에서 제외하도록 설정한다.
     */
    @Bean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        mapper.setSerializationInclusion(JsonInclude.Include.NON_NULL); // null 필드 제외
        return mapper;
    }

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
}
```

---

## 5. 의존성 주입(DI) — 세 가지 방식 비교

### 📌 생성자 주입 (권장)

Spring 공식 문서에서 권장하는 방식이다. Lombok의 `@RequiredArgsConstructor`와 함께 사용하면 보일러플레이트를 줄일 수 있다.

```java
/**
 * @RequiredArgsConstructor: final 필드를 대상으로 생성자를 자동 생성한다.
 * 생성자가 1개면 @Autowired 생략 가능 (Spring 4.3+).
 */
@Service
@RequiredArgsConstructor
public class OrderService {

    private final PaymentService paymentService;   // 불변 보장
    private final OrderRepository orderRepository; // 불변 보장
}
```

생성자 주입이 권장되는 이유 세 가지다.

- `final` 키워드로 불변성 보장
- 순환 참조를 컴파일/실행 시점에 바로 감지
- 테스트 시 컨테이너 없이 직접 주입 가능 → 단위 테스트 용이

### 📌 세터 주입 (선택적 의존성)

의존성이 반드시 필요하지 않은 경우에만 사용한다.

```java
@Service
public class EmailService {

    private SmtpClient smtpClient;

    @Autowired(required = false) // Bean이 없어도 동작 가능한 경우
    public void setSmtpClient(SmtpClient smtpClient) {
        this.smtpClient = smtpClient;
    }
}
```

### 📌 필드 주입 (테스트 코드 외 지양)

```java
@Service
public class UserService {

    @Autowired  // 외부 주입 불가, 테스트 어려움 → 실무에서 지양
    private UserRepository userRepository;
}
```

---

## 6. AOP — 관심사의 분리

### 📌 프록시 구조

스프링 AOP는 프록시 패턴 기반으로 동작한다. 컨테이너가 Bean을 생성할 때, AOP 대상 Bean은 원본 객체를 감싸는 프록시 객체로 교체된다.

- 인터페이스가 있으면 → JDK Dynamic Proxy
- 없으면 → CGLIB (클래스 상속 기반)
- 스프링 부트 기본값 → CGLIB

```java
@Aspect
@Component
public class LoggingAspect {

    private static final Logger log = LoggerFactory.getLogger(LoggingAspect.class);

    /**
     * Pointcut: service 패키지 하위 모든 메서드를 AOP 적용 대상으로 지정.
     * execution 표현식으로 패키지, 클래스, 메서드, 파라미터를 세밀하게 제어할 수 있다.
     */
    @Pointcut("execution(* com.example.service..*(..))")
    private void serviceLayer() {}

    /**
     * Around: 메서드 실행 전후를 모두 제어하는 가장 강력한 Advice.
     * joinPoint.proceed()를 기준으로 앞/뒤에 로직을 삽입한다.
     */
    @Around("serviceLayer()")
    public Object logExecutionTime(ProceedingJoinPoint joinPoint) throws Throwable {
        long start = System.currentTimeMillis();
        String methodName = joinPoint.getSignature().getName();

        log.info("[AOP] {} 시작", methodName);
        Object result = joinPoint.proceed(); // 실제 메서드 호출
        log.info("[AOP] {} 완료 — {}ms", methodName, System.currentTimeMillis() - start);

        return result;
    }

    @AfterThrowing(pointcut = "serviceLayer()", throwing = "ex")
    public void logException(JoinPoint joinPoint, Exception ex) {
        log.error("[AOP] {} 예외 발생: {}", joinPoint.getSignature().getName(), ex.getMessage());
    }
}
```

| Advice 종류 | 설명 |
|------------|------|
| `@Before` | 메서드 실행 전 |
| `@After` | 실행 후 (항상, 예외 무관) |
| `@AfterReturning` | 정상 반환 후 |
| `@AfterThrowing` | 예외 발생 시 |
| `@Around` | 전/후 모두 제어 (가장 강력) |

---

## 7. @SpringBootApplication 내부 구조

### 📌 어노테이션 해부

```java
// @SpringBootApplication의 실제 구성 (단순화)
@SpringBootConfiguration     // = @Configuration (Bean 설정 클래스)
@EnableAutoConfiguration     // ← 자동 설정의 핵심
@ComponentScan(excludeFilters = { ... }) // 컴포넌트 스캔
public @interface SpringBootApplication { ... }
```

`@EnableAutoConfiguration`이 `spring-boot-autoconfigure` 라이브러리의 `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` 파일을 읽어 수백 개의 자동 설정을 조건부로 적용한다.

예를 들어 `spring-boot-starter-web` 추가 시 `DispatcherServletAutoConfiguration`, `WebMvcAutoConfiguration` 등이 자동으로 등록된다.

---

## 8. Bean 생명주기

### 📌 8단계 흐름

| 단계 | 내용 | 콜백 |
|------|------|------|
| 1 | 인스턴스화 | 생성자 호출 |
| 2 | 의존성 주입 | @Autowired 처리 |
| 3 | Aware 인터페이스 | BeanNameAware, ApplicationContextAware |
| 4 | BeanPostProcessor Before | 초기화 전 가공 |
| 5 | 초기화 | @PostConstruct → afterPropertiesSet() → initMethod |
| 6 | BeanPostProcessor After | **AOP 프록시 생성 시점** |
| 7 | 사용 | 컨테이너가 싱글톤으로 보관 |
| 8 | 소멸 | @PreDestroy |

> 💡 6단계(BeanPostProcessor After)가 AOP의 핵심 연결 지점이다. `AbstractAutoProxyCreator`가 이 시점에 대상 Bean을 프록시로 교체한다. 컨테이너에서 꺼낸 Bean이 대부분 프록시 객체인 이유가 여기에 있다.

```java
@Component
public class DatabaseConnectionPool implements BeanNameAware, ApplicationContextAware {

    /**
     * 1단계: 인스턴스화.
     * 컨테이너가 가장 먼저 생성자를 호출한다.
     */
    public DatabaseConnectionPool() {
        System.out.println("[1] 인스턴스화 — 생성자 호출");
    }

    /** 3단계: Bean 이름 주입 */
    @Override
    public void setBeanName(String name) {
        System.out.println("[3-1] BeanNameAware — beanName: " + name);
    }

    /** 3단계: ApplicationContext 주입 */
    @Override
    public void setApplicationContext(ApplicationContext ctx) {
        System.out.println("[3-2] ApplicationContextAware — context 주입");
    }

    /** 5단계: 초기화 — DB 커넥션 풀 준비 */
    @PostConstruct
    public void init() {
        System.out.println("[5] @PostConstruct — 커넥션 풀 초기화");
    }

    /** 8단계: 소멸 — 컨테이너 종료 시 리소스 정리 */
    @PreDestroy
    public void destroy() {
        System.out.println("[8] @PreDestroy — 커넥션 풀 종료");
    }
}
```

---

## 9. 정리

- IoC는 객체 생성 제어권을 컨테이너에 넘기는 것이고, DI는 그 결과로 의존성을 외부에서 주입받는 방식이다.
- DI는 생성자 주입을 사용해야 불변성 보장과 테스트 용이성을 모두 확보할 수 있다.
- AOP는 프록시 기반으로 동작하며, BeanPostProcessor After 단계에서 프록시로 교체된다.
- `@SpringBootApplication` 하나가 컴포넌트 스캔 + 자동 설정 + Bean 등록을 모두 처리한다.

---

## 10. 참고 자료

- [Spring Framework 공식 문서 — IoC Container](https://docs.spring.io/spring-framework/reference/core/beans.html)
- [Spring Boot 공식 문서 — Auto-configuration](https://docs.spring.io/spring-boot/docs/current/reference/html/using.html#using.auto-configuration)
- [Spring Framework 공식 문서 — AOP](https://docs.spring.io/spring-framework/reference/core/aop.html)
- [Spring Framework 공식 문서 — Dependency Injection](https://docs.spring.io/spring-framework/reference/core/beans/dependencies/factory-collaborators.html)
