---
title: Spring Boot Spring Security 완전 정리 — 필터 체인, JWT 인증, 인가
date: 2026-04-21 12:00:00 +0900
categories: [Spring, 시큐리티]
tags: [SpringBoot, SpringSecurity, JWT, FilterChain, Authentication, Authorization]
---

## 1. 개요

Spring Security는 스프링 기반 애플리케이션의 인증(Authentication)과 인가(Authorization)를 담당하는 보안 프레임워크다. 서블릿 필터 체인 위에서 동작하기 때문에 DispatcherServlet에 도달하기 전에 모든 보안 처리가 완료된다.

| 주제 | 내용 |
|------|------|
| 필터 체인 구조 | DelegatingFilterProxy, FilterChainProxy, SecurityFilterChain |
| SecurityFilterChain 설정 | Spring Security 6.x 방식 (WebSecurityConfigurerAdapter 제거) |
| JWT 인증 필터 | OncePerRequestFilter 기반 구현 |
| JwtTokenProvider | 토큰 생성, 검증, 인증 객체 추출 |
| 예외 처리 | AuthenticationEntryPoint, AccessDeniedHandler |
| UserDetailsService | 사용자 정보 로드 |
| 메서드 레벨 인가 | @PreAuthorize, @PostAuthorize |

> 💡 본 포스트의 모든 코드는 Spring Boot 3.x / Spring Security 6.x / Jakarta EE 10 기준으로 작성한다.

---

## 2. Spring Security 필터 체인 구조

### 📌 전체 요청 흐름

```
HTTP 요청
    │
    ▼
Tomcat 서블릿 필터 체인
    │  CharacterEncodingFilter, CorsFilter ...
    │  DelegatingFilterProxy ← 스프링 시큐리티 진입점
    │
    ▼
FilterChainProxy (스프링 Bean)
    │  요청 URL 매칭 → SecurityFilterChain 선택
    │
    ▼
SecurityFilterChain
    │  SecurityContextPersistenceFilter   (SecurityContext 로드/저장)
    │  UsernamePasswordAuthenticationFilter (폼 로그인)
    │  JwtAuthenticationFilter (커스텀 — JWT 검증)
    │  ExceptionTranslationFilter         (인증/인가 예외 처리)
    │  FilterSecurityInterceptor          (인가 결정)
    │
    ▼
DispatcherServlet → Controller
```

### 📌 DelegatingFilterProxy의 역할

서블릿 필터는 서블릿 컨테이너(Tomcat)가 관리하므로 스프링 Bean을 직접 주입받을 수 없다. `DelegatingFilterProxy`는 이 간극을 메우는 브릿지다. 서블릿 컨텍스트에는 일반 필터로 등록되지만, 실제 처리는 스프링 Bean인 `FilterChainProxy`에 위임한다.

```
Tomcat → DelegatingFilterProxy (서블릿 필터)
              │  스프링 ApplicationContext에서 "springSecurityFilterChain" Bean 조회
              ▼
         FilterChainProxy (스프링 Bean)
              │  등록된 SecurityFilterChain 목록에서 URL 매칭
              ▼
         SecurityFilterChain (우리가 설정하는 Bean)
```

---

## 3. SecurityFilterChain 설정

### 📌 Spring Security 6.x 방식

스프링 부트 3.x(Spring Security 6.x)부터 `WebSecurityConfigurerAdapter`가 완전히 제거됐다. 대신 `SecurityFilterChain`을 Bean으로 직접 등록한다.

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true) // @PreAuthorize 활성화
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final CustomAuthenticationEntryPoint authenticationEntryPoint;
    private final CustomAccessDeniedHandler accessDeniedHandler;

    /**
     * SecurityFilterChain: 보안 필터 체인 Bean 등록.
     * 여러 개를 등록할 수 있으며, requestMatchers로 각 체인의 적용 URL을 구분한다.
     */
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
            // REST API는 세션을 사용하지 않으므로 CSRF 비활성화
            .csrf(csrf -> csrf.disable())

            // JWT 기반 → 세션 미사용 (STATELESS)
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))

            // CORS 설정
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))

            // 경로별 인가 규칙 — 순서가 중요하다. 구체적인 경로를 먼저 선언한다.
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**").permitAll()           // 인증 API
                .requestMatchers("/api/public/**").permitAll()         // 공개 API
                .requestMatchers("/actuator/health").permitAll()       // 헬스체크
                .requestMatchers(HttpMethod.GET, "/api/products/**").permitAll() // 상품 조회
                .requestMatchers("/api/admin/**").hasRole("ADMIN")     // 관리자 전용
                .anyRequest().authenticated()                          // 나머지 인증 필요
            )

            // 인증/인가 예외 처리 커스터마이징
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint(authenticationEntryPoint)   // 401 처리
                .accessDeniedHandler(accessDeniedHandler)             // 403 처리
            )

            // JWT 필터를 폼 로그인 필터 앞에 삽입
            .addFilterBefore(jwtAuthenticationFilter,
                             UsernamePasswordAuthenticationFilter.class)

            .build();
    }

    /**
     * CORS 설정.
     * SecurityFilterChain에서 .cors()로 참조하면 스프링 시큐리티 레벨에서 CORS를 처리한다.
     * WebMvcConfigurer의 addCorsMappings보다 먼저 적용된다.
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of(
            "https://app.example.com",
            "https://admin.example.com"
        ));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L); // 프리플라이트 캐시 (초)

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        // BCrypt: 단방향 해시, 강도(strength) 기본값 10 — 높을수록 느리고 안전
        return new BCryptPasswordEncoder();
    }
}
```

---

## 4. JWT 인증 필터

### 📌 OncePerRequestFilter 기반 구현

```java
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * JWT 인증 필터.
 * 매 요청마다 Authorization 헤더의 JWT를 검증하고
 * 유효하면 SecurityContext에 인증 정보를 등록한다.
 *
 * OncePerRequestFilter: 요청당 정확히 한 번만 실행 보장.
 * 포워드/인클루드 시 중복 실행을 방지한다.
 */
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtTokenProvider jwtTokenProvider;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        String token = extractToken(request);

        if (token != null && jwtTokenProvider.isValid(token)) {
            /**
             * SecurityContextHolder: 현재 스레드의 보안 컨텍스트 보관.
             * 여기서 Authentication을 설정하면 이후 컨트롤러까지 전달된다.
             * 기본 전략은 ThreadLocal — 요청 스레드에 국한된다.
             * 비동기(@Async) 환경에서는 MODE_INHERITABLETHREADLOCAL로 변경 필요.
             */
            Authentication authentication = jwtTokenProvider.getAuthentication(token);
            SecurityContextHolder.getContext().setAuthentication(authentication);
        }

        filterChain.doFilter(request, response);
        // 응답 이후 SecurityContextHolder는 SecurityContextPersistenceFilter가 정리한다.
    }

    /**
     * Authorization 헤더에서 Bearer 토큰 추출.
     * 헤더 없음 또는 Bearer 접두사 없으면 null 반환.
     */
    private String extractToken(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (StringUtils.hasText(header) && header.startsWith("Bearer ")) {
            return header.substring(7);
        }
        return null;
    }
}
```

---

## 5. JwtTokenProvider

```java
/**
 * JWT 토큰 생성, 검증, 파싱을 담당하는 컴포넌트.
 * jjwt 라이브러리(0.12.x) 기준으로 작성한다.
 */
@Component
public class JwtTokenProvider {

    private final SecretKey signingKey;
    private final Duration accessTokenExpiry;
    private final Duration refreshTokenExpiry;
    private final UserDetailsService userDetailsService;

    public JwtTokenProvider(AppProperties appProperties,
                             UserDetailsService userDetailsService) {
        byte[] keyBytes = Decoders.BASE64.decode(appProperties.jwt().secret());
        this.signingKey = Keys.hmacShaKeyFor(keyBytes);
        this.accessTokenExpiry = appProperties.jwt().accessTokenExpiry();
        this.refreshTokenExpiry = appProperties.jwt().refreshTokenExpiry();
        this.userDetailsService = userDetailsService;
    }

    /**
     * 액세스 토큰 생성.
     * subject: 사용자 식별자 (이메일 또는 ID)
     * roles: 권한 목록 (클레임으로 포함)
     */
    public String generateAccessToken(UserDetails userDetails) {
        return Jwts.builder()
                .subject(userDetails.getUsername())
                .issuedAt(new Date())
                .expiration(Date.from(Instant.now().plus(accessTokenExpiry)))
                .claim("roles", userDetails.getAuthorities().stream()
                        .map(GrantedAuthority::getAuthority)
                        .toList())
                .signWith(signingKey)
                .compact();
    }

    /**
     * 리프레시 토큰 생성.
     * 최소한의 정보만 포함 — subject만 담는다.
     */
    public String generateRefreshToken(String subject) {
        return Jwts.builder()
                .subject(subject)
                .issuedAt(new Date())
                .expiration(Date.from(Instant.now().plus(refreshTokenExpiry)))
                .signWith(signingKey)
                .compact();
    }

    /**
     * 토큰 유효성 검증.
     * 서명 불일치, 만료, 형식 오류 모두 false 반환.
     */
    public boolean isValid(String token) {
        try {
            parseClaims(token);
            return true;
        } catch (ExpiredJwtException e) {
            log.warn("[JWT] 만료된 토큰: {}", e.getMessage());
        } catch (JwtException e) {
            log.warn("[JWT] 유효하지 않은 토큰: {}", e.getMessage());
        } catch (IllegalArgumentException e) {
            log.warn("[JWT] 토큰이 비어있음");
        }
        return false;
    }

    /**
     * 토큰에서 Authentication 객체 생성.
     * DB 조회 방식: 항상 최신 사용자 상태(권한 변경, 계정 잠금 등)를 반영.
     * 클레임 파싱 방식: DB 조회 없이 빠름. 단, 토큰 발급 후 권한 변경은 반영 안 됨.
     */
    public Authentication getAuthentication(String token) {
        String username = parseClaims(token).getSubject();
        UserDetails userDetails = userDetailsService.loadUserByUsername(username);
        return new UsernamePasswordAuthenticationToken(
                userDetails, null, userDetails.getAuthorities());
    }

    public String getSubject(String token) {
        return parseClaims(token).getSubject();
    }

    private Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(signingKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
```

---

## 6. 인증/인가 예외 처리

### 📌 AuthenticationEntryPoint — 401 처리

```java
/**
 * 인증되지 않은 요청이 보호된 리소스에 접근할 때 호출된다.
 * 스프링 시큐리티의 ExceptionTranslationFilter가 AuthenticationException을
 * 잡아 이 핸들러로 위임한다.
 *
 * 기본 동작: 로그인 페이지로 리다이렉트.
 * REST API에서는 JSON 응답을 반환하도록 커스터마이징한다.
 */
@Component
@RequiredArgsConstructor
public class CustomAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ObjectMapper objectMapper;

    @Override
    public void commence(HttpServletRequest request,
                         HttpServletResponse response,
                         AuthenticationException authException) throws IOException {

        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");

        ApiResponse<Void> body = ApiResponse.failure(
                ApiResponse.ErrorDetail.of("AUTH_001", "인증이 필요합니다."));
        response.getWriter().write(objectMapper.writeValueAsString(body));
    }
}
```

### 📌 AccessDeniedHandler — 403 처리

```java
/**
 * 인증은 됐지만 권한이 없는 리소스에 접근할 때 호출된다.
 * ExceptionTranslationFilter가 AccessDeniedException을 잡아 위임한다.
 *
 * 주의: 이 핸들러는 @ControllerAdvice가 아닌 스프링 시큐리티 레벨에서 동작한다.
 * 따라서 GlobalExceptionHandler의 @ExceptionHandler와 별개로 등록해야 한다.
 */
@Component
@RequiredArgsConstructor
public class CustomAccessDeniedHandler implements AccessDeniedHandler {

    private final ObjectMapper objectMapper;

    @Override
    public void handle(HttpServletRequest request,
                       HttpServletResponse response,
                       AccessDeniedException accessDeniedException) throws IOException {

        response.setStatus(HttpServletResponse.SC_FORBIDDEN);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");

        ApiResponse<Void> body = ApiResponse.failure(
                ApiResponse.ErrorDetail.of("AUTH_002", "접근 권한이 없습니다."));
        response.getWriter().write(objectMapper.writeValueAsString(body));
    }
}
```

---

## 7. UserDetailsService 구현

```java
/**
 * UserDetailsService: 스프링 시큐리티가 인증 시 사용자 정보를 로드하는 인터페이스.
 * loadUserByUsername()이 반환하는 UserDetails 객체로:
 * 1. 비밀번호 검증 (PasswordEncoder.matches())
 * 2. 권한 부여 (GrantedAuthority 목록)
 * 3. 계정 상태 확인 (만료, 잠금, 활성화 여부)
 */
@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepository;

    @Override
    @Transactional(readOnly = true)
    public UserDetails loadUserByUsername(String email) throws UsernameNotFoundException {

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException(
                        "사용자를 찾을 수 없습니다: " + email));

        return org.springframework.security.core.userdetails.User.builder()
                .username(user.getEmail())
                .password(user.getPassword())       // BCrypt 해시된 비밀번호
                .roles(user.getRole().name())        // ROLE_ 접두사 자동 추가
                .accountExpired(!user.isActive())
                .accountLocked(user.isLocked())
                .credentialsExpired(false)
                .disabled(!user.isEnabled())
                .build();
    }
}
```

---

## 8. 인증 API 컨트롤러

```java
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<TokenResponse>> login(
            @RequestBody @Valid LoginRequest request) {
        TokenResponse tokens = authService.login(request);
        return ResponseEntity.ok(ApiResponse.success(tokens));
    }

    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<TokenResponse>> refresh(
            @RequestBody @Valid RefreshRequest request) {
        TokenResponse tokens = authService.refresh(request.refreshToken());
        return ResponseEntity.ok(ApiResponse.success(tokens));
    }

    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(
            @AuthenticationPrincipal UserDetails userDetails) {
        authService.logout(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success());
    }
}

@Service
@RequiredArgsConstructor
public class AuthService {

    private final AuthenticationManager authenticationManager;
    private final JwtTokenProvider jwtTokenProvider;
    private final UserDetailsService userDetailsService;
    private final RedisTemplate<String, String> redisTemplate;

    public TokenResponse login(LoginRequest request) {
        // AuthenticationManager가 UserDetailsService와 PasswordEncoder를 사용해 검증
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        request.email(), request.password()));

        UserDetails userDetails = (UserDetails) authentication.getPrincipal();
        String accessToken = jwtTokenProvider.generateAccessToken(userDetails);
        String refreshToken = jwtTokenProvider.generateRefreshToken(userDetails.getUsername());

        // 리프레시 토큰 Redis에 저장 (무효화를 위해)
        redisTemplate.opsForValue().set(
                "REFRESH:" + userDetails.getUsername(),
                refreshToken,
                Duration.ofDays(30));

        return new TokenResponse(accessToken, refreshToken);
    }

    public void logout(String email) {
        // Redis에서 리프레시 토큰 삭제 → 재발급 불가
        redisTemplate.delete("REFRESH:" + email);
    }
}
```

---

## 9. 메서드 레벨 인가

```java
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    /**
     * @AuthenticationPrincipal: SecurityContext에서 인증된 사용자를 파라미터로 주입.
     */
    @GetMapping("/me")
    public ResponseEntity<ApiResponse<UserResponse>> getMyInfo(
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(
                ApiResponse.success(userService.findByEmail(userDetails.getUsername())));
    }

    /**
     * @PreAuthorize: 메서드 실행 전 SpEL 표현식으로 인가 결정.
     * ADMIN이거나 자기 자신의 정보만 삭제 가능.
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or #id == authentication.principal.id")
    public ResponseEntity<ApiResponse<Void>> deleteUser(@PathVariable Long id) {
        userService.delete(id);
        return ResponseEntity.ok(ApiResponse.success());
    }

    /**
     * @PostAuthorize: 메서드 실행 후 반환값 기준 인가.
     * 반환된 데이터의 소유자가 현재 사용자인지 확인.
     */
    @GetMapping("/{id}/orders")
    @PostAuthorize("returnObject.body.data.userId == authentication.principal.id")
    public ResponseEntity<ApiResponse<List<OrderResponse>>> getUserOrders(
            @PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success(orderService.findByUserId(id)));
    }
}
```

---

## 10. 정리

- `DelegatingFilterProxy`가 서블릿 컨텍스트와 스프링 컨텍스트를 연결한다. 실제 보안 로직은 스프링 Bean인 `FilterChainProxy` → `SecurityFilterChain`에서 처리된다.
- Spring Security 6.x부터 `WebSecurityConfigurerAdapter`가 제거됐다. `SecurityFilterChain` Bean을 직접 등록하는 방식을 사용한다.
- JWT 필터(`JwtAuthenticationFilter`)는 `OncePerRequestFilter`를 상속하고 `UsernamePasswordAuthenticationFilter` 앞에 삽입한다. 검증 성공 시 `SecurityContextHolder`에 `Authentication`을 설정한다.
- 인증 실패(401)는 `AuthenticationEntryPoint`, 인가 실패(403)는 `AccessDeniedHandler`에서 JSON 응답으로 처리한다. 두 핸들러 모두 `@ControllerAdvice`가 아닌 시큐리티 레벨에서 동작한다.
- `@PreAuthorize`로 메서드 레벨 인가를 적용할 때는 `@EnableMethodSecurity(prePostEnabled = true)`를 추가해야 한다.

---

## 11. 참고 자료

- [Spring Security 공식 문서 — Architecture](https://docs.spring.io/spring-security/reference/servlet/architecture.html)
- [Spring Security 공식 문서 — Authentication](https://docs.spring.io/spring-security/reference/servlet/authentication/index.html)
- [Spring Security 공식 문서 — Authorization](https://docs.spring.io/spring-security/reference/servlet/authorization/index.html)
- [Spring Security 공식 문서 — OAuth2 / JWT](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html)
- [jjwt 공식 문서](https://github.com/jwtk/jjwt)
