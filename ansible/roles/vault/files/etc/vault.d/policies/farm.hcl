path "secret/corporate/*" {
  policy = "read"
}

path "secret/credentials/admin_keys" {
  policy = "read"
}

path "secret/host-credentials/*" {
  policy = "read"
}

path "secret/group-credentials/*" {
  policy = "read"
}

path "auth/token/lookup-self" {
  policy = "read"
}
