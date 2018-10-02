package builtinplugins

import (
	"fmt"
	"strings"

	"github.com/hashicorp/vault/helper/consts"
)

// BuiltinFactory is the func signature that should be returned by
// the plugin's New() func.
type BuiltinFactory func() (interface{}, error)

func toBuiltinFactory(ifc interface{}) BuiltinFactory {
	return func() (interface{}, error) {
		return ifc, nil
	}
}

// Get returns the BuiltinFactory func for a particular backend plugin
// from the databasePlugins map.
func Get(name string, pluginType consts.PluginType) (BuiltinFactory, bool) {
	switch pluginType {
	case consts.PluginTypeCredential:
		f, ok := credentialBackends[name]
		return toBuiltinFactory(f), ok
	case consts.PluginTypeSecrets:
		f, ok := logicalBackends[name]
		return toBuiltinFactory(f), ok
	case consts.PluginTypeDatabase:
		f, ok := databasePlugins[name]
		return f, ok
	default:
		return nil, false
	}
}

// Keys returns the list of plugin names that are considered builtin databasePlugins.
func Keys() []string {
	var plugins []string
	for k := range databasePlugins {
		// These are already in the format below so no concatenation is needed.
		plugins = append(plugins, k)
	}
	for k := range credentialBackends {
		plugins = append(plugins, fmt.Sprintf("%s-%s-plugin", k, consts.PluginTypeCredential.String()))
	}
	for k := range logicalBackends {
		plugins = append(plugins, fmt.Sprintf("%s-%s-plugin", k, consts.PluginTypeSecrets.String()))
	}
	return plugins
}

// ParseKey returns a key's:
//   - Name
//   - PluginType
func ParseKey(key string) (string, consts.PluginType, error) {
	fields := strings.Split(key, "-")
	name := fields[0]
	strType := fields[1]
	pluginType, err := consts.ParsePluginType(strType)
	if err != nil {
		return "", consts.PluginTypeUnknown, err
	}
	return name, pluginType, nil
}
