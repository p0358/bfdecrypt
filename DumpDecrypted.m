/*
    bfinject - Inject shared libraries into running App Store apps on iOS 11.x < 11.2
    https://github.com/BishopFox/bfinject
    
    Carl Livitt @ Bishop Fox

	Based on code originally by 10n1c: https://github.com/stefanesser/dumpdecrypted/blob/master/dumpdecrypted.c
	Now with the following enhancements:
	- Dump ALL encrypted images in the target application: the app itself, its frameworks, etc.
	- Create a valid .ipa containing the decrypted binaries. Save it in ~/Documents/decrypted-app.ipa
	- The .ipa can be modified and re-signed with a developer cert for redeployment to non-jailbroken devices
	- Auto detection of all the necessary sandbox paths
	- Converted into an Objective-C class for ease of use.
*/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#include <objc/runtime.h>
#include <mach/mach.h>
#include <err.h>
#include <mach-o/ldsyms.h>
#include <libkern/OSCacheControl.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <sys/time.h>
#include <sys/uio.h>
#include <netdb.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <errno.h>
#import "SSZipArchive.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "DumpDecrypted.h"

//#define DEBUG(...) NSLog(__VA_ARGS__);
#define DEBUG(...) {}

#define swap32(value) (((value & 0xFF000000) >> 24) | ((value & 0x00FF0000) >> 8) | ((value & 0x0000FF00) << 8) | ((value & 0x000000FF) << 24) )


@implementation DumpDecrypted

-(id) initWithPathToBinary:(NSString *)pathToBinary {
	if(!self) {
		self = [super init];
	}

	[self setAppPath:[pathToBinary stringByDeletingLastPathComponent]];
    
    NSString *docPath = [[[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject] path];
    NSDictionary *pathAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:docPath error:nil];
    NSLog(@"path: %@ %@", pathAttrs, docPath);
	[self setDocPath:docPath];
    
    //[self setDocPath:@"/var/mobile/Library/Preferences"];
	char *lastPartOfAppPath = strdup([[self appPath] UTF8String]);
	lastPartOfAppPath = strrchr(lastPartOfAppPath, '/') + 1;
	NSLog(@"[dumpdecrypted] init: appDirName: %s", lastPartOfAppPath);
	self->appDirName = strdup(lastPartOfAppPath);

	return self;
}


-(void) makeDirectories:(const char *)encryptedImageFilenameStr {
	char *appPath = (char *)[[self appPath] UTF8String];
	char *docPath = (char *)[[self docPath] UTF8String];
	char *savePtr;
	char *encryptedImagePathStr = savePtr = strdup(encryptedImageFilenameStr);
	self->filename = strdup(strrchr(encryptedImagePathStr, '/') + 1);

	// Normalize the filenames
	if(strstr(encryptedImagePathStr, "/private") == encryptedImagePathStr)
		encryptedImagePathStr += 8;
	if(strstr(appPath, "/private") == appPath)
		appPath += 8;
	
	// Find start of image path, relative to the base of the app sandbox (ie. /var/mobile/.../FooBar.app/THIS_PART_HERE)
	encryptedImagePathStr += strlen(appPath) + 1; // skip over the app path
	char *p = strrchr(encryptedImagePathStr, '/');
	if(p)
		*p = '\0';

	DEBUG(@"[dumpdecrypted] encryptedImagePathStr: %s", encryptedImagePathStr);
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSError *err = nil;
	char *lastPartOfAppPath = strdup(appPath); // Must free()
	lastPartOfAppPath = strrchr(lastPartOfAppPath, '/');
	lastPartOfAppPath++;
	NSString *path = [NSString stringWithFormat:@"%s/ipa/Payload/%s", docPath, lastPartOfAppPath];
	self->appDirPath = strdup([path UTF8String]);
	if(p)
		path = [NSString stringWithFormat:@"%@/%s", path, encryptedImagePathStr];

	DEBUG(@"[dumpdecrypted] make_directories making dir: %@", path);
	if(! [fm createDirectoryAtPath:path withIntermediateDirectories:true attributes:nil error:&err]) {
		DEBUG(@"[dumpdecrypted] WARNING: make_directories failed to make directory %@. Error: %@", path, err);
	}

	free(savePtr);

	snprintf(self->decryptedAppPathStr, PATH_MAX, "%s/%s", [path UTF8String], self->filename);

	return;
}

 
-(BOOL) dumpDecryptedImage:(const struct mach_header *)image_mh fileName:(const char *)encryptedImageFilenameStr image:(int)imageNum {
	struct load_command *lc;
	struct encryption_info_command *eic;
	struct fat_header *fh;
	struct fat_arch *arch;
	struct mach_header *mh;
	char buffer[1024];
	unsigned int fileoffs = 0, off_cryptid = 0, restsize;
	int i, fd, outfd, r, n;
	
	/* detect if this is a arm64 binary */
	if (image_mh->magic == MH_MAGIC_64) {
		lc = (struct load_command *)((unsigned char *)image_mh + sizeof(struct mach_header_64));
		DEBUG(@"[dumpDecrypted] detected 64bit ARM binary in memory.\n");
	} else if(image_mh->magic == MH_MAGIC) { /* we might want to check for other errors here, too */
		lc = (struct load_command *)((unsigned char *)image_mh + sizeof(struct mach_header));
		DEBUG(@"[dumpDecrypted] detected 32bit ARM binary in memory.\n");
	} else {
		NSLog(@"[dumpDecrypted] No valid header found!!");
		return false;
	}
	
	/* searching all load commands for an LC_ENCRYPTION_INFO load command */
	for (i=0; i<image_mh->ncmds; i++) {
		if (lc->cmd == LC_ENCRYPTION_INFO || lc->cmd == LC_ENCRYPTION_INFO_64) {
			eic = (struct encryption_info_command *)lc;
			
			const char *appFilename = strrchr(encryptedImageFilenameStr, '/');
			if(appFilename == NULL) {
				NSLog(@"[dumpDecrypted] There are no / in the filename. This is an error.\n");
				return false;
			}
			appFilename++;

			/* If this load command is present, but data is not crypted then exit */
			if (eic->cryptid == 0) {
				NSLog(@"[dumpDecrypted] CryptID = 0!! ");
				return false;
			}

			// Create a dir structure in ~ just like in /path/to/FooApp.app/Whatever
			[self makeDirectories:encryptedImageFilenameStr];

			off_cryptid=(off_t)((off_t)(void*)&eic->cryptid - (off_t)(void*)image_mh);
			DEBUG(@"[dumpDecrypted] offset to cryptid (%d) found in memory @ %p (from %p). off_cryptid = %u (0x%x)\n", eic->cryptid, &eic->cryptid, image_mh, off_cryptid, off_cryptid);
			//NSLog(@"[dumpDecrypted] Found encrypted data at offset %u 0x%08x. image_mh @ %p. cryptedData @ 0x%x. cryptsize = %u (0x%x) bytes.\n", eic->cryptoff, eic->cryptoff, image_mh, (unsigned int)image_mh + eic->cryptoff, eic->cryptsize, eic->cryptsize);
			
			DEBUG(@"[dumpDecrypted] Dumping: %s", encryptedImageFilenameStr);
			DEBUG(@"[dumpDecrypted]    Into: %s", self->decryptedAppPathStr);
			fd = open(encryptedImageFilenameStr, O_RDONLY);
			if (fd == -1) {
				NSLog(@"[dumpDecrypted] Failed to open %s", encryptedImageFilenameStr);
				return false;
			}
			
			DEBUG(@"[dumpDecrypted] Reading header");
			n = read(fd, (void *)buffer, sizeof(buffer));
			if (n != sizeof(buffer)) {
				NSLog(@"[dumpDecrypted] Warning read only %d of %lu bytes from encrypted file.\n", n, sizeof(buffer));
				return false;
			}

			DEBUG(@"[dumpDecrypted] Detecting header type\n");
			fh = (struct fat_header *)buffer;
			
			/* Is this a FAT file - we assume the right endianess */
			if (fh->magic == FAT_CIGAM) {
				DEBUG(@"[dumpDecrypted] Executable is a FAT image - searching for right architecture\n");
				arch = (struct fat_arch *)&fh[1];
				for (i=0; i<swap32(fh->nfat_arch); i++) {
					if ((image_mh->cputype == swap32(arch->cputype)) && (image_mh->cpusubtype == swap32(arch->cpusubtype))) {
						fileoffs = swap32(arch->offset);
						DEBUG(@"[dumpDecrypted] Correct arch is at offset 0x%x in the file.\n", fileoffs);
						break;
					}
					arch++;
				}
				if (fileoffs == 0) {
					NSLog(@"[dumpDecrypted] Could not find correct arch in FAT image\n");
					return false;
				}
			} else if (fh->magic == MH_MAGIC || fh->magic == MH_MAGIC_64) {
				DEBUG(@"[dumpDecrypted] Executable is a plain MACH-O image, fileoffs = 0\n");
			} else {
				NSLog(@"[dumpDecrypted] Executable is of unknown type, fileoffs = 0\n");
				return false;
			}

			DEBUG(@"[dumpDecrypted] Opening %s for writing.\n", decryptedAppPathStr);
			outfd = open(decryptedAppPathStr, O_RDWR|O_CREAT|O_TRUNC, 0644);
			if (outfd == -1) {
				NSLog(@"[dumpDecrypted] Failed opening: ");
				return false;
			}
			
			/* calculate address of beginning of crypted data */
			n = fileoffs + eic->cryptoff;
			
			restsize = lseek(fd, 0, SEEK_END) - n - eic->cryptsize;		
			//NSLog(@"[dumpDecrypted] restsize = %u, n = %u, cryptsize = %u, total = %u", restsize, n, eic->cryptsize, n + eic->cryptsize + restsize);
			lseek(fd, 0, SEEK_SET);
			
			DEBUG(@"[dumpDecrypted] Copying the not encrypted start of the file (%u bytes)\n", n);
			
			/* first copy all the data before the encrypted data */
			char *buf = (char *)malloc((size_t)n);
			r = read(fd, buf, n);
			if(r != n) {
				NSLog(@"[dumpDecrypted] Error reading start of file\n");
				return false;
			}
			r = write(outfd, buf, n);
			if(r != n) {
				NSLog(@"[dumpDecrypted] Error writing start of file\n");
				return  false;
			}
			free(buf);

			/* now write the previously encrypted data */

			DEBUG(@"[dumpDecrypted] Dumping the decrypted data into the file (%u bytes)\n", eic->cryptsize);
			r = write(outfd, (unsigned char *)image_mh + eic->cryptoff, eic->cryptsize);
			if (r != eic->cryptsize) {
				NSLog(@"[dumpDecrypted] Error writing encrypted part of file\n");
				return false;
			}
			
			/* and finish with the remainder of the file */
			DEBUG(@"[dumpDecrypted] Copying the not encrypted remainder of the file (%u bytes)\n", restsize);
			lseek(fd, eic->cryptsize, SEEK_CUR);
			buf = (char *)malloc((size_t)restsize);
			r = read(fd, buf, restsize);
			if (r != restsize) {
				NSLog(@"[dumpDecrypted] Error reading rest of file, got %u bytes\n", r);
				return false;
			}
			r = write(outfd, buf, restsize);
			if (r != restsize) {
				NSLog(@"[dumpDecrypted] Error writing rest of file\n");
				return false;
			}
			free(buf);

			if (off_cryptid) {
				uint32_t zero=0;
				off_cryptid += fileoffs;
				DEBUG(@"[dumpDecrypted] Setting the LC_ENCRYPTION_INFO->cryptid to 0 at offset 0x%x (0x%x into file)\n", off_cryptid, off_cryptid + fileoffs);
				if (lseek(outfd, off_cryptid, SEEK_SET) == off_cryptid) {
					if(write(outfd, &zero, 4) != 4) {
						NSLog(@"[dumpDecrypted] Error writing cryptid value!!\n");
						// Not a fatal error, just warn
					}
				} else {
					NSLog(@"[dumpDecrypted] Failed to seek to cryptid offset!!");
					// this error is not treated as fatal
				}
			}
	
			close(fd);
			close(outfd);
			sync();
			
			return true;
		}
		
		lc = (struct load_command *)((unsigned char *)lc+lc->cmdsize);		
	}
	DEBUG(@"[!] This mach-o file is not encrypted. Nothing was decrypted.\n");
	return false;
}


-(void) dumpDecrypted {
	uint32_t numberOfImages = _dyld_image_count();
	struct mach_header *image_mh;
	const char *appPath = [[self appPath] UTF8String];

	NSLog(@"[dumpDecrypted] There are %d images mapped.", numberOfImages);
	for(int i = 0; i < numberOfImages; i++) {
		DEBUG(@"[dumpDecrypted] image %d", i);
		image_mh = (struct mach_header *)_dyld_get_image_header(i);
		const char *imageName = _dyld_get_image_name(i);

		if(!imageName || !image_mh)
			continue;

		// Attempt to decrypt any image loaded from the app's Bundle directory.
		// This covers the app binary, frameworks, extensions, etc etc
		DEBUG(@"[dumpDecrypted] Comparing %s to %s", imageName, appPath);
		if(strstr(imageName, appPath) != NULL) {
			NSLog(@"[dumpDecrypted] Dumping image %d: %s", i, imageName);
			[self dumpDecryptedImage:image_mh fileName:imageName image:i];
		}
	}
}


-(BOOL) fileManager:(NSFileManager *)f shouldProceedAfterError:(BOOL)proceed copyingItemAtPath:(NSString *)path toPath:(NSString *)dest {
	return true;
} 

- (BOOL) fileManager:(NSFileManager *)f shouldProceedAfterError:(BOOL)proceed movingItemAtPath:(NSString *)path toPath:(NSString *)dest {
	return true;
}

-(NSString *)IPAPath {
	return [NSString stringWithFormat:@"%@/decrypted-app-temp.ipa", [self docPath]];
}

-(NSString *)FinalIPAPath {
	return [NSString stringWithFormat:@"%@/decrypted-app.ipa", [self docPath]];
}

-(void) createIPAFile {
	NSString *IPAFile = [self IPAPath];
	NSString *appDir  = [self appPath];
	NSString *appCopyDir = [NSString stringWithFormat:@"%@/ipa/Payload/%s", [self docPath], self->appDirName];
	NSString *zipDir = [NSString stringWithFormat:@"%@/ipa", [self docPath]];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSError *err = nil;

	[fm removeItemAtPath:IPAFile error:nil];
	[fm removeItemAtPath:appCopyDir error:nil];
	[fm createDirectoryAtPath:appCopyDir withIntermediateDirectories:true attributes:nil error:&err];
    //mkdir([appCopyDir UTF8String]);
    mkdir([appCopyDir UTF8String], 0755);
    chown([appCopyDir UTF8String], 501, 501);
    NSLog(@"create directory error: %@", err);
	[fm setDelegate:(id<NSFileManagerDelegate>)self];

	NSLog(@"[dumpDecrypted] ======== START FILE COPY - IGNORE ANY SANDBOX WARNINGS ========");
	NSLog(@"[dumpDecrypted] IPAFile: %@", IPAFile);
	NSLog(@"[dumpDecrypted] appDir: %@", appDir);
	NSLog(@"[dumpDecrypted] appCopyDir: %@", appCopyDir);
	NSLog(@"[dumpDecrypted] zipDir: %@", zipDir);
	
	[fm copyItemAtPath:appDir toPath:appCopyDir error:&err];
    NSLog(@"error: %@", err);
	NSLog(@"[dumpDecrypted] ======== END OF FILE COPY ========");

	// Replace encrypted binaries with decrypted versions
	NSLog(@"[dumpDecrypted] ======== START DECRYPTION PROCESS ========");
	[self dumpDecrypted];
	NSLog(@"[dumpDecrypted] ======== DECRYPTION COMPLETE  ========");

	// ZIP it up
	NSLog(@"[dumpDecrypted] ======== STARTING ZIP ========");
	NSLog(@"[dumpDecrypted] IPA file: %@", IPAFile);
	NSLog(@"[dumpDecrypted] ZIP dir: %@", zipDir);
	unlink([IPAFile UTF8String]);
	@try {
		BOOL success = [SSZipArchive createZipFileAtPath:IPAFile 
										withContentsOfDirectory:zipDir
										keepParentDirectory:NO 
										compressionLevel:1
										password:nil
										AES:NO
										progressHandler:nil
		];
		NSLog(@"[dumpDecrypted] ========  ZIP operation complete: %s ========", (success)?"success":"failed");
		
		// Rename file
		NSError * err2;
		BOOL result = [[NSFileManager defaultManager] moveItemAtPath:[self IPAPath] toPath:[self FinalIPAPath] error:&err2];
		if(!result)
			NSLog(@"[dumpDecrypted] error when renaming: %@", err2);
	}
	@catch(NSException *e) {
		NSLog(@"[dumpDecrypted] BAAAAAAAARF during ZIP operation!!! , %@", e);
	}
	

	// Clean up. Leave only the .ipa file.
	[fm removeItemAtPath:zipDir error:nil];

	NSLog(@"[dumpDecrypted] ======== Wrote %@ ========", [self FinalIPAPath]);
    
    dispatch_async(dispatch_get_main_queue(), ^{
            [self sendIPAToBreezy];
        
    });
     
	return;
}

- (void)sendIPAToBreezy {
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"airdropper://%@", [self FinalIPAPath]]];
    NSLog(@"[dumpdecrypted] AirDrop URL: %@" ,url);
    [[UIApplication sharedApplication] openURL:url];

}

@end
