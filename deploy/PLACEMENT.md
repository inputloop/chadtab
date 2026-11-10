# Placing a project on the ghostwheel: the rubric, and chadtab.com scored with it

A reusable rubric for choosing which ghostwheel host a new site, service or CI job lands on. It has
gates (any one failing rules a host out) and weighted scores (the highest total wins; a tie goes to the
host with fewer human accounts). Every input is either probed on the host by the one command below or
read from the host notes; each scored line says which.

The weights are the house set (4, 9, 17), picked, not derived: 17 for the thing that matters most, 9 for
the things that change the work, 4 for the things that only make it easier. Falsifier for the weights: a
placement the rubric picks that Corwin would not have picked. When that happens, the weight that put it
there is the one to change, and the case goes in the table at the end.

## Gates

| gate | passes when | read from |
|---|---|---|
| G1 access | the host's own gwN login reaches it, with sudo | probe: `sudo yes` |
| G2 not leaving | the host is not slated to be rebuilt, retired or handed over within the project's first stage | host notes (rings plan) |
| G3 no tenant at risk | a new, untested service there cannot take down someone else's service | host notes; probe: listening ports and vhosts |

## Scores

| # | weight | scores 1 when | 0.5 when | read from |
|---|---|---|---|---|
| S1 stage fit | 17 | the host's ring role matches the project's stage (a new project goes to a dev/test host; a proven one to its ring) | the host can take it but is meant for something else first | host notes |
| S2 serves the web | 9 | a web server and a certificate tool are already running | one of the two | probe: `has nginx/apache2/caddy`, `has certbot/dehydrated`, ports 80 and 443 |
| S3 neighbours | 9 | the host already holds what the project works with (for chadtab: /c4) | | probe: `c4 yes` |
| S4 room | 4 | at least 4 GB memory free and 9 GB disk free | one of the two | probe: `mem_mb`, `disk_root_mb` |
| S5 builds | 4 | python3, emacs, dpkg-deb and git are all there | all but one | probe: `has ...` |
| tie | | fewer human accounts | | probe: `humans` |

## The probe (one ssh, read-only, nothing installed)

```sh
ssh gwN@gwN.bru.st 'h=$(hostname); echo "host $h"; echo "os $( . /etc/os-release 2>/dev/null; echo $PRETTY_NAME)"; echo "load $(cut -d" " -f1-3 /proc/loadavg)"; echo "cpus $(nproc)"; echo "mem_mb $(awk "/MemTotal/{t=\$2}/MemAvailable/{a=\$2}END{print int(t/1024)\" \"int(a/1024)}" /proc/meminfo)"; echo "disk_root_mb $(df -Pm / | awk "NR==2{print \$2\" \"\$4}")"; for p in nginx apache2 caddy dehydrated certbot docker python3 emacs dpkg-deb git forgejo; do command -v $p >/dev/null 2>&1 && echo "has $p"; done; echo "listen $(ss -ltnH | awk "{print \$4}" | sed "s/.*://" | sort -un | tr "\n" " ")"; echo "humans $(getent passwd | awk -F: "\$3>=1000 && \$3<60000 && \$7 !~ /(nologin|false)\$/" | wc -l)"; sudo -n true 2>/dev/null && echo "sudo yes"; [ -d /c4 ] && echo "c4 yes"'
```

## chadtab.com, 2026-11-10

Probed gw33, gw34 and gw10 (key_run, the projects ssh key, each host under its own login).

| host | what the probe said |
|---|---|
| gw33 | Ubuntu 26.04; 8 cpus; 13 GB of 14 free; 65 GB free on /, 1.9 TB on /c4; nginx + certbot, serving 80 and 443 with 5 sites (corwin.cloud, obsmage.com, ghostlights.theater, comie.tech, default); docker, python3, dpkg-deb, git; no emacs; 13 human accounts; sudo yes; /c4 yes |
| gw34 | Debian 13; 12 cpus; 24 GB of 31 free; 847 GB free; no web server or certificate tool; python3, dpkg-deb, git; 14 human accounts; sudo yes; /c4 yes |
| gw10 | Ubuntu 24.04; 8 cpus; 30 GB of 32 free; 1.3 TB free; nginx (6 sites), no certificate tool on PATH; forgejo, postgres, samba; docker, python3, emacs, dpkg-deb, git; 19 human accounts; sudo yes; no /c4 |

Gates: all three pass G1. gw7 (not probed) fails G2: it is due for a rebuild in the GRAIN ring.
G3: gw10 carries other people's services (forgejo, postgres, samba, 19 accounts), so a new service there
is held to "proven first"; it passes, narrowly, for a static site only.

| host | S1 stage (17) | S2 web (9) | S3 /c4 (9) | S4 room (4) | S5 builds (4) | total |
|---|---|---|---|---|---|---|
| gw33 | 1: the lab's dev host (dev.ghostwheel.chat, obsmage.com, corwin.cloud) | 1 | 1 | 1 | 0.5 (no emacs) | **37** |
| gw34 | 0.5: GRAIN prototype, C4 as hypervisor, clowntable's home; not yet serving | 0 | 1 | 1 | 0.5 (no emacs) | 21.5 |
| gw10 | 0.5: GREAT ring's live lab; proven things go there | 0.5 | 0 | 1 | 1 | 19 |

**chadtab.com goes to gw33.** Its CI goes there too, run by chadtab itself (a block that pulls the
repository, runs the tests, and writes the result page): emacs-nox is installed there for the second reader
(the Emacs Lisp clocks), under the standing rule that Emacs goes in as soon as Emacs-dependent work needs
testing. When chadtab is proven, the rubric's S1 points it at the GREAT ring (gw10's role).

## Cases (where the rubric and Corwin disagreed)

None yet.

Copyright 2026 INPUTLOOP (Bryant Frankford and Corwin Brust); CC-BY-SA-4.0. Mentat (for Corwin; claude-opus-5-5).
