TARGET := iphone:clang:13.5:12.0
GO_EASY_ON_ME = 1

ARCHS = arm64 arm64e

BFINJECT_SRC=DumpDecrypted.m bfdecrypt.m
MINIZIP_SRC=SSZipArchive/minizip/crypt.c \
SSZipArchive/minizip/ioapi.c \
SSZipArchive/minizip/ioapi_buf.c \
SSZipArchive/minizip/ioapi_mem.c \
SSZipArchive/minizip/minishared.c \
SSZipArchive/minizip/unzip.c \
SSZipArchive/minizip/zip.c \
SSZipArchive/minizip/aes/aes_ni.c \
SSZipArchive/minizip/aes/aescrypt.c \
SSZipArchive/minizip/aes/aeskey.c \
SSZipArchive/minizip/aes/aestab.c \
SSZipArchive/minizip/aes/fileenc.c \
SSZipArchive/minizip/aes/hmac.c \
SSZipArchive/minizip/aes/prng.c \
SSZipArchive/minizip/aes/pwd2key.c \
SSZipArchive/minizip/aes/sha1.c
SSZIPARCHIVE_SRC=SSZipArchive/SSZipArchive.m

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = bfdecrypt
$(TWEAK_NAME)_FILES = bfdecrypt.m DumpDecrypted.m $(MINIZIP_SRC) $(SSZIPARCHIVE_SRC)
# 
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -I SSZipArchive -I SSZipArchive/minizip
$(TWEAK_NAME)_FRAMEWORKS += CoreFoundation IOKit Foundation JavaScriptCore UIKit Security CFNetwork CoreGraphics
#$(TWEAK_NAME)_EXTRA_FRAMEWORKS += Cephei

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
