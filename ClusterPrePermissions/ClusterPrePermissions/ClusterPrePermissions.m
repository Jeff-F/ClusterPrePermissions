//
//  ClusterPrePermissions.m
//  ClusterPrePermissions
//
//  Created by Rizwan Sattar on 4/7/14.
//  Copyright (c) 2014 Cluster Labs, Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

typedef NS_ENUM(NSInteger, ClusterTitleType) {
    ClusterTitleTypeRequest,
    ClusterTitleTypeDeny
};

//refer to http://stackoverflow.com/a/7848772/544251
#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)


#define kDidRegisterPushNotification @"didRegisterForPush"


#import "ClusterPrePermissions.h"
#import <AddressBook/AddressBook.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>

@interface ClusterPrePermissions () <UIAlertViewDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) UIAlertView *prePhotoPermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler photoPermissionCompletionHandler;

@property (strong, nonatomic) UIAlertView *preContactPermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler contactPermissionCompletionHandler;

@property (strong, nonatomic) UIAlertView *preLocationPermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler locationPermissionCompletionHandler;
@property (strong, nonatomic) CLLocationManager *locationManager;

@property (strong, nonatomic) UIAlertView *prePushNotificationPermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler pushNotificationPermissionCompletionHandler;

@property (strong, nonatomic) UIAlertView *preVideoCapturePermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler videoCapturePermissionCompletionHandler;

@end

static ClusterPrePermissions *__sharedInstance;

@implementation ClusterPrePermissions

+ (instancetype) sharedPermissions
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[ClusterPrePermissions alloc] init];
    });
    return __sharedInstance;
}


#pragma mark - Photo Permissions Help

- (void) showPhotoPermissionsWithTitle:(NSString *)requestTitle
                               message:(NSString *)message
                       denyButtonTitle:(NSString *)denyButtonTitle
                      grantButtonTitle:(NSString *)grantButtonTitle
                     completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    //iOS 5, we don't show alert for contact.
    if (SYSTEM_VERSION_LESS_THAN(@"6.0")) {
        //Since the Address Book permission requirement was only recently added as of iOS 6 you don't have to ask for permission.
        //default return authorised and not showing the alert.
        if (completionHandler) {
            completionHandler(YES, ClusterDialogResultGranted, ClusterDialogResultGranted);
        }
        return;
    }

    if (requestTitle.length == 0) {
        requestTitle = NSLocalizedString(@"Access Photos?", );
    }

    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];

    //iOS 6.0 +
    ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
    if (status == ALAuthorizationStatusNotDetermined) {
        self.photoPermissionCompletionHandler = completionHandler;
        self.prePhotoPermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                      message:message
                                                                     delegate:self
                                                            cancelButtonTitle:denyButtonTitle
                                                            otherButtonTitles:grantButtonTitle, nil];
        [self.prePhotoPermissionAlertView show];
    } else {
        if (completionHandler) {
            completionHandler((status == ALAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showActualPhotoPermissionAlert
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        // Got access! Show login
        [self firePhotoPermissionCompletionHandler];
        *stop = YES;
    } failureBlock:^(NSError *error) {
        // User denied access
        [self firePhotoPermissionCompletionHandler];
    }];
}


- (void) firePhotoPermissionCompletionHandler
{
    ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
    if (self.photoPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == ALAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == ALAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == ALAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == ALAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.photoPermissionCompletionHandler((status == ALAuthorizationStatusAuthorized),
                                              userDialogResult,
                                              systemDialogResult);
        self.photoPermissionCompletionHandler = nil;
    }
}


#pragma mark - Contact Permissions Help


- (void) showContactsPermissionsWithTitle:(NSString *)requestTitle
                                  message:(NSString *)message
                          denyButtonTitle:(NSString *)denyButtonTitle
                         grantButtonTitle:(NSString *)grantButtonTitle
                        completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    //iOS 5, we don't show alert for contact.
    if (SYSTEM_VERSION_LESS_THAN(@"6.0")) {
        //Since the Address Book permission requirement was only recently added as of iOS 6 you don't have to ask for permission.
        //default return authorised and not showing the alert.
        if (completionHandler) {
            completionHandler(YES, ClusterDialogResultGranted, ClusterDialogResultGranted);
        }
        return;
    }

    if (requestTitle.length == 0) {
        requestTitle = NSLocalizedString(@"Access Contacts?", );
    }

    denyButtonTitle = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];

    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    if (status == kABAuthorizationStatusNotDetermined) {
        self.contactPermissionCompletionHandler = completionHandler;
        self.preContactPermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                        message:message
                                                                       delegate:self
                                                              cancelButtonTitle:denyButtonTitle
                                                              otherButtonTitles:grantButtonTitle, nil];
        [self.preContactPermissionAlertView show];
    } else {
        if (completionHandler) {
            completionHandler((status == kABAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showActualContactPermissionAlert
{
    CFErrorRef error = nil;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(nil, &error);
    ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fireContactPermissionCompletionHandler];
        });
    });
}


- (void) fireContactPermissionCompletionHandler
{
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    if (self.contactPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == kABAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == kABAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == kABAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == kABAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.contactPermissionCompletionHandler((status == kABAuthorizationStatusAuthorized),
                                                userDialogResult,
                                                systemDialogResult);
        self.contactPermissionCompletionHandler = nil;
    }
}


#pragma mark - Location Permission Help


- (void) showLocationPermissionsWithTitle:(NSString *)requestTitle
                                  message:(NSString *)message
                          denyButtonTitle:(NSString *)denyButtonTitle
                         grantButtonTitle:(NSString *)grantButtonTitle
                        completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = NSLocalizedString(@"Access Location?", );
    }

    denyButtonTitle = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];

    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusNotDetermined) {
        self.locationPermissionCompletionHandler = completionHandler;
        self.preLocationPermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                         message:message
                                                                        delegate:self
                                                               cancelButtonTitle:denyButtonTitle
                                                               otherButtonTitles:grantButtonTitle, nil];
        [self.preLocationPermissionAlertView show];
    } else {
        if (completionHandler) {
            completionHandler((status == kCLAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showActualLocationPermissionAlert
{
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    [self.locationManager startUpdatingLocation];
}


- (void) fireLocationPermissionCompletionHandler
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (self.locationPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == kCLAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == kCLAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == kCLAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == kCLAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.locationPermissionCompletionHandler((status == kCLAuthorizationStatusAuthorized),
                                                 userDialogResult,
                                                 systemDialogResult);
        self.locationPermissionCompletionHandler = nil;
    }
    if (self.locationManager) {
        [self.locationManager stopUpdatingLocation], self.locationManager = nil;
    }
}

#pragma mark CLLocationManagerDelegate

- (void) locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status != kCLAuthorizationStatusNotDetermined) {
        [self fireLocationPermissionCompletionHandler];
    }
}

#pragma mark - Push Notification Permission Help

-(void) showPushNotificationPermissionsWithTitle:(NSString *)requestTitle
                                         message:(NSString *)message
                                 denyButtonTitle:(NSString *)denyButtonTitle
                                grantButtonTitle:(NSString *)grantButtonTitle
                               completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = NSLocalizedString(@"Allow Push Notifications?", );
    }

    denyButtonTitle = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];

    PushAuthorizationStatus status = [self pushAuthorizationStatus];
    if (status == kPushAuthorizationStatusNotDetermined) {
        self.pushNotificationPermissionCompletionHandler = completionHandler;
        self.prePushNotificationPermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                                 message:message
                                                                                delegate:self
                                                                       cancelButtonTitle:denyButtonTitle
                                                                       otherButtonTitles:grantButtonTitle, nil];
        [self.prePushNotificationPermissionAlertView show];
    } else {
        if (completionHandler) {
            completionHandler((status == kPushAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}

- (void) showActualPushNotificationPermissionAlert
{
    //Modify this to change which type of push notifications are allowed
    [self registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    [self firePushNotificationPermissionCompletionHandler];
}

- (void)registerForRemoteNotificationTypes:(NSUInteger)types
{
    // Register for Push Notitications, if running iOS 8
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationType userNotificationTypes = types;
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:userNotificationTypes
                                                                                 categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    } else {
        // Register for Push Notifications before iOS 8
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:types];
    }
}

- (void) firePushNotificationPermissionCompletionHandler
{
    PushAuthorizationStatus status = [self pushAuthorizationStatus];
    if (self.pushNotificationPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if(status == kPushAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if(status == kPushAuthorizationStatusAuthorized ) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if(status == kPushAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        }
        self.pushNotificationPermissionCompletionHandler((status == kPushAuthorizationStatusAuthorized),
                                                         userDialogResult,
                                                         systemDialogResult);
        self.pushNotificationPermissionCompletionHandler = nil;
    }
}

+ (PushAuthorizationStatus)pushAuthorizationStatus
{
    return [[ClusterPrePermissions sharedPermissions] pushAuthorizationStatus];
}

- (PushAuthorizationStatus)pushAuthorizationStatus
{
    //iOS 8.0+
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(currentUserNotificationSettings)]) {
        UIUserNotificationSettings *settings = [[UIApplication sharedApplication] currentUserNotificationSettings];
        UIUserNotificationType types = settings.types;
        if (types != UIUserNotificationTypeNone) {
            return kPushAuthorizationStatusAuthorized;
        }
    //iOS 7.0 and before
    } else {
        UIRemoteNotificationType types = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
        if(types != UIRemoteNotificationTypeNone) {
            return kPushAuthorizationStatusAuthorized;
        }
    }

    BOOL didRegisterforPush = [ClusterPrePermissions didRegisterPushNotification];
    //If YES, they declined to receive push notifications from the actual dialog
    if(didRegisterforPush) {
        //user grant permission the first time, so didRegisterForPush is YES,
        //but later user changes his mind so he deny the permission, and causes UIRemoteNotificationType to be UIRemoteNotificationTypeNone
        return kPushAuthorizationStatusDenied;
    }
    return kPushAuthorizationStatusNotDetermined;
}

+ (BOOL)didRegisterPushNotification
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kDidRegisterPushNotification] == nil) {
        return NO;
    }
    return [defaults boolForKey:kDidRegisterPushNotification];
}

+ (void)setResultForRigisterPushNotification:(BOOL)didRegisterPushNotification
{
    [[NSUserDefaults standardUserDefaults] setBool:didRegisterPushNotification forKey:kDidRegisterPushNotification];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - UIAlertViewDelegate
- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView == self.prePhotoPermissionAlertView) {
        if (buttonIndex == alertView.cancelButtonIndex) {
            // User said NO, jerk.
            [self firePhotoPermissionCompletionHandler];
        } else {
            // User granted access, now show the REAL permissions dialog
            [self showActualPhotoPermissionAlert];
        }
        self.prePhotoPermissionAlertView = nil;
    } else if (alertView == self.preContactPermissionAlertView) {
        if (buttonIndex == alertView.cancelButtonIndex) {
            // User said NO, that jerk.
            [self fireContactPermissionCompletionHandler];
        } else {
            // User granted access, now try to trigger the real contacts access
            [self showActualContactPermissionAlert];
        }
    } else if (alertView == self.preLocationPermissionAlertView) {
        if (buttonIndex == alertView.cancelButtonIndex) {
            // User said NO, that jerk.
            [self fireLocationPermissionCompletionHandler];
        } else {
            // User granted access, now try to trigger the real location access
            [self showActualLocationPermissionAlert];
        }
    } else if (alertView == self.prePushNotificationPermissionAlertView) {
        if (buttonIndex == alertView.cancelButtonIndex) {
            //User said NO, that jerk.
            [self firePushNotificationPermissionCompletionHandler];
        } else {
            //User granted access, now show the real permission dialog for push notifications
            [self showActualPushNotificationPermissionAlert];
        }
    } else if (alertView == self.preVideoCapturePermissionAlertView) {
        if (buttonIndex == alertView.cancelButtonIndex) {
            // User said NO, that jerk.
            [self fireVideoCapturePermissionCompletionHandler];
        } else {
            // User granted access, now try to trigger the real video capture access
            [self showActualVideoCapturePermissionAlert];
        }
    }
}

#pragma mark - VideoCapture Permissions
- (void)showVideoCapturePermissionsWithTitle:(NSString *)requestTitle
                                     message:(NSString *)message
                             denyButtonTitle:(NSString *)denyButtonTitle
                            grantButtonTitle:(NSString *)grantButtonTitle
                           completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = NSLocalizedString(@"Access Camera?", );
    }

    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];
    //iOS 7.0 +
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusNotDetermined) {
        self.videoCapturePermissionCompletionHandler = completionHandler;
        self.preVideoCapturePermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                             message:message
                                                                            delegate:self
                                                                   cancelButtonTitle:denyButtonTitle
                                                                   otherButtonTitles:grantButtonTitle, nil];
        [self.preVideoCapturePermissionAlertView show];
    } else {
        if (completionHandler) {
            completionHandler((status == AVAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}

- (void) fireVideoCapturePermissionCompletionHandler
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (self.videoCapturePermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == AVAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == AVAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == AVAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == AVAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.videoCapturePermissionCompletionHandler((status == AVAuthorizationStatusAuthorized),
                                                userDialogResult,
                                                systemDialogResult);
        self.videoCapturePermissionCompletionHandler = nil;
    }
}

- (void)showActualVideoCapturePermissionAlert
{
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        [self fireVideoCapturePermissionCompletionHandler];
    }];
}

#pragma mark - Helper methods
- (NSString *)titleFor:(ClusterTitleType)titleType fromTitle:(NSString *)title
{
    switch (titleType) {
        case ClusterTitleTypeDeny:
            title = (title.length == 0) ? NSLocalizedString(@"Not Now", ): title;
            break;
        case ClusterTitleTypeRequest:
            title = (title.length == 0) ? NSLocalizedString(@"Give Access", ): title;
            break;
        default:
            title = @"";
            break;
    }
    return title;
}
@end
