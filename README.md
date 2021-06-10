# Description

This is an attempt to build a "distroless" docker image containing an up-to-date mosquitto (currently v2.0.10) based on a docker scratch container. The Dockerfile itself is an "extended" version of the Dockerfile contained within Mosquitto.

# Usage

```sh
docker run -p 1883:1883 -p 9001:9001 distrolessdocker/distroless-mosquitto:latest
```

# Licenses
This image itself is published under the `CC0 license`.

This image also contains:
- Mosquito which is licensed under the `EPL/EDL` license.

However, this image might also contain other software(parts) which may be under other licenses (such as OpenSSL or other dependencies). Some licenses are automatically collected and exported to the /licenses folder within the container. It is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.

