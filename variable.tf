# ---------------------------------------------------------------------------
# 추가할 노드 풀 정의
# key: 노드 풀 이름 (소문자/숫자, 최대 12자 - Azure 제약)
# ---------------------------------------------------------------------------
variable "node_pools" {
  description = "기존 AKS 클러스터에 추가할 노드 풀 목록"
  type = map(object({
    resource_group_name = string # 기존 AKS가 속한 리소스 그룹
    aks_cluster_name     = string # 기존 AKS 클러스터 이름

    vm_size             = string
    node_count          = number
    enable_auto_scaling = bool
    min_count           = optional(number)
    max_count           = optional(number)

    os_disk_size_gb = optional(number, 128)
    os_type         = optional(string, "Linux")
    mode            = optional(string, "User") # "System" or "User"

    vnet_subnet_id = optional(string) # null이면 클러스터 기본 subnet 사용
    zones          = optional(list(string))

    node_labels = optional(map(string), {})
    node_taints = optional(list(string), [])
    tags        = optional(map(string), {})
  }))
}
