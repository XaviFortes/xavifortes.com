# Ansible

Playbooks for xavifortes.com infrastructure.
All sensitive values (IPs, domains, connection details) are SOPS-encrypted — only accessible with the Age private key.

## Setup

```bash
pip install ansible-core
ansible-galaxy collection install community.sops
ansible-galaxy collection install community.general
```

Ensure your Age private key is available at `~/.config/sops/age/keys.txt`.

## Playbooks

### Deploy HAProxy to GRA8

```bash
# Dry run
ansible-playbook -i inventory/hosts.yml playbooks/gra8-haproxy.yml --check --diff

# Apply
ansible-playbook -i inventory/hosts.yml playbooks/gra8-haproxy.yml
```

## Encrypted files

| File | Contents |
|------|----------|
| `group_vars/gra8/vars.sops.yml` | HAProxy backend IPs, domains, MAD1 node IPs, ACME thumbprint |
| `host_vars/vps-f24bf8b4/vault.sops.yml` | SSH connection details (host IP, user, key path) |

To edit any encrypted file:
```bash
sops ansible/group_vars/gra8/vars.sops.yml
sops ansible/host_vars/vps-f24bf8b4/vault.sops.yml
```

To create `group_vars/gra8/vars.sops.yml` from scratch, see the variable reference comments at the top of that file.
