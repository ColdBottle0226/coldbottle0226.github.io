---
title: "NestJS 개념 정리 - Controller, Provider, Module, Middleware"
date: 2026-03-17 09:00:00 +0900
categories: [NestJS, Basic]
tags: [NestJS, TypeScript, Controller, Provider, Module, Middleware, DI, IoC]
---

## 📗 1. 개요

---

NestJS를 처음 배울 때 가장 먼저 만나는 개념이 Controller, Provider, Module, Middleware다. 이 4가지는 독립적으로 존재하지 않고 서로 역할을 분담하면서 하나의 요청-응답 사이클을 완성한다. 이번 글에서는 공식문서 기반으로 각 개념을 정리한다.

### 📌 전체 역할 구조

| 개념 | 역할 | 핵심 데코레이터 |
|------|------|----------------|
| Controller | HTTP 요청 수신 → 라우팅 → 응답 반환 | `@Controller()`, `@Get()`, `@Post()` |
| Provider | 비즈니스 로직 처리 (Service, Repository 등) | `@Injectable()` |
| Module | 관련 컴포넌트 묶음 + DI 컨텍스트 정의 | `@Module()` |
| Middleware | 라우트 핸들러 이전에 실행되는 함수 | `NestMiddleware` |

> 💡 요청이 들어오면 `Middleware → Controller → Provider` 순서로 처리된다.
> Module은 이 전체를 조직하는 컨테이너다.

### 📌 모듈 구조 한눈에 보기

![NestJS 모듈 구조](/assets/images/nestjs-core-concepts/nestjs-module-structure.svg)

---

## 📗 2. Controller

---

컨트롤러는 들어오는 요청을 처리하고 클라이언트에 응답을 반환하는 역할을 한다. 라우팅 메커니즘이 어떤 컨트롤러가 요청을 처리할지 결정한다.

### 📌 기본 구조

```typescript
// cats.controller.ts
import {
  Controller, Get, Post, Put, Delete,
  Body, Param, Query
} from '@nestjs/common';
import { CreateCatDto } from './dto/create-cat.dto';

@Controller('cats') // ← '/cats' 경로 prefix
export class CatsController {

  @Post()
  create(@Body() createCatDto: CreateCatDto) {
    return 'This action adds a new cat';
  }

  @Get()
  findAll(@Query('breed') breed: string) {
    return `All cats, breed: ${breed}`;
  }

  @Get(':id')                      // ← GET /cats/:id
  findOne(@Param('id') id: string) {
    return `Cat #${id}`;
  }

  @Put(':id')
  update(@Param('id') id: string, @Body() updateDto: any) {
    return `Update cat #${id}`;
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return `Remove cat #${id}`;
  }
}
```

### 📌 요청 데이터 추출 데코레이터

| 데코레이터 | 매핑 | 설명 |
|---|---|---|
| `@Req()` | `req` | 전체 요청 객체 |
| `@Body(key?)` | `req.body[key]` | 요청 바디 |
| `@Param(key?)` | `req.params[key]` | URL 경로 파라미터 |
| `@Query(key?)` | `req.query[key]` | 쿼리 스트링 |
| `@Headers(name?)` | `req.headers[name]` | 요청 헤더 |
| `@Ip()` | `req.ip` | 클라이언트 IP |
| `@Res()` | `res` | 응답 객체 (Library-specific mode 진입) |

### 📌 DTO는 interface가 아닌 class로

TypeScript interface는 컴파일 후 사라진다. Pipe 같은 기능이 런타임에 metatype에 접근할 때 class만 유효하다.

```typescript
// create-cat.dto.ts
export class CreateCatDto {
  name: string;
  age: number;
  breed: string;
}
```

### 📌 응답 처리 방식 비교

| 방식 | 설명 | 주의 |
|------|------|------|
| Standard (권장) | 객체/배열 반환 시 자동 JSON 직렬화. 기본 200, POST는 201 | Interceptor, `@HttpCode()` 등 NestJS 기능과 완전 호환 |
| Library-specific | `@Res()` 주입 후 `res.json()`, `res.send()` 직접 호출 | 플랫폼 종속, Interceptor 비활성화 |

> 💡 `@Res({ passthrough: true })`를 쓰면 쿠키/헤더 세팅은 직접 하면서 응답 처리는 NestJS에 위임할 수 있다.

```typescript
@Get()
findAll(@Res({ passthrough: true }) res: Response) {
  res.status(HttpStatus.OK); // 헤더만 직접 설정
  return [];                 // 응답 처리는 NestJS가
}
```

---

## 📗 3. Provider

---

프로바이더는 NestJS의 핵심 개념이다. 서비스, 레포지토리, 팩토리, 헬퍼 등 많은 기본 클래스들이 프로바이더로 취급될 수 있다. 핵심 아이디어는 의존성으로 주입(inject)될 수 있다는 것이며, 이 "배선" 작업은 Nest 런타임 시스템이 처리한다.

### 📌 서비스 정의

```typescript
// cats.service.ts
import { Injectable } from '@nestjs/common';
import { Cat } from './interfaces/cat.interface';

/**
 * @Injectable() 데코레이터가 핵심.
 * Nest IoC 컨테이너가 이 클래스를 관리할 수 있도록 메타데이터를 부착한다.
 * 다른 클래스에서 constructor를 통해 주입받을 수 있게 된다.
 */
@Injectable()
export class CatsService {
  private readonly cats: Cat[] = [];

  create(cat: Cat) {
    this.cats.push(cat);
  }

  findAll(): Cat[] {
    return this.cats;
  }
}
```

### 📌 의존성 주입 (DI)

```typescript
// cats.controller.ts
@Controller('cats')
export class CatsController {
  /**
   * TypeScript 타입 정보를 기반으로 Nest가 자동으로 CatsService를 주입한다.
   * private 키워드로 선언과 초기화를 한 줄에 처리.
   */
  constructor(private catsService: CatsService) {}

  @Get()
  async findAll(): Promise<Cat[]> {
    return this.catsService.findAll();
  }
}
```

### 📌 주입 방식 비교

| 방식 | 코드 | 권장 여부 |
|------|------|-----------|
| Constructor-based | `constructor(private svc: Service) {}` | ✅ 권장 - 의존성이 명확히 드러남 |
| Property-based | `@Inject('TOKEN') private svc: Service` | 상속 계층이 깊을 때만 사용 |

### 📌 Provider Scope (생명주기)

프로바이더는 기본적으로 앱 라이프사이클과 동일한 수명을 가진다. 앱 부트스트랩 시 인스턴스화되고 종료 시 소멸된다.

| Scope | 설명 | 사용 사례 |
|-------|------|-----------|
| `DEFAULT` | 싱글톤 (앱 전체에서 동일 인스턴스) | 대부분의 서비스 |
| `REQUEST` | HTTP 요청마다 새 인스턴스 생성 | 요청별 캐싱, 멀티테넌시 |
| `TRANSIENT` | 주입받는 곳마다 새 인스턴스 생성 | 상태 없는 유틸리티 |

### 📌 선택적 프로바이더

```typescript
import { Injectable, Optional, Inject } from '@nestjs/common';

@Injectable()
export class HttpService<T> {
  /**
   * HTTP_OPTIONS가 없어도 에러가 발생하지 않는다.
   * 설정 객체처럼 "있으면 쓰고 없으면 기본값" 패턴에 유용하다.
   */
  constructor(@Optional() @Inject('HTTP_OPTIONS') private httpClient: T) {}
}
```

---

## 📗 4. Module

---

모듈은 `@Module()` 데코레이터로 어노테이션된 클래스다. 모든 Nest 앱은 최소 하나의 루트 모듈(AppModule)을 가지며, 이것이 Nest가 애플리케이션 그래프를 구성하는 시작점이 된다.

### 📌 @Module() 데코레이터 속성

| 속성 | 설명 |
|------|------|
| `providers` | 이 모듈에서 인스턴스화될 프로바이더 목록 |
| `controllers` | 이 모듈에서 인스턴스화될 컨트롤러 목록 |
| `imports` | 이 모듈에 필요한 프로바이더를 export하는 모듈 목록 |
| `exports` | 다른 모듈에서 사용할 수 있도록 공개하는 프로바이더 목록 |

### 📌 Feature Module (기능 모듈)

```
src/
├── cats/
│   ├── dto/
│   │   └── create-cat.dto.ts
│   ├── interfaces/
│   │   └── cat.interface.ts
│   ├── cats.controller.ts
│   ├── cats.service.ts
│   └── cats.module.ts   ← Feature Module
├── app.module.ts        ← Root Module
└── main.ts
```

```typescript
// cats/cats.module.ts
import { Module } from '@nestjs/common';
import { CatsController } from './cats.controller';
import { CatsService } from './cats.service';

@Module({
  controllers: [CatsController],
  providers: [CatsService],
  // exports에 추가해야 다른 모듈에서 CatsService를 주입받을 수 있다
})
export class CatsModule {}

// app.module.ts
import { Module } from '@nestjs/common';
import { CatsModule } from './cats/cats.module';

@Module({
  imports: [CatsModule],
})
export class AppModule {}
```

### 📌 Shared Module (공유 모듈)

Nest에서 모듈은 기본적으로 싱글톤이다. 동일한 Provider 인스턴스를 여러 모듈에서 공유할 수 있다.

```typescript
@Module({
  controllers: [CatsController],
  providers: [CatsService],
  exports: [CatsService], // ← 이제 CatsModule을 import하는 모든 모듈이 CatsService 사용 가능
})
export class CatsModule {}
```

> 💡 exports 없이 각 모듈이 직접 등록하면 별도 인스턴스가 생겨 메모리 낭비 + 상태 불일치가 발생할 수 있다. exports를 통한 공유가 정석이다.

### 📌 Global Module

```typescript
import { Module, Global } from '@nestjs/common';

/**
 * DB 연결, 공통 헬퍼처럼 어디서나 필요한 것들에만 사용한다.
 * 남발하면 모듈 간 결합도가 높아져 유지보수가 어려워진다.
 */
@Global()
@Module({
  providers: [CatsService],
  exports: [CatsService],
})
export class CatsModule {}
// → 이 모듈을 import하지 않아도 CatsService를 바로 주입받을 수 있다
```

### 📌 Dynamic Module

런타임에 설정을 받아 동적으로 프로바이더를 생성해야 할 때 사용한다. `TypeOrmModule.forRoot()`, `ConfigModule.forRoot()` 같은 라이브러리들이 이 패턴으로 만들어져 있다.

```typescript
// database.module.ts
import { Module, DynamicModule } from '@nestjs/common';

@Module({
  providers: [Connection],
  exports: [Connection],
})
export class DatabaseModule {
  /**
   * 정적 메서드로 DynamicModule을 반환한다.
   * 반환 객체가 @Module()의 기본 메타데이터를 extend(오버라이드 아님)한다.
   */
  static forRoot(entities = [], options?): DynamicModule {
    const providers = createDatabaseProviders(options, entities);
    return {
      module: DatabaseModule,
      providers: providers,
      exports: providers,
    };
  }
}

// 사용 예
@Module({
  imports: [DatabaseModule.forRoot([User, Product])],
})
export class AppModule {}
```

---

## 📗 5. Middleware

---

미들웨어는 라우트 핸들러보다 먼저 호출되는 함수다. request, response 객체와 `next()` 함수에 접근할 수 있다. Nest 미들웨어는 기본적으로 Express 미들웨어와 동일하다.

미들웨어에서 할 수 있는 것: 임의 코드 실행, request/response 객체 변경, 요청-응답 사이클 종료, 스택의 다음 미들웨어 호출.

### 📌 클래스 기반 미들웨어

```typescript
// common/middleware/logger.middleware.ts
import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

/**
 * @Injectable()이 붙으므로 DI가 가능하다.
 * → 같은 모듈의 Service를 constructor로 주입받을 수 있다.
 */
@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    console.log(`[${req.method}] ${req.url}`);
    next(); // ← 반드시 호출해야 한다. 안 하면 요청이 멈춰버린다.
  }
}
```

### 📌 함수형 미들웨어

```typescript
// 의존성이 없는 단순한 미들웨어라면 함수로 작성하는 것이 더 간결하다.
import { Request, Response, NextFunction } from 'express';

export function logger(req: Request, res: Response, next: NextFunction) {
  console.log(`Request...`);
  next();
}
```

### 📌 미들웨어 적용 방법

미들웨어는 `@Module()` 데코레이터 안에 넣을 수 없다. 모듈 클래스의 `configure()` 메서드를 통해 설정한다. 미들웨어를 포함하는 모듈은 반드시 `NestModule` 인터페이스를 구현해야 한다.

```typescript
// app.module.ts
import {
  Module, NestModule, MiddlewareConsumer, RequestMethod
} from '@nestjs/common';
import { LoggerMiddleware } from './common/middleware/logger.middleware';
import { CatsModule } from './cats/cats.module';
import { CatsController } from './cats/cats.controller';

@Module({
  imports: [CatsModule],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(LoggerMiddleware)        // 적용할 미들웨어
      .exclude(                       // 제외할 라우트 (선택)
        { path: 'cats', method: RequestMethod.POST },
        'cats/{*splat}',
      )
      .forRoutes(CatsController);     // 문자열, RouteInfo, Controller 모두 가능
  }
}
```

### 📌 미들웨어 적용 범위 비교

| 적용 방식 | 코드 | 설명 |
|---|---|---|
| 특정 경로 | `.forRoutes('cats')` | '/cats' 경로에만 |
| 경로 + 메서드 | `.forRoutes({ path: 'cats', method: RequestMethod.GET })` | GET /cats에만 |
| 컨트롤러 단위 | `.forRoutes(CatsController)` | 컨트롤러 전체 라우트에 (권장) |
| 복수 미들웨어 | `.apply(cors(), helmet(), logger)` | 순서대로 실행 |
| 전역 (main.ts) | `app.use(logger)` | 함수형만 가능, DI 불가 |

> 💡 전역 미들웨어(`app.use()`)에서는 DI 컨테이너에 접근할 수 없다. 의존성이 필요한 미들웨어는 `.forRoutes('*')`를 써야 한다.

---

## 📗 6. 정리

---

![NestJS 요청 처리 흐름](/assets/images/nestjs-core-concepts/nestjs-request-lifecycle.svg)

- Controller는 HTTP 요청을 받아 라우팅하고, 실제 로직은 Provider에 위임한다.
- Provider는 `@Injectable()`로 등록되며, DI를 통해 자동으로 주입된다. 기본 싱글톤.
- Module은 Controller + Provider를 하나의 단위로 묶는다. `exports`를 통해 Provider를 외부에 공개할 수 있다.
- Middleware는 route handler 이전에 실행되며, `@Module()` 밖에서 `configure()`로 등록한다.
- 이 4가지가 조합되어 `요청 → Middleware → Controller → Provider → 응답` 흐름이 완성된다.

---

## 참고 자료

- 공식문서 - Controllers: <https://docs.nestjs.com/controllers>
- 공식문서 - Providers: <https://docs.nestjs.com/providers>
- 공식문서 - Modules: <https://docs.nestjs.com/modules>
- 공식문서 - Middleware: <https://docs.nestjs.com/middleware>
- 공식문서 - Injection Scopes: <https://docs.nestjs.com/fundamentals/injection-scopes>
