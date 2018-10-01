package builtinplugins

import (
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

// TODO this should now include more keys, and differentiate based on the plugin type. Probably needs to be an array of objects with plugin_type and plugin_name.
// TODO need to go through this workflow and update the code and docs:
// https://www.vaultproject.io/api/system/plugins-catalog.html
// Keys returns the list of plugin names that are considered builtin databasePlugins.
func Keys() []string {
	keys := make([]string, len(databasePlugins))

	i := 0
	for k := range databasePlugins {
		keys[i] = k
		i++
	}

	return keys
}
