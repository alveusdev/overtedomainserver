# Overte Domain Server AIO

All-in-one docker image for Overte Domain Server hosting.

Contains: Domain server, Assignment servers for Audio Mixer, Avatar Mixer, Entities Server, Asset Server, Entity Script Server, Messages Server, Scripted Agent.

---

Please refer to overte documentation for how to configure the domain server (https://docs.overte.org/en/latest/host/configure-settings.html).

---

Pull from docker: `alveusdev/overtedomainserver:latest`

Currently only available for amd64 architecture.

---

Exposed ports:

- 40100/tcp
- 40101/tcp
- 40102/tcp
- 40100/udp
- 40101/udp
- 40102/udp
- 48000/udp
- 48001/udp
- 48002/udp
- 48003/udp
- 48004/udp
- 48005/udp
- 48006/udp

Domain server web UI available on port `40100` (HTTP)

---

Running with Docker Compose 

```yaml
services:
  overte-server:
    image: alveusdev/overtedomainserver:latest
    container_name: overte-server
    restart: unless-stopped
    expose:
      - "40100-40102"
    ports:
      - "40100-40102:40100-40102"
      - "40100-40102:40100-40102/udp"
      - "48000-48006:48000-48006/udp"
    volumes:
      - "./logs:/var/log/overte"
      - "./data:/root/.local/share/Overte"
```


[![status-badge](https://wci.alveus.dev/api/badges/31/status.svg)](https://wci.alveus.dev/repos/31)