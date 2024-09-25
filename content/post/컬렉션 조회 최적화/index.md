---
title: "컬렉션 조회 최적화"
date: 2024-09-25T20:34:54+09:00
# weight: 1
# aliases: ["/first"]
tags: ["spring boot", "JPA"]
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

> 해당 글은 김영한님의 인프런 강의 [스프링부트와 JPA활용2 - API 개발과 성능 최적화](https://www.inflearn.com/course/%EC%8A%A4%ED%94%84%EB%A7%81%EB%B6%80%ED%8A%B8-JPA-API%EA%B0%9C%EB%B0%9C-%EC%84%B1%EB%8A%A5%EC%B5%9C%EC%A0%81%ED%99%94)을 듣고 내용을 정리하기 위한 것으로 자세한 설명은 해당 강의를 통해 확인할 수 있습니다.
> 

---

주문내역에서 추가로 주문한 상품 정보를 추가로 조회를 한다.

Order 기준으로 컬렉션인 OrderItem와 Item이 필요하다.

컬렉션인 일대다 관계(OneToMany)를 조회하고 최적화 하는 방법을 알아본다.

## 주문 조회 V1: 엔티티 직접노출

```java
@RestController
@RequiredArgsConstructor
public class OrderApiController {

    private final OrderRepository orderRepository;
    
		/**
     * V1. 엔티티 직접 노출
     * - Hibernate5Module 모듈 등록, LAZY=null 처리
     * - 양방향 관계 문제 발생 -> @JsonIgnore
     */
    @GetMapping("/api/v1/orders")
    public List<Order> ordersV1() {
        List<Order> all = orderRepository.findAllByString(new OrderSearch());
        for (Order order : all) {
            order.getMember().getName(); //Lazy 강제 초기화
            order.getDelivery().getAddress(); //Lazy 강제 초기화
            List<OrderItem> orderItems = order.getOrderItems();
            orderItems.stream().forEach(o -> o.getItem().getName()); //Lazy 강제 초기화
        }
        return all;
    }
}
```

Lazy 강제 초기화하면 Hibernate5module 설정에 의해 엔티티를 JSON으로 생성하고 양방향 연관관계면 무한루프가 걸리지 않게 한쪽에 @JsonIgnore을 추가해야 한다.

위 방법은 엔티티를 직접 노출하므로 좋은 방법이 아니다.

---

## 주문 조회 V2: 엔티티를 DTO로 변환

```java
@GetMapping("/api/v2/orders")
public List<OrderDto> ordersV2() {
    List<Order> orders = orderRepository.findAllByString(new OrderSearch());
    List<OrderDto> result = orders.stream()
            .map(o -> new OrderDto(o))
            .collect(Collectors.toList());

    return result;
}
```

**OrderApiController에 추가**

```java
@Data
static class OrderDto {

    private Long orderId;
    private String name;
    private LocalDateTime orderDate;
    private OrderStatus orderStatus;
    private Address address;
    private List<OrderItemDto> orderItems; //엔티티 외부 노출 하면 안됨, OrderItemDto로 수정

    public OrderDto(Order order) {
        orderId = order.getId();
        name = order.getMember().getName();
        orderDate = order.getOrderDate();
        orderStatus = order.getStatus();
        address = order.getDelivery().getAddress();
        orderItems = order.getOrderItems().stream()
                .map(orderItem -> new OrderItemDto(orderItem))
                .collect(Collectors.toList());
    }
}

@Getter
static class OrderItemDto {

    private String itemName; //상품 명
    private int orderPrice; //주문 가격
    private int count; //주문 수량

    public OrderItemDto(OrderItem orderItem) {
        itemName = orderItem.getItem().getName();
        orderPrice = orderItem.getOrderPrice();
        count = orderItem.getCount();
    }
}
```

- 지연로딩으로 많은 SQL 실행
- SQL 실행수
    - order 1번
    - member, address N번
    - orderItem N번
    - item N번

---

## 주문 조회 V3: 엔티티를 DTO로 변환 - 페치 조인 최적화

OrderApiController에 추가

```java
@GetMapping("/api/v3/orders")
public List<OrderDto> ordersV3() {
    List<Order> orders = orderRepository.findAllWithItem();

    List<OrderDto> result = orders.stream()
            .map(o -> new OrderDto(o))
            .collect(Collectors.toList());

    return result;
}
```

OrderRepository에 추가

```java
public List<Order> findAllWithItem() {
    return em.createQuery(
                    "select distinct o from Order o" +
                            " join fetch o.member m" +
                            " join fetch o.delivery d" +
                            " join fetch o.orderItems oi" +
                            " join fetch oi.item i", Order.class)
            .getResultList();

}
```

> 스프링 부트 3버전대, 정확히는 하이버네이트 6버전을 사용하시면서 자동으로 distinct가 적용
> 
- 페치 조인으로 SQL 1번 실행
- orderItems로 인해 일대다 조인이 되서 데이터베이스 row가 증가해서 order 엔티티 수도 증가하낟. JPA의 distinct는 SQL에 distinct를 추가하고, 같은 엔티티가 조회되면 애플리케이션에서 중복을 걸러준다.
- 단점
    - **페이징 불가능**(메모리에서 페이징 실행)
    
    > 컬렉션 페치 조인을 사용하면 페이징이 불가능하다. 하이버네이트는 경고 로그를 남기면서 모든 데이터를 DB에서 읽어오고, 메모리에서 페이징 해버린다(매우 위험하다)
    > 

> 컬렉션 페치 조인은 1개만 사용할 수 있다. 컬렉션 둘 이상에 페치 조인을 사용하면 안된다. 데이터가 부정합하게 조회될 수 있다.
> 

---

## 주문 조회 V3.1: 엔티티를 DTO로 변환 - 페이징과 한계 돌파

### 한계 돌파

페이징과 컬렉션 엔티티를 함께 조회하려면 어떻게 해야하나?

- 먼저 ToOne 관계를 모두 페치조인 한다. ToOne 관계는 row수를 증가시키지않아 페이징 쿼리에 영향X
- 컬렉션은 지연로딩으로 조회
- 지연 로딩 성능 최적화를 위해 `hibernate.default_batch_fetch_size(글로벌 설정)`, `@BatchSize(개별 최적화)`를 적용한다.
    - 이 옵션을 사용하면 컬렉션이나, 프록시 객체를 한꺼번에 설정한 size 만큼 IN 쿼리로 조회

**OrderRepository에 추가**

```java
public List<Order> findAllWithMemberDelivery(int offset, int limit) {
    return em.createQuery(
                    "select o from Order o" +
                            " join fetch o.member m" +
                            " join fetch o.delivery d", Order.class
            ).setFirstResult(offset)
            .setMaxResults(limit)
            .getResultList();
}
```

**OrderApiController에 추가**

```java
@GetMapping("/api/v3.1/orders")
public List<OrderDto> ordersV3_page(
        @RequestParam(value = "offset", defaultValue = "0") int offset,
        @RequestParam(value = "limit", defaultValue = "100") int limit) {

    List<Order> orders = orderRepository.findAllWithMemberDelivery(offset, limit);

    List<OrderDto> result = orders.stream()
            .map(o -> new OrderDto(o))
            .collect(Collectors.toList());

    return result;
}
```

**최적화 옵션**

```yaml
spring:
	jpa:
		properties:
			hibernate:
				default_batch_fetch_size: 1000
```

개별로 설정하려면 컬렉션은 컬렉션 필드에, 엔티티는 엔티티 클래스에 `@BatchSize`를 적용하면 된다.

@GetMapping("/api/v3.1/orders")가 실행되면 아래처럼 쿼리가 나간다.

?가 배치사이즈 만큼 채워지는건 배치 사이즈 만큼 ?토큰이 다 채워진 쿼리를 재사용는거 같기 때문이다.

```sql
select
    oi1_0.order_id,
    oi1_0.order_item_id,
    oi1_0.count,
    oi1_0.item_id,
    oi1_0.order_price 
from
    order_item oi1_0 
where
    oi1_0.order_id in (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ....)
```

- 장점
    - 쿼리 호출 수가 1 + N → 1 + 1로 최적화
    - 조인보다 DB 데이터 전송량이 최적화(Order와 OrderItem을 조인하면 Order가 OrderItem 만큼 중복해서 조회된다. 이 방법은 각각 조회하므로 전송해야할 중복 데이터가 없다.)
    - 페치 조인 방식과 비교해서 쿼리 호출 수가 약간 증가하지만, DB 데이터 전송량이 감소
    - **컬렉션 페치 조인은 페이징이 불가능 하지만 이 방법은 페이징이 가능**
- 결론
    - ToOne 관계는 페치 조인해도 페이징에 영향X, 따라서 ToOne 관계는 페치조인으로 쿼리수 감소하고, 나머지는 `hibernate.default_batch_fetch_size` 로 최적화

> 참고:`default_batch_fetch_size`의 크기는 적당한 사이즈를 골라야 하는데, 100~1000 사이를 선택하는 것을 권장한다. 이 전략을 SQL IN 절을 사용하는데, 데이터베이스에 따라 IN 절 파라미터를 1000으로 제한하기도 한다. 1000으로 잡으면 한번에 1000개를 DB에서 애플리케이션에 불러오므로 DB에 순간 부하가 증가할 수 있다. 하지만 애플리케이션은 100이든 1000이든 결국 전체 데이터를 로딩해야 하므로 메모리 사용량이 같다. 1000으로 설정하는 것이 성능상 가장 좋지만, 결국 DB든 애플리케이션이든 순간 부하를 어디까지 견딜 수 있는지로 결정하면 된다.
> 

---

## 주문 조회 V4: JPA에서 DTO 직접 조회

**OrderApiController에 추가**

```java
@GetMapping("/api/v4/orders")
public List<OrderQueryDto> ordersV4(){
    return orderQueryRepository.findOrderQueryDtos();
}
```

**OrderQueryRepository**

```java
@Repository
@RequiredArgsConstructor
public class OrderQueryRepository {

    private final EntityManager em;

	    public List<OrderQueryDto> findOrderQueryDtos() {
		    //루트 조회(toOne 코드를 모두 한번에 조회)
        List<OrderQueryDto> result = findOrders();
				
				//루프를 돌면서 컬렉션 추가(추가 쿼리 실행)
        result.forEach(o ->{
            List<OrderItemQueryDto> orderItems = findOrderItems(o.getOrderId());
            o.setOrderItems(orderItems);
        });

        return result;
    }
		
		//1:N 관계인 orderItems 조회
    private List<OrderItemQueryDto> findOrderItems(Long orderId) {
        return em.createQuery(
                        "select new jpabook.jpashop.repository.order.query.OrderItemQueryDto(oi.order.id, i.name, oi.orderPrice, oi.count)" +
                                " from OrderItem oi" +
                                " join oi.item i" +
                                " where oi.order.id =: orderId", OrderItemQueryDto.class)
                .setParameter("orderId", orderId)
                .getResultList();

    }
		
		//1:N 관계(컬렉션)을 제외한 나머지 조회
    private List<OrderQueryDto> findOrders() {
        return em.createQuery(
                "select new jpabook.jpashop.repository.order.query.OrderQueryDto(o.id, m.name, o.orderDate, o.status, d.address)" +
                        " from Order o" +
                        " join o.member m" +
                        " join o.delivery d", OrderQueryDto.class
        ).getResultList();
    }
}
```

**OrderQueryDto**

```java
@Data
public class OrderQueryDto {

    private Long orderId;
    private String name;
    private LocalDateTime orderDate;
    private OrderStatus orderStatus;
    private Address address;
    private List<OrderItemQueryDto> orderItems;

    public OrderQueryDto(Long orderId, String name, LocalDateTime orderDate, OrderStatus orderStatus, Address address) {
        this.orderId = orderId;
        this.name = name;
        this.orderDate = orderDate;
        this.orderStatus = orderStatus;
        this.address = address;
    }
}
```

**OrderItemQueryDto**

```java
@Data
public class OrderItemQueryDto {

    @JsonIgnore
    private Long orderId;
    private String itemName;
    private int orderPrice;
    private int count;

    public OrderItemQueryDto(Long orderId, String itemName, int orderPrice, int count) {
        this.orderId = orderId;
        this.itemName = itemName;
        this.orderPrice = orderPrice;
        this.count = count;
    }
}
```

- 쿼리: 루트 1번, 컬렉션 N번
- xToOne 관계들을 먼저 조회, xToMany 관계는 각각 별도로 처리
- 위 방식을 선택한이유
    - xToOne 관계는 조인해도 데이터 row수 증가X
    - xToMany 관계는 조인하면 row수 증가
- row수가 증가하지 않는 ToONe 관계는 조인으로 최적화 하기 쉽기때문에 한번에 조회하고, ToMany 관계는 최적화가 어렵기때문에 findOrderItems()같은 별도의 메서드로 조회

---

## 주문 조회 V5: JPA에서 DTO 직접 조회 - 컬렉션 조회 최적화

---

## 주문 조회 V6: JPA에서 DTO로 직접 조회, 플랫 데이터 최적화

---

## 정리

---