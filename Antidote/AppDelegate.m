//
//  AppDelegate.m
//  Antidote
//
//  Created by Dmitry Vorobyov on 18.07.14.
//  Copyright (c) 2014 dvor. All rights reserved.
//

#import <MobileCoreServices/MobileCoreServices.h>

#import "AppDelegate.h"
#import "AppDelegate+Utilities.h"
#import "CustomLogFormatter.h"
#import "DDFileLogger.h"
#import "DDASLLogger.h"
#import "DDTTYLogger.h"
#import "AllChatsViewController.h"
#import "FriendsViewController.h"
#import "SettingsViewController.h"
#import "ProfileViewController.h"
#import "UIAlertView+BlocksKit.h"
#import "AppearanceManager.h"
#import "ProfileManager.h"

#define LOG_IDENTIFIER @"AppDelegate"

@interface AppDelegate ()

@property (strong, nonatomic) DDFileLogger *fileLogger;

@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTask;

@end

@implementation AppDelegate

#pragma mark -  UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];

    [self configureLoggingStuff];

    // initialize context
    [[AppContext sharedContext] recreateTabBarController];

    if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationType types =
            UIUserNotificationTypeAlert |
            UIUserNotificationTypeBadge |
            UIUserNotificationTypeSound;

        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types categories:nil];

        [application registerUserNotificationSettings:settings];
    }

    if (launchOptions[UIApplicationLaunchOptionsLocalNotificationKey]) {
        // FIXME
        // UILocalNotification *notification = launchOptions[UIApplicationLaunchOptionsLocalNotificationKey];

        // [[AppContext sharedContext].events handleLocalNotification:notification];
    }

    [self.window makeKeyAndVisible];
    return YES;
}

- (BOOL)  application:(UIApplication *)application
              openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication
           annotation:(id)annotation
{
    if ([url isFileURL]) {
        NSURLRequest *fileUrlRequest = [[NSURLRequest alloc] initWithURL:url
                                                             cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                         timeoutInterval:.1];

        NSURLResponse *response = nil;
        [NSURLConnection sendSynchronousRequest:fileUrlRequest returningResponse:&response error:nil];

        NSString *mimeType = [response MIMEType];

        CFStringRef mimeTypeRef = (__bridge CFStringRef)mimeType;
        CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeTypeRef, NULL);

        if (CFStringCompare(UTI, kUTTypeData, 0) == kCFCompareEqualTo) {
            [self handleIncomingFileAtUrl:url isDataFile:YES];
        }
        else {
            [self handleIncomingFileAtUrl:url isDataFile:NO];
        }
    }

    return YES;
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    // FIXME
    // [[AppContext sharedContext].events handleLocalNotification:notification];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

    AALogInfo(@"starting background task...");
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        AALogInfo(@"starting background task... time is up, stopping it");

        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark -  Private

- (NSArray *)getLogFilesPaths
{
    return [self.fileLogger.logFileManager unsortedLogFilePaths];
}

- (void)configureLoggingStuff
{
    self.fileLogger = [DDFileLogger new];
    self.fileLogger.maximumFileSize = 1024 * 1024;
    self.fileLogger.rollingFrequency = 0.0;
    self.fileLogger.logFileManager.maximumNumberOfLogFiles = 2;

    [DDLog addLogger:self.fileLogger];

    // your log statements will be sent to the Console.app and the Xcode console (just like a normal NSLog)
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];

    CustomLogFormatter *formatter = [CustomLogFormatter new];

    [self.fileLogger setLogFormatter:formatter];
    [[DDASLLogger sharedInstance] setLogFormatter:formatter];
    [[DDTTYLogger sharedInstance] setLogFormatter:formatter];

    DDLogInfo(@"\n\n\n\t\t\t\t\t\t***** Application started *****\n\n\n");
    DDLogInfo(@"Device:\n\tname = %@\n\tmodel = %@\n\tsystemVersion = %@\n\n",
              [UIDevice currentDevice].name,
              [UIDevice currentDevice].model,
              [UIDevice currentDevice].systemVersion);
}

- (void)handleIncomingFileAtUrl:(NSURL *)url isDataFile:(BOOL)isDataFile
{
    void (^removeFile)() = ^() {
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    };

    if (isDataFile) {
        NSString *message = [NSString stringWithFormat:
                             NSLocalizedString(@"Use \"%@\" file as tox save file?", @"Incoming file"),
                             [url lastPathComponent]];

        UIAlertView *alert = [UIAlertView bk_alertViewWithTitle:nil message:message];

        [alert bk_addButtonWithTitle:NSLocalizedString(@"Yes", @"Incoming file") handler:^{
            NSString *title = NSLocalizedString(@"Enter profile name", @"Incoming file");

            UIAlertView *nameAlert = [UIAlertView bk_alertViewWithTitle:title];
            nameAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
            [nameAlert textFieldAtIndex:0].text = [url lastPathComponent];

            [nameAlert bk_addButtonWithTitle:NSLocalizedString(@"OK", @"Incoming file") handler:^{
                NSString *name = [nameAlert textFieldAtIndex:0].text;

                [[AppContext sharedContext].profileManager createProfileWithToxSave:url name:name];
                removeFile();

                [self switchToSettingsTabAndShowProfiles];
            }];

            [nameAlert bk_setCancelButtonWithTitle:NSLocalizedString(@"Cancel", @"Incoming file") handler:removeFile];
            [nameAlert show];

        }];

        [alert bk_setCancelButtonWithTitle:NSLocalizedString(@"No", @"Incoming file") handler:removeFile];
        [alert show];
    }
    else {
        removeFile();
    }
}

@end
