# Infrastructure Setup — Local Development Environment

## Environment Specification

| Component | Details |
|-----------|---------|
| Hypervisor | Proxmox VE 9.2 (bare-metal, HP ProLiant ML350p Gen8) |
| Guest OS | Ubuntu Server 24.04.5 LTS |
| VM ID | 100 — `quickballot-dev` |
| vCPUs | 2 |
| RAM | 4 GB |
| Disk | 20 GB |
| Network | Bridged (static DHCP lease assigned via router by MAC address) |
| Access | SSH key-only, VS Code Remote SSH |

Running the development environment inside a dedicated VM (rather than WSL2 or Docker Desktop on the host) keeps the host/guest boundary clean: all tooling installs, port bindings, and Docker operations happen inside the VM exactly as they would on a remote server or EC2 instance.

---

## User and Access Setup

A non-root user with `sudo` rights is the only account used. Root login is disabled.

```bash
# Create deploy user (done at VM provisioning time)
sudo adduser <username>
sudo usermod -aG sudo <username>

# Authorise SSH key
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "<public-key>" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

---

## SSH Hardening

`/etc/ssh/sshd_config` changes applied:

```
PasswordAuthentication no
PermitRootLogin no
```

```bash
sudo systemctl restart ssh
```

Connections use an ed25519 key pair generated on the Windows host:

```powershell
ssh-keygen -t ed25519 -C "quickballot-dev" -f "$HOME\.ssh\quickballot"
ssh -i "$HOME\.ssh\quickballot" <username>@<VM_IP>
```

---

## Firewall — UFW

Default-deny inbound, allow only what the application needs:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

Verify:

```bash
sudo ufw status verbose
```

---

## Setup Script — `scripts/setup-server.sh`

An idempotent shell script provisions all required tooling. Running it twice produces no errors and no unintended state changes.

What it installs / configures:

| Tool | Purpose |
|------|---------|
| Docker CE | Container runtime |
| Docker Compose plugin | Local multi-service orchestration |
| Node.js 20 (NodeSource) | vote-ui and vote-api runtimes |
| Python 3 + pip | results-api runtime |
| nginx | Reverse proxy / static serving |
| fail2ban | SSH brute-force protection |
| 2 GB swap file | Prevents OOM on 4 GB VM during builds |

Run:

```bash
chmod +x scripts/setup-server.sh
sudo ./scripts/setup-server.sh
```

Log out and back in once after the first run so the `docker` group membership takes effect.

---

## Verification

```bash
docker run hello-world          # Docker working
sudo ufw status verbose         # Firewall rules
sudo systemctl status fail2ban  # fail2ban active
free -h                         # Swap present
node --version                  # Node.js 20.x
python3 --version               # Python 3.12.x
```

---

## QEMU Guest Agent

Installed so Proxmox can report the VM's IP address and coordinate clean shutdowns:

```bash
sudo apt install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
```

---

## Network Design

The VM receives a static DHCP lease assigned by the home router using its MAC address. No changes to the guest's netplan configuration are required. The Proxmox hypervisor and the VM sit on the same LAN segment with the router as the default gateway.

---

## VS Code Remote SSH

Development happens inside the VM via VS Code Remote SSH. The workspace root is `/home/<username>/quickballot-app`.

`~/.ssh/config` on the Windows host (optional convenience entry):

```
Host quickballot-dev
    HostName <VM_IP>
    User <username>
    IdentityFile ~/.ssh/quickballot
```

Connect: **Remote Explorer → SSH → quickballot-dev**.

---

## Repository Initialisation

```bash
git clone https://github.com/Stanleyobazee/quickballot-app.git
cd quickballot-app
git config user.name "Stanley Obazee"
git config user.email "obazeestanley@gmail.com"
```