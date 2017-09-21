path "secret/root/*" {
  policy = "read"
}

path "secret/corporate/*" {
  policy = "read"
}

path "secret/credentials/*" {
  policy = "read"
}

path "auth/token/lookup-self" {
  policy = "read"
}
