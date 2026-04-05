---
title: "AI 에이전트는 이렇게 만든다 - LangChain 03장 에이전트 개발 기초"
date: 2026-03-15 14:00:00 +0900
categories: [LangChain]
tags: [LangChain, Agent, Tool, Memory, Middleware, StructuredOutput, Python, OpenAI]
---

## 📗 1. 개요

---

02장에서 모델 호출과 기본기를 익혔다면, 03장에서는 본격적으로 "동작하는 에이전트"를 만든다. 단순히 질문에 답하는 챗봇이 아니라, 외부 도구를 직접 호출하고 결과를 종합하며 업무를 수행하는 에이전트다.

이번 글에서는 03장의 4개 섹션인 에이전트 기초(Tool), 메모리 기반 에이전트, Built-in 미들웨어, 구조화된 답변 생성까지 코드와 다이어그램을 함께 정리한다.

### 📌 03장 전체 구조

| 섹션 | 핵심 개념 | 구현 요소 |
| --- | --- | --- |
| 3-1) 에이전트 기초 | @tool + create_agent | tool_calls, ToolMessage, 시스템 프롬프트 |
| 3-2) 메모리 기반 에이전트 | checkpointer + thread_id | InMemorySaver, PostgresSaver |
| 3-3) Built-in 미들웨어 | 실행 흐름 중간 개입 | PII, TodoList, HITL, Emulator |
| 3-4) 구조화된 답변 생성 | response_format | ToolStrategy, structured_response |

---

## 📗 2. 에이전트 기초 (3-1)

---

에이전트의 진정한 가치는 유창한 언어 구사력이 아닌, 목적을 달성하는 실행력(Action)에 있다. 기존의 챗봇이 그럴듯한 문장을 생성하는 데 그쳤다면, 에이전트는 실제 도구를 호출하여 객관적인 데이터에 기반한 답변을 도출한다.

### 📌 왜 Tool이 필요한가

LLM은 학습이 완료된 시점(Knowledge Cut-off) 과거의 지식만 가지고 있다. 회사 내부 DB나 실시간으로 변하는 주식, 날씨 같은 외부 API 응답은 당연히 알지 못한다. "현재 날씨", "오늘의 베스트셀러" 같은 질문을 받으면 대답을 회피하거나 할루시네이션을 지어낸다.

Tool은 이 치명적인 약점을 완벽하게 보완한다. 모델이 스스로 판단해 "이 질문은 내 지식으론 부족하니 날씨 검색 도구를 써야겠다"라고 결정하고, 그 도구가 물어다 준 신선한 데이터를 바탕으로 최종 답변을 생성하게 만든다.

### 📌 Tool 구현 방법

랭체인에서 Tool은 기본적으로 실행 가능한 파이썬 함수 형태로 만든다. 모델이 도구를 올바르게 선택하려면 다음 세 가지 정보가 반드시 포함되어야 한다.

- 함수 이름: 도구의 직관적인 명칭
- 타입 힌트 (Type Hints): 입력값과 출력값의 타입
- 독스트링 (Docstring): 도구가 언제 쓰이고 어떤 역할을 하는지에 대한 상세한 설명

이렇게 정교하게 작성한 함수에 `@tool` 데코레이터를 달면, 단순한 함수를 넘어 LLM과 실행기(런타임) 사이의 명확한 계약서가 완성된다.

```python
from langchain.tools import tool

@tool
def get_weather(location: str) -> str:
    """특정 지역의 날씨 정보를 제공합니다."""
    return f"{location}의 날씨는 맑고, 영하 2도입니다"
```

> 💡 도구 함수를 작성할 때 이름이나 설명이 모호하다면 어처구니없는 오작동이 발생할 수 있다. 날씨를 묻는데 계산기 도구를 호출하거나, 문자를 넣어야 할 곳에 숫자를 넣어 실행 에러가 날 수 있다. 이름, 타입 힌팅, 독스트링을 충분히 친절하게 설계해야 한다.

### 📌 실습 1: 날씨 에이전트

**1단계: Tool 정의하기**

```python
from langchain.tools import tool

@tool
def get_weather(location: str) -> str:
    """특정 지역의 날씨 정보를 제공합니다."""
    return f"{location}의 날씨는 맑고, 영하 2도입니다"
```

**2단계: 모델 초기화 및 에이전트 생성**

`create_agent`를 사용할 때는 두 가지 핵심 인자를 전달해야 한다. 에이전트의 판단과 추론을 담당할 모델 객체(model)와, 에이전트가 꺼내 쓸 수 있는 도구 리스트(tools)다.

```python
from langchain.agents import create_agent
from langchain.chat_models import init_chat_model

model = init_chat_model("gpt-5-nano")
agent = create_agent(model, tools=[get_weather])
```

**3단계: 에이전트 실행**

`invoke()`를 호출할 때는 `"messages"` 키에 대화 흐름을 리스트 형태로 담아 보낸다. 에이전트는 이 메시지 목록을 받아 사용자의 의도를 파악하고, 필요하다면 도구를 꺼내 실행한다. 모든 과정이 끝나면 실행 결과가 포함된 전체 메시지 리스트를 반환하는데, 가장 마지막 메시지(`[-1]`)가 최종 답변이다.

```python
result = agent.invoke({
    "messages": [
        {"role": "user", "content": "서울 날씨 어때요?"}
    ]
})
print(result["messages"][-1].content)
```

```
현재 서울은 맑고 기온은 영하 2도예요. 아주 추우니 두꺼운 옷, 코트와 목도리 챙기세요.
```

### 📌 에이전트 실행 흐름 (tool_calls & ToolMessage)

에이전트를 실행하고 나면 결과값 안에 `messages` 리스트가 담겨 온다. 이 리스트는 단순한 대화 기록이 아니라 에이전트의 행동이 낱낱이 기록된 실행 로그다.

![에이전트 실행 흐름](/assets/images/langchain-03/agent_execution_flow.svg)

```python
{
  'messages': [
    # 1. 사용자의 질문 (입력)
    HumanMessage(content='서울 날씨 어때요?'),

    # 2. 에이전트의 판단: "도구가 필요해!" (도구 호출 결정)
    AIMessage(content='', tool_calls=[{'name': 'get_weather', 'args': {'location': '서울'}}]),

    # 3. 도구 실행 결과: "함수를 실행해서 정보를 가져왔어"
    ToolMessage(content='서울의 날씨는 맑고, 영하 2도입니다', name='get_weather'),

    # 4. 에이전트의 최종 답변: "가져온 정보를 바탕으로 대답할게"
    AIMessage(content='현재 서울은 맑고 기온은 영하 2도예요. 외출하실 때 옷차림에 신경 쓰셔야겠네요!')
  ]
}
```

실행 흐름은 세 단계로 정리된다.

1. 계획 수립 (tool_calls): 모델이 도구가 필요하다고 판단하면 `AIMessage` 안에 "이 도구를 이렇게 실행해 줘"라는 구체적인 계획(tool_calls)을 남긴다. 이때 자연어 텍스트 답변은 비어 있다.
2. 실제 실행 (ToolMessage): 런타임 환경이 실제 파이썬 함수(`get_weather`)를 실행하고, 반환값을 `ToolMessage`에 담아 대화 기록에 추가한다.
3. 최종 답변 생성: 모델이 `ToolMessage`를 읽고 사용자에게 전달할 최종 자연어 답변을 완성한다.

> 💡 Tool을 호출할지 말지, 어떤 Tool을 호출할지, 호출할 때 필요한 인자는 누가 결정하는가? 정답은 Agent 객체 속에 있는 언어 모델이다. 모델이 본인의 과거 지식으로 무턱대고 대답하는 대신, 스스로 판단하여 도구를 호출하고 그 반환값을 근거로 최종 답변을 조립한다.

### 📌 실습 2: 시스템 프롬프트로 도구 사용 강제하기

모델에게 여러 개의 도구를 쥐여주면 질문의 성격에 맞춰 알아서 도구를 선택한다. 그런데 LLM은 "42 + 3 * 23"처럼 단순한 수식을 받았을 때 도구를 사용하지 않고 직접 답변을 생성해버리는 경우가 있다. 이럴 때 시스템 프롬프트로 행동 지침을 엄격하게 잡아주는 것이 가장 확실한 해결책이다.

```python
from langchain.tools import tool

@tool
def add(a: int, b: int) -> int:
    """`a`와 `b` 덧셈."""
    return a + b

@tool
def multiply(a: int, b: int) -> int:
    """`a`와 `b` 곱셈."""
    return a * b

@tool
def divide(a: int, b: int) -> float:
    """`a`와 `b` 나눗셈."""
    return a / b

tools = [add, multiply, divide]

agent = create_agent(
    model,
    tools,
    system_prompt="당신은 유능한 수학 선생님입니다. 추측하지 말고, 계산 시 모든 단계에서 tool들을 이용하시오."
)
```

시스템 프롬프트에 금지 사항("추측하지 마십시오")과 필수 행동("반드시 tool을 이용")을 명확히 새겨두면, 모델은 확률적 추측을 멈추고 도구를 꺼내 든다.

```python
result = agent.invoke(
    {"messages": [{"role": "user", "content": "42 + 3 * 23은 뭔가요?"}]},
)
print(result)
```

```python
{
  'messages': [
    HumanMessage(content='42 + 3 * 23은 뭔가요?'),

    # 첫 번째 판단: "먼저 곱셈부터 해야겠어"
    AIMessage(content='', tool_calls=[{'name': 'multiply', 'args': {'a': 3, 'b': 23}}]),
    ToolMessage(content='69', name='multiply'),

    # 두 번째 판단: "이제 나온 결과에 42를 더하자"
    AIMessage(content='', tool_calls=[{'name': 'add', 'args': {'a': 42, 'b': 69}}]),
    ToolMessage(content='111', name='add'),

    # 최종 응답
    AIMessage(content='정답은 111입니다. 3 * 23 = 69를 먼저 계산한 뒤, 42를 더해 111이 되었습니다.')
  ]
}
```

### 📌 실습 3: 외부 API 활용 (알라딘 베스트셀러)

실무 도구를 작성할 때는 세 가지 원칙을 반드시 지킨다.

| 원칙 | 내용 |
| --- | --- |
| 보안 | API 키는 `os.getenv()` 환경변수에서 주입, 절대 하드코딩 금지 |
| 토큰 다이어트 | API 전체 응답을 그대로 넘기지 말고, 모델에게 필요한 핵심 필드만 추출 |
| 우아한 실패 | 에러 시 파이썬 예외를 뿜지 않고, 에러 메시지를 문자열로 반환 |

```python
import requests
from typing import Any, Dict, List, Union
from langchain.tools import tool

@tool
def fetch_aladin_bestseller_top10() -> Union[List[Dict[str, Any]], str]:
    """
    현재 시점의 알라딘 베스트셀러 Top 10 도서 목록을 조회하여 반환한다.
    반환값은 도서 정보가 담긴 딕셔너리의 리스트이거나, 호출 실패 시 에러 메시지(문자열)이다.
    """
    try:
        ttb_key = os.getenv("ALADIN_TTB_KEY")
        url = "http://www.aladin.co.kr/ttb/api/ItemList.aspx"
        params = {
            "ttbkey": ttb_key,
            "QueryType": "Bestseller",
            "MaxResults": 10,
            "start": 1,
            "SearchTarget": "Book",
            "output": "js",
            "Version": "20131101",
        }
        # API 호출 (타임아웃 10초 설정으로 무한 대기 방지)
        resp = requests.get(url, params=params, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        # 토큰 다이어트: 전체 응답 중 도서 목록 10개만 슬라이싱하여 반환
        return data.get("item", [])[:10]
    except Exception as e:
        # 우아한 실패: 에러를 텍스트로 반환
        return f"API 호출 중 오류가 발생하여 베스트셀러 정보를 가져오지 못했습니다. 원인: {str(e)}"
```

```python
agent = create_agent(model, tools=[fetch_aladin_bestseller_top10])
response = agent.invoke(
    {"messages": [{"role": "user", "content": "지금 알라딘 베스트셀러 1위부터 3위까지 알려줘."}]}
)
print(response["messages"][-1].content)
```

```
다음은 현재 알라딘 베스트셀러 Top 10(2025-11-05 기준) 목록입니다.
1) 요츠바랑! 16 — 아즈마 키요히코
2) 트렌드 코리아 2026 — 김난도 외
3) 멜론은 어쩌다 — 아밀
```

---

## 📗 3. 메모리 기반 에이전트 (3-2)

---

도구를 사용하는 에이전트를 만들었어도, 멀티턴 대화 속에서 사용자의 상황과 제약 조건을 잊어버린다면 "동작은 하지만 쓸모는 없는" 시스템이 된다.

### 📌 단기 vs 장기 메모리

| 구분 | 설명 | 예시 |
| --- | --- | --- |
| 단기 메모리 | 하나의 대화 스레드(세션) 안에서만 맥락이 이어지는 기억 | ChatGPT 하나의 채팅방 |
| 장기 메모리 | 세션을 넘나들며 영구적으로 유지되어야 하는 핵심 기억 | ChatGPT 개인 맞춤 설정 |

메모리의 원리는 단순하다. 기본적으로 과거를 기억하지 못하는(Stateless) 언어 모델을 위해, 대화의 맥락(상태)을 시스템 외부 저장소에 기록해 두었다가, 다음 질문이 들어올 때 과거의 대화 내역을 모델에게 다시 던져주어 재사용하는 메커니즘이다.

### 📌 checkpointer와 thread_id

랭체인에서 단기 메모리 시스템은 두 가지 핵심 요소가 맞물려 돌아간다.

- checkpointer (기억 보관소): 에이전트가 나눈 대화 기록(상태, State)을 실제로 저장하고 필요할 때 다시 꺼내오는 저장소다.
- thread_id (기억의 열쇠): 수많은 사용자의 수많은 대화 기록 중, 지금 답변해야 할 사용자의 대화 기록이 어떤 것인지 식별하는 고유한 키 값이다.

핵심 규칙은 아주 단순하다.

- 같은 thread_id → "아, 아까 그 사람이구나!" 기존 대화 맥락을 이어서 답변
- 다른 thread_id → "처음 뵙겠습니다!" 완전히 새로운 대화 시작

아래 다이어그램은 thread_id를 열쇠 삼아 이전 대화 상태를 불러오고, 모델과 도구를 실행한 뒤, 새롭게 추가된 답변까지 포함하여 다시 체크포인터에 덮어쓰는 과정을 보여준다.

![checkpointer + thread_id 메모리 구조](/assets/images/langchain-03/checkpointer_thread_memory.svg)

### 📌 실습: 메모리 지원 기초 에이전트 구현

```python
from langchain.agents import create_agent
from langgraph.checkpoint.memory import InMemorySaver

# 1. InMemorySaver 객체를 생성하여 checkpointer 인자로 주입합니다.
agent = create_agent(
    model,
    tools,
    checkpointer=InMemorySaver(),
)
```

메모리가 탑재된 에이전트를 호출할 때는 기억의 열쇠인 `thread_id`를 `config` 딕셔너리를 통해 전달한다.

```python
# 2. config 딕셔너리에 thread_id를 "1"로 고정합니다.
cfg = {"configurable": {"thread_id": "1"}}

# 첫 번째 턴: 사용자 정보(이름) 전달
response = agent.invoke(
    {"messages": [{"role": "user", "content": "안녕하세요! 저는 Bloom AI의 Jay 입니다."}]},
    cfg,
)
print("[에이전트의 답변]:", response["messages"][-1].content)
```

```
[에이전트의 답변]: 안녕하세요, Jay님! Bloom AI와 함께하게 되어 반갑습니다.
```

두 번째 질문은 이름을 다시 말해주지 않아도 기억한다.

```python
# 두 번째 턴: 이전 맥락을 바탕으로 질문하기 (동일한 thread_id 사용)
response = agent.invoke(
    {"messages": [{"role": "user", "content": "방금 제가 제 이름을 뭐라고 했죠?"}]},
    cfg,
)
print("[에이전트의 답변]:", response["messages"][-1].content)
```

```
[에이전트의 답변]: Bloom AI의 Jay라고 알려주셨습니다.
```

thread_id를 변경하면 완전히 새로운 세션이 된다.

```python
# 세 번째 턴: thread_id를 "2"로 변경하여 완전히 새로운 채팅방을 엽니다.
response = agent.invoke(
    {"messages": [{"role": "user", "content": "지금까지 우리가 무슨 얘기를 나눴죠?"}]},
    {"configurable": {"thread_id": "2"}},  # 열쇠 변경!
)
print("[에이전트의 답변]:", response["messages"][-1].content)
```

```
[에이전트의 답변]: 지금까지의 대화 내용을 제가 직접 보지 못해서 답변드릴 수 없습니다.
```

### 📌 디버깅 팁: messages 배열로 누적 상태 확인하기

메모리가 제대로 쌓이고 있는지 확인하는 가장 확실한 방법은 `messages` 리스트 전체를 순회하며 출력해 보는 것이다.

```python
response = agent.invoke(
    {"messages": [{"role": "user", "content": "지금까지 무슨 얘기 나눴죠?"}]},
    {"configurable": {"thread_id": "1"}},
)

for i, msg in enumerate(response["messages"], start=1):
    print(f"--- Message {i} ({msg.type}) ---")
    print(msg.content)
    print()
```

```
--- Message 1 (human) ---
안녕하세요! 저는 Bloom AI의 Jay 입니다.

--- Message 2 (ai) ---
안녕하세요, Jay님! Bloom AI와 함께하게 되어 반갑습니다.

--- Message 3 (human) ---
방금 제가 제 이름을 뭐라고 했죠?

--- Message 4 (ai) ---
Bloom AI의 Jay라고 알려주셨습니다.
```

### 📌 InMemorySaver의 치명적 한계와 해결책

실습에 사용한 `InMemorySaver`는 데이터가 컴퓨터의 RAM에만 머물러 있어서 두 가지 문제가 있다.

- 서버 재시작 시 초기화: 코드를 수정해 서버를 재배포하거나 프로세스가 재시작되는 순간 모든 사용자의 대화 기억이 사라진다.
- 스케일아웃 시 끊김 현상: 서버를 3대로 늘렸을 때 로드밸런서가 첫 번째 질문을 A 서버로, 두 번째 질문을 B 서버로 보내면 B 서버의 RAM에는 앞선 대화 기록이 없다.

실무에서는 MySQL이나 PostgreSQL 같은 관계형 데이터베이스를 사용한다.

```python
from langchain.agents import create_agent
from langgraph.checkpoint.postgres import PostgresSaver
from psycopg import Connection

# 1. 중앙 DB 연결 설정
DB_URI = "postgresql://user:password@localhost:5432/agent_db"
conn = Connection.connect(DB_URI)

# 2. RDB 기반의 체크포인터 생성
db_checkpointer = PostgresSaver(conn)
db_checkpointer.setup()  # 상태 저장을 위한 내부 테이블 자동 생성

# 3. 에이전트에 영구 저장소 주입
agent = create_agent(
    model,
    tools,
    checkpointer=db_checkpointer,
)
```

이렇게 구현한 에이전트는 대화 턴이 끝날 때마다 누적된 messages 상태를 DB에 저장하고, 새로운 요청이 들어오면 thread_id로 과거 데이터를 SELECT 해온다. 서버가 10대로 늘어나더라도 모든 에이전트가 동일한 DB를 바라보게 된다.

| checkpointer | 특징 | 적합한 상황 |
| --- | --- | --- |
| InMemorySaver | RAM 저장, 초기화 위험 | 로컬 테스트, 주피터 노트북 실습 |
| PostgresSaver | 영구 저장, 스케일아웃 지원 | 프로덕션 서비스 |
| MySQL | SQLAlchemy 기반 또는 직접 구현 | MySQL 스택 프로덕션 |

---

## 📗 4. Built-in 미들웨어 (3-3)

---

에이전트가 외부 도구를 호출해 직접 행동할 수 있게 되면, 사용자가 무심코 민감한 개인정보를 입력하거나 에이전트가 권한을 오남용해 돌이킬 수 없는 사고를 일으킬 수 있다.

미들웨어(Middleware)는 이러한 불안정성을 해소하기 위해 존재한다. 에이전트의 실행 흐름 중간에 개입하여 다양한 통제 정책과 검증 로직을 주입하는 핵심 레이어다.

![미들웨어 레이어 구조](/assets/images/langchain-03/middleware_layer.svg)

사용법은 아주 직관적이다. `create_agent()` 에 원하는 미들웨어 객체들을 `middleware=[...]` 리스트 형태로 적어주면 된다.

```python
agent = create_agent(
    model,
    tools=[...],
    middleware=[...],
)
```

### 📌 1) LLM Tool Emulator: 프로토타입 빠른 검증

아직 연결해야 할 외부 API가 개발 중이거나 호출당 비용이 너무 비싸 매번 실제 데이터를 가져오기 부담스러운 상황에서 사용한다. 에이전트가 도구를 호출하려 할 때 실제 함수를 실행하는 대신 경량 모델이 그럴싸한 가짜 데이터를 창작한다.

> 💡 에뮬레이터가 내놓는 결과는 언어 모델이 논리적으로 추론해 만들어낸 '가짜 데이터'다. 실제 운영 환경에 배포할 때는 반드시 이 미들웨어를 제거하고 실제 서비스 로직과 연결해야 한다.

```python
from langchain.agents import create_agent
from langchain.agents.middleware import LLMToolEmulator

agent = create_agent(
    model,
    tools=[send_email_tool, read_email_tool],
    middleware=[
        LLMToolEmulator(model="gpt-5-nano"),
        # tools=["send_email_tool"]처럼 특정 도구만 에뮬레이션할 수 있다.
    ],
)
```

에뮬레이터 운영 3대 원칙은 다음과 같다.

- 에뮬레이터 전용 경량 모델(model="gpt-5-nano") 지정: 메인 에이전트에는 고성능 모델을, 에뮬레이터에는 경량 모델을 사용해 리소스를 최적화한다.
- 상세한 타입 힌트와 독스트링 필수: 에뮬레이터는 독스트링을 프롬프트로 활용해 결과물을 창작하므로, 입력 규격과 설명을 구체적으로 작성해야 품질 높은 모의 데이터를 얻을 수 있다.
- 특정 도구만 선택적으로 에뮬레이션: `tools=["send_email_tool"]`처럼 특정 도구 이름만 넘기면 해당 도구만 에뮬레이터가 가로채고 나머지는 실제 함수를 실행한다.

### 📌 2) TodoListMiddleware: 복잡한 요청을 단계로 쪼개기

"메일함을 확인해서 내용을 요약하고 보고서를 작성한 뒤, 중요한 메일에는 답장하고 그 결과를 알려줘"처럼 여러 과업이 섞인 지시를 받으면 에이전트는 당황하기 마련이다. `TodoListMiddleware`는 에이전트가 사용자의 복잡한 지시사항을 받자마자 스스로 세부 할당량(To-do 리스트)을 쪼개도록 유도하고, 각 단계를 하나씩 완수할 때마다 체크하도록 강제한다.

```python
from langchain.agents.middleware import LLMToolEmulator, TodoListMiddleware

agent = create_agent(
    model,
    tools=[send_email_tool, read_email_tool],
    middleware=[
        LLMToolEmulator(model="gpt-5-nano"),
        TodoListMiddleware(),
    ],
)
```

### 📌 3) HumanInTheLoopMiddleware: 사람의 승인 요청

이메일 발송, 결제 승인, DB 데이터 삭제처럼 중요한 행동은 에이전트 마음대로 처리하지 못하게 하고, 반드시 사람의 승인을 거치도록 통제한다.

> 💡 HITL 패턴은 에이전트가 실행 중간에 멈춰 서서 사람의 결정을 기다려야 하므로, 반드시 앞 장에서 배운 단기 메모리(checkpointer)를 함께 주입해야 한다.

```python
from langchain.agents.middleware import HumanInTheLoopMiddleware, LLMToolEmulator
from langgraph.checkpoint.memory import InMemorySaver

checkpointer = InMemorySaver()

agent = create_agent(
    model,
    tools=[send_email_tool, read_email_tool],
    checkpointer=checkpointer,
    middleware=[
        LLMToolEmulator(model="gpt-5-nano"),
        HumanInTheLoopMiddleware(
            interrupt_on={
                # 이메일 전송은 부작용이 크므로 승인/수정/거절 옵션을 활성화
                "send_email_tool": {"allowed_decisions": ["approve", "edit", "reject"]},
                # 이메일 읽기는 단순 조회이므로 중단 없이 바로 실행 허용
                "read_email_tool": False,
            }
        ),
    ],
)
```

설정 핵심은 세 가지다.

- `checkpointer` 결합: 에이전트가 사람의 승인을 기다리는 동안 도구 실행 직전의 문맥을 잃어버리지 않도록 checkpointer를 주입한다.
- 도구별 세밀한 개입 정책(`interrupt_on`): 단순 조회는 `False`로 즉시 실행, 민감한 발송 작업에만 멈춤 조건을 부여한다.
- 사용자 선택 옵션(`allowed_decisions`): `["approve", "edit", "reject"]` 리스트로 에이전트가 멈춰 명확한 가이드를 제시하도록 한다.

```python
cfg = {"configurable": {"thread_id": "HIL-a"}}

# 민감한 도구(메일 발송) 호출 테스트
prompt = "교수님한테 내일 찾아뵙겠다는 메일 작성해서 보내줘."
response = agent.invoke(
    {"messages": [{"role": "user", "content": prompt}]},
    {"configurable": {"thread_id": "HIL-a"}}
)
print(response["messages"][-1].content)
```

```
다음 초안을 사용해 교수님께 메일을 보내드릴 수 있습니다.

초안:
- 제목: 내일 오후 3시에 찾아뵙고 인사드립니다

필요한 정보:
- 교수님 성함
- 교수님 이메일 주소
이 정보를 주시면 최종적으로 바로 보내는 버전으로 만들어 드리겠습니다.
```

"보내줘"라고 지시했지만 에이전트는 즉시 발송하지 않고, 초안을 먼저 보여주고 확정을 요청하고 대기 상태에 들어간다. 사용자가 정보를 입력하며 승인(approve)할 때 비로소 멈춰있던 도구 실행이 진행된다.

### 📌 4) PIIMiddleware: 개인정보 차단 및 마스킹

사용자가 무심코 카드번호나 비밀번호를 입력할 때, 그 데이터가 외부 LLM API로 넘어가거나 DB에 평문으로 저장되면 치명적인 사고로 이어진다.

**4가지 개인정보 처리 전략**

| strategy | 처리 방식 | 적합한 상황 |
| --- | --- | --- |
| redact | [REDACTED_EMAIL]처럼 완전히 가림 | 가장 안전 |
| mask | `****-****-****-4321`처럼 마지막 일부만 남김 | 고객 응대 시 유용 |
| hash | 일관된 해시값으로 변환 | 식별자는 유지하되 원본 가림 |
| block | 민감 정보 감지 시 에이전트 실행 중단 | API 키 등 절대 유출 불가 정보 |

**기본 사용법: 이메일과 카드번호 가리기**

```python
from langchain.agents.middleware import PIIMiddleware

agent = create_agent(
    model,
    tools=[save_customer_feedback],
    middleware=[
        PIIMiddleware(pii_type="email", strategy="redact", apply_to_input=True),
        PIIMiddleware(pii_type="credit_card", strategy="mask", apply_to_input=True),
    ],
)

prompt = "안녕하세요. 이메일은 user123@example.com 입니다. 제 카드번호는 1234123443214321 입니다."
response = agent.invoke({"messages": [{"role": "user", "content": prompt}]})

print(response["messages"][0].content)
```

```
안녕하세요. 이메일은 [REDACTED_email] 입니다. 제 카드번호는 ****4321 입니다.
```

사용자의 프롬프트가 외부 LLM 서버로 날아가기 직전에 미들웨어가 먼저 문장을 가로채어 필터링한다.

**커스텀 PII 규칙 만들기 (정규식/함수 활용)**

```python
# 예시 1: 정규식을 이용한 휴대폰 번호 마스킹
phone_number_regex = r"\b(010)[-\s]?(\d{3,4})[-\s]?(\d{4})\b"
phone_masking_middleware = PIIMiddleware(
    pii_type="phone_number",
    detector=phone_number_regex,
    strategy="mask",
    apply_to_input=True,
)

# 예시 2: 함수를 이용한 복잡한 검증 로직
import re

def detect_api_key(content: str) -> list[dict[str, str | int]]:
    """'sk-'로 시작하는 32자리 문자열을 API 키로 간주하고 탐지합니다."""
    matches = []
    pattern = r"sk-[a-zA-Z0-9]{32}"
    for match in re.finditer(pattern, content):
        matches.append({
            "text": match.group(0),
            "start": match.start(),
            "end": match.end(),
        })
    return matches

api_key_blocker = PIIMiddleware(
    pii_type="api_key",
    detector=detect_api_key,
    strategy="block",  # 발견 즉시 실행 중단
    apply_to_input=True,
)
```

> 💡 커스텀 함수를 짤 때는 단순히 일치 여부(True/False)를 반환하는 것이 아니라, `match.start()`, `match.end()`처럼 민감 정보가 위치한 정확한 인덱스 구간을 반환해야 한다. 그래야 미들웨어가 해당 텍스트 부분을 핀포인트로 도려낼 수 있기 때문이다.

### 📌 그 밖의 Built-in 미들웨어

| 목적 | 미들웨어 | 설명 |
| --- | --- | --- |
| 비용 통제 | ModelCallLimitMiddleware | 언어 모델 호출 최대 횟수 제한 |
| 비용 통제 | ToolCallLimitMiddleware | 특정 도구 실행 횟수 한도 설정 |
| 안정성 | ModelFallbackMiddleware | 메인 모델 장애 시 대체 모델로 우회 |
| 안정성 | ToolRetryMiddleware | 도구 실행 실패 시 자동 재시도 |
| 최적화 | SummarizationMiddleware | 오래된 대화를 자동으로 요약 압축 |
| 최적화 | LLMToolSelectorMiddleware | 많은 도구 중 현재 질문에 필요한 것만 필터링 |
| 권한 확장 | FilesystemMiddleware | 에이전트에게 파일 시스템 권한 부여 |

---

## 📗 5. 구조화된 답변 생성 (3-4)

---

에이전트는 도구를 여러 번 호출하며 긴 과정을 거친다. 이때 최종 결과가 자연어 줄글로만 나오면 그 뒤에 이어질 자동화 파이프라인(DB 저장, API 호출, 알림 발송)이 크게 흔들린다.

`response_format=ToolStrategy(...)` 옵션을 사용하면 "도구를 지지고 볶는 과정은 에이전트 자율에 맡기되, 마지막 산출물만큼은 반드시 우리가 정한 스키마로 가져와라"라고 통제할 수 있다.

### 📌 모델 단위 vs 에이전트 단위 구조화된 출력 비교

| 구분 | 방법 | 특징 |
| --- | --- | --- |
| 모델 단위 (2-3장) | `model.with_structured_output(Schema)` | 단 한 번의 질문-대답에 적합 |
| 에이전트 단위 (3-4장) | `response_format=ToolStrategy(Schema)` | 다중 도구 호출 후 최종 산출물에 적용 |

### 📌 1) 사전 준비: 도구 정의

```python
from langchain.tools import tool
from typing import Dict, List

@tool
def send_email_tool(to: str, subject: str, body: str) -> str:
    """지정한 이메일 주소로 메일을 보내는 도구(프로토타입)."""
    return f"✅ 이메일이 성공적으로 전송되었습니다.\n수신자: {to}\n제목: {subject}"

@tool
def read_email_tool(limit: int = 1) -> List[Dict[str, str]]:
    """가상의 고객 이메일을 조회하는 도구."""
    return f"✅ 이메일이 성공적으로 조회되었습니다."
```

### 📌 2) 스키마 설계: EmailAnalysis

```python
from pydantic import BaseModel, Field
from typing import Literal

class EmailAnalysis(BaseModel):
    """이메일 내용을 분석한 결과 구조."""
    intent: Literal["complaint", "inquiry", "confirmation", "other"] = Field(
        description="이메일의 주요 의도 (complaint=불만, inquiry=문의, confirmation=확인, other=기타)"
    )
    sentiment: Literal["positive", "negative", "neutral"] = Field(
        description="고객의 감정 상태"
    )
    summary: str = Field(
        description="이메일의 핵심 내용을 1~2문장으로 짧게 요약"
    )
    next_action: str = Field(
        description="담당자가 취해야 할 다음 단계 (예: 환불 부서 이관, 매뉴얼 링크 발송 등)"
    )
```

### 📌 3) 에이전트 생성 및 구조화 출력 적용

```python
from langchain.agents import create_agent
from langchain.agents.middleware import LLMToolEmulator
from langchain.agents.structured_output import ToolStrategy
from langchain.chat_models import init_chat_model

model = init_chat_model("gpt-5-nano")
tools = [send_email_tool, read_email_tool]

agent = create_agent(
    model=model,
    tools=tools,
    # 핵심: 최종 산출물의 규격을 EmailAnalysis 스키마로 강제합니다.
    response_format=ToolStrategy(EmailAnalysis),
    middleware=[
        LLMToolEmulator(model="gpt-5-nano"),
    ],
)
```

### 📌 4) 실행 및 결과 객체 뜯어보기

```python
response = agent.invoke({
    "messages": [{
        "role": "user",
        "content": "최근 온 메일을 읽고, 고객의 의도와 감정, 요약, 그리고 필요한 다음 조치를 분석해줘.",
    }]
})

# messages 배열을 뒤지는 대신, structured_response 키로 바로 접근합니다.
analysis = response["structured_response"]
print(analysis)
```

```
EmailAnalysis(
  intent='complaint',
  sentiment='negative',
  summary='주문에 대한 배송 지연, 박스 손상, 이어폰 불량 및 충전 케이스 미충전 문제로 환불 또는 교환 요청.',
  next_action='고객에게 환불 또는 교환 옵션을 안내하고, 반품 라벨 발급 및 반품 절차를 제공.'
)
```

`response_format`을 적용했을 때 반환되는 `response` 딕셔너리는 두 가지 키로 나뉜다.

![구조화된 출력 response 구조](/assets/images/langchain-03/structured_output_response.svg)

- `response["messages"]`: 에이전트의 사고 및 행동 과정이 순서대로 기록
- `response["structured_response"]`: 우리가 지시한 스키마 규격에 맞춰 뽑아낸 최종 산출물(Pydantic 객체)

### 📌 후처리 응용: 에이전트를 백엔드 파이프라인에 연결하기

구조화된 출력의 진가는 다음 시스템으로 넘기기가 쉽다는 데 있다. `analysis.model_dump()` 메서드를 통해 JSON으로 완벽하게 변환된다.

```python
# Pydantic 객체를 딕셔너리로 변환
data_for_db = analysis.model_dump()

if data_for_db["intent"] == "complaint" and data_for_db["sentiment"] == "negative":
    # 1. CS팀 슬랙 채널에 긴급 알림 전송 (API 호출)
    # 2. Jira 이슈 트래커에 '긴급(High)' 티켓 자동 생성
    print("🚨 [긴급] 불만 접수! CS팀에 즉시 알림을 전송합니다.")
    print(f"요약: {data_for_db['summary']}")
elif data_for_db["intent"] == "inquiry":
    # FAQ 데이터베이스 검색 후 자동 회신 스크립트 실행
    print("ℹ️ 일반 문의 접수. 자동 회신 프로세스를 시작합니다.")
```

이처럼 구조화된 출력은 LLM의 모호한 텍스트 답변을 프로그래밍 가능한 "데이터"로 치환해 준다. 전통적인 백엔드 소프트웨어 엔지니어링 파이프라인(if/else 분기, DB 저장, 외부 API 전송)과 완벽하게 맞물려 돌아가게 된다.

---

## 📗 6. 정리

---

03장에서 배운 핵심 내용을 한 줄씩 요약한다.

- `@tool` 데코레이터로 파이썬 함수를 에이전트 도구로 변환하고, 이름/타입 힌트/독스트링을 충분히 친절하게 작성해야 LLM이 올바르게 호출한다.
- 에이전트 실행 흐름은 HumanMessage → AIMessage(tool_calls) → ToolMessage → AIMessage(최종) 순서로 쌓이며, `result["messages"][-1].content`가 최종 답변이다.
- 시스템 프롬프트로 "추측하지 말고 tool을 사용하라"고 강제하면 모델의 임의 추측을 막을 수 있다.
- 메모리는 `checkpointer=InMemorySaver()`와 `config={"configurable": {"thread_id": "..."}}` 조합으로 구현된다. 프로덕션에서는 `PostgresSaver`를 사용한다.
- 미들웨어 4종(PII, TodoList, HITL, Emulator)은 `middleware=[...]` 리스트에 순서대로 꽂으면 된다. HITL은 checkpointer를 반드시 함께 주입해야 한다.
- 에이전트 단위 구조화된 출력은 `response_format=ToolStrategy(Schema)`로 설정하고, 결과는 `response["structured_response"]`로 꺼낸다.

---

## 참고 자료

- 위키독스 - AI 에이전트는 이렇게 만든다: <https://wikidocs.net/book/19240>
- LangChain 공식 문서 - Agents: <https://python.langchain.com/docs/concepts/agents/>
- LangChain 공식 문서 - Built-in Middleware: <https://python.langchain.com/docs/concepts/middleware/>
- LangChain 공식 문서 - Messages: <https://python.langchain.com/docs/concepts/messages/>
- LangGraph Checkpoint - PostgresSaver: <https://langchain-ai.github.io/langgraph/reference/checkpoints/>
