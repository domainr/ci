# CI

**CI support for Domainr**

At the moment, this is just a Dockerfile, used to create `domainr/ci` on
Docker Hub as a public image.

**Nothing proprietary or secret goes in this image.**

We want to get new stable releases of Go quickly, so use the Golang upstreams
which are fast enough, then add in whatever other packages and tools we
expect.

We include the `docker` client, to work with Circle CI’s `setup_remote_docker`
(where a container talks to `docker` to create images from inside `docker`).

We also include `heroku`, `dep` and various other things.

## Docker Tag Names

We build `latest` from master, but we also include a generational
pseudo-latest tag, named for a [lake in Montana](https://en.wikipedia.org/wiki/List_of_lakes_in_Montana).  If experiments with a branch
build reveal something which would break existing builds if merged to master,
and we're lucky enough to spot those problems, then we can update the lake
name in Docker Hub before the merge, so that future builds get a new lake name
and dependencies can update independently.

The first is `swan`, in case this experiment takes a swan dive. Next: [Bowman Lake](https://en.wikipedia.org/wiki/Bowman_Lake_(Montana)) in Glacier National Park.

We also git-tag some releases with Go version numbers, so if latest or
$lake is broken by a bad merge, we can at least re-docker-tag that back onto
the docker-tag from that git-tag and get *something* working, even if not the
most recent.
