# chadtab: make check | make prove-red | make deb.  Copyright 2026 INPUTLOOP; GPL-3.0-or-later.
VERSION := $(shell python3 chadtab --version | cut -d' ' -f2)
DEB := dist/chadtab_$(VERSION)_all.deb
check:
	sh tests/run.sh
prove-red:
	sh tests/run.sh --prove-red
deb: $(DEB)
$(DEB): chadtab chadtab.el README.org debian/control debian/copyright debian/chadtab.service
	rm -rf build/deb && mkdir -p build/deb/DEBIAN build/deb/usr/bin build/deb/usr/share/emacs/site-lisp/chadtab \
	  build/deb/usr/share/doc/chadtab build/deb/usr/lib/systemd/user dist
	sed 's/@VERSION@/$(VERSION)/' debian/control > build/deb/DEBIAN/control
	install -m 755 chadtab build/deb/usr/bin/chadtab
	install -m 644 chadtab.el build/deb/usr/share/emacs/site-lisp/chadtab/chadtab.el
	install -m 644 README.org DESIGN.org RESERVED debian/copyright build/deb/usr/share/doc/chadtab/
	install -m 644 debian/chadtab.service build/deb/usr/lib/systemd/user/chadtab.service
	dpkg-deb --root-owner-group --build build/deb $@
	cd dist && sha256sum $(notdir $@) > $(notdir $@).sha256
.PHONY: check prove-red deb
