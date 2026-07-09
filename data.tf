# ---------------------------------------------------------------------------
# 기존 리소스 조회용 로컬 값
# state는 비어있지만 Azure 상에는 이미 존재하는 리소스이므로 data source로 참조
# ---------------------------------------------------------------------------
locals {
  # 중복 없이 리소스 그룹 이름만 추출
  resource_group_names = toset([for v in var.node_pools : v.resource_group_name])

  # "rg명|클러스터명" 형태로 유니크 클러스터 목록 추출 (같은 클러스터에 여러 풀 추가 가능)
  aks_cluster_keys = toset([
    for v in var.node_pools : "${v.resource_group_name}|${v.aks_cluster_name}"
  ])
}

data "azurerm_resource_group" "rg" {
  for_each = local.resource_group_names

  name = each.value
}

data "azurerm_kubernetes_cluster" "aks" {
  for_each = { for c in local.aks_cluster_keys : c => c }

  name                = split("|", each.value)[1]
  resource_group_name = split("|", each.value)[0]
}
