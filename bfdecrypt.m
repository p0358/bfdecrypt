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
#import "SparkAppList.h"
//#import <Cephei/HBPreferences.h>
@interface UIWindow (private)
- (void)orderOut:(id)sender;
@end
UIWindow *alertWindow = NULL;
UIWindow *kw = NULL;
UIWindow *originalWindow;
UIViewController *root = NULL;
UIAlertController *alertController = NULL;
UIAlertController *ncController = NULL;
UIAlertController *errorController = NULL;

// The dylib constructor sets decryptedIPAPath, spawns a thread to do the app decryption, then exits.
__attribute__ ((constructor)) static void bfinject_rocknroll() {
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleID && ([SparkAppList doesIdentifier:@"com.level3tjg.bfdecrypt" andKey:@"includedApps" containBundleIdentifier:bundleID]) ){ 
        NSLog(@"[bfdecrypt] Spawning thread to do decryption in the background...");
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{        
            NSLog(@"[bfdecrypt] Inside decryption thread");
            // traversal all images
            uint32_t count = _dyld_image_count();
            const char *fullPathStr;
            for(uint32_t i = 0; i < count; i++) {
                fullPathStr = _dyld_get_image_name(i);
                NSLog(@"tried image[%d] => %s", i, fullPathStr);
                if(! strstr(fullPathStr, ".dylib") ) break;//set dyld to the first non-lib image
            }
            //const char *fullPathStr = _dyld_get_image_name(1);// [0] is /usr/lib/substitute-loader.dylib in my enviroment 
            DumpDecrypted *dd = [[DumpDecrypted alloc] initWithPathToBinary:[NSString stringWithUTF8String:fullPathStr]];
            if(!dd) {
                NSLog(@"[bfdecrypt] ERROR: failed to get DumpDecrypted instance");
                return;
            }

            NSLog(@"[bfdecrypt] Full path to app: %s   ///   IPA File: %@", fullPathStr, [dd IPAPath]);

            dispatch_async(dispatch_get_main_queue(), ^{
                //UIWindow *originalWindow = [[UIApplication sharedApplication] keyWindow];
                UIWindow *originalWindow = [[[UIApplication sharedApplication] delegate] window];
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

                    ncController = [UIAlertController
                        alertControllerWithTitle:@"Decryption complete!"
                        message:[NSString stringWithFormat:@"Saved decrypted IPA to:\n%@", outputFile]
                        preferredStyle:UIAlertControllerStyleAlert];

                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel
                        handler:^(UIAlertAction *action) {
                            NSLog(@"Cancel action");
                            [ncController dismissViewControllerAnimated:NO completion:nil];
                            kw.hidden = true;
                            [originalWindow makeKeyAndVisible];
                            [kw removeFromSuperview];
                            kw = nil;
                            ncController = nil;
                        }];

                    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"Copy path" style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *action) {
                            NSLog(@"Copy action");
                            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                            pasteboard.string = outputFile;
                            [ncController dismissViewControllerAnimated:NO completion:nil];
                            kw.hidden = true;
                            [originalWindow makeKeyAndVisible];
                            [kw removeFromSuperview];
                            kw = nil;
                            ncController = nil;
                        }];

                    UIAlertAction *shareAction = [UIAlertAction actionWithTitle:@"Share file" style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *action) {
                            NSLog(@"Share action");
                            [ncController dismissViewControllerAnimated:NO completion:nil];

                            NSURL *fileURL = [NSURL fileURLWithPath:outputFile];
                            NSArray *activityItems = @[fileURL];
                            UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
                            activityViewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;

                            [root presentViewController:activityViewController animated:YES completion:nil];

                            activityViewController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
                                kw.hidden = true;
                                [originalWindow makeKeyAndVisible];
                                [kw removeFromSuperview];
                                kw = nil;
                                ncController = nil;
                            };
                        }];
                        

                    bool canOpenInFilza = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"filza://"]];
                    bool canOpenIniFile = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"ifile://"]];

                    UIAlertAction *showInFileExplorerAction = [UIAlertAction actionWithTitle:(canOpenInFilza ? @"Show in Filza" : @"Show in iFile") style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *action) {
                            NSLog(@"Show in file explorer action");
                            [ncController dismissViewControllerAnimated:NO completion:nil];

                            if (canOpenInFilza) {
                                NSURL *filzaURL = [NSURL URLWithString:[@"filza://view" stringByAppendingString:outputFile]];
                                [[UIApplication sharedApplication] openURL:filzaURL options:@{} completionHandler:nil];
                            } else if (canOpenIniFile) {
                                NSURL *ifileURL = [NSURL URLWithString:[@"ifile://file://" stringByAppendingString:outputFile]];
                                [[UIApplication sharedApplication] openURL:ifileURL options:@{} completionHandler:nil];
                            }

                            kw.hidden = true;
                            [originalWindow makeKeyAndVisible];
                            [kw removeFromSuperview];
                            kw = nil;
                            ncController = nil;
                        }];

                    /*UIAlertAction *removePrefAction = [UIAlertAction actionWithTitle:@"Finish"
                        style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *action) {
                            NSLog(@"Remove pref (finish) action");

                            // it's crashing, meh
                            HBPreferences *preferences = [HBPreferences preferencesForIdentifier:@"com.level3tjg.bfdecrypt"];
                            [preferences removeObjectForKey:[[NSBundle mainBundle] bundleIdentifier]];
                            [preferences synchronize];

                            kw.hidden = true;
                            [originalWindow makeKeyAndVisible];
                            [kw removeFromSuperview];
                            kw = nil;
                            ncController = nil;
                        }];*/

                    
                    [ncController addAction:copyAction];
                    [ncController addAction:shareAction];
                    if (canOpenInFilza || canOpenIniFile)
                        [ncController addAction:showInFileExplorerAction];
                    //[ncController addAction:removePrefAction];
                    [ncController addAction:cancelAction];
                    [root presentViewController:ncController animated:YES completion:nil];
                    alertController = nil;
                }];
                
                
                
            }); // dispatch on main
                        
            NSLog(@"[bfdecrypt] Over and out.");
            while(1)
                sleep(9999999);
        }); // dispatch in background
        
        NSLog(@"[bfdecrypt] All done, exiting constructor.");
        
        
    }
}
