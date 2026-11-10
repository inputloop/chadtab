#!/bin/sh
# deploy/install.sh -- put chadtab and chadtab.com on gw33.  Run as gw33 (it uses sudo for the root steps).
#   sh install.sh http      first stage: the app under /c4/g/z/chadtab, the site, nginx on plain http
#   sh install.sh tls       once DNS points here: certbot (webroot), then the https config
#   sh install.sh daemon    emacs-nox for the second reader; chadtab's own CI as a system service run as gw33
#   sh install.sh site      refresh the site's files only
# Each stage says what it does; old site copies are kept (site.YYYYMMDD-HHMMSS), never deleted.
# Copyright 2026 INPUTLOOP; GPL-3.0-or-later.  Mentat (for Corwin; claude-opus-5-5)
set -eu
src=$(cd "$(dirname "$0")/.." && pwd)
app=/c4/g/z/chadtab
www=/var/www/chadtab.com
stage=${1:-}
site() {
  [ -d "$www/public" ] && sudo cp -a "$www/public" "$www/site.$(date +%Y%m%d-%H%M%S)"
  sudo mkdir -p "$www/public/ci" "$www/acme"
  sudo cp "$src"/site/*.html "$src"/site/*.css "$www/public/"
  sudo chown -R gw33:www-data "$www/public"; sudo find "$www/public" -type d -exec chmod 755 {} +; sudo find "$www/public" -type f -exec chmod 644 {} +
  echo "site: $www/public"
}
case "$stage" in
http)
  sudo mkdir -p "$app"; sudo chown gw33:gw33 "$app"
  rsync -a --delete --exclude reg --exclude state "$src"/ "$app"/
  site
  sudo cp "$src/deploy/nginx-chadtab.com.http.conf" /etc/nginx/sites-available/chadtab.com
  sudo ln -sf /etc/nginx/sites-available/chadtab.com /etc/nginx/sites-enabled/chadtab.com
  sudo nginx -t && sudo systemctl reload nginx
  echo "http: chadtab.com served over plain http from $www/public" ;;
tls)
  sudo certbot certonly --webroot -w "$www/acme" -d chadtab.com -d www.chadtab.com --non-interactive --keep-until-expiring
  sudo cp "$src/deploy/nginx-chadtab.com.conf" /etc/nginx/sites-available/chadtab.com
  sudo nginx -t && sudo systemctl reload nginx
  echo "tls: https://chadtab.com" ;;
daemon)
  command -v emacs >/dev/null 2>&1 || sudo apt-get install -y emacs-nox
  sudo tee /etc/systemd/system/chadtab-gw33.service >/dev/null <<UNIT
[Unit]
Description=chadtab on gw33 (chadtab's own CI, run by chadtab)
After=network-online.target

[Service]
User=gw33
WorkingDirectory=$app
Environment=CHADTAB_CI_OUT=$www/public/ci
ExecStart=/usr/bin/python3 $app/chadtab daemon $app/deploy/gw33.tab --state $app/state
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
  sudo systemctl daemon-reload && sudo systemctl enable --now chadtab-gw33.service
  sleep 2; systemctl --no-pager status chadtab-gw33.service | head -5 ;;
site) site ;;
*) echo "usage: sh install.sh http|tls|daemon|site"; exit 1 ;;
esac
