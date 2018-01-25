# CI

CI support for Domainr

### circlego

Used in some Circle CI setups; is based on `circleci/golang` but adds the
Heroku tool and some common test packages which we use.

Used to create: `domainr/ci:1.9.2`

This is confusing overlap in tag naming space and should be reconsidered.
My fault (Phil).

### docker-go

Used to create: `domainr/docker-go:go1.9.3-docker17.12.0-ce`

Possibly used in future builds, having the Docker client tool to talk to a
remote docker server, so should work with Circle CI's `setup_remote_docker`.
