//
//  facebook_Login.m
//  ForgeModule
//
//  Created by Antoine van Gelder on 2014/04/01.
//  Copyright (c) 2014 Trigger Corp. All rights reserved.
//

#import "facebook_Util.h"
#import "facebook_LoginDelegate.h"


@implementation LoginContext
- (LoginContext*) initWithTask:(ForgeTask*)newTask permissions:(NSArray*)newPermissions audience:(NSString*)newAudience loginUI:(BOOL)newLoginUI {
    if (self = [super init]) {
        _task = newTask;
        _permissions = newPermissions;
        _audience = newAudience;
        _loginUI = newLoginUI;
    }
    return self;
}
@end



@implementation facebook_LoginDelegate

+ (void)handleLogin:(LoginContext*)context {
    // [ForgeLog d:[NSString stringWithFormat:@"facebook_Login.handleLogin: %d", FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded]];
    BOOL loggedinWithoutUI = false;
    
    if (FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded) {
        loggedinWithoutUI = [facebook_LoginDelegate openActiveSession:NO context:context];
        if (!loggedinWithoutUI && context.loginUI) {
            loggedinWithoutUI = [facebook_LoginDelegate openActiveSession:YES context:context];
        } else if (!loggedinWithoutUI && !context.loginUI) {
            [context.task error:@"User not logged in or insufficient read permissions" type:@"EXPECTED_FAILURE" subtype:nil];
            return;
        }
    } else {
        if (context.loginUI) {
            loggedinWithoutUI = [facebook_LoginDelegate openActiveSession:YES context:context];
        } else {
            loggedinWithoutUI = [facebook_LoginDelegate openActiveSession:NO context:context];
            if (!loggedinWithoutUI) {
                [context.task error:@"User not logged in or insufficient read permissions" type:@"EXPECTED_FAILURE" subtype:nil];
                return;
            }
        }
    }
}


+ (BOOL) openActiveSession:(BOOL)allowLoginUI context:(LoginContext*)context {
    NSArray *readPermissions = [facebook_Util readPermissionsInPermissions:context.permissions];
    BOOL loggedinWithoutUI = [FBSession openActiveSessionWithReadPermissions:readPermissions
                                                                allowLoginUI:allowLoginUI
                                                           completionHandler:^(FBSession *session, FBSessionState state, NSError *error) {
                                                               [facebook_LoginDelegate sessionStateChanged:session state:state error:error context:context];
                                                           }];
    return loggedinWithoutUI;
}


+ (void)requestNewPublishPermissions:(FBSession*) session context:(LoginContext*)context {
    NSArray *publishPermissions = [facebook_Util publishPermissionsInPermissions:context.permissions];
    FBSessionDefaultAudience publishAudience = [facebook_Util lookupAudience:context.audience];
    [session requestNewPublishPermissions:publishPermissions
                          defaultAudience:publishAudience
                        completionHandler:^(FBSession *session, NSError *error) {
                            [facebook_LoginDelegate publishCompletionHandler:session error:error context:context];
                        }];
}


+ (void)sessionStateChanged:(FBSession *)session state:(FBSessionState) state error:(NSError *)error context:(LoginContext*)context {
    //[ForgeLog d:[NSString stringWithFormat:@"facebook_Login.sessionStateChanged: %@ %@", [facebook_LoginDelegate ParseState:session.state], error ? error : @"SUCCESS"]];
    
    if (error) {
        return [facebook_Util handleError:error task:context.task];
    }
    
    switch (state) {
        case FBSessionStateOpen:
        case FBSessionStateOpenTokenExtended:
            if (![facebook_LoginDelegate checkPublishPermissions:context]) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [facebook_LoginDelegate requestNewPublishPermissions:session context:context];
                });
            } else {
                [context.task success:[facebook_LoginDelegate AccessToken:FBSession.activeSession]];
            }
            break;
        case FBSessionStateClosed:
            [context.task error:@"Session closed" type:@"EXPECTED_FAILURE" subtype:nil];
            break;
        case FBSessionStateClosedLoginFailed:
            [session closeAndClearTokenInformation];
            [context.task error:@"Login failed" type:@"EXPECTED_FAILURE" subtype:nil];
            break;
        default:
            [context.task error:[NSString stringWithFormat:@"Unknown error: %@", [facebook_LoginDelegate ParseState:session.state]] type:@"UNEXPECTED_FAILURE" subtype:nil];
            break;
    }
}



+ (void)publishCompletionHandler:(FBSession *)session error:(NSError *)error context:(LoginContext*)context {
    //[ForgeLog d:[NSString stringWithFormat:@"facebook_Login.publishCompletionHandler: %@ %@", [facebook_LoginDelegate ParseState:session.state], error ? error : @"SUCCESS"]];
    if (error) {
        return [facebook_Util handleError:error task:context.task];
    }
    [context.task success:[facebook_LoginDelegate AccessToken:FBSession.activeSession]];
}



+ (BOOL)checkPublishPermissions:(LoginContext*)context {
    return [facebook_Util permissionsAllowedByPermissions:FBSession.activeSession.permissions requestedPermissions:context.permissions];
}


+ (NSDictionary*)AccessToken:(FBSession*)session {
    return @{
        @"access_token": [NSString stringWithFormat:@"%@", session.accessTokenData.accessToken],
        @"access_expires": [NSNumber numberWithDouble:round([session.accessTokenData.expirationDate timeIntervalSince1970] * 1000.0)]
    };
}


+ (NSString*)ParseState:(FBSessionState)state {
    switch (state) {
        case FBSessionStateOpen:
            return @"FBSessionStateOpen";
        case FBSessionStateClosed:
            return @"FBSessionStateClosed";
        case FBSessionStateClosedLoginFailed:
            return @"FBSessionStateClosedLoginFailed";
        case FBSessionStateCreated:
            return @"FBSessionStateCreated";
        case FBSessionStateCreatedOpening:
            return @"FBSessionStateCreatedOpening";
        case FBSessionStateCreatedTokenLoaded:
            return @"FBSessionStateCreatedTokenLoaded";
        case FBSessionStateOpenTokenExtended:
            return @"FBSessionStateOpenTokenExtended";
        default:
            return @"FBSessionStateUnknown";
    }
}


@end
