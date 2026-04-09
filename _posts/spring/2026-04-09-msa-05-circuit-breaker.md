---
title: "스프링 클라우드 기반 MSA 구성 - Circuit Breaker"
date: 2026-04-09 09:40:00 +0900
categories: [Spring, MSA]
tags: [SpringCloud, MSA, CircuitBreaker, Resilience4j, Fallback, CascadeFailure, FeignClient]
---

##  1. 개요

---

MSA에서는 서비스들이 서로 HTTP 호출로 연결되어 있다. 만약 `ai-service`가 다운됐는데 `recommendation-service`가 계속 ai-service를 호출한다면 어떤 일이 벌어질까?

호출 스레드가 타임아웃을 기다리며 쌓이고, 결국 스레드 풀이 고갈되어 recommendation-service까지 죽는다. 이 현상을 **Cascade Failure(연쇄 장애)**라고 한다.

**Circuit Breaker(서킷 브레이커)**는 이 문제를 막는 패턴이다. 마치 전기 회로의 차단기처럼, 장애가 감지되면 즉시 요청을 차단하고 **Fallback(대체 응답)**을 반환한다.

> 💡 Chris Richardson의 책 "Microservice Patterns"에서는 이렇게 설명한다: "A service client should invoke a remote service via a proxy that functions in a similar fashion to an electrical circuit breaker."

Spring Cloud는 Circuit Breaker의 공식 추상화 레이어로 **Spring Cloud CircuitBreaker** 프로젝트를 제공하며, 구현체로 **Resilience4j**를 권장한다.

> "The Spring Cloud Circuit Breaker project solves this. It provides an abstraction layer across different circuit breaker implementations."
> 출처: [spring.io/projects/spring-cloud-circuitbreaker](https://spring.io/projects/spring-cloud-circuitbreaker/)

### 📌 Hystrix vs Resilience4j

과거에는 Netflix Hystrix를 사용했지만, Spring Cloud 2020.0부터 Hystrix가 제거됐다.

| 구분 | Netflix Hystrix | Resilience4j |
|---|---|---|
| 유지보수 | Netflix (deprecated) | 활발히 개발 중 |
| Spring Boot 3 지원 | ❌ | ✅ |
| Java 8 함수형 지원 | 제한적 | ✅ (FP 스타일) |
| 스레드 모델 | ThreadPool 기반 | Semaphore / ThreadPool 선택 가능 |
| 모듈 분리 | 단일 패키지 | CB, Retry, RateLimit, Bulkhead 분리 |

---

##  2. 핵심 개념 — 상태 전이

---

### 📌 Circuit Breaker 상태 머신

> Resilience4j 공식 문서: "The CircuitBreaker is implemented via a finite state machine with three normal states: CLOSED, OPEN and HALF_OPEN."

```
┌─────────┐  실패율 ≥ 임계값  ┌──────┐
│ CLOSED  │ ────────────────▶ │ OPEN │
│(정상 운영)│                   │(차단)│
└─────────┘                   └──────┘
     ▲                            │
     │ 테스트 성공                  │ 대기 시간 경과
     │                            ▼
     │                      ┌───────────┐
     └──────────────────────│ HALF_OPEN │
       성공률 ≥ 임계값        │ (테스트 중) │
                            └───────────┘
```

| 상태 | 동작 |
|---|---|
| **CLOSED** | 정상 상태. 모든 요청을 통과시키고 결과를 슬라이딩 윈도우에 기록 |
| **OPEN** | 차단 상태. 모든 요청을 즉시 `CallNotPermittedException`으로 거부하고 Fallback 실행 |
| **HALF_OPEN** | 복구 테스트 상태. 설정한 수만큼의 요청을 테스트로 허용. 성공 → CLOSED, 실패 → OPEN |

### 📌 슬라이딩 윈도우 (Sliding Window)

Circuit Breaker가 실패율을 계산하는 방식이다. 두 가지 타입이 있다.

- **COUNT_BASED**: 최근 N번의 호출 결과를 기준으로 실패율 계산
- **TIME_BASED**: 최근 N초 동안의 호출 결과를 기준으로 실패율 계산

> 💡 예를 들어 `slidingWindowSize: 10`에 `failureRateThreshold: 50`이면, 최근 10번 중 5번 이상 실패하면 OPEN 상태로 전환된다. 단, 최소 호출 수(`minimumNumberOfCalls`)에 도달해야 실패율이 계산된다.

---

##  3. 설정

---

### 📌 build.gradle

```groovy
/**
 * Spring Cloud Circuit Breaker는 Resilience4j와 Spring Retry 두 구현체를 제공한다.
 * 비동기(Reactive) 애플리케이션이 아니라면 non-reactive 스타터를 사용한다.
 *
 * resilience4j-micrometer는 Actuator와 연동해 Circuit Breaker 메트릭을 Prometheus로 내보낸다.
 */
dependencies {
    // ...기존 코드

    // Spring Cloud Circuit Breaker (non-reactive)
    implementation 'org.springframework.cloud:spring-cloud-starter-circuitbreaker-resilience4j'

    // Resilience4j Micrometer 메트릭 연동
    implementation 'io.github.resilience4j:resilience4j-micrometer'

    // Actuator (메트릭 엔드포인트 노출)
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
}
```

### 📌 application.yml — recommendation-service 기준

```yaml
resilience4j:
  circuitbreaker:
    configs:
      # default 설정: 모든 인스턴스의 기본값
      default:
        # 슬라이딩 윈도우 타입: COUNT_BASED 또는 TIME_BASED
        sliding-window-type: COUNT_BASED

        # 최근 10번의 호출을 기준으로 실패율 계산
        sliding-window-size: 10

        # 실패율이 50% 이상이면 OPEN 상태로 전환
        failure-rate-threshold: 50

        # 실패율 계산 시작 최소 호출 수
        minimum-number-of-calls: 5

        # OPEN 상태 유지 시간: 10초 후 HALF_OPEN으로 전환
        wait-duration-in-open-state: 10s

        # HALF_OPEN에서 허용하는 테스트 요청 수
        permitted-number-of-calls-in-half-open-state: 3

        # 어떤 예외를 실패로 볼 것인가
        record-exceptions:
          - java.io.IOException
          - java.util.concurrent.TimeoutException
          - feign.FeignException

        # 이 예외는 실패로 집계하지 않음 (비즈니스 예외 등)
        ignore-exceptions:
          - com.seouldate.common.exception.BusinessException

    instances:
      # place-service용 Circuit Breaker
      place-service:
        base-config: default

      # ai-service용 Circuit Breaker (LLM 호출은 복구에 시간이 더 필요)
      ai-service:
        base-config: default
        wait-duration-in-open-state: 30s   # 30초 대기 후 HALF_OPEN
        sliding-window-size: 5             # 5번 호출 기준으로 빠르게 감지

  # 재시도 설정
  retry:
    instances:
      ai-service:
        max-attempts: 2              # 최대 2번 재시도
        wait-duration: 500ms         # 재시도 전 500ms 대기
        retry-exceptions:
          - feign.RetryableException

  # 타임아웃 설정
  timelimiter:
    instances:
      ai-service:
        timeout-duration: 10s        # AI 서비스는 최대 10초 허용 (RAG 파이프라인 고려)
      place-service:
        timeout-duration: 3s

# Actuator에서 Circuit Breaker 상태 조회 활성화
management:
  endpoint:
    health:
      show-details: always
  health:
    circuitbreakers:
      enabled: true
```

### 📌 FeignClient에 Circuit Breaker 적용

```yaml
# FeignClient에 Circuit Breaker 자동 적용
spring:
  cloud:
    openfeign:
      circuitbreaker:
        enabled: true   # FeignClient에 CB 자동 적용
```

```java
/**
 * fallbackFactory를 사용하면 어떤 예외가 발생했는지 fallback 메서드에서 알 수 있다.
 * 단순 fallback(fallback = ...) 방식은 예외 정보를 받을 수 없다.
 *
 * FeignClient의 name은 resilience4j.circuitbreaker.instances의 키와 일치해야
 * 해당 설정이 적용된다.
 */
@FeignClient(
    name = "place-service",
    fallbackFactory = PlaceServiceClientFallbackFactory.class
)
public interface PlaceServiceClient {

    @GetMapping("/places/{placeId}")
    PlaceResponse getPlace(@PathVariable Long placeId);

    @GetMapping("/places/batch")
    List<PlaceResponse> getPlaces(@RequestParam List<Long> ids);
}
```

```java
/**
 * FallbackFactory는 Circuit Breaker가 OPEN 상태일 때 또는 예외 발생 시 호출된다.
 * cause 파라미터를 통해 어떤 예외인지 확인하고 로깅하거나 다르게 처리할 수 있다.
 */
@Component
@Slf4j
public class PlaceServiceClientFallbackFactory
        implements FallbackFactory<PlaceServiceClient> {

    @Override
    public PlaceServiceClient create(Throwable cause) {
        return new PlaceServiceClient() {

            @Override
            public PlaceResponse getPlace(Long placeId) {
                log.warn("[CircuitBreaker] place-service 장애. placeId={}, cause={}",
                    placeId, cause.getMessage());
                // 빈 응답 또는 캐시에서 가져온 값을 반환
                return PlaceResponse.empty(placeId);
            }

            @Override
            public List<PlaceResponse> getPlaces(List<Long> ids) {
                log.warn("[CircuitBreaker] place-service batch 장애. count={}", ids.size());
                return Collections.emptyList();
            }
        };
    }
}
```

---

##  4. Circuit Breaker 상태 모니터링

---

Actuator와 연동하면 `/actuator/health` 엔드포인트에서 각 Circuit Breaker 상태를 확인할 수 있다.

```json
// GET http://localhost:8083/actuator/health
{
  "status": "UP",
  "components": {
    "circuitBreakers": {
      "status": "UNKNOWN",
      "details": {
        "ai-service": {
          "status": "CIRCUIT_OPEN",
          "details": {
            "failureRate": "100.0%",
            "failureRateThreshold": "50.0%",
            "bufferedCalls": 5,
            "failedCalls": 5,
            "state": "OPEN"
          }
        },
        "place-service": {
          "status": "CIRCUIT_CLOSED",
          "details": {
            "failureRate": "0.0%",
            "state": "CLOSED"
          }
        }
      }
    }
  }
}
```

> 💡 `ai-service`가 OPEN 상태라면 해당 인스턴스로의 요청이 즉시 차단되고 Fallback이 동작 중임을 의미한다.

---

##  5. Resilience4j Aspect 실행 순서

---

Resilience4j는 여러 패턴을 함께 적용할 수 있다. 기본 실행 순서는 다음과 같다.

```
Retry
  └─ CircuitBreaker
       └─ RateLimiter
            └─ TimeLimiter
                 └─ Bulkhead
                      └─ 실제 메서드 호출
```

즉, Retry가 가장 바깥 레이어다. CircuitBreaker가 OPEN 상태여서 `CallNotPermittedException`이 발생하면, Retry가 이를 캐치해서 재시도한다. 이 순서를 이해하지 못하면 예상치 못한 동작이 발생할 수 있다.

순서를 바꾸려면:

```yaml
resilience4j:
  circuitbreaker:
    circuit-breaker-aspect-order: 1   # 낮을수록 내부 레이어 (나중에 실행)
  retry:
    retry-aspect-order: 2             # 높을수록 외부 레이어 (먼저 실행)
```

---

##  6. 트러블슈팅

---

### 📌 Fallback이 호출되지 않음

원인: `spring.cloud.openfeign.circuitbreaker.enabled: true` 설정이 누락됐거나, FeignClient의 `name`이 Resilience4j 인스턴스 키와 다를 수 있다.

해결:
1. `spring.cloud.openfeign.circuitbreaker.enabled: true` 설정 확인
2. `@FeignClient(name = "place-service")`와 `resilience4j.circuitbreaker.instances.place-service` 이름 일치 확인

### 📌 "CallNotPermittedException" 자체가 Retry를 유발함

Retry의 `retry-exceptions`에 `CallNotPermittedException`이 포함되면 OPEN 상태에서도 계속 재시도하게 된다.

해결:

```yaml
resilience4j:
  retry:
    instances:
      ai-service:
        ignore-exceptions:
          - io.github.resilience4j.circuitbreaker.CallNotPermittedException
```

---

##  7. 정리

---

- Circuit Breaker는 **Cascade Failure(연쇄 장애)**를 막는 필수 패턴이다.
- CLOSED → OPEN → HALF_OPEN → CLOSED의 **상태 전이**로 장애 격리와 자동 복구를 처리한다.
- Spring Boot 3.x에서는 Hystrix 대신 **Resilience4j**를 사용해야 한다.
- `FallbackFactory`를 사용하면 예외 원인을 전달받아 세밀한 Fallback 처리가 가능하다.
- `/actuator/health` 엔드포인트로 **실시간 Circuit Breaker 상태**를 모니터링할 수 있다.

---

## 참고 자료

- Resilience4j 공식 문서 - CircuitBreaker: <https://resilience4j.readme.io/docs/circuitbreaker>
- Spring Cloud CircuitBreaker 공식 문서: <https://docs.spring.io/spring-cloud-circuitbreaker/docs/current/reference/html/>
- Resilience4j Spring Boot 설정 문서: <https://resilience4j.readme.io/docs/getting-started-3>
- Baeldung - Quick Guide to Spring Cloud Circuit Breaker: <https://www.baeldung.com/spring-cloud-circuit-breaker>
