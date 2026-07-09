# ---------------------------------------------------------------------------
# 테스트용 최소 사양 노드 풀
# 실제 리소스 그룹/클러스터 이름으로 반드시 교체할 것
# ---------------------------------------------------------------------------
node_pools = {
  "shtestpool" = {
    resource_group_name = "TEST-AKS-RG"       # 실제 리소스 그룹명으로 교체
    aks_cluster_name    = "testtest"  # 실제 AKS 클러스터명으로 교체

    vm_size             = "Standard_B2s" # 2 vCPU, 4GB - 테스트용 저가 SKU
    node_count          = 1
    enable_auto_scaling = false

    os_disk_size_gb = 30 
    os_type         = "Linux"
    mode            = "User"

    node_labels = {
      env = "test"
    }
    tags = {
      purpose = "test"
    }
  }
}

