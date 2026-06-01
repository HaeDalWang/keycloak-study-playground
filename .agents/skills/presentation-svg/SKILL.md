---
name: presentation-svg
description: HTML 슬라이드 프레젠테이션 제작 패턴. 간결한 레이아웃 + SVG 일러스트로 기술 개념을 시각화하는 방법. 이 프로젝트에서 직접 겪은 실패 사례와 해결책 포함.
version: 1.0.0
source: keycloak-ezl-session
---

# Presentation SVG Skill

이 프로젝트의 프레젠테이션(`presentation/keycloak-iam.html`)을 만들면서 정립한 패턴.
새 슬라이드를 추가하거나 기존 슬라이드를 수정할 때 이 가이드를 따른다.

---

## 슬라이드 구조

### 기본 레이아웃 (img-layout)

텍스트 + SVG 일러스트를 좌우로 배치하는 표준 레이아웃.

```html
<section class="slide" data-i="N">
  <div class="img-layout">
    <div class="text-side">
      <div class="label">NN · CATEGORY</div>
      <h2>제목 <span class="blue">강조</span></h2>
      <ul class="bullets">
        <li>핵심 포인트 1</li>
        <li>핵심 포인트 2</li>
      </ul>
      <div class="callout">핵심 메시지</div>
      <!-- 또는 -->
      <p class="next">→ <span>다음 슬라이드 연결 문장</span></p>
    </div>
    <div class="img-side">
      <svg viewBox="0 0 260 240" xmlns="http://www.w3.org/2000/svg"
           style="width:100%;max-height:min(52vh,380px)">
        <!-- SVG 내용 -->
      </svg>
    </div>
  </div>
</section>
```

### SVG 전용 레이아웃 (다이어그램 중심)

텍스트 없이 SVG가 메인인 슬라이드 (예: RBAC 슬라이드).

```html
<section class="slide" data-i="N">
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:clamp(1.5rem,4vw,4rem);align-items:center;height:100%">
    <div>
      <div class="label">NN · CATEGORY</div>
      <h2>제목</h2>
      <ul class="bullets">...</ul>
    </div>
    <div style="display:flex;align-items:center;justify-content:center">
      <svg viewBox="0 0 300 195" ...>
        <!-- SVG 내용 -->
      </svg>
    </div>
  </div>
</section>
```

---

## SVG 제작 규칙

### viewBox 설정

```
img-layout 슬라이드:  viewBox="0 0 260 240"  (표준)
                      viewBox="0 0 320 248"  (좌우 패널 비교형)
SVG 전용 슬라이드:    viewBox="0 0 300 195"  (표준)
                      viewBox="0 0 320 230"  (여유 필요시)
```

**핵심 규칙**: 마지막 요소의 y좌표 + 높이 + 최소 10px 여백 = viewBox 높이.
여백 없이 딱 맞추면 반드시 잘린다.

### 색상 팔레트

```
파란색 (주요/인증):  #1a56db  배경: #eff6ff
초록색 (허용/좋음):  #16a34a  배경: #f0fdf4
빨간색 (위험/나쁨):  #dc2626  배경: #fee2e2  #fff1f2
주황색 (토큰/경고):  #d97706  배경: #fef3c7  #fff7ed
보라색 (그룹/역할):  #9333ea  배경: #fdf4ff
회색 (설명 텍스트):  #6b7280
어두운 텍스트:       #374151
테두리:              #e5e7eb
```

### 폰트 크기 기준

```
제목/강조:    font-size="12-13"  font-weight="700"
본문 라벨:    font-size="10-11"
설명 텍스트:  font-size="9"
보조 설명:    font-size="7-8"
```

폰트 패밀리:
- 코드/태그: `font-family="JetBrains Mono,monospace"`
- 일반 텍스트: `font-family="Space Grotesk,sans-serif"`

---

## 화살표 제작 — 실패 사례와 해결책

### ❌ 나쁜 예: 대각선 화살표

```xml
<!-- 이렇게 하면 polygon 좌표 계산이 틀리기 쉽고 겹침 발생 -->
<line x1="108" y1="148" x2="198" y2="72" stroke="#16a34a" stroke-width="1"/>
<polygon points="194,68 200,74 194,78" fill="#16a34a"/>
```

**문제**: 대각선 끝점에서 화살촉 방향 계산이 복잡하고 틀리기 쉬움.
여러 대각선이 교차하면 가독성 0.

### ✅ 좋은 예: 수평/수직 화살표만 사용

```xml
<!-- 오른쪽 방향 화살표 -->
<line x1="58" y1="60" x2="94" y2="60" stroke="#1a56db" stroke-width="2"/>
<polygon points="90,55 96,60 90,65" fill="#1a56db"/>

<!-- 왼쪽 방향 화살표 -->
<line x1="246" y1="63" x2="224" y2="63" stroke="#d97706" stroke-width="1.5"/>
<polygon points="228,59 222,63 228,67" fill="#d97706"/>

<!-- 아래 방향 화살표 -->
<line x1="150" y1="44" x2="150" y2="62" stroke="#1a56db" stroke-width="2"/>
<polygon points="144,58 150,68 156,58" fill="#1a56db"/>
```

**화살촉 polygon 공식**:
```
오른쪽: points="(끝x-6),(끝y-5) (끝x),(끝y) (끝x-6),(끝y+5)"
왼쪽:   points="(끝x+6),(끝y-5) (끝x),(끝y) (끝x+6),(끝y+5)"
아래:   points="(끝x-6),(끝y-10) (끝x),(끝y) (끝x+6),(끝y-10)"
위:     points="(끝x-6),(끝y+10) (끝x),(끝y) (끝x+6),(끝y+10)"
```

---

## 텍스트 박스 크기 계산

### ❌ 나쁜 예: 박스가 텍스트보다 작음

```xml
<!-- "PW DB" + "⚠ 해킹 위험" 두 줄인데 height=20은 너무 작음 -->
<rect x="64" y="46" width="38" height="20" rx="4" .../>
<text x="83" y="57">PW DB</text>
<text x="83" y="67">⚠ 해킹 위험</text>  <!-- 박스 밖으로 탈출 -->
```

### ✅ 좋은 예: 텍스트 줄 수 × 줄 간격 + 상하 패딩

```
한 줄 텍스트:  height = 22-24px
두 줄 텍스트:  height = 34-36px
세 줄 텍스트:  height = 48-52px

텍스트 y좌표 = rect y + 16 (첫 줄)
다음 줄 y좌표 = 첫 줄 y + 14
```

```xml
<!-- 두 줄 텍스트 박스 -->
<rect x="74" y="48" width="70" height="34" rx="4" fill="#fee2e2" stroke="#dc2626" stroke-width="1.5"/>
<text x="109" y="62" text-anchor="middle" font-size="8">PW DB</text>
<text x="109" y="76" text-anchor="middle" font-size="7">⚠ 해킹 위험</text>
```

---

## 레이아웃 패턴별 SVG 템플릿

### 패턴 1: 좌우 비교형 (기존 방식 vs 새 방식)

```xml
<svg viewBox="0 0 320 248" xmlns="http://www.w3.org/2000/svg"
     style="width:100%;max-height:min(52vh,380px)">

  <!-- 왼쪽 패널 (나쁜 예) -->
  <rect x="6" y="6" width="146" height="164" rx="7" fill="#fff1f2" stroke="#dc2626" stroke-width="1.5"/>
  <text x="79" y="24" text-anchor="middle" font-size="10" font-weight="700" fill="#dc2626">기존 방식</text>
  <!-- 내용 -->

  <!-- 오른쪽 패널 (좋은 예) -->
  <rect x="162" y="6" width="152" height="164" rx="7" fill="#f0fdf4" stroke="#16a34a" stroke-width="1.5"/>
  <text x="238" y="24" text-anchor="middle" font-size="10" font-weight="700" fill="#16a34a">새 방식</text>
  <!-- 내용 -->

  <!-- 구분선 -->
  <line x1="6" y1="180" x2="314" y2="180" stroke="#e5e7eb" stroke-width="1" stroke-dasharray="3,3"/>

  <!-- 하단 설명 박스 (왼쪽) -->
  <rect x="6" y="186" width="146" height="56" rx="5" fill="#fee2e2" stroke="#dc2626" stroke-width="1"/>
  <text x="79" y="202" text-anchor="middle" font-size="8" font-weight="700" fill="#dc2626">문제점</text>
  <text x="79" y="216" text-anchor="middle" font-size="7" fill="#374151">설명 텍스트</text>

  <!-- 하단 설명 박스 (오른쪽) -->
  <rect x="162" y="186" width="152" height="56" rx="5" fill="#f0fdf4" stroke="#16a34a" stroke-width="1"/>
  <text x="238" y="202" text-anchor="middle" font-size="8" font-weight="700" fill="#16a34a">장점</text>
  <text x="238" y="216" text-anchor="middle" font-size="7" fill="#374151">설명 텍스트</text>
</svg>
```

### 패턴 2: 허브-스포크형 (1개 중심 → 여러 연결)

```xml
<svg viewBox="0 0 280 240" xmlns="http://www.w3.org/2000/svg"
     style="width:100%;max-height:min(52vh,380px)">

  <!-- 왼쪽: 사람/입력 -->
  <circle cx="44" cy="46" r="20" fill="#eff6ff" stroke="#1a56db" stroke-width="2"/>
  <circle cx="44" cy="46" r="11" fill="#1a56db"/>
  <text x="44" y="78" text-anchor="middle" font-size="10" fill="#6b7280">사용자</text>

  <!-- 중앙: 허브 -->
  <circle cx="140" cy="120" r="28" fill="#1a56db"/>
  <text x="140" y="116" text-anchor="middle" font-size="11" font-weight="700" fill="#fff">허브</text>
  <text x="140" y="130" text-anchor="middle" font-size="8" fill="#bfdbfe">설명</text>

  <!-- 오른쪽: 스포크들 (수평 화살표만) -->
  <rect x="200" y="28" width="66" height="26" rx="5" fill="#f0fdf4" stroke="#16a34a" stroke-width="1.5"/>
  <text x="233" y="45" text-anchor="middle" font-size="10" fill="#16a34a">항목 1</text>
  <!-- 반복 -->
</svg>
```

### 패턴 3: 계층형 (위→아래 흐름)

```xml
<svg viewBox="0 0 300 195" xmlns="http://www.w3.org/2000/svg"
     style="width:100%;max-height:min(42vh,300px)">

  <!-- 최상위 박스 -->
  <rect x="90" y="8" width="120" height="36" rx="6" fill="#eff6ff" stroke="#1a56db" stroke-width="2"/>
  <text x="150" y="30" text-anchor="middle" font-size="12" font-weight="700" fill="#1a56db">최상위</text>

  <!-- 수직 화살표 -->
  <line x1="150" y1="44" x2="150" y2="62" stroke="#1a56db" stroke-width="2"/>
  <polygon points="144,58 150,68 156,58" fill="#1a56db"/>

  <!-- 중간 박스 -->
  <rect x="90" y="68" width="120" height="36" rx="6" fill="#fdf4ff" stroke="#9333ea" stroke-width="2"/>
  <text x="150" y="90" text-anchor="middle" font-size="12" font-weight="700" fill="#9333ea">중간</text>

  <!-- 부채꼴 연결선 (수직선에서 분기) -->
  <line x1="150" y1="104" x2="60" y2="128" stroke="#9333ea" stroke-width="1.5" opacity=".45"/>
  <line x1="150" y1="104" x2="150" y2="128" stroke="#9333ea" stroke-width="1.5" opacity=".45"/>
  <line x1="150" y1="104" x2="240" y2="128" stroke="#9333ea" stroke-width="1.5" opacity=".45"/>
</svg>
```

### 패턴 4: 레이어 스택형 (확장 관계)

```xml
<svg viewBox="0 0 260 240" xmlns="http://www.w3.org/2000/svg"
     style="width:100%;max-height:min(52vh,380px)">

  <!-- 상위 레이어 (확장) -->
  <rect x="14" y="14" width="232" height="116" rx="7" fill="#f0fdf4" stroke="#16a34a" stroke-width="2"/>
  <text x="130" y="34" text-anchor="middle" font-size="11" font-weight="700" fill="#16a34a">확장 레이어</text>
  <!-- 내용 박스 -->
  <rect x="26" y="42" width="208" height="78" rx="5" fill="#fff" stroke="#16a34a" stroke-width="1"/>

  <!-- 확장 화살표 (위 방향) -->
  <line x1="130" y1="138" x2="130" y2="130" stroke="#16a34a" stroke-width="2"/>
  <polygon points="124,132 130,126 136,132" fill="#16a34a"/>

  <!-- 하위 레이어 (기반) -->
  <rect x="14" y="140" width="232" height="56" rx="7" fill="#eff6ff" stroke="#1a56db" stroke-width="2"/>
  <text x="130" y="160" text-anchor="middle" font-size="11" font-weight="700" fill="#1a56db">기반 레이어</text>
</svg>
```

---

## 절대 하지 말 것

| 금지 사항 | 이유 | 대안 |
|-----------|------|------|
| SVG 내 이모지 (`🔑`, `🎫`) | 브라우저/OS마다 렌더링 다름 | 작은 원 + 텍스트로 대체 |
| 대각선 화살표 여러 개 교차 | 겹쳐서 가독성 0 | 수평/수직만 사용 |
| viewBox 높이를 마지막 요소에 딱 맞춤 | 잘림 | +10~20px 여유 |
| 박스 width를 텍스트 길이보다 작게 | 텍스트 탈출 | 텍스트 길이 × 폰트크기 × 0.6 + 패딩 |
| 방사형 레이아웃 (원형 배치) | 연결선 계산 복잡, 겹침 | 세로 목록 + 수평 화살표 |
| 한 SVG에 요소 10개 이상 | 복잡해서 반드시 오류 | 핵심 3~5개만 |

---

## 슬라이드 흐름 원칙

1. **문제 제시** → 개념 설명 → 해결책 순서
2. 각 슬라이드는 **하나의 메시지**만
3. `callout`: 슬라이드의 결론 한 줄
4. `next`: 다음 슬라이드로 자연스럽게 연결하는 질문
5. SVG는 텍스트를 **보완**하는 것이지 대체하는 게 아님 — 텍스트만 봐도 이해 가능해야 함

---

## 검증 체크리스트

SVG 작성 후 확인:

- [ ] 모든 텍스트가 viewBox 안에 있는가?
- [ ] 화살표가 수평/수직인가? (대각선 최소화)
- [ ] 박스 높이가 텍스트 줄 수에 맞는가?
- [ ] 이모지를 사용하지 않았는가?
- [ ] viewBox 높이에 여백이 있는가?
- [ ] 한 SVG에 요소가 10개 이하인가?
- [ ] 색상이 팔레트에서 벗어나지 않는가?
