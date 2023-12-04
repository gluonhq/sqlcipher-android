include VERSION

sqlite := sqlite-$(version)

GRADLE = ./gradlew
TARGET := build

SQLITE_FLAGS := $($(target)_SQLITE_FLAGS)
SQLITE_AMAL_PREFIX = sqlite-amalgamation-$(shell ./amalgamation_version.sh $(version))
SQLITE_DST := sqlcipher/src/main/jni/sqlcipher

.PHONY: clean build-debug build-release \
	publish-snapshot-to-local-maven \
	publish-snapshot-to-local-nexus

SQLITE_OUT:=$(SQLITE_DST)/sqlite3.c
SQLITE_ARCHIVE:=$(TARGET)/$(sqlite)-sqlcipher.zip
SQLITE_UNPACKED:=$(TARGET)/sqlite-unpack.log

$(SQLITE_ARCHIVE):
	echo "Downloading Archive"
	mkdir -p $(TARGET)
	curl -SL "https://github.com/gluonhq/sqlcipher/releases/download/$(version)/sqlcipher-amal-$(version).zip" > $@
	@mkdir -p $(@D)

$(SQLITE_UNPACKED): $(SQLITE_ARCHIVE)
	unzip -qo $< -d $(TARGET)
	if [ -d "$(TARGET)/sqlcipher-$(version)" ] ; then mv $(TARGET)/sqlcipher-$(version) $(TARGET)/$(SQLITE_AMAL_PREFIX);fi
	touch $@

copy-sqlite: $(SQLITE_UNPACKED)
	cp $(TARGET)/$(SQLITE_AMAL_PREFIX)/sqlite3.c $(SQLITE_DST)
	cp $(TARGET)/$(SQLITE_AMAL_PREFIX)/sqlite3.h $(SQLITE_DST)

copy-external-deps: copy-sqlite
	cp -R external-dependencies/libcrypto sqlcipher/src/main/jni/sqlcipher/android-libs
	cp -R external-dependencies/openssl-1.1.1t/include sqlcipher/src/main/jni/sqlcipher/android-libs

clean:
	-rm -rf build
	-rm -f $(SQLITE_DST)/sqlite3.c
	-rm -f $(SQLITE_DST)/sqlite3.h
	-rm -rf $(SQLITE_DST)/android-libs
	$(GRADLE) clean

build-debug: copy-external-deps
	$(GRADLE) \
	assembleDebug

build-release: copy-external-deps
	$(GRADLE) \
	-PsqlcipherAndroidVersion="$(SQLCIPHER_ANDROID_VERSION)" \
	assembleRelease

deploy: build-release
	$(GRADLE) \
	-PpublishSnapshot=false \
	-PpublishLocal=false \
	-PdebugBuild=false \
	-PnexusUsername="${GLUON_NEXUS_USERNAME}" \
	-PnexusPassword="${GLUON_NEXUS_PASSWORD}" \
	-PsqlcipherAndroidVersion="$(SQLCIPHER_ANDROID_VERSION)" \
	sqlcipher:publish

deploy-local: build-debug
	$(GRADLE) \
	-PpublishSnapshot=true \
	sqlcipher:publishToMavenLocal
