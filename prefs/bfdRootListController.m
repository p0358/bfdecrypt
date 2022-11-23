#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "SparkAppListTableViewController.h"
#import <UIKit/UIKit.h>
#import "SparkAppList.h"

void ShowAlert(NSString *msg, NSString *title) {
	UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:title
                                 message:msg
                                 preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* dismissButton = [UIAlertAction
                                actionWithTitle:@"OK"
                                style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction * action) {}];

    [alert addAction:dismissButton];

    [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alert animated:YES completion:nil];
}


@interface bfdRootListController: PSListController
-(void)selectIncludeApps;
-(void)reloadPreferences:(NSNotification *)notification;
@end



@implementation bfdRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

-(instancetype)init {
	self = [super init];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(reloadPreferences:)
        name:@"com.level3tjg.bfdecrypt.sparkapplistupdate"
        object:nil];
    [self reloadPreferences:nil];
    return self;
}


-(void)selectIncludeApps
{
    SparkAppListTableViewController* s = [[SparkAppListTableViewController alloc] initWithIdentifier:@"com.level3tjg.bfdecrypt" andKey:@"includedApps"];

    [self.navigationController pushViewController:s animated:YES];
    self.navigationItem.hidesBackButton = FALSE;
}

-(void)reloadPreferences:(NSNotification *)notification
{
    NSArray *preferences = [SparkAppList getAppListForIdentifier:@"com.level3tjg.bfdecrypt" andKey:@"includedApps"];
    NSMutableArray *bundles = [[NSMutableArray alloc] init];

    for (NSString *key in preferences) {
            [bundles addObject:key];
    }

    NSDictionary *filterDict = @{
        @"Filter": @{
            @"Bundles": bundles
        }
    };
    NSLog(@"[bfdecryptPrefs] filterDict: %@", [[[NSString stringWithFormat:@"%@", filterDict] stringByReplacingOccurrencesOfString:@"\n" withString:@""] stringByReplacingOccurrencesOfString:@"    " withString:@" "]);
    
    @try
    {
//        [filterDict writeToFile:@"/Library/MobileSubstrate/DynamicLibraries/bfdecrypt.plist.pref" atomically:NO];
        [filterDict writeToFile:@"/Library/MobileSubstrate/DynamicLibraries/bfdecrypt.plist" atomically:NO];
    }   
    @catch(id anException) {
        NSLog(@"[bfdecryptPrefs] Error writing preferences");
        ShowAlert(@"Error writing preferences", @"Error");
    }   
}   

@end
