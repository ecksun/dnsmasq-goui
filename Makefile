NAME = dnsmasq-goui
VERSION = $(shell git describe --always --match 'v[0-9]*' HEAD)
VERSION_NUMBER = $(shell echo $(VERSION) | cut -c2-)
OUT_DIR = build
PACKAGE_DIR = $(OUT_DIR)/$(NAME)-$(VERSION)

$(OUT_DIR)/$(NAME): main.go go.mod
	go build -o $@ .

$(PACKAGE_DIR)/usr/bin/$(NAME): $(OUT_DIR)/$(NAME)
	install -D $< $@

$(PACKAGE_DIR)/DEBIAN/control: debian/control
	install -D -m 644 $< $@
	echo "Version: $(VERSION_NUMBER)" >> $@

$(PACKAGE_DIR)/lib/systemd/system/dnsmasq-goui.service: dnsmasq-goui.service
	install -D -m 644 $< $@

$(PACKAGE_DIR).deb: $(PACKAGE_DIR)/usr/bin/$(NAME) $(PACKAGE_DIR)/DEBIAN/control $(PACKAGE_DIR)/lib/systemd/system/dnsmasq-goui.service
	fakeroot dpkg-deb --build $(PACKAGE_DIR)

.PHONY: deb
deb: $(PACKAGE_DIR).deb
