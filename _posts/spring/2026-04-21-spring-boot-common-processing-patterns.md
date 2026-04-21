---
title: Spring Boot 공통 처리 패턴(예외처리, 공통 응답, 검증, MDC)
date: 2026-04-21 11:00:00 +0900
categories: [Spring, SpringBoot]
order: 5
tags: [SpringBoot, ExceptionHandler, ControllerAdvice, ApiResponse, Validation, MDC, ErrorCode]
---

## 1. 개요

API 서버를 개발할 때 반복적으로 등장하는 공통 처리 패턴들이 있다. 응답 포맷을 통일하지 않으면 클라이언트가 엔드포인트마다 다른 파싱 로직을 작성해야 하고, 예외 처리가 분산되면 일관성을 유지하기 어렵다. 이 글에서는 실무에서 바로 적용할 수 있는 공통 처리 구조를 코드 레벨로 정리한다.

| 주제 | 내용 |
|------|------|
| 공통 응답 포맷 | ApiResponse\<T\> 설계 |
| 에러 코드 체계 | ErrorCode enum 중앙 관리 |
| 전역 예외 처리 | @RestControllerAdvice + @ExceptionHandler |
| 요청 검증 | @Valid, @Validated, 커스텀 Validator |
| 공통 요청 처리 | MDC, RequestContextHolder |
| ProblemDetail | RFC 7807 표준 에러 응답 (Spring 6+) |

---

## 2. 공통 응답 포맷 설계 — ApiResponse\<T\>

### 📌 왜 공통 응답 포맷이 필요한가

API 응답 형태가 엔드포인트마다 제각각이면 클라이언트가 파싱 로직을 여러 개 작성해야 한다. 성공과 실패 모두 동일한 최상위 구조를 갖도록 설계해야 유지보수가 편하다.

```
성공: {"success": true,  "data": {...},  "error": null}
실패: {"success": false, "data": null,   "error": {"code": "...", "message": "..."}}
```

### 📌 ApiResponse 구현

```java
/**
 * 공통 API 응답 포맷.
 * @JsonInclude(NON_NULL): null 필드는 JSON 출력에서 제외한다.
 * 성공 응답의 error, 실패 응답의 data가 자동으로 제거된다.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiResponse<T>(
        boolean success,
        T data,
        ErrorDetail error
) {
    // 성공 — 데이터 있음
    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>(true, data, null);
    }

    // 성공 — 데이터 없음 (삭제 등)
    public static ApiResponse<Void> success() {
        return new ApiResponse<>(true, null, null);
    }

    // 실패
    public static <T> ApiResponse<T> failure(ErrorDetail error) {
        return new ApiResponse<>(false, null, error);
    }

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record ErrorDetail(
            String code,      // 에러 코드 (예: "USER_001")
            String message,   // 사용자 노출 메시지
            Object details    // 추가 정보 (검증 오류 목록 등)
    ) {
        public static ErrorDetail of(String code, String message) {
            return new ErrorDetail(code, message, null);
        }

        public static ErrorDetail of(String code, String message, Object details) {
            return new ErrorDetail(code, message, details);
        }
    }
}
```

### 📌 컨트롤러 사용 예

```java
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<UserResponse>> getUser(@PathVariable Long id) {
        UserResponse user = userService.findById(id);
        return ResponseEntity.ok(ApiResponse.success(user));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<UserResponse>> createUser(
            @RequestBody @Valid CreateUserRequest request) {
        UserResponse user = userService.create(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                             .body(ApiResponse.success(user));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteUser(@PathVariable Long id) {
        userService.delete(id);
        return ResponseEntity.ok(ApiResponse.success());
    }
}
```

---

## 3. 에러 코드 체계 설계

### 📌 ErrorCode enum

에러 코드를 문자열로 흩뿌리면 관리가 안 된다. HTTP 상태 코드, 에러 코드 문자열, 기본 메시지를 `enum` 하나로 중앙 관리한다.

```java
/**
 * 에러 코드 enum.
 * HTTP 상태 코드와 에러 코드, 기본 메시지를 한 곳에서 관리한다.
 * 신규 에러 추가 시 이 파일만 수정하면 된다.
 */
@Getter
@RequiredArgsConstructor
public enum ErrorCode {

    // 공통
    INVALID_INPUT(HttpStatus.BAD_REQUEST,             "COMMON_001", "잘못된 입력값입니다."),
    INTERNAL_SERVER_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "COMMON_002", "서버 내부 오류가 발생했습니다."),
    METHOD_NOT_ALLOWED(HttpStatus.METHOD_NOT_ALLOWED, "COMMON_003", "허용되지 않는 HTTP 메서드입니다."),

    // 인증/인가
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED,   "AUTH_001", "인증이 필요합니다."),
    FORBIDDEN(HttpStatus.FORBIDDEN,         "AUTH_002", "접근 권한이 없습니다."),
    INVALID_TOKEN(HttpStatus.UNAUTHORIZED,  "AUTH_003", "유효하지 않은 토큰입니다."),
    EXPIRED_TOKEN(HttpStatus.UNAUTHORIZED,  "AUTH_004", "만료된 토큰입니다."),

    // 사용자
    USER_NOT_FOUND(HttpStatus.NOT_FOUND,    "USER_001", "사용자를 찾을 수 없습니다."),
    EMAIL_DUPLICATED(HttpStatus.CONFLICT,   "USER_002", "이미 사용 중인 이메일입니다."),

    // 주문
    ORDER_NOT_FOUND(HttpStatus.NOT_FOUND,       "ORDER_001", "주문을 찾을 수 없습니다."),
    ORDER_CANNOT_CANCEL(HttpStatus.BAD_REQUEST, "ORDER_002", "취소할 수 없는 주문 상태입니다."),

    // 재고
    INSUFFICIENT_STOCK(HttpStatus.CONFLICT, "STOCK_001", "재고가 부족합니다.");

    private final HttpStatus httpStatus;
    private final String code;
    private final String message;
}
```

### 📌 BusinessException 계층 구조

```java
/**
 * 비즈니스 예외 기반 클래스.
 * 서비스 레이어에서 발생하는 모든 예외는 이 클래스를 상속한다.
 * RuntimeException을 상속하므로 @Transactional 롤백 대상이다.
 */
@Getter
public class BusinessException extends RuntimeException {

    private final ErrorCode errorCode;

    public BusinessException(ErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
    }

    public BusinessException(ErrorCode errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }
}

// 도메인별 구체적 예외 — 호출 측에서 의미를 명확히 알 수 있다
public class UserNotFoundException extends BusinessException {
    public UserNotFoundException(Long userId) {
        super(ErrorCode.USER_NOT_FOUND,
              "사용자를 찾을 수 없습니다. id=" + userId);
    }
}

public class InsufficientStockException extends BusinessException {
    public InsufficientStockException(Long productId, int requested, int available) {
        super(ErrorCode.INSUFFICIENT_STOCK,
              String.format("재고 부족. productId=%d, 요청=%d, 잔여=%d",
                            productId, requested, available));
    }
}

// 서비스에서 사용
@Service
public class UserService {

    public UserResponse findById(Long id) {
        return userRepository.findById(id)
                .map(UserResponse::from)
                .orElseThrow(() -> new UserNotFoundException(id));
    }
}
```

---

## 4. @RestControllerAdvice — 전역 예외 처리

### 📌 ExceptionResolver 처리 우선순위

컨트롤러에서 예외가 발생하면 DispatcherServlet이 등록된 HandlerExceptionResolver를 순서대로 탐색한다.

```
1. ExceptionHandlerExceptionResolver   ← 가장 먼저
   → @RestControllerAdvice + @ExceptionHandler 탐색

2. ResponseStatusExceptionResolver
   → @ResponseStatus 어노테이션 처리
   → ResponseStatusException 처리

3. DefaultHandlerExceptionResolver
   → 스프링 표준 예외 처리
     (MethodArgumentNotValidException → 400,
      HttpRequestMethodNotSupportedException → 405 등)

4. 미처리 예외
   → WAS(Tomcat) → /error → BasicErrorController
```

> 💡 Filter에서 발생한 예외는 스프링 컨텍스트 바깥이므로 1~3번이 적용되지 않는다. Filter 내부에서 try-catch로 직접 처리하거나 `response.sendError()`로 Tomcat 에러 처리에 위임해야 한다.

### 📌 GlobalExceptionHandler 구현

```java
import jakarta.validation.ConstraintViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.http.converter.HttpMessageNotReadableException;

/**
 * 전역 예외 처리 핸들러.
 * ExceptionHandlerExceptionResolver가 이 클래스의 @ExceptionHandler를 탐색한다.
 *
 * 처리 범위:
 * 1. 비즈니스 예외 (BusinessException 계열)
 * 2. Bean Validation 예외 (@Valid, @Validated)
 * 3. 스프링 MVC 공통 예외 (타입 불일치, JSON 파싱 실패 등)
 * 4. 예상치 못한 예외 (Exception)
 */
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    /**
     * 비즈니스 예외 처리.
     * 서비스에서 throw한 모든 BusinessException을 잡아 ErrorCode 기반으로 응답한다.
     */
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Void>> handleBusinessException(BusinessException ex) {
        log.warn("[BusinessException] code={}, message={}",
                 ex.getErrorCode().getCode(), ex.getMessage());

        ErrorCode errorCode = ex.getErrorCode();
        return ResponseEntity.status(errorCode.getHttpStatus())
                .body(ApiResponse.failure(
                        ApiResponse.ErrorDetail.of(
                                errorCode.getCode(),
                                ex.getMessage())));
    }

    /**
     * @RequestBody @Valid 검증 실패 처리.
     * 필드별 에러 메시지를 details에 포함한다.
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Void>> handleValidationException(
            MethodArgumentNotValidException ex) {

        Map<String, String> fieldErrors = ex.getBindingResult()
                .getFieldErrors()
                .stream()
                .collect(Collectors.toMap(
                        FieldError::getField,
                        fe -> fe.getDefaultMessage() != null
                                ? fe.getDefaultMessage() : "invalid",
                        (a, b) -> a // 같은 필드에 오류 여러 개면 첫 번째만
                ));

        log.warn("[Validation] fieldErrors={}", fieldErrors);

        return ResponseEntity.badRequest()
                .body(ApiResponse.failure(
                        ApiResponse.ErrorDetail.of(
                                ErrorCode.INVALID_INPUT.getCode(),
                                ErrorCode.INVALID_INPUT.getMessage(),
                                fieldErrors)));
    }

    /**
     * @Validated 메서드 파라미터 검증 실패 처리.
     * @PathVariable, @RequestParam에 붙은 검증 어노테이션 실패 시 발생한다.
     */
    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiResponse<Void>> handleConstraintViolationException(
            ConstraintViolationException ex) {

        Map<String, String> violations = ex.getConstraintViolations()
                .stream()
                .collect(Collectors.toMap(
                        v -> v.getPropertyPath().toString(),
                        v -> v.getMessage()
                ));

        return ResponseEntity.badRequest()
                .body(ApiResponse.failure(
                        ApiResponse.ErrorDetail.of(
                                ErrorCode.INVALID_INPUT.getCode(),
                                ErrorCode.INVALID_INPUT.getMessage(),
                                violations)));
    }

    /**
     * @PathVariable, @RequestParam 타입 불일치.
     * 예: /api/users/abc (id가 Long인데 abc 전달)
     */
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ApiResponse<Void>> handleTypeMismatch(
            MethodArgumentTypeMismatchException ex) {

        String message = String.format(
                "파라미터 '%s'의 값 '%s'이(가) 올바르지 않습니다.",
                ex.getName(), ex.getValue());

        return ResponseEntity.badRequest()
                .body(ApiResponse.failure(
                        ApiResponse.ErrorDetail.of(
                                ErrorCode.INVALID_INPUT.getCode(), message)));
    }

    /**
     * JSON 파싱 실패.
     * 요청 body가 유효하지 않은 JSON이거나 필드 타입 불일치 시 발생한다.
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiResponse<Void>> handleMessageNotReadable(
            HttpMessageNotReadableException ex) {

        return ResponseEntity.badRequest()
                .body(ApiResponse.failure(
                        ApiResponse.ErrorDetail.of(
                                ErrorCode.INVALID_INPUT.getCode(),
                                "요청 본문을 읽을 수 없습니다. JSON 형식을 확인해주세요.")));
    }

    /**
     * 예상치 못한 예외 — 최후 방어선.
     * 운영에서는 상세 원인을 클라이언트에 노출하지 않는다.
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleException(Exception ex) {
        log.error("[UnhandledException] {}", ex.getMessage(), ex);

        return ResponseEntity.internalServerError()
                .body(ApiResponse.failure(
                        ApiResponse.ErrorDetail.of(
                                ErrorCode.INTERNAL_SERVER_ERROR.getCode(),
                                ErrorCode.INTERNAL_SERVER_ERROR.getMessage())));
    }
}
```

---

## 5. 요청 검증 — @Valid, @Validated, 커스텀 Validator

### 📌 @Valid — Bean Validation

```java
/**
 * Jakarta Bean Validation 기반 요청 DTO 검증.
 * @Valid를 붙이면 ArgumentResolver가 바인딩 시점에 검증을 실행한다.
 * 실패 시 MethodArgumentNotValidException 발생.
 */
public record CreateUserRequest(

        @NotBlank(message = "이름은 필수입니다.")
        @Size(min = 2, max = 50, message = "이름은 2~50자 사이여야 합니다.")
        String name,

        @NotBlank(message = "이메일은 필수입니다.")
        @Email(message = "이메일 형식이 올바르지 않습니다.")
        String email,

        @NotBlank(message = "비밀번호는 필수입니다.")
        @Pattern(
            regexp = "^(?=.*[A-Za-z])(?=.*\\d)(?=.*[@$!%*#?&])[A-Za-z\\d@$!%*#?&]{8,}$",
            message = "비밀번호는 8자 이상, 영문·숫자·특수문자를 포함해야 합니다."
        )
        String password,

        @NotNull(message = "나이는 필수입니다.")
        @Min(value = 0, message = "나이는 0 이상이어야 합니다.")
        @Max(value = 150, message = "나이는 150 이하여야 합니다.")
        Integer age,

        @NotEmpty(message = "역할은 하나 이상 선택해야 합니다.")
        List<@NotBlank String> roles
) {}
```

### 📌 @Validated — 그룹 검증 & 메서드 레벨 검증

생성/수정처럼 같은 DTO를 여러 용도로 사용할 때 검증 그룹을 다르게 적용한다.

```java
// 검증 그룹 마커 인터페이스
public interface ValidationGroups {
    interface Create {}
    interface Update {}
}

public record UserRequest(

        @NotNull(groups = ValidationGroups.Update.class, message = "수정 시 ID 필수")
        Long id,

        @NotBlank(groups = ValidationGroups.Create.class, message = "생성 시 이름 필수")
        @Size(min = 2, max = 50)
        String name,

        @NotBlank(groups = ValidationGroups.Create.class)
        @Email
        String email
) {}

/**
 * 클래스 레벨 @Validated: @PathVariable, @RequestParam 검증 활성화.
 * 메서드 파라미터에 붙은 @Min, @Max 등이 동작하려면 반드시 필요하다.
 * 실패 시 ConstraintViolationException 발생.
 */
@RestController
@RequestMapping("/api/v1/users")
@Validated
public class UserController {

    @PostMapping
    public ResponseEntity<ApiResponse<UserResponse>> createUser(
            @RequestBody @Validated(ValidationGroups.Create.class) UserRequest request) {
        return ResponseEntity.ok(ApiResponse.success(userService.create(request)));
    }

    @PutMapping
    public ResponseEntity<ApiResponse<UserResponse>> updateUser(
            @RequestBody @Validated(ValidationGroups.Update.class) UserRequest request) {
        return ResponseEntity.ok(ApiResponse.success(userService.update(request)));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<UserResponse>>> getUsers(
            @RequestParam @Min(0) int page,
            @RequestParam @Max(100) int size) {
        return ResponseEntity.ok(ApiResponse.success(userService.findAll(page, size)));
    }
}
```

### 📌 커스텀 Validator

단순 어노테이션으로 표현하기 어려운 복잡한 검증 규칙은 `ConstraintValidator`로 구현한다.

```java
// 1. 필드 레벨 커스텀 어노테이션 — 전화번호 형식 검증
@Target({ElementType.FIELD, ElementType.PARAMETER})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = PhoneNumberValidator.class)
@Documented
public @interface ValidPhone {
    String message() default "올바른 전화번호 형식이 아닙니다.";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

public class PhoneNumberValidator implements ConstraintValidator<ValidPhone, String> {

    private static final Pattern PHONE_PATTERN =
            Pattern.compile("^01[016789]-?\\d{3,4}-?\\d{4}$");

    @Override
    public boolean isValid(String value, ConstraintValidatorContext context) {
        if (value == null) return true; // null 검사는 @NotNull에 위임
        return PHONE_PATTERN.matcher(value.replaceAll("-", "")).matches();
    }
}
```

```java
// 2. 클래스 레벨 커스텀 Validator — 필드 간 조합 검증 (날짜 범위)
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = DateRangeValidator.class)
@Documented
public @interface ValidDateRange {
    String message() default "시작일은 종료일보다 이전이어야 합니다.";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

public class DateRangeValidator implements ConstraintValidator<ValidDateRange, SearchRequest> {

    @Override
    public boolean isValid(SearchRequest request, ConstraintValidatorContext context) {
        if (request.startDate() == null || request.endDate() == null) return true;
        return !request.startDate().isAfter(request.endDate());
    }
}

// 3. 적용
@ValidDateRange
public record SearchRequest(
        @ValidPhone String phone,
        LocalDate startDate,
        LocalDate endDate
) {}
```

---

## 6. 공통 요청 처리 — MDC & RequestContextHolder

### 📌 MDC — 로그 추적

MDC(Mapped Diagnostic Context)는 스레드 로컬 기반 로그 컨텍스트다. 한 번 설정하면 같은 스레드의 모든 로그에 자동으로 포함된다.

```java
/**
 * MDC 로깅 필터.
 * 모든 요청에 requestId를 부여하고 MDC에 등록해 로그 추적을 가능하게 한다.
 *
 * logback.xml 패턴 예시:
 * [%X{requestId}] [%X{userId}] %d{HH:mm:ss} %-5level %msg%n
 *
 * 출력 예:
 * [a1b2c3d4] [42] 09:00:01 INFO  [OrderService] 주문 생성 시작
 * [a1b2c3d4] [42] 09:00:01 INFO  [PaymentService] 결제 처리 시작
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class MdcLoggingFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        try {
            // 클라이언트가 전달한 requestId 재사용 또는 신규 생성
            String requestId = Optional.ofNullable(request.getHeader("X-Request-Id"))
                    .orElse(UUID.randomUUID().toString().replace("-", "").substring(0, 12));

            String userId = Optional.ofNullable(request.getHeader("X-User-Id"))
                    .orElse("anonymous");

            MDC.put("requestId", requestId);
            MDC.put("userId", userId);
            MDC.put("method", request.getMethod());
            MDC.put("uri", request.getRequestURI());

            response.setHeader("X-Request-Id", requestId); // 응답 헤더에도 전달

            filterChain.doFilter(request, response);

        } finally {
            MDC.clear(); // 스레드 풀 환경에서 반드시 정리 — 없으면 이전 요청 데이터 오염
        }
    }
}
```

### 📌 RequestContextHolder — 서비스까지 컨텍스트 전달

```java
/**
 * RequestContextHolder: 스프링이 관리하는 요청 컨텍스트 스레드 로컬.
 * Interceptor에서 인증 후 UserPrincipal을 설정하고 서비스에서 꺼내 사용한다.
 *
 * 주의: 비동기(@Async) 처리 시 컨텍스트가 전파되지 않는다.
 * 비동기 환경에서는 파라미터로 명시적으로 전달하는 것이 안전하다.
 */
@Component
public class RequestContextUtils {

    private static final String USER_PRINCIPAL_KEY = "USER_PRINCIPAL";

    public static void setUserPrincipal(UserPrincipal principal) {
        HttpServletRequest request = getCurrentRequest();
        request.setAttribute(USER_PRINCIPAL_KEY, principal);
    }

    public static UserPrincipal getUserPrincipal() {
        HttpServletRequest request = getCurrentRequest();
        UserPrincipal principal = (UserPrincipal) request.getAttribute(USER_PRINCIPAL_KEY);
        if (principal == null) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }
        return principal;
    }

    private static HttpServletRequest getCurrentRequest() {
        return ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes())
                .getRequest();
    }
}

// Interceptor에서 설정
@Component
public class AuthInterceptor implements HandlerInterceptor {

    private final TokenService tokenService;

    @Override
    public boolean preHandle(HttpServletRequest request,
                             HttpServletResponse response,
                             Object handler) throws Exception {
        String token = request.getHeader("Authorization");
        if (token != null && token.startsWith("Bearer ")) {
            UserPrincipal principal = tokenService.extractPrincipal(token.substring(7));
            RequestContextUtils.setUserPrincipal(principal); // 컨텍스트에 저장
            MDC.put("userId", String.valueOf(principal.id())); // MDC도 업데이트
        }
        return true;
    }
}

// 서비스에서 꺼내 사용
@Service
public class OrderService {

    @Transactional
    public OrderResponse createOrder(CreateOrderRequest request) {
        UserPrincipal loginUser = RequestContextUtils.getUserPrincipal();
        Order order = Order.create(loginUser.id(), request);
        return OrderResponse.from(orderRepository.save(order));
    }
}
```

---

## 7. ProblemDetail — RFC 7807 표준 에러 응답 (Spring 6+)

스프링 6(스프링 부트 3)부터 RFC 7807 표준을 구현한 `ProblemDetail`을 공식 지원한다. 팀 또는 프로젝트 표준에 따라 커스텀 `ApiResponse` 대신 이 방식을 선택할 수 있다.

```java
/**
 * ProblemDetail 응답 형태:
 * Content-Type: application/problem+json
 *
 * {
 *   "type": "https://api.example.com/errors/user-not-found",
 *   "title": "USER_NOT_FOUND",
 *   "status": 404,
 *   "detail": "사용자를 찾을 수 없습니다. id=42",
 *   "instance": "/api/v1/users/42",
 *   "errorCode": "USER_001",
 *   "timestamp": "2026-04-21T09:00:00Z"
 * }
 */
@RestControllerAdvice
public class ProblemDetailExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    public ProblemDetail handleBusinessException(BusinessException ex,
                                                 HttpServletRequest request) {
        ErrorCode errorCode = ex.getErrorCode();

        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                errorCode.getHttpStatus(), ex.getMessage());

        problemDetail.setTitle(errorCode.name());
        problemDetail.setType(URI.create(
                "https://api.example.com/errors/"
                + errorCode.getCode().toLowerCase().replace("_", "-")));
        problemDetail.setInstance(URI.create(request.getRequestURI()));

        // 커스텀 속성 추가
        problemDetail.setProperty("errorCode", errorCode.getCode());
        problemDetail.setProperty("timestamp", Instant.now());

        return problemDetail;
    }
}
```

> 💡 `ApiResponse<T>`와 `ProblemDetail` 중 어떤 것을 선택할지는 팀 컨벤션에 따른다. 성공/실패 응답을 동일한 래퍼로 통일하고 싶다면 `ApiResponse<T>`, RFC 표준을 따르고 싶다면 `ProblemDetail`을 선택한다. 두 가지를 혼용하면 클라이언트가 혼란스러우므로 하나를 선택해 일관되게 사용한다.

---

## 8. 응답 예시 정리

```
GET /api/v1/users/42 → 성공
{
  "success": true,
  "data": {
    "id": 42,
    "name": "김병찬",
    "email": "chan@example.com"
  }
}

POST /api/v1/users → 검증 실패
{
  "success": false,
  "error": {
    "code": "COMMON_001",
    "message": "잘못된 입력값입니다.",
    "details": {
      "email": "이메일 형식이 올바르지 않습니다.",
      "password": "8자 이상, 영문·숫자·특수문자를 포함해야 합니다."
    }
  }
}

GET /api/v1/users/9999 → 비즈니스 오류
{
  "success": false,
  "error": {
    "code": "USER_001",
    "message": "사용자를 찾을 수 없습니다. id=9999"
  }
}

POST /api/v1/orders → 서버 오류
{
  "success": false,
  "error": {
    "code": "COMMON_002",
    "message": "서버 내부 오류가 발생했습니다."
  }
}
```

---

## 9. 정리

- `ApiResponse<T>`로 성공/실패 응답 포맷을 일원화하고, 에러 코드는 `ErrorCode` enum으로 중앙 관리한다.
- `@RestControllerAdvice` + `@ExceptionHandler`로 예외 처리를 한 곳에서 담당한다. Filter에서 발생한 예외는 스프링 컨텍스트 밖이므로 별도로 처리해야 한다.
- `@Valid`는 `@RequestBody` 검증에, `@Validated`는 `@PathVariable` / `@RequestParam` 검증 및 그룹 검증에 사용한다. 실패 시 발생하는 예외 타입이 다르므로 `GlobalExceptionHandler`에서 각각 처리한다.
- MDC는 스레드 로컬 기반이므로 `finally` 블록에서 반드시 `MDC.clear()`를 호출한다. 비동기 환경에서는 컨텍스트가 자동으로 전파되지 않는다.
- Spring Boot 3(Spring 6)부터 `ProblemDetail`로 RFC 7807 표준 에러 응답을 공식 지원한다.

---

## 10. 참고 자료

- [Spring MVC 공식 문서 — Exceptions](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann-exceptionhandler.html)
- [Spring MVC 공식 문서 — ControllerAdvice](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann-advice.html)
- [Jakarta Bean Validation 공식 문서](https://jakarta.ee/specifications/bean-validation/)
- [Spring MVC 공식 문서 — Validation](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann-methods/arguments.html#mvc-ann-methods-validation)
- [Spring Framework 공식 문서 — ProblemDetail (RFC 7807)](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-rest-exceptions.html)
- [RFC 7807 — Problem Details for HTTP APIs](https://datatracker.ietf.org/doc/html/rfc7807)
