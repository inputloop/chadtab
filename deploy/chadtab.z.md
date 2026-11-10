# c/z/gw/chadtab: chadtab, landed on gw33 (intention side)

The host side is /c4/g/z/chadtab/ (the program, its tests, deploy/, reg/ its registry, state/ its daemon
state); this note is the intention side. Each names the other.

- What: chadtab 0.2.0, a successor to cron (code.bru.st/corwin/chadtab, private for now), and chadtab.com,
  its site, served by nginx from /var/www/chadtab.com/public with a Let's Encrypt certificate (certbot, webroot).
- Why here: deploy/PLACEMENT.md, the ghostwheel placement rubric; gw33 scored 37 against gw34's 21.5 and
  gw10's 19, as the lab's dev host already serving the web with /c4 beside it.
- Running: chadtab-gw33.service (systemd, as gw33) runs deploy/gw33.tab: chadtab's own CI, at boot and hourly
  at seven past, writing https://chadtab.com/ci/ and the guarded registry atom reg/r/chadtab/ci.
- DNS: chadtab.com @ A and www CNAME at Gandi LiveDNS, set by dn1or (record in c4 d/dns/chadtab.com/).
- Installed for it: emacs-nox (the second reader's tests); /c4/g/z/c4/bin/tv1cr (the naming rule's third reader).

## Owed
- CONTROL: the source reaches gw33 by scp from avalon, not by a pull; the CI tests what was landed.
- COLLABORATIVE: the repository is private until Corwin opens it; the site says so.
- CONTINUITY: chadtab.net and chadtab.org (also at Gandi) still show Gandi's parking page.
