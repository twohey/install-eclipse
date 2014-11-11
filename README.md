Ruby script to install Eclipse along with plugins into the current directory.

There are three configuration paramters which you might want to customize.

`ECLIPSE_VERSION_BASE` is the base install prefix for the Eclipse release
you would like to install. The value defaults to the Luna Jave EE release.

`PLUGINS` is an array of hashes for plugins to install. Each plugin has a
`pkg` key which describes the plugin package and a `url` key which is the
location of the repository for the plugin.
