# Configuration
In order to merge user's groups from host to container, one can create the file `/etc/R_container/groups_to_merge` and put the groups to merge inside it.
Then the groups ( = lines) from `/etc/group.host` (which should be mapped from the `/etc/group` host, with `-v /etc/group:/etc/group.host:ro` for example) will be appended to the container's `/etc/group`.