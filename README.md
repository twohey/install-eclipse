Ruby 1.9 script to install Eclipse along with plugins into the current directory.

There are three configuration paramters which you might want to customize.

`ECLIPSE_VERSION_BASE` is the base install prefix for the Eclipse release
you would like to install. The value defaults to he Juno Jave EE release.

`PLUGINS` is an array of hashes for plugins to install. Each plugin has a
`pkg` key which describes the plugin package and a `url` key which is the
location of the repository for the plugin.

`USE_RETINA_IF_AVAILABLE` should be set to true if you want to enable
high resolution text displays. This is a work around for an Eclipse
weakness and will go away once Eclipse fixes the deeper underlying issues.
