---
title: "[자바 ORM 표준 JPA 프로그래밍 - 기본편] 연관관계 매핑 기초"
date: 2024-09-11T16:47:33+09:00
# weight: 1
# aliases: ["/first"]
tags: ["JPA"]
author: "yosong6729"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: true
disableHLJS: false # to disable highlightjs
disableShare: true
hideSummary: false
searchHidden: true
ShowReadingTime: false
ShowBreadCrumbs: true
ShowPostNavLinks: true
ShowWordCount: false
ShowRssButtonInSectionTermList: true
UseHugoToc: false
---

해당 글은 김영한님의 인프런 강의 [자바 ORM 표준 JPA 프로그래밍 - 기본편](https://www.inflearn.com/course/ORM-JPA-Basic)을 듣고 내용을 정리하기 위한 것으로 자세한 설명은 해당 강의를 통해 확인할 수 있습니다.

## 연관관계가 필요한 이유

‘객체지향 설계의 목표는 자율적인 **객체들의 협력 공동체**를 만드는 것이다.’  
– 조영호(객체지향의 사실과 오해) -

### 예제 시나리오

- 회원과 팀이 있다.
- 회원은 하나의 팀에만 소속될 수 있다.
- 회원과 팀은 다대일 관계다.

### 객체를 테이블에 맞추어 모델링

![image.png](images/객체를%20테이블에%20맞추어%20모델링.png)

연관관계가 없는 객체이다.


```java
@Entity
public class Member { 
  @Id @GeneratedValue
  private Long id;
  @Column(name = "USERNAME")
  private String name;
  @Column(name = "TEAM_ID")
  private Long teamId; 
  … 
} 
@Entity
public class Team {
  @Id @GeneratedValue
  private Long id;
  private String name; 
  … 
}
```
참조 대신에 외래 키를 그대로 사용한다.


```java
 //팀 저장
 Team team = new Team();
 team.setName("TeamA");
 em.persist(team); //영속상태가 되면 무조건 pk값이 세팅되고 영속 상태가됨
 //회원 저장
 Member member = new Member();
 member.setName("member1");
 **member.setTeamId(team.getId());**
 em.persist(member);
```
외래 키 식별자를 직접 다룬다.
setTeamId()로 외래 키를 다루는것은 객체지향스럽지 않다.

> 식별자로 다시 조회, 객체 지향적인 방법은 아니다.
> 

```java
//조회
Member findMember = em.find(Member.class, member.getId()); 
//연관관계가 없음
Team findTeam = em.find(Team.class, team.getId()); 
```

**객체를 테이블에 맞추어 데이터 중심으로 모델링 하면, 협력 관계를 만들 수 없다**.

- **테이블은 외래 키로 조인**을 사용해서 연관된 테이블을 찾는다.
- **객체는 참조**를 사용해서 연관된 객체를 찾는다.
- 테이블과 객체 사이에는 이런 큰 간격이 있다.

## 단방향 연관관계

### 객체 지향 모델링

**객체 연관관계 사용**

![image.png](images/객체%20연관관계%20사용.png)

Member에 Team의 id가 아니라 Team의 참조값을 그대로 가져온다.

```java
@Entity
public class Member { 
  @Id @GeneratedValue
  private Long id;
  @Column(name = "USERNAME")
  private String name;
  private int age;
 //  @Column(name = "TEAM_ID")
 //  private Long teamId;
  @ManyToOne
  @JoinColumn(name = "TEAM_ID")
  private Team team;
  …
```
**객체의 참조와 테이블의 외래 키를 매핑**  
하나의 팀에 여러 멤버가 소속되기 때문에 private Team team;에 @ManyToOne을 사용하여 매핑해준다.  
객체 연관관계의 Team team과 테이블 연관관계 TEAM_ID(FK)를 매핑하기 위해 @JoinColumn(name = “TEAM_ID”)를 사용하여 매핑해준다.


![image.png](images/ORM%20매핑.png)
**ORM 매핑**  
객체의 Team과 테이블 TEAM_ID를 매핑을 하면 위 사진 처럼 된다고 이해하면 된다. 

**연관관계 저장**

```java
//팀 저장
Team team = new Team();
team.setName("TeamA");
em.persist(team);
//회원 저장
Member member = new Member();
member.setName("member1");
**member.setTeam(team); //단방향 연관관계 설정, 참조 저장**
em.persist(member);
```

member.setTeam(team)을 하게되면 jpa가 알아서 팀에서 PK값을 꺼내서 FK 값에 insert할떄 FK값을 사용한다.

**참조로 연관관계 조회 - 객체 그래프 탐색**

```java
//조회
Member findMember = em.find(Member.class, member.getId()); 
//참조를 사용해서 연관관계 조회
Team findTeam = findMember.getTeam();
```

findMember.getTeam()으로 findMember의 Team을 바로 가져올수 있게된다.

**연관관계 수정**

```java
// 새로운 팀B
Team teamB = new Team();
teamB.setName("TeamB");
em.persist(teamB);
// 회원1에 새로운 팀B 설정
**member.setTeam(teamB);**
```

setTeam()을 사용하여 팀을 바꿀수 있고 DB의 외래키 값이 업데이트 된다. 이런 방식으로 연관관계를 수정할 수 있다.

## 양방향 연관관계와 연관관계의 주인

### 양방향 매핑

![image.png](images/양방향%20매핑.png)

이전 예제에서는 Member가 Team을 가져서 Member에서 Team으로는 갈수 있지만 Team에서는 Member로 갈수있는 방법이 없었다. 그래서 Team에 List member를 추가해주어서 양방향으로 만들어 주었다.

테이블은 외래키 하나만 넣어주면 양쪽으로 다 볼수있다는 점이 객체 참조와 테이블의 외래키의 가장 큰 차이점이다.

**Member 엔티티는 단방향과 동일**

```java
@Entity
public class Member { 
  @Id @GeneratedValue
  private Long id;
  @Column(name = "USERNAME")
  private String name;
  private int age;
  @ManyToOne
  @JoinColumn(name = "TEAM_ID")
  private Team team;
  …
```

**Team 엔티티는 컬렉션 추가**

```java
@Entity
public class Team {
  @Id @GeneratedValue
  private Long id;
  private String name;
  @OneToMany(mappedBy = "team")
  List<Member> members = new ArrayList<Member>();
  … 
}
```

하나의 Team에는 여러 Member가 포함되어 있기 떄문에 List타입으로 member를 만들고 @OneToMany를 사용한다. members가 Member객체의 team 변수명과 연결되어 있다는 것을 (mappedBy = “team”)으로 표시한다.

**반대 방향으로 객체 그래프 탐색**

```java
//조회
Team findTeam = em.find(Team.class, team.getId()); 
int memberSize = findTeam.getMembers().size(); //역방향 조회
```

양방향 연관관계로 findTeam.getMembers()로 역방향으로 값을 가져올수 있게 된다.

### 연관관계의 주인과 mappedBy

- mappedBy = JPA의 멘탈붕괴 난이도
- mappedBy는 처음에는 이해하기 어렵다.
- 객체와 테이블간에 연관관계를 맺는 차이를 이해해야 한다.

### 객체와 테이블이 관계를 맺는 차이

- 객체 연관관계 = 2개
    - 회원 -> 팀 연관관계 1개(단방향)
    - 팀 -> 회원 연관관계 1개(단방향)
- 테이블 연관관계 = 1개
    - 회원 ↔ 팀의 연관관계 1개(양방향)

![image.png](images/객체와%20테이블이%20관계를%20맺는%20차이.png)

### 객체의 양방향 관계

- 객체의 **양방향 관계는 사실 양방향 관계가 아니라 서로 다른 단방향 관계 2개다.**
- 객체를 양방향으로 참조하려면 **단방향 연관관계를 2개** 만들어야 한다.
- A → B (a.getB())

```java
class A {
    B b;    
}
```

- B → A (b.geA())

```java
class B {
    A a;
}
```

### 테이블의 양방향 연관관계

- 테이블은 **외래 키 하나**로 두 테이블의 연관관계를 관리
- MEMBER.TEAM_ID 외래 키 하나로 양방향 연관관계 가짐(양쪽으로 조인할 수 있다.)

```sql
SELECT * 
FROM MEMBER M
JOIN TEAM T ON M.TEAM_ID = T.TEAM_ID
// 반대 가능
SELECT * 
FROM TEAM T
JOIN MEMBER M ON T.TEAM_ID = M.TEAM_ID
```

### 둘 중 하나로 외래 키를 관리해야 한다.

![외래키 주인](images/외래키%20관리.png)

내가 멤버를 바꾸고 싶거나 다른 새로운 팀에 들어가고 싶을때 멤버의 팀의 값을 바꿔야 될지, 팀에 있는 List members를 바꿔야 할지 고민이다. 

이런 고민을 덜기 위해서 둘 중 하나를 주인을 정하는 것이 **연관관계의 주인**이다.

### 연관관계의 주인(Owner)

**양방향 매핑 규칙**

- 객체의 두 관계중 하나를 연관관계의 주인으로 지정
- **연관관계의 주인만이 외래 키를 관리(등록, 수정)**
- **주인이 아닌쪽은 읽기만 가능**
- 주인은 mappedBy 속성 사용X
- **주인이 아니면 mappedBy 속성으로 주인 지정**

### 누구를 주인으로?

- **외래 키가 있는 있는 곳을 주인으로 정해라**
- 여기서는 Member.team이 연관관계의 주인

![image.png](images/외래키%20주인.png)

List members에 값을 넣어도 변화가 생기지 않고 값을 조회하는 것은 가능하다. DB에 없데이트 하거나 값을 넣을 경우에 Member 객체의 Team team을 참조한다.

### 양방향 매핑시 가장 많이 하는 실수

연관 관계의 주인에 값을 입력하지 않는다.

```java
Team team = new Team();
team.setName("TeamA");
em.persist(team);
Member member = new Member();
member.setName("member1");
//역방향(주인이 아닌 방향)만 연관관계 설정
team.getMembers().add(member);
em.persist(member);
```

![image.png](images/양방향%20매핑%20실수.png)

역방향(주인이 아닌 방향)에만 member를 추가하게 된다면 DB에는 Member의 Team이 저장 되지 않는다.

### 양방향 매핑시 연관관계의 주인에 값을 입력해야 한다.

```java
Team team = new Team();
team.setName("TeamA");
em.persist(team);
Member member = new Member();
member.setName("member1");
team.getMembers().add(member); 
//연관관계의 주인에 값 설정 
member.setTeam(team); //**
em.persist(member);
```

![image.png](images/연관관계의%20주인%20입력.png)

연관관계의 주인에 값을 설정하게 되면 DB에 값이 저장된다.

> 순수한 객체 관계를 고려하면 항상 양쪽다 값을 입력해야 한다.
> 

### 양방향 연관관계 주의

- **순수 객체 상태를 고려해서 항상 양쪽에 값을 설정하자**
- 연관관계 편의 메소드를 생성하자
- 양방향 매핑시 무한 루프를 조심하자
    - 예: toString(), lombok, JSON 생성 라이브러리

### 양방향 매핑 정리

- **단방향 매핑만으로도 이미 연관관계 매핑은 완료**
- 양방향 매핑은 반대 방향으로 조회(객체 그래프 탐색) 기능이 추가 된 것 뿐
- JPQL에서 역방향으로 탐색할 일이 많음
- 단방향 매핑을 잘 하고 양방향은 필요할 때 추가해도 됨(테이블에 영향을 주지 않음)

### 연관관계의 주인을 정하는 기준

- 비즈니스 로직을 기준으로 연관관계의 주인을 선택하면 안됨
- **연관관계의 주인은 외래 키의 위치를기준으로 정해야함**

## 실전 예제 - 2. 연관관계 매핑 시작

### 테이블 구조

![image.png](images/테이블%20구조.png)

테이블 구조는 이전과 같다.

### 객체 구조

![image.png](images/객체%20구조.png)

참조를 사용하도록 변경한다.

> 예제 코드는 김영한님의 인프런 강의 [자바 ORM 표준 JPA 프로그래밍 - 기본편](https://www.inflearn.com/course/ORM-JPA-Basic)에서 확인 할수 있습니다.
>