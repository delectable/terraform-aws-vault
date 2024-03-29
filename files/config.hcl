cluster_name      = "vault-cluster-${ env }"
max_lease_ttl     = "192h" # One week
default_lease_ttl = "192h" # One week

listener "tcp" {
  address     = "127.0.0.1:9200"
  tls_disable = "true"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"

  # HACK HACK HACK
  # TEMPORARILY do not require TLS after the load balancer
  tls_disable       = "true"
  # tls_disable     = "false"
  # tls_min_version = "tls12"
  # tls_cert_file   = "/etc/vault/ssl/cert.crt"
  # tls_key_file    = "/etc/vault/ssl/privkey.key"

  # tls_prefer_server_cipher_suites = "true"
}

storage "s3" {
  bucket       = "${ vault_data_bucket_name }"
  region       = "${ region }"
  max_parallel = "512"
}

ha_storage "dynamodb" {
  ha_enabled = "true"
  region     = "${ region }"
  table      = "${ dynamodb_table_name }"

  max_parallel   = "25"
  read_capacity  = "5"
  write_capacity = "5"

  cluster_addr  = "https://MY_IP_SET_IN_USERDATA:8201"
  redirect_addr = "${ vault_dns_address }"
}

telemetry {
  dogstatsd_addr = "localhost:8125"
  dogstatsd_tags = ["vault_cluster:vault-cluster-${ env }"]
}
