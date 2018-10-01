package builtinplugins

import (
	credAliCloud "github.com/hashicorp/vault-plugin-auth-alicloud"
	credAzure "github.com/hashicorp/vault-plugin-auth-azure"
	credCentrify "github.com/hashicorp/vault-plugin-auth-centrify"
	credGcp "github.com/hashicorp/vault-plugin-auth-gcp/plugin"
	credJWT "github.com/hashicorp/vault-plugin-auth-jwt"
	credKube "github.com/hashicorp/vault-plugin-auth-kubernetes"
	ad "github.com/hashicorp/vault-plugin-secrets-ad/plugin"
	"github.com/hashicorp/vault-plugin-secrets-alicloud"
	azure "github.com/hashicorp/vault-plugin-secrets-azure"
	gcp "github.com/hashicorp/vault-plugin-secrets-gcp/plugin"
	"github.com/hashicorp/vault-plugin-secrets-kv"
	credAppId "github.com/hashicorp/vault/builtin/credential/app-id"
	credAppRole "github.com/hashicorp/vault/builtin/credential/approle"
	credAws "github.com/hashicorp/vault/builtin/credential/aws"
	credCert "github.com/hashicorp/vault/builtin/credential/cert"
	credGitHub "github.com/hashicorp/vault/builtin/credential/github"
	credLdap "github.com/hashicorp/vault/builtin/credential/ldap"
	credOkta "github.com/hashicorp/vault/builtin/credential/okta"
	credRadius "github.com/hashicorp/vault/builtin/credential/radius"
	credUserpass "github.com/hashicorp/vault/builtin/credential/userpass"
	"github.com/hashicorp/vault/builtin/logical/aws"
	"github.com/hashicorp/vault/builtin/logical/cassandra"
	"github.com/hashicorp/vault/builtin/logical/consul"
	"github.com/hashicorp/vault/builtin/logical/database"
	"github.com/hashicorp/vault/builtin/logical/mongodb"
	"github.com/hashicorp/vault/builtin/logical/mssql"
	"github.com/hashicorp/vault/builtin/logical/mysql"
	"github.com/hashicorp/vault/builtin/logical/nomad"
	"github.com/hashicorp/vault/builtin/logical/pki"
	"github.com/hashicorp/vault/builtin/logical/postgresql"
	"github.com/hashicorp/vault/builtin/logical/rabbitmq"
	"github.com/hashicorp/vault/builtin/logical/ssh"
	"github.com/hashicorp/vault/builtin/logical/totp"
	"github.com/hashicorp/vault/builtin/logical/transit"
	"github.com/hashicorp/vault/logical"
)

var credentialBackends = map[string]logical.Factory{
	"alicloud":   credAliCloud.Factory,
	"app-id":     credAppId.Factory,
	"approle":    credAppRole.Factory,
	"aws":        credAws.Factory,
	"azure":      credAzure.Factory,
	"centrify":   credCentrify.Factory,
	"cert":       credCert.Factory,
	"gcp":        credGcp.Factory,
	"github":     credGitHub.Factory,
	"jwt":        credJWT.Factory,
	"kubernetes": credKube.Factory,
	"ldap":       credLdap.Factory,
	"okta":       credOkta.Factory,
	"radius":     credRadius.Factory,
	"userpass":   credUserpass.Factory,
}

var logicalBackends = map[string]logical.Factory{
	"ad":         ad.Factory,
	"alicloud":   alicloud.Factory,
	"aws":        aws.Factory,
	"azure":      azure.Factory,
	"cassandra":  cassandra.Factory,
	"consul":     consul.Factory,
	"database":   database.Factory,
	"gcp":        gcp.Factory,
	"kv":         kv.Factory,
	"mongodb":    mongodb.Factory,
	"mssql":      mssql.Factory,
	"mysql":      mysql.Factory,
	"nomad":      nomad.Factory,
	"pki":        pki.Factory,
	"postgresql": postgresql.Factory,
	"rabbitmq":   rabbitmq.Factory,
	"ssh":        ssh.Factory,
	"totp":       totp.Factory,
	"transit":    transit.Factory,
}
