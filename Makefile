# makefile

#
# Patches/Installs/Builds DSDT patches for H77M-ITX
#
# Created by RehabMan
# Adapted by vbourachot
#

# DSDT patch: from compiled acpi tables to installed patched dsdt/ssdt-1
# make distclean disassemble patch && make && make install
#
# AppleHDA patch: Create injector kext and install in SLE
# make patch_hda && sudo make install_hda
#
# Install Clover config
# make install_config

EFIDIR=/Volumes/EFI
EFIVOL=/dev/disk0s1
LAPTOPGIT=../Laptop-DSDT-Patch
DEBUGGIT=../OS-X-ACPI-Debug
BUILDDIR=./build
PATCHED=./patched
UNPATCHED=./unpatched
DISASSEMBLE_SCRIPT=./disassemble.sh
OSXV=10.10

PATCH_HDA_SCRIPT=./patch_hda.sh
HDACODEC=ALC892

NULLETHDIR=./null_eth
PATCH_RMNE_SCRIPT=./patch_null_eth_mac.sh

IASLFLAGSVERBOSE=-vr -w1
IASLFLAGS=-ve
IASL=/usr/local/bin/iasl
PATCHMATIC=/usr/local/bin/patchmatic
PRODUCTS=$(BUILDDIR)/dsdt.aml

XMLLINT=xmllint --valid --noout
#XMLLINT=touch

# Compile DSDT/SSDTs
all: $(PRODUCTS)

$(BUILDDIR)/dsdt.aml: $(PATCHED)/dsdt.dsl
	$(IASL) $(IASLFLAGS) -p $@ $<

# Patch with 'patchmatic'
patch:
	cp $(UNPATCHED)/DSDT.aml.dsl $(PATCHED)/dsdt.dsl
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_HPET.txt $(PATCHED)/dsdt.dsl
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_IRQ.txt $(PATCHED)/dsdt.dsl
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_WAK1.txt $(PATCHED)/dsdt.dsl
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_RTC.txt $(PATCHED)/dsdt.dsl
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/usb/usb_7-series.txt $(PATCHED)/dsdt.dsl
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_SMBUS.txt $(PATCHED)/dsdt.dsl

	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/syntax.txt $(PATCHED)/dsdt.dsl

	# Toleda's patches for syntax/audio
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/ib1-ami_efi_clean_compile.txt $(PATCHED)/dsdt.dsl
	# For HD4K as primary GPU - enables HDMI audio
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/ib3-hdmi_audio_ami_efi_hd4000-3.txt $(PATCHED)/dsdt.dsl
	# For PCIE as primary GPU
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/ib3-hdmi_audio_ami_efi_pcie-3.txt $(PATCHED)/dsdt.dsl

# Clover Install DSDT/SSDTs
install: $(PRODUCTS)
	if [ ! -d $(EFIDIR) ]; then mkdir $(EFIDIR) && diskutil mount -mountPoint $(EFIDIR) $(EFIVOL); fi
	cp $(BUILDDIR)/dsdt.aml $(EFIDIR)/EFI/CLOVER/ACPI/patched
	diskutil unmount $(EFIDIR)
	if [ -d $(EFIDIR) ]; then rmdir $(EFIDIR); fi


# Clean everything but the disassembled unpatched dsdt
clean:
	rm -f $(PRODUCTS)
	rm -rf $(BUILDDIR)/AppleHDA_$(HDACODEC).kext
	rm -f $(PATCHED)/*.dsl

# Clean everything
distclean: clean
	rm -f $(UNPATCHED)/*.dsl

# Disassemble DSDT/SSDTs from origin/ acpi extract
disassemble:
	$(DISASSEMBLE_SCRIPT)

# Patch AppleHDA for ALC892 codec
patch_hda:
	$(PATCH_HDA_SCRIPT)

# Install AppleHDA_ALC892.kext injector in SLE
install_hda:
	if [ -d /System/Library/Extensions/AppleHDA_$(HDACODEC).kext ]; \
	then rm -rf /System/Library/Extensions/AppleHDA_$(HDACODEC).kext && cp -R $(BUILDDIR)/AppleHDA_$(HDACODEC).kext /System/Library/Extensions/; \
	else cp -R $(BUILDDIR)/AppleHDA_$(HDACODEC).kext /System/Library/Extensions/; fi
	touch /System/Library/Extensions


# Install Clover config.plist
# Appends smbios info if ./config.plist.smbios exists
install_config:
	if [ -f ./config.plist.smbios ]; then \
		./config_append_smbios.sh && \
		$(XMLLINT) ./config.plist.local; \
	else \
		$(XMLLINT) ./config.plist; \
	fi
	if [ ! -d $(EFIDIR) ]; then mkdir $(EFIDIR) && diskutil mount -mountPoint $(EFIDIR) $(EFIVOL); fi
	if [ -f ./config.plist.smbios ]; then \
		cp ./config.plist.local $(EFIDIR)/EFI/CLOVER/config.plist; \
		diff ./config.plist $(EFIDIR)/EFI/CLOVER/config.plist || exit 0; \
	else \
		cp ./config.plist $(EFIDIR)/EFI/CLOVER/; \
	fi
	diskutil unmount $(EFIDIR)
	if [ -d $(EFIDIR) ]; then rmdir $(EFIDIR); fi

.PHONY: all clean distclean patch patch_debug install \
		disassemble patch_hda install_hda install_config

