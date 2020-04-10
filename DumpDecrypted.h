
@interface DumpDecrypted : NSObject {
	char decryptedAppPathStr[PATH_MAX];
	char *filename;
	char *appDirName;
	char *appDirPath;
}

@property (assign) NSString *appPath;
@property (assign) NSString *docPath;

-(id)initWithPathToBinary:(NSString *)pathToBinary;
-(NSString *)createIPAFile;
-(BOOL)dumpDecryptedImage:(const struct mach_header *)image_mh fileName:(const char *)encryptedImageFilenameStr image:(int)imageNum;
-(NSString *)IPAPath;
-(NSString *)FinalIPAPath;
@end
