---
title: Spring Boot TDD — 개념부터 실전 전략까지
date: 2026-04-13 09:00:00 +0900
categories: [TDD, 개념 및 사용법]
tags: [TDD, 개념 및 사용법, JUnit5, Mockito, SpringBoot, 테스트전략]
---

TDD를 처음 배울 때 가장 흔하게 하는 오해가 있다. "테스트 코드를 잘 짜는 방법"이라고 생각하는 것이다.
TDD(Test-Driven Development)는 테스트 기법이 아니라 **설계 방법론**이다.
테스트를 먼저 작성함으로써 코드를 사용하는 입장에서 API를 먼저 설계하게 되고, 이것이 자연스럽게 더 나은 인터페이스로 이어진다.

이 글에서는 Spring Boot 3.x 환경에서 JUnit 5 + Mockito를 활용한 TDD 사이클 전반을 다룬다.
회원가입, 로그인 도메인을 예시로 삼아 실제로 어떻게 실패 코드를 먼저 쓰고, 구현하고, 리팩토링하는지 흐름 그대로 설명한다.

## 1. 전체 구조

| 챕터 | 내용 |
|------|------|
| 2. TDD 핵심 사이클 | Red → Green → Refactor 개념 |
| 3. 테스트 환경 세팅 | build.gradle, application.yml |
| 4. 테스트 계층 구조 | 단위 / 슬라이스 / 통합 |
| 5. 실패 코드(Red)의 의미 | Red 단계에서 생각해야 할 것 |
| 6. 서비스 단위 테스트 | 회원가입 / 로그인 전 사이클 실습 |
| 7. Repository 테스트 | @DataJpaTest |
| 8. Controller 테스트 | @WebMvcTest + MockMvc |
| 9. 통합 테스트 | @SpringBootTest |
| 10. 예외 & 경계값 전략 | Edge Case 집중 |
| 11. 실무 패턴 | BDD Mockito, @ParameterizedTest, @Nested |
| 12. 안티패턴 & 체크리스트 | 자주 하는 실수 정리 |

---

## 2. TDD 핵심 사이클 — Red → Green → Refactor

TDD는 아래 3단계를 반복하는 짧은 개발 사이클로 구성된다.

### 📌 Red — 실패하는 테스트를 먼저 작성한다

아직 구현되지 않은 기능에 대한 테스트를 먼저 작성한다.
테스트가 실패함으로써 그 테스트 자체가 올바른 검증을 수행하고 있음을 증명한다.

### 📌 Green — 테스트를 통과하는 최소한의 코드를 작성한다

이 단계에서는 설계의 완성도보다 "테스트를 통과하는 것"에만 집중한다.
깔끔한 코드, 성능 최적화는 이 단계의 목표가 아니다.

### 📌 Refactor — 동작을 유지하면서 코드를 개선한다

모든 테스트가 Green일 때만 리팩토링을 수행한다.
리팩토링 후 테스트가 깨진다면, 그것이 내 실수에서 비롯된 것임을 확신할 수 있다.

> 💡 이 사이클이 하나의 기능에 대해 5~10분 단위로 반복된다. 각 사이클이 끝날 때마다 로컬 커밋을 남기면 잘못된 방향으로 갔을 때 빠르게 되돌릴 수 있다.

---

## 3. 테스트 환경 세팅

### 📌 build.gradle (Gradle Kotlin DSL, Spring Boot 3.x)

```kotlin
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-validation")

    runtimeOnly("com.h2database:h2") // 테스트용 인메모리 DB

    // spring-boot-starter-test가 JUnit 5, Mockito, AssertJ, MockMvc를 모두 포함
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.security:spring-security-test")
}

tasks.withType<Test> {
    useJUnitPlatform() // JUnit 5 활성화 필수
}
```

`spring-boot-starter-test` 하나만 추가하면 JUnit 5, Mockito, AssertJ가 전이적으로 함께 딸려온다.
별도로 의존성을 추가할 필요가 없다.

### 📌 테스트 전용 application.yml (src/test/resources)

```yaml
spring:
  datasource:
    url: jdbc:h2:mem:testdb;MODE=MySQL
    driver-class-name: org.h2.Driver
  jpa:
    hibernate:
      ddl-auto: create-drop
    show-sql: true
```

---

## 4. 테스트 계층 구조

Spring Boot에서 테스트는 크게 세 계층으로 나뉜다.
테스트 피라미드 관점에서 단위 테스트를 가장 많이, 통합 테스트를 가장 적게 작성하는 것이 기본 원칙이다.

| 어노테이션 | 로드 범위 | 속도 | 주 용도 |
|---|---|---|---|
| `@ExtendWith(MockitoExtension.class)` | 없음 (순수 Java) | 매우 빠름 | Service, 비즈니스 로직 |
| `@WebMvcTest` | Web Layer만 | 빠름 | Controller, Filter |
| `@DataJpaTest` | JPA 관련만 | 빠름 | Repository, JPQL |
| `@SpringBootTest` | 전체 컨텍스트 | 느림 | E2E, 통합 시나리오 |

Spring Boot는 레이어별 슬라이스 테스트 어노테이션을 제공한다.
예를 들어 웹 레이어만 테스트할 때는 전체 Spring 컨텍스트를 로드할 필요가 없다.
`@WebMvcTest`는 웹 레이어, `@DataJpaTest`는 JPA 레포지토리 테스트에 특화된 부분 컨텍스트를 생성한다.

---

## 5. 실패 코드(Red)를 먼저 쓴다는 것의 진짜 의미

TDD 입문자가 가장 헷갈려하는 부분이다. "왜 컴파일도 안 되는 코드를 먼저 쓰는가?"

Red 단계에서 발생하는 실패 유형은 세 가지다.

```
1. 컴파일 에러(Red)
   → 클래스/메서드가 아직 존재하지 않는다는 의미
   → 테스트를 씀으로써 인터페이스를 먼저 설계한 것

2. assertion 실패(Red)
   → 구현은 있지만 올바르지 않다는 의미
   → 명세가 명확하게 정의된 것

3. 테스트가 처음부터 Green
   → 테스트 자체가 잘못됐거나 이미 구현됨
   → 반드시 의심해야 한다
```

> 💡 가장 중요한 원칙: 실패하는 테스트를 작성한 뒤 반드시 **실제로 실패하는지 실행**해서 확인해야 한다. 처음부터 Green이면 그 테스트는 아무것도 검증하지 못한다.

### 📌 나쁜 Red vs 좋은 Red

```java
// ❌ 나쁜 Red: assertion이 없어 항상 Green → 아무것도 검증하지 못함
@Test
void 회원가입_테스트() {
    memberService.register(new RegisterRequest(...));
    // assertion 없음
}

// ✅ 좋은 Red: 단 하나의 동작, 명확한 실패 이유
@Test
@DisplayName("이미 가입된 이메일로 회원가입 시 DuplicateEmailException 발생")
void register_duplicateEmail_throwsException() {
    given(memberRepository.existsByEmail("chan@test.com")).willReturn(true);

    assertThatThrownBy(() -> memberService.register(registerRequest))
        .isInstanceOf(DuplicateEmailException.class)
        .hasMessage("이미 사용 중인 이메일입니다.");
}
```

---

## 6. 서비스 단위 테스트 — 회원가입 / 로그인

TDD에서는 테스트를 쓰기 전에 사용하는 쪽(클라이언트)의 관점에서 API를 먼저 구상한다.

```java
// 먼저 어떻게 사용할지 결정
memberService.register(RegisterRequest.of("chan@test.com", "password123!"));
memberService.login(LoginRequest.of("chan@test.com", "password123!"));
```

### 📌 Step 1 — Red: 실패하는 테스트 먼저 작성

```java
@ExtendWith(MockitoExtension.class)
class MemberServiceTest {

    @Mock
    private MemberRepository memberRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @InjectMocks
    private MemberService memberService; // 아직 이 클래스는 없거나 비어 있음

    // ===== 회원가입 테스트 =====

    @Test
    @DisplayName("[Red] 정상적인 회원가입 요청 시 저장된 회원 정보를 반환한다")
    void register_validRequest_returnsSavedMember() {
        // Given
        RegisterRequest request = new RegisterRequest("chan@test.com", "pass123!");
        Member savedMember = Member.builder()
            .id(1L).email("chan@test.com").password("encoded_pass").build();

        given(memberRepository.existsByEmail("chan@test.com")).willReturn(false);
        given(passwordEncoder.encode("pass123!")).willReturn("encoded_pass");
        given(memberRepository.save(any(Member.class))).willReturn(savedMember);

        // When
        MemberResponse response = memberService.register(request); // 이 시점에 컴파일 에러 → Red

        // Then
        assertThat(response.getId()).isEqualTo(1L);
        assertThat(response.getEmail()).isEqualTo("chan@test.com");
    }

    @Test
    @DisplayName("[Red] 이미 가입된 이메일로 요청 시 DuplicateEmailException 발생")
    void register_duplicateEmail_throwsDuplicateEmailException() {
        // Given
        RegisterRequest request = new RegisterRequest("chan@test.com", "pass123!");
        given(memberRepository.existsByEmail("chan@test.com")).willReturn(true);

        // When & Then
        assertThatThrownBy(() -> memberService.register(request))
            .isInstanceOf(DuplicateEmailException.class)
            .hasMessage("이미 사용 중인 이메일입니다.");

        // 저장 로직은 절대 호출되지 않아야 함
        then(memberRepository).should(never()).save(any(Member.class));
    }

    @Test
    @DisplayName("[Red] 비밀번호는 암호화되어 저장된다")
    void register_passwordIsEncoded() {
        // Given
        RegisterRequest request = new RegisterRequest("chan@test.com", "raw_password");
        given(memberRepository.existsByEmail(anyString())).willReturn(false);
        given(passwordEncoder.encode("raw_password")).willReturn("hashed_password");
        given(memberRepository.save(any(Member.class))).willAnswer(invocation -> {
            Member member = invocation.getArgument(0);
            assertThat(member.getPassword()).isEqualTo("hashed_password"); // 저장 시 인코딩 검증
            return member;
        });

        // When
        memberService.register(request);

        // Then
        then(passwordEncoder).should(times(1)).encode("raw_password");
    }

    // ===== 로그인 테스트 =====

    @Test
    @DisplayName("[Red] 존재하지 않는 이메일로 로그인 시 MemberNotFoundException 발생")
    void login_emailNotFound_throwsMemberNotFoundException() {
        // Given
        LoginRequest request = new LoginRequest("notexist@test.com", "password");
        given(memberRepository.findByEmail("notexist@test.com")).willReturn(Optional.empty());

        // When & Then
        assertThatThrownBy(() -> memberService.login(request))
            .isInstanceOf(MemberNotFoundException.class);
    }

    @Test
    @DisplayName("[Red] 비밀번호 불일치 시 InvalidPasswordException 발생")
    void login_wrongPassword_throwsInvalidPasswordException() {
        // Given
        LoginRequest request = new LoginRequest("chan@test.com", "wrong_pass");
        Member member = Member.builder()
            .email("chan@test.com").password("encoded_correct_pass").build();

        given(memberRepository.findByEmail("chan@test.com")).willReturn(Optional.of(member));
        given(passwordEncoder.matches("wrong_pass", "encoded_correct_pass")).willReturn(false);

        // When & Then
        assertThatThrownBy(() -> memberService.login(request))
            .isInstanceOf(InvalidPasswordException.class);
    }
}
```

### 📌 Step 2 — Green: 테스트를 통과하는 최소한의 구현

```java
@Service
@RequiredArgsConstructor
@Transactional
public class MemberService {

    private final MemberRepository memberRepository;
    private final PasswordEncoder passwordEncoder;

    public MemberResponse register(RegisterRequest request) {
        // 중복 이메일 검증
        if (memberRepository.existsByEmail(request.getEmail())) {
            throw new DuplicateEmailException("이미 사용 중인 이메일입니다.");
        }

        // 비밀번호 인코딩 후 저장
        Member member = Member.builder()
            .email(request.getEmail())
            .password(passwordEncoder.encode(request.getPassword()))
            .build();

        Member saved = memberRepository.save(member);
        return MemberResponse.from(saved);
    }

    @Transactional(readOnly = true)
    public LoginResponse login(LoginRequest request) {
        Member member = memberRepository.findByEmail(request.getEmail())
            .orElseThrow(MemberNotFoundException::new);

        if (!passwordEncoder.matches(request.getPassword(), member.getPassword())) {
            throw new InvalidPasswordException();
        }

        return LoginResponse.of(member);
    }
}
```

### 📌 Step 3 — Refactor: 코드 개선 (테스트는 그대로 Green)

```java
/**
 * 리팩토링 포인트: 비밀번호 검증 책임을 도메인 객체(Member)로 이동한다.
 * 서비스가 직접 matches()를 호출하는 것보다 Member가 스스로 검증하는 것이 더 응집력 있다.
 */
@Entity
public class Member {

    // ...

    public void validatePassword(String rawPassword, PasswordEncoder encoder) {
        if (!encoder.matches(rawPassword, this.password)) {
            throw new InvalidPasswordException();
        }
    }
}

// 서비스는 더 간결해짐
public LoginResponse login(LoginRequest request) {
    Member member = memberRepository.findByEmail(request.getEmail())
        .orElseThrow(MemberNotFoundException::new);

    member.validatePassword(request.getPassword(), passwordEncoder); // 책임 위임
    return LoginResponse.of(member);
}
```

리팩토링 후에는 반드시 기존 테스트가 모두 Green인지 확인한다.
외부 동작이 바뀌지 않았다면 테스트는 그대로 통과해야 한다.

---

## 7. Repository 슬라이스 테스트 — @DataJpaTest

```java
/**
 * @DataJpaTest는 H2 인메모리 DB와 JPA 관련 빈만 로드한다.
 * 서비스, 컨트롤러 계층은 포함되지 않으므로 빠르게 실행된다.
 */
@DataJpaTest
class MemberRepositoryTest {

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private TestEntityManager em;

    @Test
    @DisplayName("이메일로 회원 조회 시 해당 회원을 반환한다")
    void findByEmail_existingEmail_returnsMember() {
        // Given
        Member member = Member.builder()
            .email("chan@test.com")
            .password("encoded_pass")
            .name("김병찬")
            .build();
        em.persistAndFlush(member);
        em.clear(); // 1차 캐시 초기화 → 실제 DB 조회 검증

        // When
        Optional<Member> result = memberRepository.findByEmail("chan@test.com");

        // Then
        assertThat(result).isPresent();
        assertThat(result.get().getEmail()).isEqualTo("chan@test.com");
    }

    @Test
    @DisplayName("존재하지 않는 이메일 조회 시 빈 Optional 반환")
    void findByEmail_nonExistingEmail_returnsEmpty() {
        Optional<Member> result = memberRepository.findByEmail("notexist@test.com");
        assertThat(result).isEmpty();
    }

    @Test
    @DisplayName("가입된 이메일이면 existsByEmail이 true를 반환한다")
    void existsByEmail_existingEmail_returnsTrue() {
        // Given
        em.persistAndFlush(Member.builder().email("chan@test.com").password("pass").build());

        // When & Then
        assertThat(memberRepository.existsByEmail("chan@test.com")).isTrue();
    }
}
```

> 💡 `em.clear()`로 1차 캐시를 비워야 실제 DB 쿼리가 실행된다. 비우지 않으면 캐시에서 반환되어 쿼리가 잘못 작성돼도 테스트가 통과해버린다.

---

## 8. Controller 슬라이스 테스트 — @WebMvcTest + MockMvc

```java
/**
 * @WebMvcTest는 웹 레이어 빈(Controller, Filter, HandlerMethodArgumentResolver 등)만 로드한다.
 * Service는 @MockBean으로 교체해야 한다.
 * @Mock이 아닌 @MockBean을 써야 Spring 컨텍스트에 정상 등록된다.
 */
@WebMvcTest(MemberController.class)
class MemberControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean // @Mock이 아닌 @MockBean: Spring 컨텍스트에 등록
    private MemberService memberService;

    @Test
    @DisplayName("POST /api/members - 정상 요청 시 201 Created 반환")
    void register_validRequest_returns201() throws Exception {
        // Given
        RegisterRequest request = new RegisterRequest("chan@test.com", "pass123!");
        MemberResponse response = MemberResponse.builder().id(1L).email("chan@test.com").build();

        given(memberService.register(any(RegisterRequest.class))).willReturn(response);

        // When & Then
        mockMvc.perform(post("/api/members")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(1L))
            .andExpect(jsonPath("$.email").value("chan@test.com"))
            .andDo(print()); // 요청/응답 콘솔 출력 (디버깅 시 유용)
    }

    @Test
    @DisplayName("POST /api/members - 이메일 형식 오류 시 400 Bad Request 반환")
    void register_invalidEmail_returns400() throws Exception {
        // Given - Bean Validation 테스트 (Service Mock 불필요)
        RegisterRequest request = new RegisterRequest("invalid-email", "pass123!");

        mockMvc.perform(post("/api/members")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("POST /api/members - 중복 이메일 시 409 Conflict 반환")
    void register_duplicateEmail_returns409() throws Exception {
        // Given
        RegisterRequest request = new RegisterRequest("chan@test.com", "pass123!");
        given(memberService.register(any())).willThrow(new DuplicateEmailException("이미 사용 중인 이메일입니다."));

        mockMvc.perform(post("/api/members")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.message").value("이미 사용 중인 이메일입니다."));
    }

    @Test
    @DisplayName("POST /api/auth/login - 정상 로그인 시 토큰 반환")
    void login_validCredentials_returnsToken() throws Exception {
        // Given
        LoginRequest request = new LoginRequest("chan@test.com", "pass123!");
        LoginResponse loginResponse = LoginResponse.builder()
            .accessToken("jwt.access.token")
            .refreshToken("jwt.refresh.token")
            .build();

        given(memberService.login(any(LoginRequest.class))).willReturn(loginResponse);

        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.accessToken").isNotEmpty());
    }
}
```

---

## 9. 통합 테스트 — @SpringBootTest

```java
/**
 * @SpringBootTest는 전체 Spring 컨텍스트를 로드한다.
 * 실행 속도가 느리므로 단위/슬라이스 테스트로 충분히 커버되지 않는
 * 전체 플로우 검증에만 사용한다.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Transactional // 각 테스트 후 롤백
class MemberIntegrationTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    @DisplayName("회원가입 → 로그인 전체 플로우 검증")
    void registerThenLogin_fullFlow() {
        // 1. 회원가입
        RegisterRequest registerRequest = new RegisterRequest("chan@test.com", "pass123!");
        ResponseEntity<MemberResponse> registerResponse = restTemplate.postForEntity(
            "/api/members", registerRequest, MemberResponse.class);

        assertThat(registerResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        // 2. DB에 실제로 저장됐는지 확인
        Member saved = memberRepository.findByEmail("chan@test.com").orElseThrow();
        assertThat(passwordEncoder.matches("pass123!", saved.getPassword())).isTrue();

        // 3. 로그인
        LoginRequest loginRequest = new LoginRequest("chan@test.com", "pass123!");
        ResponseEntity<LoginResponse> loginResponse = restTemplate.postForEntity(
            "/api/auth/login", loginRequest, LoginResponse.class);

        assertThat(loginResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(loginResponse.getBody().getAccessToken()).isNotBlank();
    }
}
```

---

## 10. 예외 처리 & 경계값 테스트 전략

테스트 코드에서 가장 가치 있는 부분은 경계값(Edge Case)과 예외 케이스다.
정상 케이스는 구현하다 보면 자연스럽게 동작하지만, 경계값은 명시적으로 검증하지 않으면 반드시 놓친다.

```java
@ExtendWith(MockitoExtension.class)
class MemberServiceEdgeCaseTest {

    @Nested
    @DisplayName("비밀번호 정책 검증")
    class PasswordValidationTest {

        @Test
        @DisplayName("비밀번호가 8자 미만이면 예외 발생")
        void register_shortPassword_throwsException() {
            RegisterRequest request = new RegisterRequest("chan@test.com", "short");

            assertThatThrownBy(() -> memberService.register(request))
                .isInstanceOf(InvalidPasswordException.class)
                .hasMessageContaining("비밀번호");
        }

        @Test
        @DisplayName("비밀번호에 특수문자가 없으면 예외 발생")
        void register_noSpecialChar_throwsException() {
            RegisterRequest request = new RegisterRequest("chan@test.com", "nospecial1");

            assertThatThrownBy(() -> memberService.register(request))
                .isInstanceOf(InvalidPasswordException.class);
        }
    }

    @Test
    @DisplayName("중복 이메일인 경우 save()는 절대 호출되지 않는다")
    void register_duplicateEmail_neverCallsSave() {
        given(memberRepository.existsByEmail(anyString())).willReturn(true);

        assertThatThrownBy(() -> memberService.register(request))
            .isInstanceOf(DuplicateEmailException.class);

        // 저장 로직이 단 한 번도 호출되지 않았는지 검증
        then(memberRepository).should(never()).save(any(Member.class));

        // 비밀번호 인코딩도 불필요하게 호출되지 않아야 함
        then(passwordEncoder).should(never()).encode(anyString());
    }
}
```

---

## 11. 실무 패턴

### 📌 BDD Mockito — given/when/then 스타일

```java
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;

@Test
@DisplayName("BDD 스타일: 이메일로 회원 조회 시 회원 반환")
void findMember_bddStyle() {
    // Given
    Member member = Member.builder().id(1L).email("chan@test.com").build();
    given(memberRepository.findByEmail("chan@test.com")).willReturn(Optional.of(member));

    // When
    MemberResponse result = memberService.findByEmail("chan@test.com");

    // Then
    assertThat(result.getEmail()).isEqualTo("chan@test.com");
    then(memberRepository).should(times(1)).findByEmail("chan@test.com");
}
```

`Mockito.when()` 대신 `BDDMockito.given()`을 사용하면 given/when/then 구조가 자연스럽게 맞아떨어진다.
실무에서는 BDD 스타일을 표준으로 정해두는 팀이 많다.

### 📌 @ParameterizedTest — 다양한 입력값 테스트

```java
/**
 * 유효하지 않은 비밀번호 케이스가 여럿이면 @ParameterizedTest로 묶는다.
 * 테스트 코드 중복을 줄이면서도 각 케이스를 명확히 확인할 수 있다.
 */
@ParameterizedTest(name = "비밀번호 \"{0}\" 는 유효하지 않다")
@ValueSource(strings = {"", " ", "short", "nouppercase1!", "NOLOWERCASE1!"})
@DisplayName("유효하지 않은 비밀번호 목록 테스트")
void register_invalidPasswords_throwsException(String invalidPassword) {
    RegisterRequest request = new RegisterRequest("chan@test.com", invalidPassword);
    given(memberRepository.existsByEmail(anyString())).willReturn(false);

    assertThatThrownBy(() -> memberService.register(request))
        .isInstanceOf(InvalidPasswordException.class);
}

// CSV 소스를 활용한 복합 입력 테스트
@ParameterizedTest
@CsvSource({
    "chan@test.com, pass123!, true",
    "chan@gmail.com, pass123!, true",
    ", pass123!, false",
    "chan@test.com, , false"
})
@DisplayName("이메일/비밀번호 조합별 유효성 검증")
void register_variousInputCombinations(String email, String password, boolean shouldSucceed) {
    // ...
}
```

### 📌 @Nested — 테스트 구조화

```java
@ExtendWith(MockitoExtension.class)
class MemberServiceTest {

    @Nested
    @DisplayName("회원가입(register)")
    class RegisterTest {

        @Test
        @DisplayName("정상 요청 → 성공")
        void success() { /* ... */ }

        @Test
        @DisplayName("중복 이메일 → DuplicateEmailException")
        void duplicateEmail() { /* ... */ }

        @Nested
        @DisplayName("비밀번호 정책")
        class PasswordPolicy {
            @Test void tooShort() { /* ... */ }
            @Test void noSpecialChar() { /* ... */ }
        }
    }

    @Nested
    @DisplayName("로그인(login)")
    class LoginTest {
        @Test void success() { /* ... */ }
        @Test void emailNotFound() { /* ... */ }
        @Test void wrongPassword() { /* ... */ }
    }
}
```

`@Nested`로 구조화하면 IDE의 테스트 결과 트리에서 계층 구조가 시각적으로 보여 가독성이 크게 높아진다.

### 📌 좋은 테스트 이름 짓기

```java
// ❌ 나쁜 이름 — 무엇을 검증하는지 알 수 없음
@Test void test1() {}
@Test void registerTest() {}

// ✅ 좋은 이름 — 조건과 결과가 명확
@Test
@DisplayName("이미 가입된 이메일로 회원가입 요청 시 DuplicateEmailException이 발생한다")
void register_whenEmailAlreadyExists_throwsDuplicateEmailException() {}

// 메서드명 컨벤션: {메서드}_{조건}_{기대결과}
void login_whenPasswordWrong_throwsInvalidPasswordException() {}
void findById_whenIdNotExists_throwsMemberNotFoundException() {}
```

---

## 12. 안티패턴 & 체크리스트

### 📌 자주 하는 실수 5가지

**1. 구현 세부사항을 테스트한다**
private 메서드나 내부 필드를 리플렉션으로 접근해서 검증하는 것이다.
리팩토링 시 구현이 바뀌면 테스트가 깨진다.
public 인터페이스(입력 → 출력)만 검증해야 한다.

**2. 하나의 테스트에 여러 동작을 검증한다**
`register()` 호출 후 `login()`, 이메일 전송까지 한 테스트에서 검증하면 실패 원인이 불명확해진다.
테스트 1개 = 동작 1개가 원칙이다.

**3. assertion이 없는 테스트를 작성한다**
메서드 호출만 하고 아무것도 검증하지 않으면 항상 Green이므로 아무 의미가 없다.
반드시 `assertThat()` 또는 `then().should()`로 예상 결과를 명시적으로 검증해야 한다.

**4. 테스트 간 의존성이 생긴다**
test1에서 생성한 데이터를 test2가 사용하면 테스트 순서에 따라 결과가 달라진다.
`@BeforeEach`로 각 테스트마다 독립적인 상태를 설정해야 한다.

**5. 과도하게 Mocking한다**
테스트 대상 자체(SUT)까지 Mock으로 만들거나, 모든 것을 stubbing하면 실제 로직을 검증하지 못한다.
SUT의 직접 의존성만 Mock하고, 값 객체(VO, DTO)는 실제 객체를 사용한다.

### 📌 테스트 작성 전 체크리스트

- `@DisplayName`이 "무엇을 → 어떤 조건에서 → 어떤 결과"를 한 문장으로 설명하는가?
- 테스트를 실행했을 때 처음에 반드시 Red(실패)인가? 처음부터 Green이면 테스트를 의심해야 한다.
- 하나의 테스트에 하나의 동작(행위)만 검증하는가?
- given/when/then 각 구간이 주석 없이도 구분되는가?
- 외부 의존성(DB, HTTP, 파일)은 Mock/Stub으로 격리되어 있는가?
- 통합 테스트가 단위 테스트로 충분히 커버 가능한 내용을 중복 검증하지 않는가?
- 경계값(빈 문자열, null, 최대/최솟값, 중복값)이 별도 테스트 케이스로 존재하는가?

---

## 13. 정리

- TDD는 테스트 기법이 아니라 설계 방법론이다. 테스트를 먼저 쓰면 API 설계가 먼저 정해진다.
- Red → Green → Refactor 사이클을 5~10분 단위로 반복한다. Refactor는 모든 테스트가 Green일 때만 수행한다.
- 테스트 피라미드 원칙에 따라 단위 테스트를 가장 많이, 통합 테스트를 가장 적게 작성한다.
- 가장 가치 있는 테스트는 경계값과 예외 케이스다. 정상 케이스는 구현하다 보면 자연스럽게 동작하지만 경계값은 반드시 명시적으로 검증해야 한다.
- 테스트 코드가 잘 작성되면 팀원이 테스트만 읽어도 시스템의 동작 방식을 이해할 수 있는 살아있는 명세서(Living Documentation)가 된다.

---

## 14. 참고 자료

- [Spring Boot Testing 공식 문서](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.testing)
- [JUnit 5 User Guide](https://junit.org/junit5/docs/current/user-guide/)
- [Mockito 공식 Javadoc](https://javadoc.io/doc/org.mockito/mockito-core/latest/org/mockito/Mockito.html)
- [AssertJ 공식 문서](https://assertj.github.io/doc/)
- [Spring Security Test 공식 문서](https://docs.spring.io/spring-security/reference/servlet/test/index.html)

---

> 출처: Claude Desktop 대화 (2026-04-13)
