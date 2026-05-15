# Deployment guide

End-to-end checklist for taking the built `dist/` directory live on a
home server, fronted by Cloudflare. Pick one of the two networking
paths in step 4 (direct + DNS, or Cloudflare Tunnel). Everything else
is shared.

## 0. Decide naming

Pick these values up front. They show up in several places.

- [ ] Production hostname, e.g. `jackruder.xyz`.
- [ ] Server LAN-side hostname/IP, e.g. `homelab.lan` or `192.168.1.10`.
- [ ] Deploy user on the server, e.g. `deploy`.
- [ ] Site root path on the server, e.g. `/var/www/personal-site`.

## 1. Prepare the home server

Run on the server.

- [ ] Install Caddy (Debian/Ubuntu):
  ```sh
  sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
  sudo apt update && sudo apt install -y caddy
  ```
- [ ] Create the deploy user and site root:
  ```sh
  sudo useradd -m -s /bin/bash deploy
  sudo mkdir -p /var/www/personal-site
  sudo chown -R deploy:deploy /var/www/personal-site
  ```
- [ ] Lock the deploy user down to rsync-only (optional but recommended).
  Append to the relevant key in `/home/deploy/.ssh/authorized_keys`:
  ```
  command="rsync --server -vlogDtprze.iLsfxC . /var/www/personal-site/",no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding <ssh-ed25519 …>
  ```
  Skip this if you'd rather keep a normal shell for the user.

## 2. Generate a deploy SSH key for GitHub Actions

Run on your local machine.

- [ ] Generate an ed25519 keypair dedicated to this deploy. **Do not
      reuse your personal SSH key.**
  ```sh
  ssh-keygen -t ed25519 -N '' -f ./deploy_key -C 'github-actions deploy'
  ```
- [ ] Copy the public key to the server's deploy user:
  ```sh
  ssh-copy-id -i ./deploy_key.pub deploy@<server-host>
  ```
  (Or paste `deploy_key.pub` into `/home/deploy/.ssh/authorized_keys`
  on the server, prefixed with the `command="..."` from step 1 if you
  locked it down.)
- [ ] Test the key works for rsync from your laptop:
  ```sh
  rsync -avz --delete -e "ssh -i ./deploy_key" ./dist/ deploy@<server-host>:/var/www/personal-site/
  ```
- [ ] Capture the server's host key for `known_hosts`:
  ```sh
  ssh-keyscan -t ed25519 <server-host>
  ```
  Save the output — you'll paste it as a GitHub secret in step 3.

## 3. Add GitHub Actions secrets

In the repo settings → Secrets and variables → Actions → New repository secret.

- [ ] `DEPLOY_SSH_KEY` — the **contents** of `./deploy_key` (the
      private key, including `BEGIN`/`END` lines).
- [ ] `DEPLOY_USER` — `deploy` (or whichever user you created).
- [ ] `DEPLOY_HOST` — public DNS name or IP the GH Actions runner can
      reach (see step 4 for whether this is the public domain or
      something else).
- [ ] `DEPLOY_PATH` — `/var/www/personal-site/` (trailing slash matters
      for rsync semantics).
- [ ] `DEPLOY_KNOWN_HOSTS` — the `ssh-keyscan` output from step 2.

Once all five are set, uncomment the `Deploy with rsync` step in
`.github/workflows/deploy.yml` and push to `main`.

After deleting the local `deploy_key` and `deploy_key.pub`:
```sh
shred -u deploy_key deploy_key.pub   # or: rm -P on macOS
```

## 4. Networking: pick one

### Option A: Cloudflare Tunnel (recommended — no port forwarding)

Best when your home connection is behind CGNAT, has a dynamic IP, or
you don't want to open inbound ports.

- [ ] Install `cloudflared` on the server.
- [ ] `sudo cloudflared service install <token>` after creating a
      tunnel in the Cloudflare dashboard (Zero Trust → Networks →
      Tunnels → Create).
- [ ] In the tunnel's Public Hostname tab, route `jackruder.xyz` →
      `http://localhost:80` (Caddy listens locally, tunnel terminates
      TLS at Cloudflare).
- [ ] `DEPLOY_HOST` in step 3 stays your LAN-side hostname/IP, since
      GH Actions reaches the server via SSH separately. If your server
      isn't publicly reachable for SSH either, use a second Cloudflare
      Tunnel route for SSH or a self-hosted runner. (See "self-hosted
      runner" below.)

### Option B: Direct DNS + port forwarding

Simpler if you already expose ports.

- [ ] Forward ports 80 and 443 on your router to the server's LAN IP.
- [ ] In Cloudflare DNS, create an A record `jackruder.xyz` → your
      public IP, **proxied** (orange cloud).
- [ ] Set Cloudflare SSL/TLS mode to **Full (strict)**.
- [ ] On the server, Caddy will obtain a Let's Encrypt cert
      automatically (HTTP-01 works since the orange cloud allows
      `/.well-known/acme-challenge/` through by default).
- [ ] `DEPLOY_HOST` for SSH should be a different non-proxied DNS
      record (e.g. `ssh.jackruder.xyz`, grey cloud), so the SSH
      connection doesn't get routed through Cloudflare's HTTP proxy.
- [ ] Forward port 22 (or a non-standard SSH port) on your router to
      the server.

### When neither works: self-hosted runner

If the server can't accept inbound connections at all, install a
GitHub Actions self-hosted runner on the server itself. The workflow
then runs *on the server*, replaces the rsync step with a local
`rsync -avz --delete dist/ /var/www/personal-site/`, and never opens
any inbound port.

## 5. Caddy configuration

- [ ] `/etc/caddy/Caddyfile`:
  ```caddyfile
  jackruder.xyz {
      root * /var/www/personal-site
      file_server
      encode zstd gzip

      @assets path /blog-assets/* /_astro/*
      header @assets Cache-Control "public, max-age=31536000, immutable"
      header Cache-Control "public, max-age=300"

      header /index.html Cache-Control "public, max-age=60"
      header /blog/* Cache-Control "public, max-age=300"

      header X-Content-Type-Options "nosniff"
      header Referrer-Policy "strict-origin-when-cross-origin"

      handle_errors {
          rewrite * /404.html
          file_server
      }
  }
  ```
  Drop the `tls` block — Caddy auto-provisions. For Cloudflare Tunnel,
  change the site address to `:80` and remove HTTPS-specific lines
  (the tunnel handles TLS upstream).
- [ ] `sudo systemctl reload caddy`.

## 6. Site URL

Already set to `https://jackruder.xyz` in `astro.config.mjs`. If you
move to a different domain, update that constant and the fallback in
`src/components/layout/BaseLayout.astro`, then push — CI rebuilds with
the new canonical URLs, sitemap, and RSS `<link>` entries.

## 7. First deploy

- [ ] Push to `main` after un-commenting the rsync step.
- [ ] Watch the Actions tab; the `Deploy with rsync` step should
      succeed.
- [ ] Visit `https://jackruder.xyz` and confirm:
  - The hello-world post renders with KaTeX math.
  - Light/dark theme follows `prefers-color-scheme` (no flash).
  - `/rss.xml` lists the post.
  - `/sitemap-index.xml` exists.

## 8. After it's live

- [ ] In Cloudflare Rules → Cache Rules, set HTML to revalidate quickly
      (e.g. 5 min) and hash-named assets under `/_astro/` to cache for
      a year.
- [ ] Consider Cloudflare Page Rules to redirect `www.` to apex (or
      vice versa).
- [ ] Add backup: a nightly `rsync` of `/var/www/personal-site` to
      another machine, or rely on the fact that `dist/` is fully
      regenerable from the repo (the source of truth).
- [ ] Decide on a rollback strategy. The simplest: keep the previous
      `dist/` around on the server.
  ```sh
  # On the server, before each deploy (optional pre-rsync hook):
  rsync -a --delete /var/www/personal-site/ /var/www/personal-site.prev/
  ```

## Troubleshooting

- **`Permission denied (publickey)` in CI:** check `DEPLOY_SSH_KEY` is
  the private key contents (not a path), `DEPLOY_USER` matches the
  server account, and the public key sits in that user's
  `~/.ssh/authorized_keys`.
- **`Host key verification failed`:** `DEPLOY_KNOWN_HOSTS` is missing
  or doesn't match the server. Re-run `ssh-keyscan` and update the
  secret.
- **`rsync: server sent unexpected …` after a forced command:** the
  `command="…"` in `authorized_keys` is too restrictive. Either match
  the rsync command line exactly or drop the forced-command guard
  while debugging.
- **Caddy can't get a cert:** with the orange cloud on, set
  Cloudflare SSL/TLS to **Full (strict)** and ensure ports 80/443 are
  forwarded. Or use the DNS-01 challenge with the
  `caddy-dns/cloudflare` plugin for wildcard certs.
- **404s on direct deep links** (e.g. `/blog/hello-world/`): make sure
  Caddy's `file_server` resolves `index.html` inside the slug
  directory (it does by default; double-check `try_files` isn't
  overriding it).
