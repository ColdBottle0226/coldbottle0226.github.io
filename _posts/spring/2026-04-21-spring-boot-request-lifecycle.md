---
title: Spring Boot 요청 라이프사이클(Filter, Interceptor, DispatcherServlet, ArgumentResolver)
date: 2026-04-21 09:00:00 +0900
categories: [Spring, SpringBoot]
order: 2
tags: [SpringBoot, DispatcherServlet, Filter, Interceptor, ArgumentResolver, MessageConverter]
---

## 1. 개요

HTTP 요청이 스프링 부트 애플리케이션에 도달했을 때, 내부에서 어떤 컴포넌트들이 어떤 순서로 실행되는지를 코드 레벨에서 정리한다.

| 컴포넌트 | 역할 |
|---------|------|
| 내장 Tomcat | TCP 연결 수락, HTTP 파싱 |
| Filter Chain | 서블릿 레벨 공통 처리 (인코딩, CORS, 보안 토큰) |
| DispatcherServlet | 프론트 컨트롤러 — 요청 위임 총괄 |
| HandlerMapping | URL → Handler(Controller) 매핑 결정 |
| HandlerInterceptor | preHandle / postHandle / afterCompletion |
| HandlerAdapter + ArgumentResolver | 파라미터 바인딩 후 컨트롤러 메서드 호출 |
| MessageConverter | 반환 객체 → JSON 직렬화, 요청 body → 객체 역직렬화 |
| ExceptionResolver | 예외 → HTTP 응답 변환 |

> 💡 Spring Boot 3.x 부터는 `javax.servlet.*` 패키지가 `jakarta.servlet.*` 으로 변경된다. 본 포스트의 모든 코드는 Jakarta EE 10 기준으로 작성한다.

---

## 2. 전체 요청 흐름

```
Client (HTTP 요청)
    │
    ▼
내장 Tomcat
(TCP 연결 수락 → HttpServletRequest/Response 생성)
    │
    ▼
Filter Chain  ← jakarta.servlet.Filter
(CharacterEncodingFilter → CorsFilter → 커스텀 Filter → ...)
    │
    ▼
DispatcherServlet.doDispatch()
    │
    ├─ HandlerMapping          → Handler(컨트롤러 메서드) 탐색
    │
    ├─ Interceptor.preHandle   → false 반환 시 요청 중단
    │
    ├─ HandlerAdapter
    │    └─ ArgumentResolver   → 파라미터 바인딩
    │         └─ Controller 메서드 실행
    │
    ├─ Interceptor.postHandle  → ModelAndView 수정 가능
    │
    ├─ MessageConverter        → 반환값 → JSON 직렬화
    │
    └─ Interceptor.afterCompletion (finally — 예외 발생 시에도 실행)
```

---

## 3. DispatcherServlet

### 📌 프론트 컨트롤러 패턴

`DispatcherServlet`은 스프링 MVC의 **프론트 컨트롤러(Front Controller)** 구현체다. 모든 HTTP 요청이 이 단일 서블릿을 통해 진입하고, 적절한 처리 컴포넌트에 위임한다.

> 💡 Spring MVC 공식 문서: "Spring MVC is designed around the front controller pattern where a central Servlet, the DispatcherServlet, provides a shared algorithm for request processing."

스프링 부트에서는 `DispatcherServletAutoConfiguration`이 자동으로 `DispatcherServlet`을 등록하고, 기본적으로 `/` 경로(모든 요청)를 처리하도록 매핑한다.

### 📌 doDispatch() 핵심 흐름

`DispatcherServlet`의 핵심 메서드인 `doDispatch()`의 흐름을 단순화하면 다음과 같다.

```java
// DispatcherServlet 내부 핵심 로직 (단순화 — 실제 소스 기반)
protected void doDispatch(HttpServletRequest request, HttpServletResponse response)
        throws Exception {

    HttpServletRequest processedRequest = request;
    HandlerExecutionChain mappedHandler = null;

    try {
        ModelAndView mv = null;
        Exception dispatchException = null;

        // 1. HandlerMapping으로 핸들러(컨트롤러 메서드) 조회
        //    매핑 정보가 없으면 noHandlerFound() → 404
        mappedHandler = getHandler(processedRequest);
        if (mappedHandler == null) {
            noHandlerFound(processedRequest, response);
            return;
        }

        // 2. HandlerAdapter 조회
        //    핸들러 타입에 맞는 어댑터를 찾는다
        //    (@RequestMapping → RequestMappingHandlerAdapter)
        HandlerAdapter ha = getHandlerAdapter(mappedHandler.getHandler());

        // 3. 인터셉터 preHandle 실행
        //    false 반환 시 요청 즉시 중단
        if (!mappedHandler.applyPreHandle(processedRequest, response)) {
            return;
        }

        // 4. 실제 핸들러(컨트롤러 메서드) 실행
        //    ArgumentResolver로 파라미터를 바인딩한 후 메서드 호출
        //    @ResponseBody면 MessageConverter로 직렬화 후 mv = null
        mv = ha.handle(processedRequest, response, mappedHandler.getHandler());

        // 5. 인터셉터 postHandle 실행
        mappedHandler.applyPostHandle(processedRequest, response, mv);

        // 6. 뷰 렌더링 또는 이미 응답이 처리된 경우 패스
        processDispatchResult(processedRequest, response, mappedHandler, mv, dispatchException);

    } catch (Exception ex) {
        // afterCompletion은 예외 발생 시에도 반드시 실행
        triggerAfterCompletion(processedRequest, response, mappedHandler, ex);
    }
}
```

---

## 4. Filter — 서블릿 레벨 공통 처리

### 📌 Filter vs Interceptor 핵심 차이

| 항목 | Filter | Interceptor |
|------|--------|-------------|
| 동작 위치 | 서블릿 컨텍스트 (Tomcat 영역) | 스프링 컨텍스트 |
| 스프링 Bean 주입 | `@Component` 등록 시 가능 (Boot 한정) | 자유롭게 가능 |
| 적용 시점 | DispatcherServlet 진입 전후 | Handler 실행 전후 |
| 예외 처리 | `@ControllerAdvice` 미적용 | `@ControllerAdvice` 적용됨 |
| 주 사용처 | 인코딩, CORS, 보안 토큰 파싱, 요청 래핑 | 인증/인가, 공통 로깅, MDC 설정 |
| 구현 인터페이스 | `jakarta.servlet.Filter` | `HandlerInterceptor` |

> 💡 Filter에서 예외가 발생하면 `@ControllerAdvice`가 잡지 못한다. 스프링 컨텍스트 바깥에서 실행되기 때문이다. 예외를 일관되게 처리하려면 Filter 내부에서 직접 `response.sendError()`를 호출하거나, `ErrorController`로 위임한다.

### 📌 OncePerRequestFilter 구현 (Jakarta EE 10)

`OncePerRequestFilter`를 상속하면 요청당 정확히 한 번만 실행이 보장된다. 포워드(forward)나 인클루드(include) 시 일반 `Filter`는 중복 실행될 수 있다.

```java
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

/**
 * 요청 로깅 필터.
 * MDC에 requestId를 설정해 분산 로그 추적을 가능하게 한다.
 * @Order(1): 필터 순서 — 낮을수록 먼저 실행된다.
 */
@Component
@Order(1)
public class RequestLoggingFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(RequestLoggingFilter.class);

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        String requestId = UUID.randomUUID().toString().substring(0, 8);
        long startTime = System.currentTimeMillis();

        // MDC: 스레드 로컬 기반 로그 컨텍스트 — logback 패턴에서 %X{requestId}로 출력 가능
        MDC.put("requestId", requestId);
        response.setHeader("X-Request-Id", requestId); // 클라이언트에게도 전달

        log.info("[Filter] 요청 시작 — {} {}", request.getMethod(), request.getRequestURI());

        try {
            // 다음 필터 또는 DispatcherServlet으로 요청 전달
            filterChain.doFilter(request, response);
        } finally {
            // finally: 예외 발생 여부와 관계없이 반드시 실행
            long elapsed = System.currentTimeMillis() - startTime;
            log.info("[Filter] 요청 완료 — {}ms, status: {}", elapsed, response.getStatus());
            MDC.clear(); // 스레드 풀 환경에서 이전 요청 데이터 오염 방지 — 필수
        }
    }

    /**
     * 특정 경로는 필터 적용을 제외한다.
     * true를 반환하면 doFilterInternal을 건너뛴다.
     */
    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return path.startsWith("/actuator") || path.startsWith("/health");
    }
}
```

### 📌 FilterRegistrationBean으로 세밀한 등록 제어

`@Component`로 등록하면 모든 URL에 적용된다. 특정 URL 패턴에만 적용하거나 순서를 명시적으로 제어하려면 `FilterRegistrationBean`을 사용한다.

```java
@Configuration
public class FilterConfig {

    /**
     * FilterRegistrationBean: 필터 URL 패턴, 순서, 이름을 세밀하게 제어한다.
     * @Component 대신 이 방식을 사용하면 중복 등록을 방지할 수 있다.
     */
    @Bean
    public FilterRegistrationBean<RequestLoggingFilter> loggingFilter() {
        FilterRegistrationBean<RequestLoggingFilter> bean = new FilterRegistrationBean<>();
        bean.setFilter(new RequestLoggingFilter());
        bean.addUrlPatterns("/api/*");  // /api/** 경로에만 적용
        bean.setOrder(1);               // 실행 순서
        bean.setName("requestLoggingFilter");
        return bean;
    }
}
```

---

## 5. HandlerMapping — URL과 컨트롤러를 연결하는 방법

### 📌 동작 원리

`DispatcherServlet`이 요청을 받으면 가장 먼저 `HandlerMapping`에게 "이 요청을 처리할 핸들러가 누구냐"고 묻는다.

스프링 부트에서 자동 구성되는 주요 구현체는 다음과 같다.

| 구현체 | 역할 |
|--------|------|
| `RequestMappingHandlerMapping` | `@RequestMapping` 계열 어노테이션 처리 |
| `RouterFunctionMapping` | WebFlux 함수형 라우팅 |
| `SimpleUrlHandlerMapping` | 정적 리소스(`/static/**`) 처리 |
| `WelcomePageHandlerMapping` | 루트(`/`) 요청의 welcome page 처리 |

`RequestMappingHandlerMapping`은 애플리케이션 시작 시 `@Controller`, `@RestController`가 붙은 모든 Bean을 스캔해 메서드별 매핑 정보를 내부 `Map<RequestMappingInfo, HandlerMethod>`에 등록한다.

요청이 들어오면 URL, HTTP 메서드, `consumes`, `produces`, `params`, `headers` 조건을 조합해 가장 구체적으로 매칭되는 `HandlerMethod`를 반환한다.

### 📌 @RequestMapping 계열 어노테이션

```java
@RestController
@RequestMapping("/api/orders") // 클래스 레벨 공통 경로
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    // GET /api/orders?page=0&size=20
    @GetMapping
    public List<OrderResponse> getOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return orderService.findAll(page, size);
    }

    // GET /api/orders/42
    @GetMapping("/{id}")
    public OrderResponse getOrder(@PathVariable Long id) {
        return orderService.findById(id);
    }

    // POST /api/orders
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public OrderResponse createOrder(@RequestBody @Valid CreateOrderRequest request) {
        return orderService.create(request);
    }

    // PATCH /api/orders/42/cancel
    @PatchMapping("/{id}/cancel")
    public OrderResponse cancelOrder(@PathVariable Long id) {
        return orderService.cancel(id);
    }

    // DELETE /api/orders/42
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteOrder(@PathVariable Long id) {
        orderService.delete(id);
    }
}
```

---

## 6. HandlerInterceptor — 스프링 레벨 공통 처리

### 📌 세 가지 콜백 메서드

`HandlerInterceptor`는 세 가지 콜백 메서드를 제공한다.

| 메서드 | 호출 시점 | 반환값 | 주 용도 |
|--------|---------|--------|--------|
| `preHandle` | 컨트롤러 실행 전 | boolean | 인증/인가, 요청 유효성 검사 |
| `postHandle` | 컨트롤러 실행 후, 뷰 렌더링 전 | void | 공통 응답 데이터 추가 |
| `afterCompletion` | 응답 완료 후 (finally) | void | 리소스 정리, 실행 시간 측정 |

> 💡 `afterCompletion`은 예외가 발생해도 반드시 실행된다. 단, `preHandle`이 `false`를 반환한 경우 해당 인터셉터의 `afterCompletion`은 실행되지 않는다.

### 📌 인증 인터셉터 구현 (Jakarta EE 10)

```java
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.ModelAndView;

/**
 * JWT 기반 인증 인터셉터.
 * Interceptor는 스프링 컨텍스트 내에서 동작하므로 Bean 주입이 자유롭다.
 */
@Component
public class AuthInterceptor implements HandlerInterceptor {

    private final TokenService tokenService;

    public AuthInterceptor(TokenService tokenService) {
        this.tokenService = tokenService;
    }

    /**
     * preHandle: 컨트롤러 실행 전 인증 검사.
     * @PublicApi 어노테이션이 붙은 메서드는 인증 없이 통과시킨다.
     */
    @Override
    public boolean preHandle(HttpServletRequest request,
                             HttpServletResponse response,
                             Object handler) throws Exception {

        // 정적 리소스 등 HandlerMethod가 아닌 경우 통과
        if (!(handler instanceof HandlerMethod handlerMethod)) {
            return true;
        }

        // @PublicApi 어노테이션이 있으면 인증 생략
        if (handlerMethod.hasMethodAnnotation(PublicApi.class)) {
            return true;
        }

        String authHeader = request.getHeader("Authorization");

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "인증 헤더 없음");
            return false; // 요청 중단
        }

        String token = authHeader.substring(7); // "Bearer " 제거

        if (!tokenService.isValid(token)) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "유효하지 않은 토큰");
            return false;
        }

        // 다음 인터셉터 또는 컨트롤러로 진행
        return true;
    }

    /**
     * postHandle: 컨트롤러 실행 후 공통 응답 헤더 추가.
     * @ResponseBody를 사용하는 경우 ModelAndView는 null이다.
     */
    @Override
    public void postHandle(HttpServletRequest request,
                           HttpServletResponse response,
                           Object handler,
                           ModelAndView modelAndView) throws Exception {
        response.setHeader("X-Api-Version", "v1");
    }

    /**
     * afterCompletion: 응답 완료 후 실행 시간 측정 및 로깅.
     * 예외 발생 시 ex 파라미터에 예외 객체가 전달된다.
     */
    @Override
    public void afterCompletion(HttpServletRequest request,
                                HttpServletResponse response,
                                Object handler, Exception ex) throws Exception {
        if (ex != null) {
            log.error("[Interceptor] 처리 중 예외 발생: {}", ex.getMessage());
        }
    }
}
```

### 📌 인터셉터 등록 — WebMvcConfigurer

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final AuthInterceptor authInterceptor;
    private final RequestLoggingInterceptor loggingInterceptor;

    public WebConfig(AuthInterceptor authInterceptor,
                     RequestLoggingInterceptor loggingInterceptor) {
        this.authInterceptor = authInterceptor;
        this.loggingInterceptor = loggingInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {

        // 로깅 인터셉터: 모든 경로에 적용, 가장 먼저 실행
        registry.addInterceptor(loggingInterceptor)
                .addPathPatterns("/**")
                .order(0);

        // 인증 인터셉터: /api/** 에만 적용, 공개 경로 제외
        registry.addInterceptor(authInterceptor)
                .addPathPatterns("/api/**")
                .excludePathPatterns(
                    "/api/auth/login",
                    "/api/auth/signup",
                    "/api/auth/refresh",
                    "/api/public/**"
                )
                .order(1);
    }
}
```

---

## 7. HandlerAdapter & ArgumentResolver — 파라미터 바인딩

### 📌 HandlerAdapter의 역할

`HandlerMapping`이 핸들러(컨트롤러 메서드)를 찾아주면, `HandlerAdapter`가 그 핸들러를 실제로 호출하는 역할을 한다.

핸들러 타입이 다양하기 때문에(어노테이션 기반, HttpRequestHandler, Servlet 등) 어댑터 패턴으로 분리했다.

| 구현체 | 처리 대상 |
|--------|---------|
| `RequestMappingHandlerAdapter` | `@RequestMapping` 계열 메서드 (가장 일반적) |
| `HttpRequestHandlerAdapter` | `HttpRequestHandler` 구현체 |
| `SimpleControllerHandlerAdapter` | `Controller` 인터페이스 구현체 (레거시) |

### 📌 ArgumentResolver 동작 원리

`RequestMappingHandlerAdapter`가 컨트롤러 메서드를 호출하기 전, 각 파라미터에 대해 등록된 `HandlerMethodArgumentResolver` 목록을 순회하면서 `supportsParameter()`가 `true`를 반환하는 Resolver를 찾아 `resolveArgument()`로 값을 생성한다.

스프링이 기본 제공하는 주요 ArgumentResolver는 다음과 같다.

| ArgumentResolver | 처리 대상 |
|-----------------|---------|
| `PathVariableMethodArgumentResolver` | `@PathVariable` |
| `RequestParamMethodArgumentResolver` | `@RequestParam` |
| `RequestResponseBodyMethodProcessor` | `@RequestBody` |
| `ModelAttributeMethodProcessor` | `@ModelAttribute` |
| `ServletRequestMethodArgumentResolver` | `HttpServletRequest`, `InputStream` 등 |
| `PrincipalMethodArgumentResolver` | `Principal` |

### 📌 커스텀 ArgumentResolver — 로그인 사용자 주입

컨트롤러마다 토큰을 파싱하는 대신, `@LoginUser` 어노테이션 하나로 로그인 사용자를 주입받는 패턴이다.

```java
// 1. 커스텀 어노테이션 정의
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Target(ElementType.PARAMETER)
@Retention(RetentionPolicy.RUNTIME)
public @interface LoginUser {}
```

```java
// 2. UserPrincipal — 컨트롤러 파라미터 타입
public record UserPrincipal(Long id, String email, String role) {}
```

```java
// 3. ArgumentResolver 구현
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.core.MethodParameter;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

@Component
public class LoginUserArgumentResolver implements HandlerMethodArgumentResolver {

    private final TokenService tokenService;

    public LoginUserArgumentResolver(TokenService tokenService) {
        this.tokenService = tokenService;
    }

    /**
     * 이 Resolver가 처리할 파라미터인지 판단.
     * @LoginUser 어노테이션 + UserPrincipal 타입인 경우에만 true를 반환한다.
     */
    @Override
    public boolean supportsParameter(MethodParameter parameter) {
        return parameter.hasParameterAnnotation(LoginUser.class)
            && UserPrincipal.class.isAssignableFrom(parameter.getParameterType());
    }

    /**
     * 파라미터에 주입할 실제 값 생성.
     * Authorization 헤더의 JWT 토큰을 파싱해 UserPrincipal을 반환한다.
     */
    @Override
    public Object resolveArgument(MethodParameter parameter,
                                  ModelAndViewContainer mavContainer,
                                  NativeWebRequest webRequest,
                                  WebDataBinderFactory binderFactory) throws Exception {

        HttpServletRequest request = webRequest.getNativeRequest(HttpServletRequest.class);
        String authHeader = request.getHeader("Authorization");

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            throw new UnauthorizedException("인증 정보가 없습니다.");
        }

        String token = authHeader.substring(7);
        return tokenService.extractPrincipal(token); // UserPrincipal 반환
    }
}
```

```java
// 4. WebConfig에 등록
@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final LoginUserArgumentResolver loginUserArgumentResolver;

    public WebConfig(LoginUserArgumentResolver loginUserArgumentResolver) {
        this.loginUserArgumentResolver = loginUserArgumentResolver;
    }

    @Override
    public void addArgumentResolvers(List<HandlerMethodArgumentResolver> resolvers) {
        resolvers.add(loginUserArgumentResolver);
    }
}
```

```java
// 5. 컨트롤러에서 사용 — 토큰 파싱 로직 없이 바로 주입
@RestController
@RequestMapping("/api/users")
public class UserController {

    @GetMapping("/me")
    public UserResponse getMyInfo(@LoginUser UserPrincipal loginUser) {
        // loginUser.id(), loginUser.email() 바로 사용 가능
        return userService.findById(loginUser.id());
    }

    @PatchMapping("/me")
    public UserResponse updateMyInfo(@LoginUser UserPrincipal loginUser,
                                     @RequestBody @Valid UpdateUserRequest request) {
        return userService.update(loginUser.id(), request);
    }
}
```

---

## 8. MessageConverter — 직렬화와 역직렬화

### 📌 동작 원리

`@RequestBody`와 `@ResponseBody`(또는 `@RestController`)를 처리하는 게 `HttpMessageConverter`다.

- 요청 처리: `Content-Type` 헤더를 보고 적합한 컨버터로 요청 body를 Java 객체로 역직렬화한다.
- 응답 처리: 클라이언트의 `Accept` 헤더와 컨트롤러 반환 타입을 보고 적합한 컨버터로 Java 객체를 직렬화한다.

스프링 부트에 자동 등록되는 주요 컨버터는 다음과 같다.

| 컨버터 | 처리 미디어 타입 |
|--------|----------------|
| `MappingJackson2HttpMessageConverter` | `application/json` |
| `StringHttpMessageConverter` | `text/plain`, `text/*` |
| `ByteArrayHttpMessageConverter` | `application/octet-stream` |
| `ResourceHttpMessageConverter` | 파일 리소스 |
| `FormHttpMessageConverter` | `application/x-www-form-urlencoded` |

### 📌 ObjectMapper 커스터마이징

`application.yml`보다 Java 코드 설정이 우선 적용된다.

```java
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.boot.autoconfigure.jackson.Jackson2ObjectMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class JacksonConfig {

    /**
     * Jackson2ObjectMapperBuilderCustomizer:
     * 스프링 부트의 자동 구성 ObjectMapper를 커스터마이징하는 권장 방법.
     * @Bean ObjectMapper로 직접 등록하면 자동 구성이 무시되므로 주의한다.
     */
    @Bean
    public Jackson2ObjectMapperBuilderCustomizer jacksonCustomizer() {
        return builder -> builder
            // null 필드는 JSON 출력에서 제외 — 응답 크기 절감
            .serializationInclusion(JsonInclude.Include.NON_NULL)
            // 알 수 없는 필드가 들어와도 예외 발생 안 함 — API 하위 호환성 유지
            .featuresToDisable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            // LocalDateTime을 숫자 배열이 아닌 ISO 8601 문자열로 직렬화
            .featuresToDisable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
            // Java 8 날짜/시간 타입(LocalDateTime 등) 지원 모듈
            .modules(new JavaTimeModule());
    }
}
```

### 📌 application.yml Jackson 설정

```yaml
spring:
  jackson:
    # null 필드 제외
    default-property-inclusion: non_null
    # 날짜를 타임스탬프(숫자)가 아닌 문자열로
    serialization:
      write-dates-as-timestamps: false
    deserialization:
      # 모르는 필드 무시
      fail-on-unknown-properties: false
    # 날짜 포맷
    date-format: "yyyy-MM-dd'T'HH:mm:ss"
    time-zone: Asia/Seoul
```

---

## 9. ExceptionResolver — 예외를 응답으로 변환

### 📌 처리 우선순위

컨트롤러에서 예외가 발생하면 `DispatcherServlet`이 등록된 `HandlerExceptionResolver`를 순서대로 탐색해 처리한다.

```
1. ExceptionHandlerExceptionResolver   (우선순위 가장 높음)
   → @ControllerAdvice + @ExceptionHandler 탐색

2. ResponseStatusExceptionResolver
   → @ResponseStatus 어노테이션 처리
   → ResponseStatusException 처리

3. DefaultHandlerExceptionResolver
   → 스프링 표준 예외 처리
     (MethodArgumentNotValidException → 400,
      HttpRequestMethodNotSupportedException → 405 등)

4. 미처리 예외
   → WAS(Tomcat)로 전달 → /error 엔드포인트 (BasicErrorController)
```

> 💡 Filter에서 발생한 예외는 스프링 컨텍스트 밖이므로 1~3번이 적용되지 않는다. Filter에서는 try-catch로 직접 처리하거나 `response.sendError()`로 Tomcat의 에러 처리에 위임해야 한다.

### 📌 @ControllerAdvice 전역 예외 처리

PART 4에서 상세히 다루지만, ExceptionResolver와의 연결 구조를 이해하기 위해 기본 형태를 먼저 확인한다.

```java
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * @RestControllerAdvice: @ControllerAdvice + @ResponseBody 합성 어노테이션.
 * ExceptionHandlerExceptionResolver가 이 클래스에서 @ExceptionHandler를 탐색한다.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    /**
     * @Valid 검증 실패 시 발생하는 예외 처리.
     * DefaultHandlerExceptionResolver보다 이 핸들러가 우선 적용된다.
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationException(
            MethodArgumentNotValidException ex) {

        List<String> errors = ex.getBindingResult()
                .getFieldErrors()
                .stream()
                .map(fe -> fe.getField() + ": " + fe.getDefaultMessage())
                .toList();

        return ResponseEntity.badRequest()
                .body(new ErrorResponse("VALIDATION_FAILED", errors.toString()));
    }
}
```

---

## 10. 정리

- Filter는 Tomcat 레벨에서 동작하며 `DispatcherServlet` 진입 전후 모두를 감싼다. 예외가 발생해도 `@ControllerAdvice`가 적용되지 않으므로 Filter 내부에서 직접 처리해야 한다.
- Interceptor는 스프링 컨텍스트 안에서 동작하므로 Bean 주입이 자유롭고 `@ControllerAdvice`가 적용된다. `preHandle` / `postHandle` / `afterCompletion` 세 시점에 개입할 수 있다.
- `DispatcherServlet`의 `doDispatch()`가 HandlerMapping → Interceptor → HandlerAdapter → ArgumentResolver → Controller → MessageConverter 순서로 처리를 조율한다.
- `ArgumentResolver`를 커스터마이징하면 컨트롤러 파라미터 바인딩 로직을 중앙화할 수 있어 컨트롤러 코드가 간결해진다.
- Spring Boot 3.x 부터 `javax.servlet.*`이 `jakarta.servlet.*`으로 변경된다. 의존성과 import를 모두 확인해야 한다.

---

## 11. 참고 자료

- [Spring MVC 공식 문서 — DispatcherServlet](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-servlet.html)
- [Spring MVC 공식 문서 — Filters](https://docs.spring.io/spring-framework/reference/web/webmvc/filters.html)
- [Spring MVC 공식 문서 — Interceptors](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-config/interceptors.html)
- [Spring MVC 공식 문서 — Handler Methods — ArgumentResolver](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann-methods/arguments.html)
- [Spring MVC 공식 문서 — HttpMessageConverter](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-config/message-converters.html)
- [Spring Boot 공식 문서 — Migrating to Spring Boot 3.x (Jakarta EE)](https://docs.spring.io/spring-boot/docs/3.0.0/reference/html/migration-guide.html)
