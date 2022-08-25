## 🐳 Ubuntu golang build containers

Build script that generates Ubuntu golang build containers for both local and remote registries with multi-arch build options.  A single Dockerfile based on the [docker-library](https://github.com/docker-library) repositories: [buildpack-deps](https://github.com/docker-library/buildpack-deps), and [golang](https://github.com/docker-library/golang) is used with docker build args.

 - [rpinz/golang:1.19-bionic](https://hub.docker.com/r/rpinz/golang)
 - [rpinz/golang:1.19-focal](https://hub.docker.com/r/rpinz/golang)
 - [rpinz/golang:1.19-jammy](https://hub.docker.com/r/rpinz/golang)

# PLEASE NOTE: To reduce attack surface in a production environment, these containers should only be used during multi-stage builds as the build container, with run-time containers generated from official builds.

## 📦 Installation

Clone the [repository](https://gitlab.com/rpinz/golang.git) in `${HOME}/containers`:
```shellscript
$ cd ${HOME}/containers
$ git clone https://github.com/rpinz/golang.git
```

### ⚒  Build:

Build containers locally
```shellscript
$ cd ${HOME}/containers/golang
$ ./build.sh local
```

Build containers and push to registry
```shellscript
$ cd ${HOME}/containers/golang
$ ./build.sh build
```

Build multi-arch containers and push to registry
```shellscript
$ cd ${HOME}/containers/golang
$ ./build.sh buildx
```

TODO:
 - [x] Create Ubuntu Dockerfile based on [docker-library](https://github.com/docker-library)
 - [x] Add golang installation to Dockerfile
 - [x] Create build script to generate golang build containers
 - [x] Add buildx multi-arch support to build script
 - [ ] Optimize installed packages to only those needed by typical golang usage
