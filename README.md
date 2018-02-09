# CI

CI support for Domainr

At the moment, this is just a Dockerfile, used to create `domainr/ci` on
Docker Hub as a public image.

**Nothing proprietary or secret goes in this image.**

We want to get new stable releases of Go quickly, so use the Golang upstreams
which are fast enough, then add in whatever other packages and tools we
expect.

We include the docker client, to work with Circle CI's `setup_remote_docker`
(where a container talks to docker to create images from inside docker).

We also include `heroku`, `dep` and various other things.
