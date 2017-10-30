backend "consul" {
  address = "localhost:8500"
  path = "vault"
}

listener "tcp" {
 address = "127.0.0.1:8200"
{% if ansible_ec2_local_ipv4 is defined %}
 cluster_address = "{{ ansible_ec2_local_ipv4 }}:8200"
{% endif %}
 tls_cert_file = "{{ vault_ssl_crt_path }}"
 tls_key_file = "{{ vault_ssl_key_path }}"
}

{% if vault_telemetry_address is defined %}
telemetry {
  statsite_address = "{{ vault_telemetry_address }}:8125"
  disable_hostname = false
}
{% endif %}
e
