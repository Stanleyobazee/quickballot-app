# Phase 1 — Foundation walkthrough

Goal: one Ubuntu EC2 instance you SSH into with a hardened, key-only,
non-root sudo user, UFW enabled, and Docker/Nginx/fail2ban/swap installed via
an idempotent script — plus this repo pushed to GitHub with branch
protection.

## 1. Generate an SSH key pair (on your Windows machine)

PowerShell (Windows 10/11 ships an OpenSSH client):

```powershell
ssh-keygen -t ed25519 -C "quickballot-phase1" -f "$HOME\.ssh\quickballot"
```

This creates `quickballot` (private key) and `quickballot.pub` (public key)
in `%USERPROFILE%\.ssh\`. Keep the private key secret — never commit it.

## 2. Launch the EC2 instance

Console (fastest for a first pass) or AWS CLI — either is fine for Phase 1
(the "Terraform only, no console clicking" rule starts at Phase 3).

- AMI: **Ubuntu Server 22.04 LTS**
- Instance type: `t3.micro` (free-tier eligible if your account qualifies)
- Key pair: import `quickballot.pub` as a new EC2 key pair, or create one at
  launch and download the `.pem`
- Network: default VPC is fine for this throwaway practice box (see
  [vpc-subnetting-plan.md](vpc-subnetting-plan.md) for why)
- Security group: allow inbound **22/tcp (SSH)** from **your IP only** — not
  `0.0.0.0/0`. You'll open 80/443 later via UFW on the box itself; the SG is
  your outer layer.
- Storage: default 8GB gp3 is enough

Note the instance's public IP once it's running.

## 3. First login and non-root user

```powershell
ssh -i "$HOME\.ssh\quickballot.pem" ubuntu@<PUBLIC_IP>
```

On the box:

```bash
sudo adduser deploy              # pick a strong password when prompted
sudo usermod -aG sudo deploy
sudo mkdir -p /home/deploy/.ssh
sudo cp ~/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys
```

Log out, then confirm the new user works:

```powershell
ssh -i "$HOME\.ssh\quickballot.pem" deploy@<PUBLIC_IP>
```

## 4. Lock down SSH (key-only, no root login)

On the box, edit `/etc/ssh/sshd_config`:

```
PasswordAuthentication no
PermitRootLogin no
```

Then:

```bash
sudo systemctl restart ssh
```

Keep your current session open until you've verified a **fresh** SSH
connection still works — don't lock yourself out.

## 5. Run the setup script

Copy [setup-server.sh](../scripts/setup-server.sh) to the box (`scp` from
Windows, or `git clone` the repo once it's pushed) and run it:

```bash
chmod +x setup-server.sh
sudo ./setup-server.sh
```

It's idempotent — rerun it any time, it won't break anything already in
place. Log out and back in once after the first run so the `docker` group
membership takes effect (lets `deploy` run `docker` without `sudo`).

## 6. Verify

```bash
docker run hello-world
sudo ufw status verbose
sudo systemctl status fail2ban --no-pager
free -h        # should show the swap file
```

## 7. Push this repo to GitHub

From your Windows machine, in `quickballot-app/`:

```powershell
git init
git add .
git commit -m "Phase 1: project scaffold, setup script, subnetting plan"
git branch -M main
git remote add origin <your-repo-url>
git push -u origin main
```

Then in GitHub repo settings:

- **Branches → Add branch protection rule** for `main`: require a PR before
  merging, require status checks (once Phase 4 CI exists), no direct pushes.
- Add your instructor as a **collaborator/reviewer** (needed later for the
  Phase 4 approval gate).

## Done when

- [ ] You can SSH into the box as `deploy` with a key only (no password, no
      root login).
- [ ] `sudo ./setup-server.sh` runs clean twice in a row with no errors.
- [ ] `ufw status` shows default-deny incoming with only SSH/80/443 open.
- [ ] Repo is on GitHub, public, `main` is protected.

Once this is checked off, tell me and we'll move into Phase 2 (building the
three services and a shared schema).
