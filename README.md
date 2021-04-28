# Description

This Grafana container utilizes the officially binaries from Grafana.
The image is built upon docker scratch and builds libc6 from debian sources. 

# Usage

```sh
docker run -p 1883:1883 -p 9001:9001 distrolessdocker/distroless-mosquitto:latest
```

# Licenses
This image itself is published under the `CC0 license`.

This image also contains:
- Mosquito which is licensed under the `EPL/EDL` license.

However, this image might also contain other software(parts) which may be under other licenses (such as OpenSSL or other dependencies). Some licenses are automatically collected and exported to the /licenses folder within the container. It is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.
