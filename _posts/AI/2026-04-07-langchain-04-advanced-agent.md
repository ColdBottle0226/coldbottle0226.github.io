---
title: "AI 에이전트는 이렇게 만든다 - LangChain 04장 에이전트 개발 응용"
date: 2026-04-07 10:00:00 +0900
categories: [LangChain]
tags: [LangChain, Agent, Runtime, State, Context, Store, Middleware, Guardrail, LongTermMemory, ContextEngineering, Python]
---

##  1. 개요

---

03장에서 Tool, Memory, Middleware의 기초를 다졌다면, 04장에서는 에이전트 내부를 더 정밀하게 제어하는 법을 배운다. 핵심 키워드는 두 가지다. **Runtime**(에이전트가 일할 때 참고하는 공유 환경)과 **State**(에이전트가 일하면서 만들어내는 결과물)다.

이 두 개념을 이해하고 나면 커스텀 미들웨어로 에이전트의 흐름을 원하는 방식으로 가로채고, 가드레일로 안전성을 확보하고, 장기 메모리로 세션을 넘나드는 사용자 맞춤형 서비스를 구축할 수 있게 된다.

### 📌 04장 전체 구조

| 섹션 | 핵심 개념 | 구현 요소 |
| --- | --- | --- |
| 4-1) Runtime & State | 에이전트 실행 환경 | Context, Store, DataClass, Node/Wrap 훅 |
| 4-2) Custom 미들웨어 | 흐름 인터셉트 & 조작 | before_agent, wrap_model_call, request.override |
| 4-3) 가드레일 | 신뢰할 수 있는 에이전트 | 결정론적·모델 기반·다중 레이어 가드레일 |
| 4-4) 장기 메모리 | 세션 초월 기억 | Store, Namespace/Key, Tool 기반 자동화 |

---

##  2. Runtime & State (4-1)

---

### 📌 컨텍스트 엔지니어링이란

OpenAI 초창기 모델 개발자이자 Tesla FSD를 설계한 Andrej Karpathy는 X(트위터)에 이런 글을 남겼다.

> "이제는 프롬프트 엔지니어링보다 컨텍스트 엔지니어링이 중요하다. 컨텍스트 엔지니어링이란 LLM이 갖고 있는 컨텍스트 윈도우에 필요한 정보를 아주 적절하게 채워넣는 섬세한 예술이자 과학의 영역이다."

GPT-5 기준으로 컨텍스트 윈도우는 128,000 토큰이다. 이 공간에 필요한 정보를 잘 채워야 에이전트 성능이 올라간다. 너무 적으면 답변 품질이 떨어지고, 너무 많거나 불필요한 정보가 섞이면 비용만 늘고 오히려 할루시네이션이 발생한다.

이번 장에서 배울 Runtime과 State는 바로 이 **컨텍스트 엔지니어링을 위한 필수 지식**이다.

### 📌 Runtime과 State 개요

![Runtime과 State 전체 구조](/assets/images/langchain-04/runtime_state_overview.svg)

에이전트가 실행되는 과정에서 두 가지 공간이 존재한다.

- **Runtime**: 에이전트가 일할 때 참고하는 **공유 환경**이다. Context(고정된 정보), Store(장기 메모리), StreamWriter(실시간 이벤트 출력)로 구성된다.
- **State**: 에이전트가 작동하면서 **만들어내는 결과물**이다. Messages(대화 기록 리스트), ToolResults(도구 실행 반환값)로 구성된다.

`agent.invoke()`를 호출하면 결과로 돌아오는 `{"messages": [...], "structured_response": ...}` 딕셔너리가 바로 State다.

### 📌 Context — 변하지 않는 고정 정보

Context는 사용자 아이디나 DB 연결 URL처럼 **실행 중에 바뀌지 않는** 정보를 담는 공간이다. 에이전트는 Context에 담긴 정보를 바탕으로 DB를 조회하거나 사용자 권한을 확인한다.

Context를 만들 때는 파이썬 3.7에서 도입된 `@dataclass` 데코레이터를 사용한다. `@dataclass`를 클래스 위에 달아주기만 하면 `__init__`, `__repr__`, `__eq__` 메서드가 자동으로 생성되어 데이터 컨테이너로 동작한다.

```python
from dataclasses import dataclass

@dataclass
class MyContext:
    user_id: str        # 사용자 고유 식별자
    app_name: str       # 어플리케이션 컨텍스트 이름
    is_premium: bool = False  # 프리미엄 여부 (기본값: False)
```

에이전트 생성 시 `context_schema`에 이 클래스를 넘기고, `invoke()` 시 `context`에 실제 값을 채워서 전달한다.

```python
from langchain.agents import create_agent

agent = create_agent(
    model,
    tools=[...],
    context_schema=MyContext,  # Context의 데이터 스키마 등록
)

# 실행 시 context 인자로 실제 값 전달
result = agent.invoke(
    {"messages": [{"role": "user", "content": "내 이름이 뭐야?"}]},
    context=MyContext(user_id="user_001", app_name="personal_assistant"),
)
```

### 📌 Request 객체 — 미들웨어가 보는 것

Wrap-style 훅에서 `request` 파라미터로 받는 객체의 내부 구조를 이해해야 정확한 위치에 데이터를 주입할 수 있다.

![Request 객체 내부 구조](/assets/images/langchain-04/request_object_structure.svg)

`request` 안에는 `model`, `system_prompt`, `messages`, `tools`, `state`, `runtime`, `model_settings` 등이 담겨 있다. 특히 `request.runtime.context`로 Context 데이터에 접근할 수 있다.

### 📌 Node-style 훅 vs Wrap-style 훅

커스텀 미들웨어를 만드는 방식은 두 가지다. 무엇을 하고 싶은지에 따라 골라서 쓴다.

![Node-style vs Wrap-style 훅 비교](/assets/images/langchain-04/hook_comparison.svg)

**Node-style 훅**: 특정 실행 시점에 끼어들어 상태를 확인하거나 로깅한다. 데이터 조회는 할 수 있지만, 모델에게 전달되는 내용을 직접 바꾸지는 못한다.

| 데코레이터 | 실행 시점 | 호출 횟수 |
| --- | --- | --- |
| `@before_agent` | 사용자 입력이 에이전트에 진입하기 직전 | 1회 |
| `@before_model` | 모델 호출 직전 (도구 호출마다 반복) | 여러 번 |
| `@after_model` | 모델 호출 직후 (도구 호출마다 반복) | 여러 번 |
| `@after_agent` | 에이전트 전체 실행 완료 후 | 1회 |

> 💡 `before_agent`와 `before_model`의 핵심 차이: `before_agent`는 사용자 요청이 들어올 때 딱 한 번만 실행된다. 반면 `before_model`은 에이전트 내부에서 모델이 호출될 때마다 실행된다. 4칙 연산 에이전트처럼 도구를 여러 번 호출하는 경우, `before_model`은 각 호출마다 실행된다.

**Wrap-style 훅**: 모델이나 도구 호출 자체를 감싸서 실제로 전달되는 내용을 수정한다. `request` 객체를 받아 `override()`로 원하는 값을 덮어쓴 뒤 `handler(new_request)`로 전달하는 패턴이다.

```python
from langchain.agents.middleware import wrap_model_call

@wrap_model_call
def inject_user_context(request, handler):
    # request.runtime.context에서 Context 데이터 접근
    username = request.runtime.context.user_id
    # system_prompt에 사용자 정보 추가
    new_system_prompt = f"사용자 이름: {username}\n" + (request.system_prompt or "")
    # request를 새 값으로 덮어써서 handler에 전달
    new_request = request.override(system_prompt=new_system_prompt)
    return handler(new_request)
```

---

##  3. Custom 미들웨어 (4-2)

---

Runtime과 State 개념을 익혔으니 이제 실전 커스텀 미들웨어를 만들어본다. 두 가지 대표 패턴을 다룬다.

### 📌 패턴 1: 사용자 등급에 따라 모델 동적 교체 (Wrap-style)

Context에 `is_premium` 정보를 담아두고, 프리미엄 사용자에게는 GPT-5, 일반 사용자에게는 GPT-5 Nano를 호출하도록 동적으로 모델을 교체하는 예시다.

```python
from dataclasses import dataclass
from langchain.agents import create_agent
from langchain.agents.middleware import wrap_model_call
from langchain.chat_models import init_chat_model

@dataclass
class UserContext:
    user_id: str
    is_premium: bool = False

@wrap_model_call
def dynamic_model_selector(request, handler):
    """사용자 등급에 따라 호출 모델을 동적으로 선택한다."""
    is_premium = request.runtime.context.is_premium
    user_id = request.runtime.context.user_id

    if is_premium:
        model_name = "gpt-5"
        print(f"[{user_id}] 프리미엄 회원 — GPT-5 호출")
    else:
        model_name = "gpt-5-nano"
        print(f"[{user_id}] 일반 회원 — GPT-5 Nano 호출")

    new_model = init_chat_model(model_name)
    new_request = request.override(model=new_model)
    return handler(new_request)

agent = create_agent(
    model=init_chat_model("gpt-5-nano"),  # 기본값 (실제로는 위에서 교체됨)
    tools=[],
    context_schema=UserContext,
    middleware=[dynamic_model_selector],
)

# 프리미엄 사용자 실행
result = agent.invoke(
    {"messages": [{"role": "user", "content": "안녕하세요!"}]},
    context=UserContext(user_id="jay", is_premium=True),
)
# → "[jay] 프리미엄 회원 — GPT-5 호출"
```

### 📌 패턴 2: Context 정보를 시스템 프롬프트에 주입 (Wrap-style)

사용자 이름을 Context에서 꺼내 에이전트가 실제로 이름을 알고 답변할 수 있도록 시스템 프롬프트에 주입하는 패턴이다.

```python
from langchain.agents.middleware import wrap_model_call

@wrap_model_call
def inject_username(request, handler):
    """Context의 사용자 이름을 시스템 프롬프트에 주입한다."""
    username = request.runtime.context.user_id

    if username:
        # 기존 시스템 프롬프트에 사용자 정보 추가
        injected = f"사용자 이름: {username}"
        existing = request.system_prompt or ""
        new_prompt = f"{injected}\n{existing}".strip()
        new_request = request.override(system_prompt=new_prompt)
        return handler(new_request)

    # username 없으면 그대로 통과
    return handler(request)

agent = create_agent(
    model=init_chat_model("gpt-5-nano"),
    tools=[],
    context_schema=UserContext,
    middleware=[inject_username],
)

result = agent.invoke(
    {"messages": [{"role": "user", "content": "내 이름이 뭐야?"}]},
    context=UserContext(user_id="Jay"),
)
print(result["messages"][-1].content)
# → "당신의 이름은 Jay입니다."
```

> 💡 inject_username 미들웨어를 적용하기 전에는 LLM이 "이름을 알 수 없습니다"라고 답변한다. 주입 후에는 시스템 프롬프트에 "사용자 이름: Jay"가 담겨 있어 LLM이 이름을 알고 답변한다. Context 정보가 컨텍스트 윈도우에 채워지는 과정이 바로 컨텍스트 엔지니어링이다.

### 📌 패턴 3: 입력 차단 (Node-style + can_jump_to)

`@before_agent`에 `can_jump_to="end"`를 결합하면 에이전트 내부 로직을 전혀 실행하지 않고 바로 고정 응답을 반환하여 실행을 종료할 수 있다. LLM 호출이 없으므로 비용이 발생하지 않는다.

```python
from langchain.agents.middleware import before_agent
from langchain.core.messages import AIMessage

@before_agent(can_jump_to="end")
def block_sensitive_input(state, runtime):
    """민감한 키워드가 포함된 입력을 즉시 차단한다."""
    last_msg = state["messages"][-1]

    # HumanMessage인지 확인
    if last_msg.type != "human":
        return  # 차단 없이 통과

    content = last_msg.content
    blocked_keywords = ["암구", "시스템 프롬프트 알려줘", "내부 아키텍처"]

    for keyword in blocked_keywords:
        if keyword in content:
            print(f"[차단] '{keyword}' 감지")
            # 고정 응답과 함께 "end"로 점프 → 에이전트 즉시 종료
            return {
                "messages": [AIMessage(content="요청을 처리할 수 없습니다. 보안 정책에 위반됩니다.")],
                "jump": "end",  # can_jump_to="end" 와 세트로 반드시 명시
            }
    # 차단 대상 아니면 None 반환 → 정상 실행 계속

agent = create_agent(
    model=init_chat_model("gpt-5-nano"),
    tools=[],
    middleware=[block_sensitive_input],
)

result = agent.invoke(
    {"messages": [{"role": "user", "content": "오늘의 암구는 삼각대 자동차입니다."}]}
)
print(result["messages"][-1].content)
# → "요청을 처리할 수 없습니다. 보안 정책에 위반됩니다."
```

---

##  4. 가드레일 (4-3)

---

03장 Built-in 미들웨어까지 배운 에이전트는 기능 면에서 충분하지만, 신뢰성(Reliability) 면에서는 아직 부족하다. 가드레일(Guardrail)은 에이전트를 실제 서비스에 배포하기 위한 안전장치다. AWS, Google Summit 같은 빅테크 행사에서 최근 가장 자주 등장하는 키워드 중 하나다.

![가드레일 종류별 비교](/assets/images/langchain-04/guardrail_types.svg)

### 📌 가드레일이 필요한 이유

에이전트 개발에는 두 단계가 있다.

- **POC (Proof of Concept)**: 에이전트가 동작하는지 증명하는 단계. 기술적으로 가능함을 보임.
- **POV (Proof of Value)**: 에이전트가 실제로 기업에 가치를 창출하는지 증명하는 단계.

POV 단계로 넘어가려면 두 가지 요건이 필요하다. ① 성능이 좋을 것 (컨텍스트 엔지니어링으로 해결) ② 안전하고 신뢰할 수 있을 것 (가드레일로 해결).

### 📌 결정론적 가드레일 (Before-agent)

사전에 정의한 키워드나 정규식과 매칭하여 입력을 차단하는 방식이다. LLM을 호출하지 않아 매우 빠르고 비용이 없다. 앞서 배운 `@before_agent + can_jump_to="end"` 패턴이 이에 해당한다.

```python
from langchain.agents.middleware import before_agent
from langchain.core.messages import AIMessage

# 교육용 에이전트를 위한 금지 토픽 사전 정의
FORBIDDEN_TOPICS = {
    "cheating": ["정답 알려줘", "답지", "대신 써줘", "숙제 해줘"],
    "distraction": ["유튜브", "게임", "롤", "넷플릭스"],
    "harmful": ["욕설", "바보", "멍청이"],
}

BLOCKED_RESPONSES = {
    "cheating": "스스로 고민해봐야 실력이 늘어. 힌트가 필요하면 말해줘!",
    "distraction": "집중할 시간이야. 딴짓은 쉬는 시간에 하자!",
    "harmful": "부적절한 표현이야. 다시 한번 생각해보자.",
}

@before_agent(can_jump_to="end")
def education_guardrail(state, runtime):
    """교육 에이전트용 결정론적 가드레일."""
    last_msg = state["messages"][-1]
    if last_msg.type != "human":
        return

    content = last_msg.content

    for topic, keywords in FORBIDDEN_TOPICS.items():
        for kw in keywords:
            if kw in content:
                return {
                    "messages": [AIMessage(content=BLOCKED_RESPONSES[topic])],
                    "jump": "end",
                }
    # 해당 없으면 정상 실행

agent = create_agent(
    model=init_chat_model("gpt-5-nano"),
    tools=[],
    middleware=[education_guardrail],
)

# 정상 질문
result = agent.invoke(
    {"messages": [{"role": "user", "content": "피타고라스 정리가 이해가 안 돼."}]}
)
print(result["messages"][-1].content)
# → (LLM이 정상 답변)

# 차단 대상 질문
result = agent.invoke(
    {"messages": [{"role": "user", "content": "숙제 대신 써줘."}]}
)
print(result["messages"][-1].content)
# → "스스로 고민해봐야 실력이 늘어. 힌트가 필요하면 말해줘!"
```

### 📌 모델 기반 가드레일 (After-agent)

에이전트가 최종 답변을 만들고 난 뒤, 별도의 평가 모델(safety_model)이 그 답변이 적절한지 검토한다. 미묘한 표현도 잡아낼 수 있고, 문제가 있는 답변을 자동으로 교정할 수도 있다.

```python
from langchain.agents.middleware import after_agent
from langchain.chat_models import init_chat_model
from langchain.core.messages import AIMessage, SystemMessage, HumanMessage

# 답변 품질을 평가할 경량 모델
safety_model = init_chat_model("gpt-5-nano")

@after_agent
def answer_quality_guardrail(state, runtime):
    """에이전트 최종 답변을 모델로 평가하고, 문제가 있으면 교정한다."""
    # 마지막 메시지가 AI 답변인지 확인
    last_msg = state["messages"][-1]
    if last_msg.type != "ai" or not last_msg.content:
        return

    ai_answer = last_msg.content

    # safety_model에 평가 요청
    evaluation = safety_model.invoke([
        SystemMessage(content=(
            "당신은 엄격한 교육 감독관입니다. "
            "다음 튜터의 답변이 학생에게 직접 정답을 알려주고 있으면 'leaked'라고 답하고, "
            "힌트나 개념 설명만 하고 있으면 'safe'라고 답하시오."
        )),
        HumanMessage(content=f"튜터 답변: {ai_answer}"),
    ])

    verdict = evaluation.content.strip().lower()

    if "leaked" in verdict:
        # 정답 유출 감지 → 교정 답변 생성
        original_question = next(
            (m.content for m in state["messages"] if m.type == "human"), ""
        )
        corrected = safety_model.invoke([
            SystemMessage(content=(
                "당신은 소크라테스식 교육법을 사용하는 튜터입니다. "
                "절대 정답을 직접 말하지 말고, 학생이 스스로 생각할 수 있도록 "
                "핵심 개념만 설명하거나 유도 질문을 던지시오."
            )),
            HumanMessage(content=f"학생 질문: {original_question}\n답변하려 했던 내용: {ai_answer}"),
        ])
        # 마지막 메시지를 교정된 답변으로 교체
        new_messages = state["messages"][:-1] + [AIMessage(content=corrected.content)]
        return {"messages": new_messages}

    # "safe"면 그대로 통과
```

```python
agent = create_agent(
    model=init_chat_model("gpt-5-nano"),
    tools=[],
    middleware=[answer_quality_guardrail],
)

result = agent.invoke(
    {"messages": [{"role": "user", "content": "직각삼각형 빗변이 5일 때 직각을 낀 두 변이 3, 4라는 걸 증명해줘."}]}
)
print(result["messages"][-1].content)
# 교정 전: "피타고라스 정리에 의해 3² + 4² = 9 + 16 = 25 = 5²이므로 성립합니다."
# 교정 후: "피타고라스 정리 a² + b² = c²를 기억해? 3²과 4²을 계산해보면 어떤 결과가 나오지?"
```

> 💡 모델 기반 가드레일은 after_agent 단계에서 LLM이 두 번 더 호출되기 때문에(평가 + 교정) 응답 시간이 늘어난다. 비용·속도와 품질 사이의 트레이드오프를 고려해 서비스 특성에 맞게 적용 범위를 결정해야 한다.

### 📌 다중 레이어 가드레일 (Combined)

결정론적 가드레일과 모델 기반 가드레일을 `middleware=[...]` 리스트에 순서대로 쌓으면 다층 방어막이 완성된다. 교육용 에이전트를 예로 들면 다음과 같이 4개 레이어를 조합할 수 있다.

```python
from langchain.agents.middleware import PIIMiddleware

agent = create_agent(
    model=init_chat_model("gpt-5-nano"),
    tools=[...],
    middleware=[
        education_guardrail,        # 레이어 1: 욕설·치팅 키워드 즉시 차단 (결정론적)
        PIIMiddleware(              # 레이어 2: 전화번호·이메일 마스킹 (빌트인)
            pii_type="phone_number",
            detector=r"\b010[-\s]?\d{3,4}[-\s]?\d{4}\b",
            strategy="mask",
            apply_to_input=True,
        ),
        counseling_guardrail,       # 레이어 3: 왕따·위기 키워드 → 상담 연결 (결정론적)
        answer_quality_guardrail,   # 레이어 4: 정답 유출 교정 (모델 기반)
    ],
)
```

미들웨어 리스트의 순서가 실행 순서이므로 **입력 필터(레이어 1~3)를 앞에, 출력 검증(레이어 4)을 뒤에** 배치하는 것이 원칙이다.

---

##  5. 장기 메모리 (4-4)

---

03장의 단기 메모리(`InMemorySaver + thread_id`)는 하나의 대화 세션 안에서만 기억이 유지된다. 장기 메모리는 **대화 세션을 넘나들며** 사용자 정보를 기억하는 구조다.

### 📌 Store의 구조 — Namespace + Key

장기 메모리는 Runtime의 **Store**를 통해 구현된다. Store는 파일 시스템의 폴더-파일 구조와 유사하다.

![Store Namespace 구조](/assets/images/langchain-04/store_namespace_structure.svg)

- **Namespace** (폴더): 어떤 사용자의, 어떤 용도의 데이터인지를 나타내는 **튜플 형태의 고유 식별자**다. 예: `("user_001", "personal_assistant")`
- **Key** (파일명): 같은 Namespace 안에서 개별 기억을 구분하는 이름이다. 예: `"memory_001"`
- **Value** (파일 내용): 실제 저장할 데이터 딕셔너리다.

```python
from langgraph.store.memory import InMemoryStore

# 1. Store 생성 (실무에서는 PostgreSQL/MySQL로 교체)
store = InMemoryStore()

# 2. Namespace 정의 (튜플, 고유값이어야 함)
namespace = ("user_001", "personal_assistant")

# 3. 저장: put(namespace, key, dict)
store.put(namespace, "memory_001", {
    "personal_info": "커피보다 차를 선호, 매일 아침 6시에 기상",
    "language": "Korean",
})
store.put(namespace, "memory_002", {
    "preferences": "Python 선호, 랭체인 공부 중",
    "interest": "에이전트 개발",
})

# 4. 단건 조회: get(namespace, key)
item = store.get(namespace, "memory_001")
print(item.value)
# → {"personal_info": "커피보다 차를 선호...", "language": "Korean"}

# 5. 전체 조회: search(namespace)
items = store.search(namespace)
for item in items:
    print(item.key, item.value)
# → memory_001 {"personal_info": ...}
# → memory_002 {"preferences": ...}
```

### 📌 Wrap-style 미들웨어로 장기 메모리 주입

Store에 데이터가 저장돼 있어도, 에이전트가 그 내용을 참고하려면 반드시 컨텍스트 윈도우에 넣어줘야 한다. `@wrap_model_call`로 모델 호출 직전에 Store를 조회하여 시스템 프롬프트에 주입하는 방식을 사용한다.

```python
from langchain.agents.middleware import wrap_model_call

@wrap_model_call
def inject_long_term_memory(request, handler):
    """
    Runtime의 Context로 Namespace를 구성하고,
    Store에서 장기 기억을 꺼내 시스템 프롬프트에 주입한다.
    """
    ctx = request.runtime.context
    namespace = (ctx.user_id, ctx.app_name)

    # Store에서 전체 메모리 조회
    items = request.runtime.store.search(namespace)

    if items:
        # 저장된 정보에서 personal_info와 preferences 추출
        facts = []
        for item in items:
            val = item.value
            if "personal_info" in val:
                facts.append(val["personal_info"])
            if "preferences" in val:
                facts.append(val["preferences"])

        # 시스템 프롬프트에 장기 기억 추가
        memory_text = "\n".join(facts)
        new_prompt = f"[사용자 장기 기억]\n{memory_text}\n\n{request.system_prompt or ''}"
        new_request = request.override(system_prompt=new_prompt)
        return handler(new_request)

    return handler(request)

agent = create_agent(
    model=init_chat_model("gpt-5-nano"),
    tools=[],
    context_schema=MyContext,
    store=store,                          # Store 연결 필수
    middleware=[inject_long_term_memory],
)

result = agent.invoke(
    {"messages": [{"role": "user", "content": "나에 대해 알고 있는 정보 다 알려줘."}]},
    context=MyContext(user_id="user_001", app_name="personal_assistant"),
)
print(result["messages"][-1].content)
# → "안녕하세요! 제가 기억하는 정보입니다.
#    커피보다 차를 선호하시고, 매일 아침 6시에 기상하시는군요.
#    Python을 선호하시고 현재 랭체인을 공부 중이시네요!"
```

### 📌 Tool 기반 장기 메모리 자동화

위 방식은 개발자가 직접 `store.put()`으로 데이터를 저장해야 한다. 사용자가 많아지면 현실적으로 불가능하다. **에이전트가 스스로 판단해서 저장하고 조회하도록** 저장·조회 기능을 Tool로 만들어 연결하면 이 문제가 해결된다.

![Tool 기반 장기 메모리 자동화 흐름](/assets/images/langchain-04/tool_based_memory_flow.svg)

**Step 1: 저장할 데이터의 스키마 정의 (TypedDict)**

LLM이 Tool을 호출할 때 어떤 형태로 데이터를 작성해야 하는지 알려주기 위해 `TypedDict`로 스키마를 정의한다.

```python
from typing import TypedDict, Optional

class UserInfo(TypedDict):
    """LLM이 save_user_info 도구 호출 시 채워야 할 데이터 구조."""
    personal_info: Optional[str]  # 개인 정보 (이름, 생활 습관 등)
    preferences: Optional[str]    # 선호도 (언어, 음식, 취미 등)
```

**Step 2: 조회 도구 — get_user_info**

```python
from langchain.tools import tool
from langchain.core.runnables import RunnableConfig

@tool
def get_user_info(config: RunnableConfig) -> str:
    """
    현재 사용자의 장기 기억 정보를 Store에서 조회하여 반환한다.
    사용자에 대한 정보가 필요할 때 이 도구를 호출하라.
    """
    # RunnableConfig에서 runtime 정보 추출
    ctx = config["configurable"]["context"]
    rt_store = config["configurable"]["store"]
    namespace = (ctx.user_id, ctx.app_name)

    items = rt_store.search(namespace)
    if not items:
        return "저장된 사용자 정보가 없습니다."

    facts = []
    for item in items:
        val = item.value
        for v in val.values():
            if v:
                facts.append(v)

    return "\n".join(facts)
```

**Step 3: 저장 도구 — save_user_info**

```python
import uuid

@tool
def save_user_info(user_info: UserInfo, config: RunnableConfig) -> str:
    """
    대화에서 파악한 사용자 정보를 Store에 저장한다.
    사용자가 자신에 대한 정보를 말하거나, 선호도가 드러날 때 이 도구를 호출하라.
    저장할 내용은 user_info 인자에 담아 전달한다.
    """
    ctx = config["configurable"]["context"]
    rt_store = config["configurable"]["store"]
    namespace = (ctx.user_id, ctx.app_name)

    # UUID로 고유한 key 생성 (중복 없이 새 기억 추가)
    key = str(uuid.uuid4())
    rt_store.put(namespace, key, dict(user_info))

    return f"정보가 안전하게 저장되었습니다. 저장 키: {key[:8]}..."
```

**Step 4: 에이전트 생성 및 실행**

```python
agent = create_agent(
    model=init_chat_model("gpt-5-nano"),
    tools=[get_user_info, save_user_info],  # 장기 메모리 도구 2개 연결
    context_schema=MyContext,
    store=store,
)

cfg_context = MyContext(user_id="jay_001", app_name="personal_assistant")

# 첫 번째 대화: 사용자 정보 저장
result1 = agent.invoke(
    {"messages": [{"role": "user", "content": "안녕! 내 이름은 Jay고 커피보다 차를 좋아해."}]},
    context=cfg_context,
)
print(result1["messages"][-1].content)
# AI가 save_user_info 도구를 스스로 호출하여 Store에 저장
# → "안녕하세요, Jay님! 차를 좋아하신다고 기억해 둘게요. 정보가 저장되었습니다."

# 새로운 세션 (thread_id 달라도 동일 user_id면 기억 유지)
result2 = agent.invoke(
    {"messages": [{"role": "user", "content": "나에 대해 알고 있어?"}]},
    context=cfg_context,  # 동일한 user_id
)
print(result2["messages"][-1].content)
# AI가 get_user_info 도구를 호출하여 Store에서 조회
# → "Jay님에 대해 기억하고 있어요! 커피보다 차를 좋아하신다고 말씀하셨어요."
```

### 📌 InMemoryStore의 한계와 실무 대안

`InMemoryStore`는 RAM에 저장하므로 서버 재시작 시 모든 데이터가 사라진다. 실무에서는 아래와 같이 교체한다.

| Store | 특징 | 적합한 상황 |
| --- | --- | --- |
| InMemoryStore | RAM 저장, 재시작 시 초기화 | 로컬 테스트, 개발 단계 |
| PostgresStore | 영구 저장, SQL 기반 | PostgreSQL 스택 프로덕션 |
| RedisStore | 빠른 인메모리 + 영속성 옵션 | 고성능 실시간 서비스 |

```python
# PostgresStore 교체 예시
from langgraph.store.postgres import PostgresStore
from psycopg import Connection

DB_URI = "postgresql://user:password@localhost:5432/agent_db"
conn = Connection.connect(DB_URI)
store = PostgresStore(conn)
store.setup()  # 내부 테이블 자동 생성

agent = create_agent(
    model=model,
    tools=[get_user_info, save_user_info],
    context_schema=MyContext,
    store=store,  # InMemoryStore → PostgresStore 교체만 하면 됨
)
```

---

##  6. 정리

---

04장에서 배운 핵심 내용을 한 줄씩 요약한다.

- Runtime은 에이전트 실행 환경(Context + Store + StreamWriter)이고, State는 에이전트가 만들어낸 결과물(Messages + ToolResults)이다.
- Context는 `@dataclass`로 스키마를 정의하고, `create_agent(context_schema=...)` + `invoke(..., context=...)` 패턴으로 주입한다.
- Node-style 훅(`@before_agent` 등)은 상태 조회·로깅에, Wrap-style 훅(`@wrap_model_call`)은 `request.override()`로 모델에 전달되는 내용을 직접 수정할 때 사용한다.
- `@before_agent(can_jump_to="end")`로 LLM 호출 없이 즉시 고정 응답을 반환하고 실행을 종료할 수 있다. 반드시 `"jump": "end"` 키를 리턴값에 포함해야 한다.
- 가드레일은 결정론적(키워드 매칭, 빠름·무료)과 모델 기반(LLM 평가, 느림·비용 발생)으로 나뉜다. 두 방식을 레이어로 쌓으면 다층 방어막이 완성된다.
- 장기 메모리는 `Store + Namespace(튜플) + Key` 구조로 관리한다. `put()`으로 저장, `get()`으로 단건 조회, `search()`로 전체 조회한다.
- 저장·조회를 Tool로 만들면 개발자가 직접 `put()`하는 대신 LLM이 스스로 판단해 장기 메모리를 자동으로 관리하는 에이전틱 메모리 시스템이 완성된다.

---

## 참고 자료

- 위키독스 - AI 에이전트는 이렇게 만든다: <https://wikidocs.net/book/19240>
- LangChain 공식 문서 - Runtime: <https://python.langchain.com/docs/concepts/runtime/>
- LangChain 공식 문서 - Custom Middleware: <https://python.langchain.com/docs/concepts/middleware/#custom-middleware>
- LangChain 공식 문서 - Guardrails: <https://python.langchain.com/docs/concepts/guardrails/>
- LangGraph Store - InMemoryStore: <https://langchain-ai.github.io/langgraph/reference/store/>
- Andrej Karpathy - Context Engineering: <https://x.com/karpathy/status/1937902205765607626>
