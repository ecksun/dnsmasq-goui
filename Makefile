NAME = dnsmasq-goui
VERSION = $(shell git describe --always --match 'v[0-9]*' HEAD)
VERSION_NUMBER = $(shell echo $(VERSION) | cut -c2-)
OUT_DIR = build
PACKAGE_DIR = $(OUT_DIR)/$(NAME)-$(VERSION)

GH_VERSION = 2.83.1
GH_ARCHIVE = $(OUT_DIR)/tmp/gh_$(GH_VERSION)_linux_amd64.tar.gz
GH = $(OUT_DIR)/tmp/gh_$(GH_VERSION)_linux_amd64/bin/gh

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

$(OUT_DIR)/tmp/:
	mkdir -p $@

$(GH_ARCHIVE): | $(OUT_DIR)/tmp/
	curl -L https://github.com/cli/cli/releases/download/v$(GH_VERSION)/gh_$(GH_VERSION)_linux_amd64.tar.gz -o $@

$(GH): $(GH_ARCHIVE)
	tar -xf $(GH_ARCHIVE) --directory $(OUT_DIR)/tmp/ gh_$(GH_VERSION)_linux_amd64/bin/gh
	touch $@

.PHONY: release
release: $(GH) $(PACKAGE_DIR).deb $(OUT_DIR)/$(NAME)
	$(GH) release create --verify-tag --notes-from-tag "$(VERSION)" \
		"$(PACKAGE_DIR).deb" \
		"$(OUT_DIR)/$(NAME)"

.PHONY: clean
clean:
	rm -rf $(OUT_DIR)
