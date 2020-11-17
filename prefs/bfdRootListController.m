#include "bfdRootListController.h"

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

void reloadPreferences()
{
	NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.level3tjg.bfdecrypt.plist"];
    NSMutableArray *bundles = [[NSMutableArray alloc] init];

    for (NSString *key in preferences) {
        if ([[preferences objectForKey:key] boolValue] == YES) {
            [bundles addObject:key];
        }
	}

    NSDictionary *filterDict = @{
        @"Filter": @{
            @"Bundles": bundles
        }
    };
    NSLog(@"[bfdecryptPrefs] filterDict: %@", [[[NSString stringWithFormat:@"%@", filterDict] stringByReplacingOccurrencesOfString:@"\n" withString:@""] stringByReplacingOccurrencesOfString:@"    " withString:@" "]);

    @try
    {
        [filterDict writeToFile:@"/Library/MobileSubstrate/DynamicLibraries/bfdecrypt_fromprefs.plist" atomically:NO];
        [filterDict writeToFile:@"/Library/MobileSubstrate/DynamicLibraries/bfdecrypt.plist" atomically:NO];
    }
    @catch(id anException) {
        NSLog(@"[bfdecryptPrefs] Error writing preferences");
        ShowAlert(@"Error writing preferences", @"Error");
    }
}

@implementation bfdRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

@end

__attribute__((constructor))
static void init(void)
{
	reloadPreferences();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reloadPreferences, CFSTR("com.level3tjg.bfdecrypt.settingschanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
