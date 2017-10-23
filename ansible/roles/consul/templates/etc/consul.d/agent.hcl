data_dir = "/tmp/consul"
ca_file = "/etc/consul.d/ssl/{{ consul_ssl_ca_cert_filename }}"
cert_file = "/etc/consul.d/ssl/{{ consul_ssl_cert_filename }}"
key_file = "/etc/consul.d/ssl/{{ consul_ssl_key_filename }}"
verify_incoming = true
verify_outgoing = true
log_level = "INFO"

{% if consul_retry_join is defined %}
retry_join {
  provider = "{{ consul_retry_join.provider }}"
  region = "{{ consul_retry_join.region }}"
  tag_key = "{{ consul_retry_join.key }}"
  tag_value = "{{ consul_retry_join.value }}"
}
{% endif %}

addresses {
    http = "0.0.0.0"
}
ports {
    http = 8500
}

{% if telemetry_address is defined %}
telemetry {
  statsite_address = "{{ telemetry_address }}:8125"
  disable_hostname = false
}
{% endif %}

{% if consul_encryption %}
encrypt = "{{ group_creds_consul_encryption_key|default('hullo') }}"
{% endif %}

