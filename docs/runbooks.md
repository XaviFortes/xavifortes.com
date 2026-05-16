# Runbooks

Day-2 operations for `xavifortes.com`.

---

## Deploy a change to the site

Normal flow — just push to `master`:

```bash
git add .
git commit -m "feat: update homepage content"
git push
```

CI builds, scans, pushes the image, bumps the tag in `deployment.yaml`, and ArgoCD
syncs within ~3 minutes. No manual steps required.

**To watch the rollout:**
```bash
kubectl rollout status deployment/xavifortes-web -n xavifortes
kubectl get pods -n xavifortes -w
```

---

## Force ArgoCD to sync immediately

```bash
kubectl annotate application xavifortes-web \
  argocd.argoproj.io/refresh=hard \
  -n argocd --overwrite
```

Or via the ArgoCD UI → xavifortes-web → Sync.

---

## Roll back to a previous image

Find the SHA tag you want in the GitHub container registry or from git log:

```bash
git log --oneline kubernetes/apps/xavifortes-web/deployment.yaml
```

Edit `deployment.yaml` to the desired SHA tag and push — ArgoCD will sync it:

```bash
# Edit the image line
sed -i 's|image: ghcr.io/xavifortes/web:sha-.*|image: ghcr.io/xavifortes/web:sha-<OLD_SHA>|' \
  kubernetes/apps/xavifortes-web/deployment.yaml
git add kubernetes/apps/xavifortes-web/deployment.yaml
git commit -m "revert(deploy): roll back to sha-<OLD_SHA>"
git push
```

---

## Check site health

```bash
# HTTP response
curl -sI https://xavifortes.com | head -5

# www redirect
curl -sI https://www.xavifortes.com | head -3

# Pods
kubectl get pods -n xavifortes

# ArgoCD app
kubectl get application xavifortes-web -n argocd

# TLS certificate
kubectl get certificate xavifortes-tls -n xavifortes
```

---

## TLS certificate expired or stuck

cert-manager renews automatically 30 days before expiry. If it's stuck:

```bash
# Check the certificate and order status
kubectl describe certificate xavifortes-tls -n xavifortes
kubectl get order,challenge -n xavifortes

# Force renewal by deleting the secret (cert-manager re-issues immediately)
kubectl delete secret xavifortes-tls -n xavifortes
kubectl delete certificaterequest -n xavifortes --all

# Watch it re-issue
kubectl get certificate xavifortes-tls -n xavifortes -w
```

If ACME HTTP-01 challenges are failing with 404, check that:
1. HAProxy `http_front` has the `ACL_xavifortes` rule routing port 80 to MAD1
2. Traefik is reachable on port 80: `curl -I http://141.227.188.178/`
3. Cloudflare is not blocking the ACME validator IP

---

## Rotate the Cloudflare API token

1. Generate a new token at `dash.cloudflare.com → My Profile → API Tokens`
   - Permissions: `Zone > DNS > Edit`, `Zone > Firewall Services > Edit`, `Zone > Settings > Edit`
2. Re-encrypt the secrets file:
   ```bash
   sops infrastructure/tofu/live/cloudflare/secrets.sops.json
   # update cloudflare_api_token value, save
   git add infrastructure/tofu/live/cloudflare/secrets.sops.json
   git commit -m "chore(secrets): rotate cloudflare api token"
   git push
   ```
3. Verify Terraform still works:
   ```bash
   cd infrastructure/tofu/live/cloudflare && terragrunt plan
   ```

---

## Rotate the ghcr.io pull secret

1. Create a new GitHub PAT at `github.com/settings/tokens` with `read:packages` scope
2. Delete and recreate the secret on the cluster:
   ```bash
   kubectl delete secret ghcr-pull-secret -n xavifortes
   kubectl create secret docker-registry ghcr-pull-secret \
     --docker-server=ghcr.io \
     --docker-username=XaviFortes \
     --docker-password=<NEW_PAT> \
     -n xavifortes
   ```
3. Restart the deployment to use the new secret:
   ```bash
   kubectl rollout restart deployment/xavifortes-web -n xavifortes
   ```

---

## Apply Cloudflare infrastructure changes

```bash
cd infrastructure/tofu/live/cloudflare
terragrunt plan    # review changes
terragrunt apply
```

Requires the Age private key in `~/.config/sops/age/keys.txt` or `SOPS_AGE_KEY` env var.

---

## HAProxy changes on GRA8

SSH into GRA8 and edit the config:

```bash
ssh vps-f24bf8b4
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak.$(date +%Y%m%d)
sudo nano /etc/haproxy/haproxy.cfg
sudo haproxy -c -f /etc/haproxy/haproxy.cfg   # validate
sudo systemctl reload haproxy
```

**Never use `restart` — use `reload`** to avoid dropping existing connections.

The current `:443` architecture (must not break this):
```
:443  https_sni_router  (TCP)
      ├── xavifortes.com/www  →  xavifortes_mad1_tcp  (TCP passthrough)
      └── everything else     →  127.0.0.1:4443  (SSL termination frontend)
```

To add a new HTTPS domain that needs SSL termination at HAProxy:
- Add a cert to `/etc/haproxy/certs/`
- Add an ACL + `use_backend` in `https_front` (the one on `127.0.0.1:4443`)

To add a new HTTPS domain that does its own TLS (like xavifortes.com):
- Add an `acl` + `use_backend` in `https_sni_router` pointing to the backend server's `:443`
- Add the TCP backend

---

## Secrets bootstrap (new machine / new CI key)

```bash
# Generate a new Age key
age-keygen -o ~/.config/sops/age/keys.txt

# Add the public key to .sops.yaml
# Then re-encrypt all secret files:
sops updatekeys infrastructure/tofu/live/cloudflare/secrets.sops.json
sops updatekeys infrastructure/tofu/live/common.sops.json
```

---

## Check CI pipeline status

```bash
# Latest run result via GitHub API (no auth needed for public repo)
curl -s "https://api.github.com/repos/XaviFortes/xavifortes.com/actions/runs?per_page=3" \
  | python3 -c "
import json,sys
for r in json.load(sys.stdin)['workflow_runs']:
    print(r['status'], r['conclusion'] or 'running', r['head_commit']['message'][:50])
"
```
