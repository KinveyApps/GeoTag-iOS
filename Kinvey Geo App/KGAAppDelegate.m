//
//  KGAAppDelegate.m
//  Kinvey GeoTag
//
//  Copyright 2012-2013 Kinvey, Inc
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  Created by Brian Wilson on 5/3/12.
//

#import "KGAAppDelegate.h"

#import "KGAViewController.h"
#import <KinveyKit/KinveyKit.h>

@interface KGAAppDelegate ()
@property (strong, nonatomic) KGAViewController *viewController;
@end

@implementation KGAAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.

    // Initialize Kinvey for our key/secret
    (void) [[KCSClient sharedClient] initializeKinveyServiceForAppKey:@"<#APP KEY#>"
                                                        withAppSecret:@"<#APP SECRET#>"
                                                         usingOptions:nil];
    
    [KCSPush registerForPush];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.viewController = [[KGAViewController alloc] initWithNibName:@"KGAViewController_iPhone" bundle:nil];
    } else {
        self.viewController = [[KGAViewController alloc] initWithNibName:@"KGAViewController_iPad" bundle:nil];
    }
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [[KCSPush sharedPush] application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken completionBlock:^(BOOL success, NSError *error)
    {
        //if there is an error, try again later
    }];
    // Additional registration goes here (if needed)
}

- (void) application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    [[KCSPush sharedPush] application:application didFailToRegisterForRemoteNotificationsWithError:error];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    [[KCSPush sharedPush] application:application didReceiveRemoteNotification:userInfo];
    [[[UIAlertView alloc] initWithTitle:@"Received a Push"
                                message:userInfo[@"aps"][@"alert"]
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
    [self.viewController refreshPlaces];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [[KCSPush sharedPush] onUnloadHelper];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [[KCSPush sharedPush] registerForRemoteNotifications];
}

@end
