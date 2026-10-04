# Cloudflared

Cloudflare Tunnel client for secure connections

**Package:** cloudflared  
**Author:** israel marques  
**Repository:** https://github.com/karnel-termuxOFC/karnel-termux  
**Official:** https://developers.cloudflare.com/cloudflare-one/connections/connect-networks  
**Type:** Networking tool (pkg)  
**License:** Apache 2.0 / Cloudflare License

## Description

Cloudflared creates secure tunnels from your local server to Cloudflare's edge network. It exposes local services to the internet through Cloudflare without opening firewall ports, providing DDoS protection and SSL/TLS encryption.

## Dependencies

- Installed via pkg

## Install

```bash
karnel install dev --cloudflared
```

## Uninstall

```bash
karnel uninstall dev --cloudflared
```

## Update

```bash
karnel update dev --cloudflared
```

## Notes

- Command: `cloudflared`
- Requires Cloudflare account for tunnel setup
- Supports load balancing and failover

