# Phase 1 — Foundation walkthrough (local VirtualBox VM)

Goal: one Ubuntu VM you SSH into with a hardened, key-only, non-root sudo
user, UFW enabled, and Docker/Nginx/fail2ban/swap installed via an idempotent
script — plus this repo pushed to GitHub with branch protection.

This box runs locally in VirtualBox instead of on EC2. The assignment
explicitly allows "local VM or EC2" for Phase 1, and a real VM (as opposed to
WSL2) keeps the host/guest boundary clean: you SSH into it from Windows
exactly like a remote server, which is the point of the exercise. Nothing
built here carries over into Phase 3 — the real VPC/EKS/RDS is required to be
on AWS and gets built fresh in Terraform.

## 0. Install VirtualBox

Download and install [VirtualBox](https://www.virtualbox.org/) for Windows
hosts. The Extension Pack is optional and not needed for this project.

## 1. Download Ubuntu Server

Get the **Ubuntu Server 24.04 LTS** ISO (not Desktop) from
[ubuntu.com/download/server](https://ubuntu.com/download/server). Any
current LTS release works for this exercise and matches what you'd use on a
real EC2 AMI — 24.04 is what this box actually ran.

## 2. Create the VM

In VirtualBox → New:

- Name: `quickballot-phase1`, Type: Linux, Version: Ubuntu (64-bit)
- Memory: 2048 MB minimum (4096 MB if your host has the headroom)
- CPU: 2 cores
- Disk: 20 GB, VDI, dynamically allocated
- Settings → Storage: attach the Ubuntu Server ISO to the optical drive

### Networking — pick one

- **Bridged Adapter (recommended)** — Settings → Network → Adapter 1 →
  attached to: *Bridged Adapter* → your Wi-Fi/Ethernet card. The VM gets its
  own IP via DHCP on your LAN and you SSH into that IP directly from
  Windows, same as you would a real remote box.
- **NAT with port forwarding (fallback)** — use this only if bridged
  networking isn't available on your network (locked-down office Wi-Fi,
  certain VPNs). Settings → Network → Adapter 1 → NAT → Advanced → Port
  Forwarding: add a rule, Host Port `2222` → Guest Port `22`. You'll then
  connect with `ssh -p 2222 <user>@127.0.0.1` instead of a LAN IP.

Since this VM isn't internet-facing, there's no AWS security-group layer in
front of it — UFW inside the box is the only firewall, which is actually a
cleaner test of UFW itself.

## 3. Install Ubuntu Server

Boot the VM and run through the installer:

- Hostname: `quickballot-vm`
- Create your initial account (e.g. your own name/username) — this is your
  first login, analogous to the default `ubuntu` user on an EC2 AMI. You'll
  create a separate `deploy` user after first login, same as the EC2 flow.
- When offered, tick **Install OpenSSH server**. Skip the featured
  snaps/server snaps (Docker etc.) — `setup-server.sh` handles that.

Let it finish and reboot (remove the ISO from the optical drive when
prompted, or eject it via Settings → Storage before the reboot).

## 4. Generate an SSH key pair (on your Windows machine)

PowerShell (Windows 10/11 ships an OpenSSH client):

```powershell
ssh-keygen -t ed25519 -C "quickballot-phase1" -f "$HOME\.ssh\quickballot"
```

This creates `quickballot` (private key) and `quickballot.pub` (public key)
in `%USERPROFILE%\.ssh\`. Keep the private key secret — never commit it.

## 5. First login and non-root user

Find the VM's IP at its console (log in with the account you created during
install):

```bash
ip a        # note the address on the bridged interface, e.g. enp0s3
```

From Windows:

```powershell
ssh <initial-user>@<VM_IP>
```

(If you used NAT + port forwarding instead: `ssh -p 2222 <initial-user>@127.0.0.1`.)

On the box, create the `deploy` user:

```bash
sudo adduser deploy              # pick a strong password when prompted
sudo usermod -aG sudo deploy
sudo chown deploy:deploy /home/deploy    # adduser usually does this, but confirm it
sudo mkdir -p /home/deploy/.ssh
sudo cp ~/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys 2>/dev/null || true
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys 2>/dev/null || true
```

Gotcha hit during setup: if `/home/deploy` ends up owned by `root:root`
(e.g. after manually creating `/home/deploy/.ssh` with `sudo mkdir` before
the home directory itself existed), `scp` into `deploy`'s home will fail
with "Permission denied" even though the `.ssh` subfolder looks correctly
owned. Check with `ls -ld /home/deploy` and fix with the `chown` above.

If `~/.ssh/authorized_keys` doesn't exist yet on the initial account (you
haven't copied your key there), copy your public key in directly instead:

Windows PowerShell:

```powershell
Get-Content "$HOME\.ssh\quickballot.pub" | ssh <initial-user>@<VM_IP> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

Then, as `deploy` on the box:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "<paste quickballot.pub contents>" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Log out, then confirm the new user works with the key:

```powershell
ssh -i "$HOME\.ssh\quickballot" deploy@<VM_IP>
```

## 6. Lock down SSH (key-only, no root login)

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

## 7. Run the setup script

Copy [setup-server.sh](../scripts/setup-server.sh) to the box (`scp` from
Windows, or `git clone` the repo once it's pushed) and run it:

```bash
chmod +x setup-server.sh
sudo ./setup-server.sh
```

It's idempotent — rerun it any time, it won't break anything already in
place. Log out and back in once after the first run so the `docker` group
membership takes effect (lets `deploy` run `docker` without `sudo`).

## 8. Verify

```bash
docker run hello-world
sudo ufw status verbose
sudo systemctl status fail2ban --no-pager
free -h        # should show the swap file
```

## 9. Snapshot the clean state (optional but handy)

VirtualBox → right-click the VM → Snapshots → Take. With a "post-setup"
snapshot saved, you can restore to it and rerun `setup-server.sh` any time
to re-prove idempotency without reinstalling Ubuntu.

## 10. Push this repo to GitHub

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
