/*
    BF Decryptor - Decrypt iOS apps and repack them into an .ipa
    https://github.com/BishopFox/bfinject

    Carl Livitt @ Bishop Fox
*/
#include <stdio.h>
#include <unistd.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <stdlib.h>
#include <dlfcn.h>
#import <UIKit/UIKit.h>
#include <stdint.h>
#include "DumpDecrypted.h"
#include <TargetConditionals.h>
@interface UIWindow (private)
- (void)orderOut:(id)sender;
@end
UIWindow *alertWindow = NULL;
UIWindow *kw = NULL;
UIViewController *root = NULL;
UIAlertController *alertController = NULL;
UIAlertController *ncController = NULL;
UIAlertController *errorController = NULL;

// The dylib constructor sets decryptedIPAPath, spawns a thread to do the app decryption, then exits.
__attribute__ ((constructor)) static void bfinject_rocknroll() {
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSNumber *value = [[[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.level3tjg.bfdecrypt.plist"] objectForKey:bundleID];
    if ([value boolValue] == YES) {
        NSLog(@"[bfdecrypt] Spawning thread to do decryption in the background...");
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{        
            NSLog(@"[bfdecrypt] Inside decryption thread");
            const char *fullPathStr = _dyld_get_image_name(0);
            DumpDecrypted *dd = [[DumpDecrypted alloc] initWithPathToBinary:[NSString stringWithUTF8String:fullPathStr]];
            if(!dd) {
                NSLog(@"[bfdecrypt] ERROR: failed to get DumpDecrypted instance");
                return;
            }

            NSLog(@"[bfdecrypt] Full path to app: %s   ///   IPA File: %@", fullPathStr, [dd IPAPath]);

            dispatch_async(dispatch_get_main_queue(), ^{
                alertWindow = [[UIWindow alloc] initWithFrame: [UIScreen mainScreen].bounds];
                alertWindow.rootViewController = [UIViewController new];
                alertWindow.windowLevel = UIWindowLevelAlert + 1;
                [alertWindow makeKeyAndVisible];
                
                // Show a "Decrypting!" alert on the device and block the UI
                alertController = [UIAlertController
                    alertControllerWithTitle:@"Decrypting"
                    message:@"Please wait, this will take a few seconds..."
                    preferredStyle:UIAlertControllerStyleAlert];
                    
                kw = alertWindow;
                if([kw respondsToSelector:@selector(topmostPresentedViewController)])
                    root = [kw performSelector:@selector(topmostPresentedViewController)];
                else
                    root = [kw rootViewController];
                root.modalPresentationStyle = UIModalPresentationFullScreen;
                [root presentViewController:alertController animated:YES completion:nil];
            });
            
            // Do the decryption
            NSString *outputFile = [dd createIPAFile];
            //[dd show]
            // Dismiss the alert box
            dispatch_async(dispatch_get_main_queue(), ^{
                [alertController dismissViewControllerAnimated:NO completion:^{
                    [alertWindow orderOut:nil];
                    #if !TARGET_OS_TV
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        NSURL *path = [NSURL fileURLWithPath:outputFile];
                        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[path] applicationActivities:nil];
                        [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:activityViewController animated:true completion:nil];
                    });
                
                    #endif
                }];
                
                
                
            }); // dispatch on main
                        
            NSLog(@"[bfdecrypt] Over and out.");
            while(1)
                sleep(9999999);
        }); // dispatch in background
        
        NSLog(@"[bfdecrypt] All done, exiting constructor.");
        
        
    }
}
