terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # 원격 백엔드 사용 시 partial config로 채움 (init -backend-config=...)
  # 현재 state에는 아무 리소스도 없는 상태 -> 신규 node pool만 생성/추적됨
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
