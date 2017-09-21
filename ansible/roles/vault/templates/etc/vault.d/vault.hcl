backend "consul" {
  address = "consul:8500"
  path = "vault"
}

listener "tcp" {
 address = "127.0.0.1:8200"
{% if ansible_ec2_local_ipv4 is defined %}
 cluster_address = "{{ ansible_ec2_local_ipv4 }}:8200"
{% endif %}
 tls_cert_file = "/etc/vault.d/ssl/bundle.crt"
 tls_key_file = "/etc/vault.d/ssl/vault.key"
}

{% if vault_telemetry_address is defined %}
telemetry {
  statsite_address = "{{ vault_telemetry_address }}:8125"
  disable_hostname = false
}
{% endif %}
