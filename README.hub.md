## 🐳 Ubuntu golang build containers

Ubuntu golang multi-arch build containers, based on the [docker-library](https://github.com/docker-library) repositories: [buildpack-deps](https://github.com/docker-library/buildpack-deps), and [golang](https://github.com/docker-library/golang).

 - rpinz/golang:1.19-bionic
 - rpinz/golang:1.19-focal
 - rpinz/golang:1.19-jammy

# PLEASE NOTE: To reduce attack surface in a production environment, these containers should only be used during multi-stage builds as the build container, with run-time containers generated from official builds.
