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

  # auto scaling 사용 시 node_count는 지정하지 않음 (drift 방지)
  node_count          = each.value.enable_auto_scaling ? null : each.value.node_count
  enable_auto_scaling = each.value.enable_auto_scaling
  min_count           = each.value.enable_auto_scaling ? each.value.min_count : null
  max_count           = each.value.enable_auto_scaling ? each.value.max_count : null

  os_disk_size_gb = each.value.os_disk_size_gb
  os_type         = each.value.os_type

  vnet_subnet_id = each.value.vnet_subnet_id
  zones          = each.value.zones

  node_labels = each.value.node_labels
  node_taints = each.value.node_taints
  tags        = each.value.tags

  lifecycle {
    # auto scaling 동작 중 Azure가 자체적으로 조정하는 node_count는 무시
    ignore_changes = [node_count]
  }
}
