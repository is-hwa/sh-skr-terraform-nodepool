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

    # AKS가 자동으로 채우는 기본값과 동일하게 명시 -> plan에서 불필요한 diff 방지
    max_surge                     = optional(string, "10%")
    drain_timeout_in_minutes      = optional(number, 0)
    node_soak_duration_in_minutes = optional(number, 0)
  }))

  validation {
    condition = alltrue([
      for np in var.node_pools :
      np.enable_auto_scaling == false || (
        np.min_count != null &&
        np.max_count != null &&
        np.min_count <= np.max_count
      )
    ])
    error_message = "enable_auto_scaling=true 인 노드풀은 min_count/max_count 를 지정해야 하며 min_count <= max_count 여야 합니다."
  }

  # node pool name rule
  validation {
    condition = alltrue([
      for k in keys(var.node_pools) :
      can(regex("^[a-z][a-z0-9]{0,11}$", k))
    ])
    error_message = "노드풀 이름은 소문자로 시작하고 영소문자+숫자 12자 이내여야 합니다 (Linux 기준)."
  }
}

