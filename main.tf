# ---------------------------------------------------------------------------
# 기존 AKS 클러스터에 노드 풀 추가
# 클러스터 자체는 data source로 참조만 하고, 새로 생성/추적되는 리소스는
# azurerm_kubernetes_cluster_node_pool 뿐이다.
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster_node_pool" "node_pool" {
  for_each = var.node_pools

  name = each.key

  kubernetes_cluster_id = data.azurerm_kubernetes_cluster.aks[
    "${each.value.resource_group_name}|${each.value.aks_cluster_name}"
  ].id

  vm_size = each.value.vm_size
  mode    = each.value.mode

  # ---------------------------------------------------------------------
  # Auto scaling 사용 여부에 따라 아래 두 블록 중 하나만 적용됨
  # (tfvars의 enable_auto_scaling 값으로 자동 분기, 코드 수정 불필요)
  #
  # - enable_auto_scaling = false 인 경우
  #   -> node_count 값 사용, min_count/max_count는 null
  # - enable_auto_scaling = true 인 경우
  #   -> node_count는 null (Azure가 자동 조정하므로 고정값을 주면 안 됨)
  #   -> min_count/max_count 필수로 채워줘야 함 (tfvars에서 지정)
  # ---------------------------------------------------------------------
  node_count           = each.value.enable_auto_scaling ? null : each.value.node_count
  auto_scaling_enabled = each.value.enable_auto_scaling
  min_count            = each.value.enable_auto_scaling ? each.value.min_count : null
  max_count            = each.value.enable_auto_scaling ? each.value.max_count : null

  os_disk_size_gb = each.value.os_disk_size_gb
  os_type         = each.value.os_type

  vnet_subnet_id = each.value.vnet_subnet_id
  zones          = each.value.zones

  node_labels = each.value.node_labels
  node_taints = each.value.node_taints
  tags        = each.value.tags

  upgrade_settings {
    max_surge = each.value.max_surge
    drain_timeout_in_minutes = each.value.drain_timeout_in_minutes
    node_soak_duration_in_minutes = each.value.node_soak_duration_in_minutes
  }

  #lifecycle {
    # auto scaling 사용 시: Azure가 자체적으로 조정하는 node_count를 무시해야
    #   매 apply마다 diff(false positive)가 안 뜸
    # auto scaling 미사용 시: 이 줄 있어도 무해함 (node_count는 tfvars 값으로 고정 관리)
    #  ignore_changes = [node_count]
    #}
}

