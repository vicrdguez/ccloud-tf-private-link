output "current_sp" {
  value = data.azuread_service_principal.current_sp
}

output "byok_key" {
  value = confluent_byok_key.byok_key
}
