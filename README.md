# transmission-base

Ubuntu LTS with Transmission built from source. Shared base for
[haugene/docker-transmission-wireguard](https://github.com/haugene/docker-transmission-wireguard)
and
[haugene/docker-transmission-openvpn](https://github.com/haugene/docker-transmission-openvpn),
so both stay on the same Ubuntu and Transmission versions.

Published on Docker Hub as [`haugene/transmission-base`](https://hub.docker.com/r/haugene/transmission-base).

## Consume in a downstream Dockerfile

```dockerfile
FROM haugene/transmission-base:4.1.4-ubuntu26.04
```

Pinning options:

| Pin | Example | When to use |
| --- | --- | --- |
| Floating tag | `4.1.4-ubuntu26.04` | Normal dependency; picks up rebuilds for the same Transmission + Ubuntu major (security / base patch refreshes) |
| Immutable tag | `4.1.4-ubuntu26.04-a1b2c3d` | Reproducible builds; never moves once published |
| Digest | `haugene/transmission-base@sha256:…` | Strongest reproducibility |

## Tag format

Tags encode **Transmission version** and **Ubuntu version**:

```text
{transmission}-ubuntu{ubuntu}           # floating (updated by rebuilds on main)
{transmission}-ubuntu{ubuntu}-{sha}     # immutable (git short SHA)
```

Examples:

- `4.1.4-ubuntu26.04` — current build of Transmission 4.1.4 on Ubuntu 26.04
- `4.1.4-ubuntu26.04-a1b2c3d` — that same combo from commit `a1b2c3d`

### Dev channel

Pushes to the `dev` branch publish a separate channel so unfinished work does
not look like a release:

- `dev`
- `4.1.4-ubuntu26.04-dev`
- `4.1.4-ubuntu26.04-dev-{sha}`

## Build arguments

| Arg | Default | Purpose |
| --- | --- | --- |
| `UBUNTU_VERSION` | `26.04` | Ubuntu LTS tag used for both build and runtime stages |
| `TRANSMISSION_VERSION` | `4.1.4` | Transmission release built from the official source tarball |
| `TRANSMISSION_SHA256` | `86e7aa02…` | Expected SHA-256 of that tarball (bump together with the version) |

`UBUNTU_VERSION` selects the Ubuntu tag, but the runtime library package
names in the Dockerfile are chosen for the default LTS (currently 26.04).
Changing to another Ubuntu major may require updating those packages.

## Local build

```bash
docker build -t haugene/transmission-base:local .
```

Override versions explicitly (checksum from [transmissionbt.com/download](https://transmissionbt.com/download)):

```bash
docker build \
  --build-arg UBUNTU_VERSION=26.04 \
  --build-arg TRANSMISSION_VERSION=4.1.4 \
  --build-arg TRANSMISSION_SHA256=86e7aa020cdf64826447034bc85f4d3b7c848d8c0891d9dc9b9fddfb2c805d22 \
  -t haugene/transmission-base:4.1.4-ubuntu26.04 \
  .
```

Multi-arch with Buildx + QEMU. Multi-platform builds are not loaded into the
local Docker engine; `--push` publishes them to a registry (CI does this):

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64,linux/arm/v7 \
  --build-arg UBUNTU_VERSION=26.04 \
  --build-arg TRANSMISSION_VERSION=4.1.4 \
  --build-arg TRANSMISSION_SHA256=86e7aa020cdf64826447034bc85f4d3b7c848d8c0891d9dc9b9fddfb2c805d22 \
  -t haugene/transmission-base:4.1.4-ubuntu26.04 \
  --push \
  .
```

## License

MIT — see [LICENSE](LICENSE).
