# ArgoCD Access Guide for Linux

This guide explains two methods to access ArgoCD on a Linux server where you're experiencing 502 Bad Gateway errors.

## Method 1: Direct HTTPS Access (Recommended)

This method bypasses nginx completely and gives you direct access to ArgoCD via HTTPS.

```bash
# Run the direct access fix script
./direct-access-fix.sh

# Access ArgoCD at
# https://YOUR_SERVER_IP:8081
# (The port may vary if 8081 is in use)
```

### Advantages

- More reliable
- Simpler setup
- No nginx configuration needed
- Uses the native ArgoCD HTTPS

### Disadvantages

- Requires accepting a self-signed certificate
- Uses a non-standard port
- Port forwarding runs in the background and will stop if you log out

## Method 2: Nginx Proxy (Standard Port 80)

This method uses nginx as a reverse proxy to access ArgoCD.

```bash
# Run the nginx fix script
./linux-fix-502.sh

# Access ArgoCD at
# http://YOUR_SERVER_IP
```

### Benefits

- Uses standard HTTP port 80
- No certificate warnings
- Standard setup

### Limitations

- More complex configuration
- May encounter networking issues with Docker
- Needs host network mode

## Troubleshooting

If you're still having issues:

1. Check if the port forwarding is running:

   ```bash
   ps aux | grep port-forward
   ```

2. Check if nginx is running:

   ```bash
   docker ps | grep nginx
   ```

3. Check nginx logs:

   ```bash
   docker logs nginx-argocd
   ```

4. Try restarting both:

   ```bash
   # Kill port forwarding
   pkill -f "kubectl.*port-forward"
   
   # Restart nginx
   docker restart nginx-argocd
   
   # Start port forwarding
   kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 &
   ```

5. If all else fails, use direct access:

   ```bash
   # Find a free port
   FREE_PORT=8081
   
   # Start direct port forwarding
   kubectl port-forward svc/argocd-server -n argocd $FREE_PORT:443 --address 0.0.0.0 &
   
   # Access ArgoCD via HTTPS
   # https://YOUR_SERVER_IP:$FREE_PORT
   ```
