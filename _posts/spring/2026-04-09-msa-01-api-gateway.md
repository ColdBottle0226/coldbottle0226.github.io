---
title: "스프링 클라우드 기반 MSA 구성 - API Gateway"
date: 2026-04-09 09:00:00 +0900
categories: [Spring, MSA]
order: 0
tags: [SpringCloud, MSA, APIGateway, SpringCloudGateway, Zuul, WebFlux, Predicate, Filter]
---

##  1. 개요

---

MSA(Microservice Architecture)를 처음 구성할 때 가장 먼저 마주치는 질문이 있다.

> "클라이언트가 서비스가 여러 개인데, 주소를 몇 개나 알아야 하지?"

예를 들어 서울 데이트 앱처럼 user-service(8081), place-service(8082), recommendation-service(8083)가 따로 떠 있다면, 클라이언트는 각 서비스 주소를 전부 알고 있어야 한다. 거기에 JWT 검증, Rate Limit, CORS 처리까지 서비스마다 각자 구현해야 한다면 중복 코드가 폭발한다.

이 문제를 해결하는 것이 **API Gateway**다. 모든 요청의 단일 진입점(Single Entry Point)이 되어, 인증·라우팅·필터링을 한 곳에서 처리한다.

> 💡 Spring Cloud 공식 문서는 Spring Cloud Gateway를 "Spring 6, Spring Boot 3, Project Reactor 기반으로 구축된 API Gateway"로 정의하며, 라우팅, 보안, 모니터링/메트릭, 복원력(Resiliency)을 제공하는 것을 목표로 한다고 설명한다.
> 출처: [docs.spring.io/spring-cloud-gateway](https://docs.spring.io/spring-cloud-gateway/reference/index.html)

### 📌 Zuul vs Spring Cloud Gateway

과거에는 Netflix Zuul을 많이 사용했지만, 현재는 **Spring Cloud Gateway가 공식 대체재**다.

| 구분 | Netflix Zuul 1.x | Spring Cloud Gateway |
|---|---|---|
| 기반 기술 | Servlet API (Blocking I/O) | Project Reactor (Non-blocking I/O) |
| Spring Cloud 지원 | 2020년 이후 deprecated | 현재 공식 지원 |
| 성능 | 스레드 풀 기반, 동시성 한계 있음 | 이벤트 루프 기반, 고동시성 처리 |
| Spring Boot 3 호환 | ❌ | ✅ |
| WebFlux 통합 | ❌ | ✅ (네이티브) |

> 💡 Zuul 2.x는 Netty 기반이지만 Spring Cloud 생태계와 통합이 없다. 신규 프로젝트에서는 반드시 Spring Cloud Gateway를 선택해야 한다.

### 📌 전체 요청 처리 흐름

```
Client 요청
  → Spring Cloud Gateway
    → Gateway Handler Mapping (라우트 매칭)
      → Gateway Web Handler
        → Pre Filter 실행 (JWT 검증, Rate Limit, Logging...)
          → 하위 서비스 (user-service, place-service 등)로 프록시
        → Post Filter 실행 (응답 헤더 추가, 로깅...)
  → Client 응답 반환
```

공식 문서에 따르면 필터는 "프록시 요청 전(pre)"과 "프록시 요청 후(post)" 두 단계로 나뉘어 실행된다.

---

##  2. 핵심 개념 3가지: Route, Predicate, Filter

---

Spring Cloud Gateway의 모든 기능은 이 세 가지 개념으로 설명된다.

### 📌 Route (라우트)

게이트웨이의 기본 구성 단위다. 하나의 Route는 다음 4가지로 구성된다.

- **ID**: 라우트 식별자 (문자열)
- **URI**: 요청을 전달할 목적지 (하위 서비스 주소)
- **Predicates**: 이 라우트를 적용할 조건 모음
- **Filters**: 요청/응답을 변환하는 필터 모음

> 💡 공식 문서: "A route is matched if the aggregate predicate is true." — 모든 Predicate 조건이 참일 때 해당 Route가 매칭된다.

### 📌 Predicate (조건자)

HTTP 요청의 어떤 속성을 기준으로 라우트를 매칭할지 결정한다. Java 8의 `Predicate<ServerWebExchange>`를 기반으로 한다.

주요 내장 Predicate:

| Predicate | 설명 | 예시 |
|---|---|---|
| `Path` | URL 경로 패턴 매칭 | `/api/users/**` |
| `Method` | HTTP 메서드 매칭 | `GET`, `POST` |
| `Header` | 요청 헤더 값 매칭 | `X-Request-Id, \d+` |
| `Host` | 호스트명 패턴 매칭 | `**.example.org` |
| `Query` | 쿼리 파라미터 매칭 | `param=value` |
| `After` / `Before` | 특정 시간 이후/이전 요청만 허용 | `datetime` |
| `RemoteAddr` | 클라이언트 IP 대역 매칭 | `192.168.0.0/24` |

### 📌 Filter (필터)

요청을 하위 서비스로 보내기 전(pre)이나 받은 후(post)에 요청/응답을 변환한다.

주요 내장 Filter:

| Filter | 설명 |
|---|---|
| `AddRequestHeader` | 요청 헤더 추가 |
| `AddResponseHeader` | 응답 헤더 추가 |
| `RewritePath` | URL 경로 재작성 |
| `StripPrefix` | URL 경로 앞부분 제거 |
| `RequestRateLimiter` | Redis 기반 Rate Limiting |
| `CircuitBreaker` | Resilience4j Circuit Breaker 연동 |
| `Retry` | 실패 시 재시도 |
| `DedupeResponseHeader` | 중복 응답 헤더 제거 |

---

##  3. 기초 설정

---

### 📌 의존성 추가

```groovy
/**
 * Spring Cloud Gateway는 WebFlux(Reactor) 기반이다.
 * spring-boot-starter-web과 함께 사용하면 충돌이 발생하므로
 * Gateway 모듈에는 web 의존성을 추가하면 안 된다.
 */
ext {
    set('springCloudVersion', "2023.0.1")
}

dependencies {
    // Gateway 핵심 의존성 (WebFlux 포함)
    implementation 'org.springframework.cloud:spring-cloud-starter-gateway'

    // Eureka Client (서비스 디스커버리 연동, lb:// 주소 해석)
    implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'

    // Rate Limiting (Redis 토큰 버킷 저장소, Reactive 필수)
    implementation 'org.springframework.boot:spring-boot-starter-data-redis-reactive'

    // Circuit Breaker (WebFlux 호환 Reactor 전용)
    implementation 'org.springframework.cloud:spring-cloud-starter-circuitbreaker-reactor-resilience4j'

    // JWT 검증
    implementation 'io.jsonwebtoken:jjwt-api:0.12.5'

    // 분산 트레이싱
    implementation 'io.micrometer:micrometer-tracing-bridge-brave'
    implementation 'io.zipkin.reporter2:zipkin-reporter-brave'

    // Actuator (헬스체크, 메트릭)
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
}

dependencyManagement {
    imports {
        mavenBom "org.springframework.cloud:spring-cloud-dependencies:${springCloudVersion}"
    }
}
```

> 💡 `spring-cloud-starter-circuitbreaker-reactor-resilience4j`를 사용하는 이유가 있다. Gateway는 WebFlux(비동기) 기반이라 일반 `resilience4j` 대신 Reactor 전용 구현체가 필요하다.

### 📌 application.yml — 라우팅 및 필터 설정

```yaml
spring:
  application:
    name: api-gateway

  cloud:
    gateway:
      # Discovery Locator를 false로 설정하는 이유:
      # true로 하면 Eureka에 등록된 모든 서비스가 /서비스명/**으로 자동 노출된다.
      # 보안상 의도치 않은 엔드포인트가 열릴 수 있어 수동 라우팅으로 명시적 제어한다.
      discovery:
        locator:
          enabled: false
          lower-case-service-id: true

      # 모든 라우트에 공통 적용되는 기본 필터
      default-filters:
        - RemoveRequestHeader=Cookie   # 쿠키를 다운스트림으로 전달하지 않음

      routes:
        # 공개 엔드포인트 (로그인/회원가입) — JWT 불필요
        - id: user-auth
          uri: lb://user-service
          predicates:
            - Path=/api/auth/**
          filters:
            - name: CircuitBreaker
              args:
                name: userCB
                fallbackUri: forward:/fallback/user
            - name: RequestRateLimiter
              args:
                redis-rate-limiter.replenishRate: 30   # 초당 30개
                redis-rate-limiter.burstCapacity: 60   # 최대 60개 (브루트포스 방지)
                key-resolver: "#{@ipKeyResolver}"

        # 인증 필요 엔드포인트
        - id: user-service
          uri: lb://user-service
          predicates:
            - Path=/api/users/**
          filters:
            - name: CircuitBreaker
              args:
                name: userCB
                fallbackUri: forward:/fallback/user
            - name: RequestRateLimiter
              args:
                redis-rate-limiter.replenishRate: 100
                redis-rate-limiter.burstCapacity: 200
                key-resolver: "#{@ipKeyResolver}"

        # AI 서비스 — LLM 비용 제어를 위해 가장 낮게 설정
        - id: ai-service
          uri: lb://ai-service
          predicates:
            - Path=/api/ai/**
          filters:
            - name: CircuitBreaker
              args:
                name: aiCB
                fallbackUri: forward:/fallback/ai
            - name: RequestRateLimiter
              args:
                redis-rate-limiter.replenishRate: 20
                redis-rate-limiter.burstCapacity: 40
                key-resolver: "#{@ipKeyResolver}"
```

### 📌 서비스별 Rate Limit 차등 설정

서비스 특성에 따라 Rate Limit 수치를 다르게 잡는다.

| 서비스 | replenishRate | burstCapacity | 이유 |
|---|---|---|---|
| `/api/auth/**` | 30/s | 60 | 브루트포스 방지 |
| `/api/users/**` | 100/s | 200 | 일반 API |
| `/api/places/**` | 200/s | 400 | 조회 트래픽 많음 |
| `/api/ai/**` | 20/s | 40 | LLM 비용 제어 |

---

##  4. 필터 실행 순서 및 파이프라인

---

### 📌 전체 요청 처리 파이프라인

클라이언트 요청이 들어왔을 때 Gateway 내부에서 아래 순서로 필터가 실행된다.

```
Client → POST /api/users/profile (Authorization: Bearer <jwt>)

1. CorsWebFilter            — CORS Preflight 처리
2. JwtAuthenticationFilter  — JWT 검증, X-User-Id 헤더 추가 (order=-1)
3. Default Filters          — RemoveRequestHeader=Cookie
4. RequestRateLimiter       — Redis 토큰 버킷 검사 (초과 시 429)
5. CircuitBreaker + TimeLimiter — 장애 격리 (OPEN 시 Fallback)
6. LoadBalancer (lb://)     — Eureka에서 인스턴스 선택 (Round-Robin)
7. → 다운스트림 서비스 실제 요청 전달
   ← 응답 반환
```

> 💡 `getOrder() = -1`로 JWT 필터를 가장 먼저 실행하는 이유가 있다. Circuit Breaker 필터(order=0)보다 먼저 실행되어, 인증 실패 시 다운스트림 호출 자체를 차단한다. 인증도 안 된 요청이 CB까지 도달해 실패 카운트를 쌓는 것을 막는 구조다.

---

##  5. JWT Authentication Filter

---

### 📌 GlobalFilter란?

Spring Cloud Gateway의 **모든 요청에 공통 적용되는 필터**다. Spring MVC의 `WebMvcConfigurer`와 달리 Gateway 전용 컨텍스트(`ServerWebExchange`, `GatewayFilterChain`)를 사용한다.

### 📌 JWT 검증 처리 흐름

```
요청 진입
  │
  ▼
isWhitelisted(path)?
  ├── YES → chain.filter() [다음 필터로 통과]
  └── NO
        │
        ▼
  Bearer 토큰 추출
        │
        ▼
  JWT 서명 검증 (HMAC-SHA256)
        ├── 성공 → X-User-Id, X-User-Roles 헤더 추가 → chain.filter()
        ├── 만료 (ExpiredJwtException)    → 401
        ├── 서명 불일치 (SignatureException) → 401
        └── 형식 오류 (MalformedJwtException) → 401
```

```java
/**
 * GlobalFilter는 모든 라우트에 자동 적용된다.
 * Ordered 구현으로 실행 순서를 명시적으로 제어한다.
 * order=-1: Circuit Breaker 필터(order=0)보다 먼저 실행
 */
@Component
public class JwtAuthenticationFilter implements GlobalFilter, Ordered {

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String path = exchange.getRequest().getURI().getPath();

        if (isWhitelisted(path)) {
            return chain.filter(exchange);
        }

        String token = extractBearerToken(exchange);

        // JWT 검증 후 사용자 정보 추출
        Claims claims = validateToken(token); // 실패 시 예외 → 401 반환

        // exchange는 불변 객체이므로 mutate()로 새 객체를 생성해 헤더를 추가한다
        ServerHttpRequest mutatedRequest = exchange.getRequest().mutate()
                .header("X-User-Id", claims.getSubject())
                .header("X-User-Roles", claims.get("roles", String.class))
                .build();

        return chain.filter(exchange.mutate().request(mutatedRequest).build());
    }

    @Override
    public int getOrder() {
        return -1; // 낮은 숫자 = 높은 우선순위 (가장 먼저 실행)
    }
}
```

> 💡 `mutate()` 패턴을 쓰는 이유가 있다. `ServerHttpRequest`는 불변 객체라 직접 헤더를 추가할 수 없다. `mutate()`로 기존 요청을 복사한 새 객체를 생성해 헤더를 추가한다. 다운스트림 서비스(user-service 등)는 `X-User-Id` 헤더를 믿고 JWT를 직접 파싱하지 않아도 된다. JWT 검증 로직이 Gateway 한 곳에만 존재하게 된다.

---

##  6. Rate Limiter — Redis 토큰 버킷

---

### 📌 토큰 버킷 알고리즘

```
버킷 최대 용량 (burstCapacity: 60)
  ├── 매 초 30개 토큰 충전 (replenishRate: 30)
  ├── 요청 1개 = 토큰 1개 소모
  └── 버킷이 비면 → 429 Too Many Requests
```

```java
/**
 * X-Forwarded-For 헤더를 우선 확인하는 이유:
 * Nginx나 LB 뒤에 Gateway가 있을 때, 실제 클라이언트 IP는
 * RemoteAddress가 아닌 X-Forwarded-For에 담겨 온다.
 * 이를 무시하면 모든 요청이 LB의 IP로 묶여 Rate Limit이 제대로 동작하지 않는다.
 */
@Primary
@Bean
public KeyResolver ipKeyResolver() {
    return exchange -> {
        String forwarded = exchange.getRequest()
                .getHeaders().getFirst("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            // X-Forwarded-For: client, proxy1, proxy2 형식에서 첫 번째가 원본 IP
            return Mono.just(forwarded.split(",")[0].trim());
        }
        String ip = exchange.getRequest().getRemoteAddress()
                .getAddress().getHostAddress();
        return Mono.just(ip);
    };
}
```

```yaml
spring:
  data:
    redis:
      host: ${SPRING_DATA_REDIS_HOST:localhost}
      lettuce:
        pool:
          max-active: 8   # Reactive 커넥션 풀
```

---

##  7. CORS 설정

---

### 📌 왜 CorsWebFilter를 사용하나?

Spring MVC 환경이라면 `WebMvcConfigurer`를 쓰면 된다. 그러나 Gateway는 **WebFlux 기반**이라 Reactive 전용 `CorsWebFilter`를 사용해야 한다. `WebMvcConfigurer`는 WebFlux 컨텍스트에서 동작하지 않는다.

```java
/**
 * allowedOriginPatterns를 사용하는 이유:
 * allowCredentials=true 일 때 allowedOrigins="*" 조합은 Spring에서 허용하지 않는다.
 * (보안 정책) allowedOriginPatterns로 패턴을 지정해야 credentials와 함께 쓸 수 있다.
 */
@Bean
public CorsWebFilter corsWebFilter() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOriginPatterns(List.of(
        "http://localhost:3000",
        "https://*.seouldate.com"
    ));
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
    config.setAllowedHeaders(List.of("*"));
    config.setAllowCredentials(true);

    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);
    return new CorsWebFilter(source);
}
```

---

##  8. 분산 트레이싱 — Micrometer + Zipkin

---

```yaml
management:
  tracing:
    sampling:
      probability: 1.0   # 100% 샘플링 (운영에서는 0.1~0.3으로 낮출 것)
  zipkin:
    tracing:
      endpoint: http://zipkin:9411/api/v2/spans

logging:
  pattern:
    console: "%d{HH:mm:ss} [%X{traceId}/%X{spanId}] %-5level %msg%n"
```

요청이 Gateway → user-service → recommendation-service를 거쳐도 동일한 `traceId`로 전체 흐름을 추적할 수 있다.

---

##  9. 트러블슈팅

---

### 📌 "spring-boot-starter-web과 충돌"

```
Description: Spring MVC found on classpath, which is incompatible with Spring Cloud Gateway.
```

원인: Spring Cloud Gateway는 WebFlux 기반이라 `spring-boot-starter-web`과 공존할 수 없다.

해결: Gateway 모듈의 `build.gradle`에서 `spring-boot-starter-web` 의존성을 제거한다.

```groovy
// 잘못된 예
implementation 'org.springframework.boot:spring-boot-starter-web'
implementation 'org.springframework.cloud:spring-cloud-starter-gateway' // 충돌!

// 올바른 예
implementation 'org.springframework.cloud:spring-cloud-starter-gateway' // WebFlux 포함
```

### 📌 "lb:// 사용 시 503 Service Unavailable"

원인: Eureka Server가 아직 올라오지 않았거나, 대상 서비스가 Eureka에 등록되지 않은 상태에서 요청이 들어온 경우.

해결: Docker Compose에서 `depends_on`으로 Eureka가 먼저 healthy 상태가 되어야 Gateway가 기동되도록 순서를 보장한다.

```yaml
api-gateway:
  depends_on:
    eureka-server:
      condition: service_healthy
```

---

##  10. 개선 고려 사항

---

| 항목 | 현재 | 개선 방향 |
|---|---|---|
| JWT 검증 | HMAC 공유 시크릿 | RSA 공개키 방식 (시크릿 공유 불필요) |
| Config Server | native (로컬 파일) | Git 백엔드 (변경 이력 관리) |
| 트레이싱 샘플링 | 1.0 (100%) | 0.1~0.3으로 낮춤 (운영 성능) |
| Actuator health | show-details: always | when-authorized로 변경 (보안) |

---

##  11. 정리

---

- Spring Cloud Gateway는 Zuul을 대체하는 공식 API Gateway로, **Non-blocking(WebFlux) 기반**이라 고동시성 환경에서 유리하다.
- 모든 라우팅은 **Route(ID + URI + Predicates + Filters)** 단위로 구성된다.
- `lb://서비스명` 형식으로 **Eureka + LoadBalancer 자동 연동**이 가능하다.
- **GlobalFilter**로 JWT 검증·Rate Limit 같은 공통 관심사를 게이트웨이 한 곳에서 처리할 수 있다.
- JWT 필터는 `order=-1`로 **CB보다 먼저 실행**되어, 인증 실패 시 다운스트림 호출 자체를 차단한다.
- CORS는 WebFlux 환경이므로 **`CorsWebFilter`(Reactive)**를 사용해야 한다.
- Discovery Locator는 `false`로 두고 **수동 라우팅**으로 엔드포인트를 명시적으로 제어한다.

---

## 참고 자료

- Spring Cloud Gateway 공식 문서: <https://docs.spring.io/spring-cloud-gateway/reference/index.html>
- Spring 공식 가이드 - Building a Gateway: <https://spring.io/guides/gs/gateway/>
- Baeldung - Exploring Spring Cloud Gateway: <https://www.baeldung.com/spring-cloud-gateway>
