# Cookbooks #

These cookbooks contain some of the common (and not-so-common) deployments for
the FoundryVTT Docker container.  Each section of the cookbook generally follows
the same structure.

- A layout of the files required.
- A list of the files that require editing to replace their `<placeholder>` values.
- Instructions for starting the container or containers.
- Instructions for accessing the services.

- [Single server running behind Caddy](caddy)
- [Single server running behind nginx](nginx)
- [Two servers running behind Caddy with different paths](caddy-two-paths)
