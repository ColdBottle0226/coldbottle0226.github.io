# 📗 1. 서블릿 컨테이너 & 스프링 컨테이너 개념

---

스프링 기반 웹 애플리케이션은 독립적으로 동작하지 않고,  
**서블릿 컨테이너 위에서 스프링 컨테이너가 구동되는 이중 구조**를 가진다.

> 📌 구조  
> **Servlet Container → Spring Container → Application**

![서블릿-스프링-구조](./images/servletcontainer/container-structure.png)

**스프링 컨테이너**는 객체 생명주기와 구성을 관리하고,  
**서블릿 컨테이너**는 HTTP 요청과 응답을 처리한다.

---

## 📌 서블릿 컨테이너(Servlet Container)

서블릿 컨테이너는 서블릿을 관리하는 **런타임 환경**이다.

대표적인 구현체로 **Tomcat**이 있다.

웹 서버와 통신하여 HTTP 요청을 받고, 서블릿을 실행한 뒤 응답을 반환한다.

### 주요 역할

- **네트워크 통신**
  - Socket 관리, 요청 수신, 응답 전송
- **서블릿 생명주기 관리**
  - 생성 → 초기화 → 실행 → 소멸
- **멀티스레딩**
  - 요청마다 스레드 할당

> Tomcat과 같은 WAS는 Java 파일을 컴파일하여 Class로 만들고,
> 메모리에 적재해 Servlet 객체를 생성한다.

---

## 📌 스프링 컨테이너(Spring Container / IoC Container)

스프링 컨테이너는 **IoC(Inversion of Control)** 와  
**DI(Dependency Injection)** 기반으로 객체를 관리한다.

즉, 객체 생성과 흐름 제어를 프레임워크가 담당한다.

### 구현체

- `BeanFactory`
- `ApplicationContext` (대표 구현체)

---

# 📗 2. 스프링 컨테이너의 역할과 기능

---

스프링 컨테이너는 애플리케이션의 **빈 생성, 관리, 주입**을 담당한다.

## 📌 주요 역할

### 1️⃣ 의존성 주입 (DI)

- 객체 간 결합도 감소
- 실행 시점에 의존관계 결정

### 2️⃣ 빈 관리

- 기본적으로 **싱글톤(Singleton)** 관리
- 메모리 효율 극대화

### 3️⃣ 구조적 특징

- **BeanFactory**
  - 기본 IoC 컨테이너
- **ApplicationContext**
  - i18n
  - 이벤트 발행
  - 리소스 로딩
  - 엔터프라이즈 기능 제공

![ApplicationContext 구조](./images/servletcontainer/applicationcontext.png)

---

# 📗 3. 서블릿 컨테이너의 역할과 기능

---

서블릿 컨테이너는 WAS의 핵심 구성요소로,
HTTP 요청을 받아 서블릿을 실행하고 응답을 반환한다.

## 📌 주요 기능

### 1️⃣ 생명주기 관리

- 서블릿 생성 / 초기화 / 호출 / 소멸 관리

### 2️⃣ 멀티스레딩

- 요청마다 별도 스레드 할당
- 동시 요청 처리

---

## 📌 HTTP 요청 처리 과정

![HTTP 흐름](./images/servletcontainer/http-flow.png)

### 처리 단계

1. 브라우저 → Web Server 요청
2. Web Server → WAS 전달
3. WAS → Servlet Container 전달
4. 서블릿 인스턴스 존재 여부 확인
5. 없으면 생성 및 `init()`
6. `service()` 실행
7. 결과 반환

---

# 📗 4. 스프링 컨테이너와 서블릿 컨테이너 연동

---

전통적인 Spring MVC 구조는 `web.xml`에서 시작된다.

여기서 두 컨테이너의 계층 구조가 결정된다.

---

## 📌 동작 단계

### 1️⃣ 서블릿 컨테이너 구동

- WAS 실행
- `WEB-INF/web.xml` 로드

### 2️⃣ Root Container 생성

- `ContextLoaderListener` 실행
- Root ApplicationContext 생성

#### 💡 ContextLoaderListener

- `ServletContextListener` 구현체
- Root Context 생성 담당

> ApplicationContext는 한 번만 초기화된다.

---

### 3️⃣ 스프링 컨테이너 구동

- ApplicationContext 설정 로드
- 비즈니스 로직 / DAO / VO 생성

---

### 4️⃣ DispatcherServlet 생성

- Front Controller 역할
- 최초 1회 생성

---

### 5️⃣ HandlerMapping 처리

- 요청 URL 분석
- 적절한 Controller 검색

---

### 6️⃣ Controller 실행

- 메서드 호출
- ModelAndView 반환

---

## 📌 전체 구동 흐름 요약

1. Tomcat 실행 → `web.xml` 로드
2. ContextLoaderListener → Root Context 생성
3. DispatcherServlet → Servlet Context 생성
4. 클라이언트 요청 → Controller 실행

![전체 흐름](./images/servletcontainer/full-flow.png)

---

# 📚 참고 자료

- https://sigridjin.medium.com/servletcontainer와-springcontainer는-무엇이-다른가-626d27a80fe5
- https://server-engineer.tistory.com/253
