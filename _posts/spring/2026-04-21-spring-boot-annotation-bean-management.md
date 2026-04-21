---
title: Spring Boot 어노테이션 & 빈 관리 (@Transactional, 스코프, 커스텀 어노테이션, BeanPostProcessor)
date: 2026-04-21 10:00:00 +0900
categories: [Spring, SpringBoot]
order: 3
tags: [SpringBoot, Transactional, BeanScope, AOP, CustomAnnotation, BeanPostProcessor, ConfigurationProperties]
---

## 1. 개요

스프링의 어노테이션은 단순한 마커가 아니다. 각 어노테이션이 어떤 메커니즘으로 동작하는지 이해하면 문제가 생겼을 때 원인을 빠르게 찾을 수 있다.

| 주제 | 내용 |
|------|------|
| 핵심 어노테이션 내부 동작 | 어노테이션 처리 메커니즘 두 가지 방식 |
| @Transactional | 전파, 격리, 롤백, 주의사항 |
| 빈 스코프 | Singleton, Prototype, Request, Session |
| 조건부 빈 | @Profile, @Conditional 계열 |
| 커스텀 어노테이션 | 합성 어노테이션, AOP 기반 어노테이션 |
| BeanPostProcessor | 스프링 내부 동작 원리 |
| 설정값 주입 | @Value, @ConfigurationProperties |
| 빈 등록 전체 흐름 | 애플리케이션 시작부터 준비 완료까지 |

---

## 2. 핵심 어노테이션 내부 동작 원리

### 📌 어노테이션 처리 메커니즘 두 가지

스프링의 어노테이션 처리 방식은 크게 두 가지다.

```
방식 1 — BeanPostProcessor가 직접 처리
    @Autowired, @Value, @Inject
        → AutowiredAnnotationBeanPostProcessor

    @PostConstruct, @PreDestroy, @Resource
        → CommonAnnotationBeanPostProcessor

    @PersistenceContext, @PersistenceUnit
        → PersistenceAnnotationBeanPostProcessor

방식 2 — AOP 프록시가 메서드 호출 시점에 처리
    @Transactional  → TransactionInterceptor
    @Async          → AsyncExecutionInterceptor
    @Cacheable      → CacheInterceptor
    @Validated      → MethodValidationInterceptor

    → BeanPostProcessor After 단계에서 프록시 생성
    → 컨테이너에서 꺼낸 Bean은 프록시 객체
```

두 방식의 핵심 차이는 실행 시점이다. BeanPostProcessor 방식은 Bean 생성 시점(컨테이너 시작 시)에 처리되고, AOP 프록시 방식은 메서드가 실제로 호출되는 런타임 시점에 처리된다.

### 📌 @Autowired 처리 흐름

`@Autowired`를 직접 처리하는 건 `AutowiredAnnotationBeanPostProcessor`다. Bean 생성 직후(의존성 주입 단계)에 해당 BeanPostProcessor가 필드와 메서드를 리플렉션으로 스캔해 주입 대상을 찾는다.

```java
/**
 * AutowiredAnnotationBeanPostProcessor 핵심 동작 (단순화).
 *
 * Bean이 인스턴스화된 직후 실행된다.
 * 1. 클래스의 모든 필드/메서드를 리플렉션으로 스캔
 * 2. @Autowired, @Value, @Inject 어노테이션 탐색
 * 3. 컨테이너에서 타입 매칭 → 주입
 */
@Override
public PropertyValues postProcessProperties(PropertyValues pvs, Object bean, String beanName) {
    InjectionMetadata metadata = findAutowiringMetadata(beanName, bean.getClass(), pvs);
    metadata.inject(bean, beanName, pvs); // 실제 주입
    return pvs;
}
```

같은 타입의 Bean이 여러 개일 때 어떤 기준으로 선택하는지 이해해야 한다.

```java
public interface PaymentGateway { void pay(BigDecimal amount); }

@Component("kakaoPayGateway")
public class KakaoPayGateway implements PaymentGateway { ... }

@Component("naverPayGateway")
public class NaverPayGateway implements PaymentGateway { ... }

@Service
public class OrderService {

    /**
     * [충돌] PaymentGateway 타입 Bean이 두 개 → NoUniqueBeanDefinitionException 발생.
     */
    @Autowired
    private PaymentGateway paymentGateway; // ← 예외

    /**
     * [해결 1] @Qualifier: Bean 이름을 명시해 선택.
     */
    @Autowired
    @Qualifier("kakaoPayGateway")
    private PaymentGateway paymentGateway;

    /**
     * [해결 2] @Primary: 해당 Bean을 기본값으로 지정.
     * 주입 시 @Qualifier가 없으면 @Primary Bean을 선택한다.
     */
    // KakaoPayGateway 클래스에 @Primary 추가

    /**
     * [해결 3] 필드명을 Bean 이름과 동일하게 — 타입 매칭 후 이름으로 2차 매칭.
     */
    @Autowired
    private PaymentGateway kakaoPayGateway; // 필드명 = Bean 이름

    /**
     * [해결 4] 전부 주입받아 직접 선택.
     */
    @Autowired
    private Map<String, PaymentGateway> paymentGateways;
    // {"kakaoPayGateway": ..., "naverPayGateway": ...}
}
```

### 📌 @Value 처리 흐름

`@Value`도 `AutowiredAnnotationBeanPostProcessor`가 처리한다. 값은 `Environment`에서 가져오며, SpEL(Spring Expression Language) 표현식도 이 시점에 평가된다.

```java
@Component
public class AppConfig {

    /**
     * PropertySourcesPlaceholderConfigurer가 ${...} 플레이스홀더를 해석.
     * Environment → PropertySource 체인 순서대로 값을 탐색한다:
     * 1. 커맨드라인 인자
     * 2. 시스템 환경 변수
     * 3. application-{profile}.yml
     * 4. application.yml
     */
    @Value("${app.name}")
    private String appName;

    @Value("${app.timeout:5000}")   // 기본값 5000 — 설정이 없어도 예외 없음
    private int timeoutMs;

    /**
     * SpEL 표현식: #{...}
     * Bean 참조, 연산, 조건식, 리스트/맵 파싱이 가능하다.
     */
    @Value("#{systemProperties['user.timezone']}")
    private String timezone;

    @Value("#{T(java.lang.Math).random() * 100}")
    private double randomValue;

    @Value("#{${app.retryMap}}")    // YAML Map → java.util.Map
    private Map<String, Integer> retryMap;
}
```

### 📌 @PostConstruct / @PreDestroy 처리 흐름

`CommonAnnotationBeanPostProcessor`가 처리한다. `@PostConstruct`는 의존성 주입이 완료된 직후, `@PreDestroy`는 컨테이너 종료 시 호출된다.

```java
@Component
public class CacheWarmupService {

    private final ProductRepository productRepository;
    private final CacheManager cacheManager;

    public CacheWarmupService(ProductRepository productRepository,
                               CacheManager cacheManager) {
        this.productRepository = productRepository;
        this.cacheManager = cacheManager;
    }

    /**
     * @PostConstruct: 생성자 호출 및 DI 완료 후 한 번 실행.
     * DB 연결이나 다른 Bean에 의존하는 초기화 작업을 여기서 수행한다.
     * 생성자 내부에서 하면 DI가 완료되지 않아 NPE가 발생할 수 있다.
     */
    @PostConstruct
    public void warmupCache() {
        List<Product> popularProducts = productRepository.findTop100ByOrderBySalesDesc();
        Cache cache = cacheManager.getCache("products");
        popularProducts.forEach(p -> cache.put(p.getId(), p));
        log.info("[Cache] 인기 상품 {}개 워밍업 완료", popularProducts.size());
    }

    /**
     * @PreDestroy: 컨테이너 종료 시 Bean 소멸 전 실행.
     * 외부 연결, 스레드 풀, 파일 핸들러 등 리소스 정리에 사용한다.
     */
    @PreDestroy
    public void evictCache() {
        cacheManager.getCache("products").clear();
        log.info("[Cache] 캐시 정리 완료");
    }
}
```

### 📌 AOP 기반 어노테이션 — 프록시 생성 원리

`@Transactional`, `@Async`, `@Cacheable` 등은 `AbstractAutoProxyCreator`(BeanPostProcessor After 단계)가 해당 어노테이션을 감지하면 실제 Bean 대신 CGLIB 프록시를 컨테이너에 등록한다.

```java
/**
 * AbstractAutoProxyCreator.postProcessAfterInitialization() 단순화.
 *
 * 이 메서드가 실행되는 시점:
 * - @PostConstruct 완료 후
 * - 모든 의존성 주입 완료 후
 *
 * 처리 결과:
 * - AOP 대상 Bean → 프록시 객체로 교체해 반환
 * - AOP 비대상 Bean → 원본 Bean 그대로 반환
 */
@Override
public Object postProcessAfterInitialization(Object bean, String beanName) {
    if (isAopTarget(bean)) {
        return createProxy(bean); // CGLIB 프록시 생성 및 반환
    }
    return bean;
}

// 프록시 여부 확인 방법
@Service
@Transactional
public class OrderService { ... }

// 컨테이너에서 꺼낸 Bean 타입 확인
OrderService service = context.getBean(OrderService.class);
System.out.println(service.getClass().getName());
// → com.example.service.OrderService$$SpringCGLIB$$0

// AopUtils로 프록시 여부 확인
System.out.println(AopUtils.isAopProxy(service));        // true
System.out.println(AopUtils.isCglibProxy(service));      // true
System.out.println(AopUtils.isJdkDynamicProxy(service)); // false (인터페이스 없음)
```

---

## 3. @Transactional — 전파, 격리, 롤백 완전 정리

### 📌 프록시 동작 구조

```
Caller
  │
  ▼
트랜잭션 프록시 (CGLIB 생성)
  ├─ ① 트랜잭션 시작 (PlatformTransactionManager.getTransaction())
  ├─ ② 실제 Service Bean 메서드 위임 호출
  ├─ ③ 정상 종료 → commit() / RuntimeException → rollback()
  └─ ④ 커넥션 반환 (커넥션 풀)
```

### 📌 전파(Propagation)

전파 속성은 "트랜잭션이 이미 존재할 때, 새로운 @Transactional 메서드 호출이 어떻게 동작할지"를 결정한다.

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final PaymentService paymentService;
    private final NotificationService notificationService;

    /**
     * REQUIRED (기본값): 트랜잭션이 있으면 참여, 없으면 새로 시작.
     * createOrder 트랜잭션 안에서 processPayment가 실행된다.
     * processPayment에서 예외 발생 → createOrder 전체 롤백.
     */
    @Transactional
    public OrderResponse createOrder(CreateOrderRequest request) {
        Order order = orderRepository.save(Order.from(request));
        paymentService.processPayment(order.getId(), request.getAmount());
        notificationService.sendOrderConfirmation(order.getId());
        return OrderResponse.from(order);
    }
}

@Service
public class PaymentService {

    /**
     * REQUIRED: 호출한 쪽 트랜잭션에 참여.
     * 여기서 예외 발생 시 createOrder 트랜잭션 전체 롤백.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public void processPayment(Long orderId, BigDecimal amount) { ... }
}

@Service
public class NotificationService {

    /**
     * REQUIRES_NEW: 항상 새 트랜잭션을 시작.
     * 기존 createOrder 트랜잭션을 잠시 보류(suspend)하고 새 트랜잭션으로 실행.
     * 알림 실패가 주문 전체를 롤백시키면 안 되는 경우에 사용한다.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendOrderConfirmation(Long orderId) { ... }
}
```

| 전파 속성 | 트랜잭션 있을 때 | 트랜잭션 없을 때 |
|---------|--------------|--------------|
| `REQUIRED` (기본) | 기존에 참여 | 새로 시작 |
| `REQUIRES_NEW` | 기존 보류, 새로 시작 | 새로 시작 |
| `SUPPORTS` | 기존에 참여 | 트랜잭션 없이 실행 |
| `NOT_SUPPORTED` | 기존 보류, 트랜잭션 없이 실행 | 트랜잭션 없이 실행 |
| `MANDATORY` | 기존에 참여 | 예외 발생 |
| `NEVER` | 예외 발생 | 트랜잭션 없이 실행 |
| `NESTED` | 중첩 트랜잭션 (savepoint) | 새로 시작 |

### 📌 격리(Isolation)

격리 수준은 "동시에 실행되는 트랜잭션 간에 얼마나 데이터를 격리할지"를 결정한다.

| 격리 수준 | Dirty Read | Non-Repeatable Read | Phantom Read |
|---------|-----------|---------------------|-------------|
| READ_UNCOMMITTED | 발생 | 발생 | 발생 |
| READ_COMMITTED | 방지 | 발생 | 발생 |
| REPEATABLE_READ | 방지 | 방지 | 발생 |
| SERIALIZABLE | 방지 | 방지 | 방지 |

```java
/**
 * READ_COMMITTED: 커밋된 데이터만 읽는다.
 * 대부분의 실무 서비스에 적합. Oracle 기본값이기도 하다.
 */
@Transactional(isolation = Isolation.READ_COMMITTED)
public ProductResponse getProduct(Long id) { ... }

/**
 * REPEATABLE_READ: 트랜잭션 내에서 같은 데이터를 여러 번 읽어도 동일한 결과 보장.
 * 재고 차감처럼 읽은 후 수정하는 로직에 적합. MySQL InnoDB 기본값이다.
 */
@Transactional(isolation = Isolation.REPEATABLE_READ)
public void decreaseStock(Long productId, int quantity) { ... }

/**
 * SERIALIZABLE: 가장 강한 격리. 완전한 순차 실행 보장.
 * 성능 비용이 매우 크므로 정합성이 절대적으로 중요한 경우에만 사용한다.
 */
@Transactional(isolation = Isolation.SERIALIZABLE)
public void transferMoney(Long fromId, Long toId, BigDecimal amount) { ... }
```

### 📌 롤백 규칙

```java
/**
 * 기본 동작:
 *   RuntimeException (unchecked) → 롤백
 *   Error                        → 롤백
 *   Exception (checked)          → 롤백 안 함 (커밋)
 *
 * rollbackFor: checked exception도 롤백 대상에 포함.
 * noRollbackFor: 특정 RuntimeException은 롤백 제외.
 */
@Transactional(
    rollbackFor = {BusinessException.class, IOException.class},
    noRollbackFor = {OptimisticLockingFailureException.class}
)
public void processOrder(Long orderId) throws IOException { ... }
```

### 📌 핵심 주의사항

```java
@Service
public class UserService {

    /**
     * [주의 1] 내부 호출 → 트랜잭션 미적용
     *
     * 프록시는 외부에서 호출될 때만 개입한다.
     * 같은 클래스 내부에서 this.updateUser()를 호출하면
     * 프록시를 거치지 않아 @Transactional이 적용되지 않는다.
     */
    public void registerUser(RegisterRequest request) {
        // this.updateUser() → 프록시 우회 → 트랜잭션 없음 (버그!)
        this.updateUser(request.getId(), request.getName());
    }

    @Transactional
    public void updateUser(Long id, String name) { ... }

    /**
     * [해결] 별도 클래스(Bean)로 분리 → 외부 호출로 프록시를 거치게 한다.
     */
    // UserUpdateService.updateUser()로 분리


    /**
     * [주의 2] private 메서드 → 트랜잭션 미적용
     *
     * CGLIB 프록시는 상속 기반이므로 private 메서드를 오버라이드할 수 없다.
     * private 메서드에 붙은 @Transactional은 완전히 무시된다.
     */
    @Transactional // 무시됨
    private void internalUpdate(Long id) { ... }


    /**
     * [주의 3] readOnly = true → 성능 최적화
     *
     * JPA: 스냅샷 저장 생략, dirty checking 비활성화 → 메모리·CPU 절감
     * DB: 읽기 전용 커넥션 또는 replica 라우팅 가능
     * 반드시 조회 전용 메서드에는 readOnly = true를 붙이는 습관을 갖는다.
     */
    @Transactional(readOnly = true)
    public UserResponse getUser(Long id) { ... }


    /**
     * [주의 4] checked exception 기본 커밋
     *
     * 아래 코드에서 IOException이 발생해도 트랜잭션은 커밋된다.
     * 의도치 않은 데이터 불일치를 막으려면 rollbackFor를 명시한다.
     */
    @Transactional // IOException 발생 시 커밋 → 데이터 불일치 위험
    public void processFile(Long id) throws IOException {
        userRepository.updateStatus(id, "PROCESSING");
        fileService.process(id); // IOException 발생 가능
    }

    @Transactional(rollbackFor = IOException.class) // 명시적 롤백 지정
    public void processFileSafe(Long id) throws IOException {
        userRepository.updateStatus(id, "PROCESSING");
        fileService.process(id);
    }
}
```

---

## 4. 빈 스코프

### 📌 스코프 종류

| 스코프 | 인스턴스 생성 주기 | 사용 예 |
|--------|----------------|--------|
| `singleton` (기본) | 컨테이너당 하나 | 서비스, 레포지토리, 대부분의 Bean |
| `prototype` | getBean() 호출마다 새로 생성 | 상태를 가지는 임시 객체 |
| `request` | HTTP 요청당 하나 | 요청별 컨텍스트 데이터 |
| `session` | HTTP 세션당 하나 | 세션별 사용자 상태 |
| `application` | ServletContext당 하나 | 애플리케이션 전역 공유 데이터 |

```java
@Component
@Scope("singleton") // 기본값 — 생략 가능
public class SingletonBean { }

@Component
@Scope("prototype") // 요청할 때마다 새 인스턴스 생성
public class PrototypeBean {
    private final String id = UUID.randomUUID().toString();
}

/**
 * proxyMode = TARGET_CLASS: 싱글톤 Bean에 주입 시 필수.
 * 싱글톤은 한 번만 주입받는데, request/session 스코프는 요청마다 달라야 한다.
 * 프록시가 실제 호출 시점에 현재 요청/세션의 인스턴스를 찾아 위임한다.
 */
@Component
@Scope(value = "request", proxyMode = ScopedProxyMode.TARGET_CLASS)
public class RequestContext {
    private String requestId = UUID.randomUUID().toString();
    private String userId;
    // getter/setter
}

@Component
@Scope(value = "session", proxyMode = ScopedProxyMode.TARGET_CLASS)
public class UserSession {
    private Long userId;
    private String role;
    // getter/setter
}
```

### 📌 prototype을 singleton에 주입할 때 주의사항

```java
@Service
public class OrderService {

    /**
     * [문제] 싱글톤에 prototype을 필드 주입하면
     * OrderService가 처음 생성될 때 한 번만 주입되어
     * 이후 항상 같은 prototype 인스턴스를 재사용한다.
     * prototype의 의미가 없어진다.
     */
    @Autowired
    private PrototypeBean prototypeBean; // 항상 같은 인스턴스 — 버그!


    /**
     * [해결 1] ObjectProvider — getObject() 호출마다 새 인스턴스 반환.
     * 스프링 표준 방식이다.
     */
    private final ObjectProvider<PrototypeBean> prototypeBeanProvider;

    public OrderService(ObjectProvider<PrototypeBean> prototypeBeanProvider) {
        this.prototypeBeanProvider = prototypeBeanProvider;
    }

    public void processWithPrototype() {
        PrototypeBean bean = prototypeBeanProvider.getObject(); // 새 인스턴스
        bean.doSomething();
    }


    /**
     * [해결 2] ApplicationContext.getBean() — 직접 컨테이너에서 꺼냄.
     * 동작은 같지만 컨테이너 의존성이 생겨 권장하지 않는다.
     */
    private final ApplicationContext context;

    public void processWithContext() {
        PrototypeBean bean = context.getBean(PrototypeBean.class);
        bean.doSomething();
    }
}
```

---

## 5. 조건부 빈 — @Profile & @Conditional

### 📌 @Profile

```java
@Configuration
public class StorageConfig {

    /**
     * local 프로파일: 로컬 파일 시스템 사용.
     * 실행 시 -Dspring.profiles.active=local 또는
     * application.yml의 spring.profiles.active: local 로 지정한다.
     */
    @Bean
    @Profile("local")
    public StorageService localStorageService() {
        return new LocalFileStorageService();
    }

    /**
     * dev, prod 프로파일: AWS S3 사용.
     * 배열로 여러 프로파일을 지정할 수 있다.
     */
    @Bean
    @Profile({"dev", "prod"})
    public StorageService s3StorageService(AmazonS3 s3Client) {
        return new S3StorageService(s3Client);
    }
}
```

### 📌 @Conditional 계열

```java
/**
 * @ConditionalOnProperty: 설정값에 따라 Bean 등록.
 * feature.payment.kakao.enabled=true 일 때만 등록된다.
 */
@Bean
@ConditionalOnProperty(
    prefix = "feature.payment",
    name = "kakao.enabled",
    havingValue = "true",
    matchIfMissing = false // 설정이 없으면 등록 안 함
)
public PaymentGateway kakaoPayGateway() {
    return new KakaoPayGateway();
}

/**
 * @ConditionalOnMissingBean: 해당 타입의 Bean이 없을 때만 등록.
 * 라이브러리가 기본 Bean을 제공하되, 사용자가 커스텀 Bean을 등록하면
 * 기본 Bean을 등록하지 않는 패턴에 사용한다.
 * 스프링 부트 자동 설정 내부에서 광범위하게 사용된다.
 */
@Bean
@ConditionalOnMissingBean(ObjectMapper.class)
public ObjectMapper defaultObjectMapper() {
    return new ObjectMapper();
}

/**
 * @ConditionalOnClass: 해당 클래스가 클래스패스에 존재할 때만 등록.
 * 스프링 부트 자동 설정의 핵심 메커니즘이다.
 * DataSource 클래스가 있을 때(= DB 관련 의존성 추가 시)만 설정 적용.
 */
@Configuration
@ConditionalOnClass(DataSource.class)
public class DataSourceAutoConfiguration { ... }

/**
 * @ConditionalOnBean: 특정 Bean이 이미 등록되어 있을 때만 등록.
 */
@Bean
@ConditionalOnBean(DataSource.class)
public JdbcTemplate jdbcTemplate(DataSource dataSource) {
    return new JdbcTemplate(dataSource);
}
```

---

## 6. 커스텀 어노테이션

### 📌 합성 어노테이션 (Composed Annotation)

반복해서 함께 붙이는 어노테이션 조합을 하나로 합친다.

```java
/**
 * @ApiController: API 컨트롤러에 반복적으로 붙이는 어노테이션을 합성.
 *
 * 기존 방식:
 *   @RestController
 *   @RequestMapping("/api/v1/users")
 *   @Validated
 *   public class UserController { }
 *
 * 합성 어노테이션 적용 후:
 *   @ApiController("/api/v1/users")
 *   public class UserController { }
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@RestController
@RequestMapping
@Validated
public @interface ApiController {

    /**
     * @AliasFor: 합성된 어노테이션의 속성을 상위 어노테이션 속성으로 위임.
     * ApiController의 value()가 RequestMapping의 value()로 연결된다.
     */
    @AliasFor(annotation = RequestMapping.class, attribute = "value")
    String[] value() default {};
}

// 사용
@ApiController("/api/v1/users")
public class UserController {
    // @RestController + @RequestMapping("/api/v1/users") + @Validated 모두 적용
}
```

### 📌 AOP 기반 커스텀 어노테이션 — 실행 시간 측정

```java
// 1. 어노테이션 정의
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface TrackTime {
    String value() default ""; // 측정 이름 (선택)
}

// 2. Aspect 구현
@Aspect
@Component
public class TrackTimeAspect {

    private static final Logger log = LoggerFactory.getLogger(TrackTimeAspect.class);

    /**
     * @annotation(trackTime): 메서드에 @TrackTime이 붙은 경우.
     * @within(trackTime): 클래스에 @TrackTime이 붙은 경우 (클래스 내 모든 메서드 적용).
     *
     * 파라미터명(trackTime)이 어노테이션 인스턴스로 바인딩되어
     * trackTime.value() 등 어노테이션 속성에 접근할 수 있다.
     */
    @Around("@annotation(trackTime) || @within(trackTime)")
    public Object trackExecutionTime(ProceedingJoinPoint joinPoint,
                                     TrackTime trackTime) throws Throwable {
        long start = System.currentTimeMillis();
        String name = trackTime.value().isEmpty()
                ? joinPoint.getSignature().toShortString()
                : trackTime.value();
        try {
            return joinPoint.proceed();
        } finally {
            long elapsed = System.currentTimeMillis() - start;
            log.info("[TrackTime] {} — {}ms", name, elapsed);
        }
    }
}

// 3. 사용
@Service
public class ReportService {

    @TrackTime("월별 리포트 생성")
    public ReportResponse generateMonthlyReport(YearMonth month) {
        // 복잡한 집계 로직 — 실행 시간이 자동으로 로깅된다
    }
}
```

### 📌 AOP 기반 커스텀 어노테이션 — 분산 락

```java
// 1. 어노테이션
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface DistributedLock {
    String key();                               // 락 키 (SpEL 표현식 지원)
    long waitTime() default 5L;                 // 락 대기 시간
    long leaseTime() default 10L;               // 락 점유 시간
    TimeUnit timeUnit() default TimeUnit.SECONDS;
}

// 2. Aspect
@Aspect
@Component
@RequiredArgsConstructor
public class DistributedLockAspect {

    private final RedissonClient redissonClient;
    private final ExpressionParser parser = new SpelExpressionParser();

    /**
     * @Transactional과 함께 사용할 때 락 획득이 트랜잭션 시작보다 먼저여야 한다.
     * @Order를 사용해 이 Aspect가 트랜잭션 Aspect보다 먼저 실행되도록 설정한다.
     */
    @Around("@annotation(distributedLock)")
    public Object lock(ProceedingJoinPoint joinPoint,
                       DistributedLock distributedLock) throws Throwable {

        String lockKey = resolveKey(distributedLock.key(), joinPoint);
        RLock lock = redissonClient.getLock("LOCK:" + lockKey);

        boolean acquired = lock.tryLock(
            distributedLock.waitTime(),
            distributedLock.leaseTime(),
            distributedLock.timeUnit()
        );

        if (!acquired) {
            throw new LockAcquisitionException("락 획득 실패: " + lockKey);
        }

        try {
            return joinPoint.proceed();
        } finally {
            // isHeldByCurrentThread: 현재 스레드가 락을 보유 중인지 확인 후 해제
            // 락 만료(leaseTime 초과)로 이미 해제된 경우 IllegalMonitorStateException 방지
            if (lock.isHeldByCurrentThread()) {
                lock.unlock();
            }
        }
    }

    /**
     * SpEL 표현식으로 동적 키 생성.
     * key = "#productId" → 실제 파라미터 값으로 치환.
     * key = "#request.orderId" → 객체 필드 접근도 가능.
     */
    private String resolveKey(String keyExpression, ProceedingJoinPoint joinPoint) {
        MethodSignature signature = (MethodSignature) joinPoint.getSignature();
        StandardEvaluationContext context = new StandardEvaluationContext();
        String[] paramNames = signature.getParameterNames();
        Object[] args = joinPoint.getArgs();
        for (int i = 0; i < paramNames.length; i++) {
            context.setVariable(paramNames[i], args[i]);
        }
        return parser.parseExpression(keyExpression).getValue(context, String.class);
    }
}

// 3. 사용
@Service
public class StockService {

    /**
     * 동일 상품에 대한 동시 재고 차감을 직렬화.
     * key = "#productId" → 상품별로 독립적인 락 사용.
     * @Transactional과 함께 사용 — 락 획득 후 트랜잭션 시작.
     */
    @DistributedLock(key = "#productId", waitTime = 3, leaseTime = 5)
    @Transactional
    public void decreaseStock(Long productId, int quantity) {
        Stock stock = stockRepository.findByProductIdWithLock(productId);
        stock.decrease(quantity); // 재고 부족 시 InsufficientStockException
        stockRepository.save(stock);
    }
}
```

---

## 7. BeanPostProcessor

### 📌 스프링 내부 주요 BeanPostProcessor

| BeanPostProcessor | 처리 내용 | 실행 단계 |
|-------------------|---------|---------|
| `AutowiredAnnotationBeanPostProcessor` | `@Autowired`, `@Value`, `@Inject` 주입 | Before + Properties |
| `CommonAnnotationBeanPostProcessor` | `@PostConstruct`, `@PreDestroy`, `@Resource` | Before (초기화 전/후) |
| `PersistenceAnnotationBeanPostProcessor` | `@PersistenceContext`, `@PersistenceUnit` | Before |
| `AbstractAutoProxyCreator` | `@Transactional`, `@Async` 등 AOP 프록시 생성 | **After** |
| `ApplicationContextAwareProcessor` | `ApplicationContextAware` 등 Aware 인터페이스 주입 | Before |

### 📌 커스텀 BeanPostProcessor

```java
/**
 * 커스텀 BeanPostProcessor — 특정 조건을 만족하지 않는 Bean의 시작을 막는다.
 * 잘못된 설정으로 서버가 시작된 후 런타임에 오류가 발생하는 것을 사전에 방지한다.
 */
@Component
public class RequiredConfigBeanPostProcessor implements BeanPostProcessor {

    /**
     * postProcessBeforeInitialization: @PostConstruct 실행 전 호출.
     * 반환값이 다른 객체면 컨테이너에 원본 대신 반환 객체가 등록된다.
     * null을 반환하면 안 된다 — 이후 BeanPostProcessor가 처리하지 못한다.
     */
    @Override
    public Object postProcessBeforeInitialization(Object bean, String beanName)
            throws BeansException {

        if (bean instanceof RequiredConfigValidator validator) {
            try {
                validator.validate();
            } catch (Exception e) {
                throw new BeanInitializationException(
                    beanName + " 필수 설정 누락: " + e.getMessage(), e);
            }
        }
        return bean; // 원본 Bean 반환 (교체하지 않음)
    }

    /**
     * postProcessAfterInitialization: @PostConstruct 실행 후 호출.
     * 이 시점에 AbstractAutoProxyCreator가 프록시로 교체한다.
     * 커스텀 래핑이 필요하면 여기서 Wrapper 객체를 반환한다.
     */
    @Override
    public Object postProcessAfterInitialization(Object bean, String beanName)
            throws BeansException {
        return bean;
    }
}
```

---

## 8. @Value & @ConfigurationProperties

### 📌 @Value

```java
@Component
public class AppProperties {

    /**
     * ${...}: 프로퍼티 플레이스홀더.
     * Environment → PropertySource 체인을 순서대로 탐색한다.
     * 1. 커맨드라인 인자 (--app.name=foo)
     * 2. 시스템 환경 변수 (APP_NAME=foo)
     * 3. application-{profile}.yml
     * 4. application.yml
     */
    @Value("${app.name}")
    private String appName;

    @Value("${app.timeout:5000}") // 기본값 5000
    private int timeoutMs;

    /**
     * #{...}: SpEL(Spring Expression Language).
     * Bean 참조, 연산, 시스템 프로퍼티, 조건식 등이 가능하다.
     */
    @Value("#{systemProperties['user.timezone']}")
    private String timezone;

    @Value("#{@orderService.getDefaultPageSize()}") // Bean 메서드 호출
    private int defaultPageSize;

    @Value("#{${app.retryDelays}}") // YAML List → java.util.List
    private List<Integer> retryDelays;
}
```

### 📌 @ConfigurationProperties (권장)

`@Value`보다 IDE 자동 완성 지원, 유효성 검사, 테스트 편의성이 뛰어나다. 관련 설정이 여러 개라면 `@ConfigurationProperties`를 사용하는 것이 좋다.

```yaml
# application.yml
app:
  storage:
    bucket: my-service-uploads
    region: ap-northeast-2
    max-upload-size-mb: 10
    presigned-url-expiry: PT1H    # java.time.Duration 자동 변환
  mail:
    host: smtp.gmail.com
    port: 587
    retry-delays:
      - 1000
      - 3000
      - 5000
```

```java
/**
 * @ConfigurationProperties: prefix에 해당하는 설정을 타입 안전하게 바인딩.
 * Record 타입 사용 시 생성자 바인딩이 자동 적용된다.
 * @Validated 추가 시 바인딩 시점에 Bean Validation을 실행한다.
 */
@ConfigurationProperties(prefix = "app.storage")
@Validated
public record StorageProperties(
    @NotBlank String bucket,
    @NotBlank String region,
    @Min(1) @Max(100) int maxUploadSizeMb,
    Duration presignedUrlExpiry  // "PT1H" → Duration.ofHours(1) 자동 변환
) {}

@ConfigurationProperties(prefix = "app.mail")
public record MailProperties(
    @NotBlank String host,
    @Range(min = 1, max = 65535) int port,
    List<Integer> retryDelays
) {}

// @ConfigurationPropertiesScan: 베이스 패키지를 스캔해 자동 등록
@SpringBootApplication
@ConfigurationPropertiesScan
public class MyApplication { ... }

// 사용
@Service
@RequiredArgsConstructor
public class StorageService {

    private final StorageProperties storageProperties;

    public String upload(MultipartFile file) {
        String bucket = storageProperties.bucket();    // 타입 안전
        String region = storageProperties.region();
        // ...
    }
}
```

---

## 9. 빈 등록 전체 흐름

```
1. @SpringBootApplication 실행
   └─ AnnotationConfigServletWebServerApplicationContext 생성

2. @ComponentScan — 베이스 패키지 재귀 탐색
   └─ @Component 계열 클래스 → BeanDefinition 등록

3. @EnableAutoConfiguration — AutoConfiguration.imports 읽기
   └─ 조건부(@ConditionalOn*) 자동 설정 적용

4. BeanPostProcessor 우선 인스턴스화
   └─ AutowiredAnnotationBeanPostProcessor
   └─ AbstractAutoProxyCreator (AOP 프록시 생성 준비)

5. 싱글톤 Bean 일괄 생성 (의존 관계 순서)
   ├─ 생성자 호출 (인스턴스화)
   ├─ 의존성 주입 (AutowiredAnnotationBeanPostProcessor)
   ├─ Aware 인터페이스 콜백
   ├─ BeanPostProcessor Before (@PostConstruct 직전)
   ├─ @PostConstruct 실행
   └─ BeanPostProcessor After → AOP 프록시 교체

6. ApplicationReadyEvent 발행
   └─ @EventListener(ApplicationReadyEvent.class) 실행
```

```java
// ApplicationReadyEvent: 서버가 완전히 준비된 후 실행할 초기화 작업
@Component
public class AppStartupRunner {

    @EventListener(ApplicationReadyEvent.class)
    public void onApplicationReady() {
        // 캐시 워밍업, 외부 연결 확인, 스케줄러 초기화 등
        log.info("애플리케이션 준비 완료 — 서비스 시작");
    }
}

// ApplicationRunner / CommandLineRunner: 유사한 목적, 더 단순한 인터페이스
@Component
@Order(1) // 여러 Runner 간 실행 순서 지정
public class DataInitRunner implements ApplicationRunner {

    @Override
    public void run(ApplicationArguments args) throws Exception {
        // 커맨드라인 인자 접근 가능
        if (args.containsOption("reset-data")) {
            dataInitService.reset();
        }
    }
}
```

---

## 10. 정리

- 어노테이션 처리는 두 가지 메커니즘으로 나뉜다. `@Autowired`, `@Value`, `@PostConstruct`는 BeanPostProcessor가 Bean 생성 시점에 처리하고, `@Transactional`, `@Async`, `@Cacheable`은 AOP 프록시가 메서드 호출 시점에 처리한다.
- `@Transactional`은 AOP 프록시 기반이므로 내부 호출과 `private` 메서드에는 적용되지 않는다. 조회 전용 메서드에는 반드시 `readOnly = true`를 붙인다.
- prototype 스코프를 싱글톤 Bean에 주입할 때는 `ObjectProvider`로 매번 새 인스턴스를 꺼내야 한다.
- 커스텀 어노테이션은 합성 어노테이션(메타 어노테이션 조합)과 AOP 기반(Aspect + @Around) 두 가지 방식으로 구현한다.
- `@ConfigurationProperties`는 `@Value`보다 타입 안전성과 IDE 지원이 뛰어나므로 관련 설정이 여러 개면 `@ConfigurationProperties`를 사용한다.

---

## 11. 참고 자료

- [Spring Framework 공식 문서 — The IoC Container](https://docs.spring.io/spring-framework/reference/core/beans.html)
- [Spring Framework 공식 문서 — BeanPostProcessor](https://docs.spring.io/spring-framework/reference/core/beans/factory-extension.html#beans-factory-extension-bpp)
- [Spring Framework 공식 문서 — Transaction Management](https://docs.spring.io/spring-framework/reference/data-access/transaction.html)
- [Spring Framework 공식 문서 — AOP](https://docs.spring.io/spring-framework/reference/core/aop.html)
- [Spring Boot 공식 문서 — @ConfigurationProperties](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.external-config.typesafe-configuration-properties)
- [Spring Framework 공식 문서 — Bean Scopes](https://docs.spring.io/spring-framework/reference/core/beans/factory-scopes.html)
