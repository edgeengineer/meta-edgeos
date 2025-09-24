# Container Runtime Support in EdgeOS

This document describes the container runtime support in EdgeOS using containerd.

## Overview

EdgeOS includes optional support for running OCI-compliant containers using containerd as the runtime. This enables running containerized workloads on edge devices with minimal overhead.

## Components

When `EDGEOS_CONTAINER_RUNTIME=1` is set, the following components are included:

- **containerd**: Industry-standard container runtime
- **runc**: OCI runtime for spawning and running containers
- **cni & cni-plugins**: Container Network Interface for container networking
- **iptables**: For NAT and port forwarding
- **Kernel modules**: Required for namespaces, cgroups, and overlay filesystem

## Building with Container Support

### Quick Start

To include container runtime in your build:

1. Set the flag in your `build/conf/local.conf`:
```bash
EDGEOS_CONTAINER_RUNTIME = "1"
```

2. Build the image:
```bash
bitbake edgeos-image
```

### Required Layers

The following Yocto layers are required and will be cloned by bootstrap.sh:
- meta-virtualization (provides containerd recipes)
- meta-filesystems (provides filesystem support)
- meta-networking (already included for network support)
- meta-python (already included as dependency)

## Usage

### Starting containerd

The containerd service starts automatically on boot:
```bash
systemctl status containerd
```

### Basic Container Operations

Pull an image:
```bash
ctr image pull docker.io/library/hello-world:latest
```

Run a container:
```bash
ctr run --rm docker.io/library/hello-world:latest hello
```

List running containers:
```bash
ctr container list
```

### Networking

Container networking is handled through CNI plugins. Basic configurations include:
- Bridge networking (default)
- Host networking
- None (no network)

Example with host networking:
```bash
ctr run --rm --net-host docker.io/library/busybox:latest test sh -c 'ip addr'
```

## Resource Considerations

### Storage
- Container images and layers are stored in `/var/lib/containerd/`
- Consider dedicating a partition for container storage on production systems
- Overlay filesystem is used by default for efficient layer management

### Memory
- Containerd itself uses ~50-100MB RAM
- Each container adds overhead depending on the workload
- Monitor memory usage on constrained devices (minimum 1GB RAM recommended)

### CPU
- Container overhead is minimal (~1-2%)
- CPU limits can be set per container using cgroups

## Integration with Edge Agent

The edge-agent can manage containers through containerd's API. This enables:
- Remote container deployment
- Container lifecycle management
- Resource monitoring
- Log collection

## Troubleshooting

### Check containerd is running
```bash
systemctl status containerd
journalctl -u containerd -n 50
```

### Verify kernel support
```bash
# Check for required kernel features
zgrep CONFIG_NAMESPACES /proc/config.gz
zgrep CONFIG_CGROUPS /proc/config.gz
zgrep CONFIG_OVERLAY_FS /proc/config.gz
```

### Test CNI networking
```bash
# Check CNI plugins are installed
ls /opt/cni/bin/

# Test bridge network
ctr run --rm docker.io/library/busybox:latest test sh -c 'ping -c 3 8.8.8.8'
```

### Debug container issues
```bash
# Get detailed container info
ctr container info <container-id>

# Check container logs
ctr task list
journalctl -u containerd --since "5 minutes ago"
```

## Security Notes

- Containers run as root by default - use user namespaces for better isolation
- Apply security profiles (seccomp, AppArmor) in production
- Regularly update container images for security patches
- Use read-only root filesystems where possible

## Performance Tuning

For resource-constrained devices:
1. Limit concurrent containers
2. Use alpine-based images for smaller footprint
3. Configure memory limits per container
4. Consider disabling unnecessary CNI plugins
5. Use local registry mirror to reduce network usage

## Future Enhancements

Planned improvements include:
- K3s integration for Kubernetes support
- Rootless container support
- GPU passthrough for ML workloads
- Integration with cloud container registries