# sh-skr-terraform-nodepool
## 1. 구성 목표

- 기존 AKS 클러스터는 건드리지 않고 신규 노드 풀만 추가
- state가 비어 있어도 클러스터 자체는 data source로 참조하여 안전하게 연결
- 테스트 목적이므로 최소 사양(저가 SKU, 단일 노드)으로 구성
- 이후 auto scaling 등 옵션 전환이 용이하도록 변수화

## 2. 파일 구조

| 파일 | 역할 |
| --- | --- |
| `provider.tf` | Terraform/azurerm provider 버전 및 backend 설정 |
| `variable.tf` | 노드 풀 정의를 위한 입력 변수(`node_pools`) 스키마 |
| `data.tf` | 기존 리소스 그룹 및 AKS 클러스터 조회 (data source) |
| `main.tf` | 신규 노드 풀 리소스 정의 (`azurerm_kubernetes_cluster_node_pool`) |
| `terraform.tfvars` | 실제 노드 풀 값 입력 (테스트용 최소 사양) |

## 3. 설계 포인트

### 3.1 data source를 통한 기존 리소스 참조

state에 정보가 없어도 Azure 상에는 AKS 클러스터가 이미 존재하므로, 클러스터를 생성 대상이 아닌 **조회 대상**으로 취급했다. `resource_group_name`과 `aks_cluster_name`을 `"rg명|클러스터명"` 형태의 문자열로 조합해 유니크 키를 만들고, 이를 통해 `data.azurerm_kubernetes_cluster.aks`를 조회한 뒤 `main.tf`에서 동일한 키로 인덱싱하여 `kubernetes_cluster_id`를 참조하는 구조로 구성했다.

### 3.2 for_each 순회 방식(set vs map) 정리

- `toset([...])`로 만든 set을 `for_each`에 사용하면 `each.key`와 `each.value`가 동일한 값을 가리킨다.
- `{ k => v }` 형태의 실제 map을 `for_each`에 사용하면 `each.key`는 원래의 키, `each.value`는 매핑된 객체를 가리킨다.
- 기존 Application Gateway 구성 코드의 스타일과 통일하기 위해, data.tf의 set 순회 부분은 `each.key`를 사용하도록 정리했다.

### 3.3 auto scaling 옵션 분기

`enable_auto_scaling` 값에 따라 `node_count`와 `min_count`/`max_count`가 상호 배타적으로 설정되도록 삼항 연산자로 분기 처리했다. 이는 auto scaling 활성화 시 고정 node_count를 함께 지정하면 충돌이 발생하는 것을 방지하기 위함이다. 또한 auto scaling 사용 시 Azure가 자체적으로 조정하는 node_count 값이 Terraform 상에서 drift로 감지되지 않도록 `lifecycle { ignore_changes = [node_count] }`를 적용했다.

### 3.4 azurerm Provider 버전 이슈 (v3 → v4)

최초 작성 시 `enable_auto_scaling` 인자를 사용했으나, 실제 환경의 azurerm provider 버전이 4.74.0으로 확인되어 `Unsupported argument` 오류가 발생했다. azurerm v4부터 `enable_*` 접두사 boolean 속성 다수가 리네이밍되었으며, 해당 인자는 `auto_scaling_enabled`로 변경되었다. provider.tf의 버전 제약도 `~> 4.0`으로 함께 수정했다.

> 참고: 변수 스키마(`variable.tf`)에서 정의한 `enable_auto_scaling`은 사용자 정의 변수명이므로 그대로 유지했으며, 실제 리소스 인자명만 수정 대상이었다.
> 

## 4. 실행 절차

1. `az login --use-device-code` — 헤드리스 서버 환경이라 device code 방식으로 인증
2. `az account set --subscription <구독ID>` — 대상 구독 지정
3. `terraform init`
4. `terraform plan` — 신규 노드 풀 1개만 생성(add) 대상으로 확인, 기존 리소스는 변경/삭제 없음
5. `terraform apply` — 노드 풀 생성 완료
6. `az aks nodepool list`로 노드 풀 생성 확인

## 5. 결과

- 노드 풀 `shtestpool` 생성 완료 (`Standard_B2s`, 1 node, auto scaling 미사용, `node_labels = { env = "test" }`)
- Plan 결과: `1 to add, 0 to change, 0 to destroy` — 기존 클러스터 및 다른 리소스에 영향 없음 확인

---

## 6. kubectl 연결 및 워크로드 배포 검증

### 6.1 클러스터 연결

```
az aks install-cli   # kubectl/kubelogin 설치 (권한 문제 시 sudo 필요)
az aks get-credentials --resource-group <RG명> --name <클러스터명>
kubectl get nodes -L agentpool   # 노드 풀 소속 확인
```

### 6.2 노드 풀 관련 개념 정리

- **노드 풀(Azure/AKS 개념)**: 동일 스펙 VM들의 그룹 단위. `az aks nodepool list`로 조회.
- **노드(쿠버네티스 개념)**: 노드 풀에 속한 개별 VM. `kubectl get nodes`로 조회되는 대상은 노드 풀이 아닌 개별 노드다.
- AKS는 노드 풀 이름을 노드에 `agentpool=<풀이름>` 라벨로 자동 부여하므로, 이를 활용해 특정 풀에만 워크로드를 배치할 수 있다.

### 6.3 특정 노드 풀 지정 배포 (nodeSelector)

System pool에는 일반적으로 `CriticalAddonsOnly` 등의 taint가 걸려 있어 별도 지정 없이도 워크로드가 User pool로만 스케줄링되는 경우가 많으나, taint가 없는 환경에서 특정 풀을 강제 지정하려면 `nodeSelector`를 사용한다.

```yaml
spec:
  nodeSelector:
    agentpool: shtestpool
  containers:
  - name: nginx
    image: nginx
```

### 6.4 배포 및 외부 노출 테스트

```
kubectl apply -f nginx-deployment.yaml
kubectl expose deployment nginx-test --port=80 --type=LoadBalancer
kubectl get service nginx-test --watch   # EXTERNAL-IP 발급 대기
```

- 지정한 노드 풀(`shtestpool`)에 pod가 정상 스케줄링됨을 `kubectl get pods -o wide`로 확인
- `type=LoadBalancer` 서비스 노출 시 Azure Public IP/Load Balancer 리소스가 실제 과금 대상으로 생성되므로, 테스트 종료 후 정리 필요

```
kubectl delete service nginx-test
kubectl delete deployment nginx-test
```

## 7. 노드 풀 분리 설계의 의의 (메모)

쿠버네티스 스케줄러는 기본적으로 리소스 여유가 있는 노드에 자동 배치하므로, 노드 풀 분리 자체가 "자동 배치"와 대립하는 개념은 아니다. 노드 풀은 아래와 같은 목적으로 분리한다.

- 워크로드별 요구 스펙 차이 대응 (GPU, 고메모리 등)
- System pool 보호 (taint를 통한 클러스터 핵심 컴포넌트와의 자원 경합 방지)
- 테넌트/컴플라이언스 단위 격리
- 노드 풀 단위 오토스케일 정책 분리
- 쿠버네티스 버전/노드 이미지 업그레이드 시 카나리 단위 분리
