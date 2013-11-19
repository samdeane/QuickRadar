//
//  AppDelegate.m
//  QuickRadar
//
//  Created by Amy Worrall on 15/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "PTHotKeyLib.h"
#import "QRRadarWindowController.h"
#import "QRPreferencesWindowController.h"
#import "QRUserDefaultsKeys.h"
#import "QRAppListManager.h"
#import "SRCommon.h"
#import "QRFileDuplicateWindowController.h"
#import <Growl/Growl.h>

@interface AppDelegate () <NSUserNotificationCenterDelegate, GrowlApplicationBridgeDelegate>
{
	NSMutableSet *windowControllerStore;
    NSStatusItem *statusItem;
}

@property (strong) QRPreferencesWindowController *preferencesWindowController;
@property (strong) QRFileDuplicateWindowController *duplicatesWindowController;
@property (assign, nonatomic) BOOL applicationHasStarted;

@end



@implementation AppDelegate

@synthesize menu = _menu;
@synthesize preferencesWindowController = _preferencesWindowController;
@synthesize applicationHasStarted = _applicationHasStarted;

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
	 QRShowInStatusBarKey: @YES,
	 QRShowInDockKey : @NO,
	 QRHandleRdarURLsKey : @(rdarURLsMethodFileDuplicate),
     }];
}

#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    BOOL shouldShowStatusBarItem = [[NSUserDefaults standardUserDefaults] boolForKey:QRShowInStatusBarKey];
 	BOOL shouldShowDockIcon = [[NSUserDefaults standardUserDefaults] boolForKey:QRShowInDockKey];
		
    if (shouldShowStatusBarItem) {
        //setup statusItem
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        statusItem.image = [NSImage imageNamed:@"MenubarTemplate"];
        statusItem.highlightMode = YES;
        statusItem.menu = self.menu;
    }
	
	if (shouldShowDockIcon)
	{
		ProcessSerialNumber psn = {0, kCurrentProcess};
		verify_noerr(TransformProcessType(&psn,
										  kProcessTransformToForegroundApplication));
	}


    //apply hotkey
    [self applyHotkey];
    
    //observe defaults for hotkey
    [[NSUserDefaultsController sharedUserDefaultsController]
     addObserver:self forKeyPath:GlobalHotkeyKeyPath options:0 context: NULL];
    
	windowControllerStore = [NSMutableSet set];
	
	if (NSClassFromString(@"NSUserNotificationCenter"))
	{
		[[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
	}
	else
	{
		[GrowlApplicationBridge setGrowlDelegate:self];
	}
	
	self.preferencesWindowController = [[QRPreferencesWindowController alloc] init];
	self.duplicatesWindowController = [[QRFileDuplicateWindowController alloc] initWithWindowNibName:@"QRFileDuplicateWindow"];

	// Without either of these settings, the app would show no UI on startup. Show prefs window so that people can figure out how to change it back!
	if (!shouldShowDockIcon && !shouldShowStatusBarItem)
	{
		[self.preferencesWindowController showWindow:self];
	}

	
	// Start tracking apps.
	[QRAppListManager sharedManager];
	
	self.applicationHasStarted = YES;

	NSAppleEventManager *em = [NSAppleEventManager sharedAppleEventManager];
	[em
	 setEventHandler:self
	 andSelector:@selector(getUrl:withReplyEvent:)
	 forEventClass:kInternetEventClass
	 andEventID:kAEGetURL];
	
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	LSSetDefaultHandlerForURLScheme((CFStringRef)@"rdar", (__bridge CFStringRef)bundleID);
	LSSetDefaultHandlerForURLScheme((CFStringRef)@"quickradar", (__bridge CFStringRef)bundleID);
	
	
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender;
{
	return (self.applicationHasStarted);
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)theApplication;
{
	[self newBug:self];
	return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
	[[QRAppListManager sharedManager] saveList];
}

#pragma mark - Auxillary windows

- (IBAction)showPreferencesWindow:(id)sender;
{
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	[self.preferencesWindowController showWindow:self];
}

- (IBAction)showDuplicateWindow:(id)sender;
{
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	[self.duplicatesWindowController showWindow:self];
}

#pragma mark growl support

- (NSDictionary *) registrationDictionaryForGrowl;
{
	NSArray *notifications = @[@"Submission Complete", @"Submission Failed"];
	
	NSDictionary *dict = @{GROWL_NOTIFICATIONS_ALL: notifications, GROWL_NOTIFICATIONS_DEFAULT: notifications};
	return dict;
}

- (NSString *) applicationNameForGrowl;
{
	return @"QuickRadar";
}

- (void) growlNotificationWasClicked:(id)clickContext;
{
	NSDictionary *dict = (NSDictionary*)clickContext;
	
	NSLog(@"Context %@", dict);
	
	NSString *stringURL = dict[@"URL"];
	
	if (!stringURL)
		return;
	
	NSURL *url = [NSURL URLWithString:stringURL];
	[[NSWorkspace sharedWorkspace] openURL:url];
}


#pragma mark - NSUserNotificationCenter

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
	return YES;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
	NSDictionary *dict = notification.userInfo;

	NSLog(@"Context %@", dict);

	NSString *stringURL = dict[@"URL"];

	if (!stringURL)
		return;

	NSURL *url = [NSURL URLWithString:stringURL];
	[[NSWorkspace sharedWorkspace] openURL:url];
}


#pragma mark IBActions

- (IBAction)activateAndShowAbout:(id)sender;
{
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanel:self];
}



- (IBAction)newBug:(id)sender;
{
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	
    QRRadarWindowController *b = [[QRRadarWindowController alloc] initWithWindowNibName:@"RadarWindow"];
    [windowControllerStore addObject:b];
    [b showWindow:nil];
	
}

- (void)newBugWithRadar:(QRRadar*)radar;
{
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	
    QRRadarWindowController *b = [[QRRadarWindowController alloc] initWithWindowNibName:@"RadarWindow"];
	[b prepopulateWithRadar:radar];
    [windowControllerStore addObject:b];
    [b showWindow:nil];
	
}


- (IBAction)bugWindowControllerSubmissionComplete:(id)sender
{
	[windowControllerStore removeObject:sender];
}


#pragma mark keyComboPanelDelegate


#pragma mark hotkey

- (void)applyHotkey {
	//unregister old
	for (PTHotKey *hotkey in [[PTHotKeyCenter sharedCenter] allHotKeys]) {
		[[PTHotKeyCenter sharedCenter] unregisterHotKey:hotkey];
	}
    
	//read plist
	id plistTool = [[NSUserDefaults standardUserDefaults] objectForKey:GlobalHotkeyName];
    
    //make default
	if(!plistTool) {
        plistTool = @{@"keyCode": @49,
                     @"modifiers": @(cmdKey+controlKey+optionKey)};
        
        [[NSUserDefaults standardUserDefaults] setObject:plistTool forKey:GlobalHotkeyName];
	}
    
    //get key combo
    PTKeyCombo *kc = [[PTKeyCombo alloc] initWithPlistRepresentation:plistTool];
    
    //register it
    PTHotKey *hotKey = [[PTHotKey alloc] init];
    hotKey.name = GlobalHotkeyName;
    hotKey.keyCombo = kc;
    hotKey.target = self;
    hotKey.action = @selector(hitHotKey:);
    [[PTHotKeyCenter sharedCenter] registerHotKey:hotKey];
    
	
	NSMenuItem *item = [_menu itemWithTag:10];
	NSString *equiv = SRStringForKeyCode(kc.keyCode);
	if ([equiv isEqualToString:@"Space"])
	{
		equiv = @" ";
	}
	item.keyEquivalent = equiv;
	item.keyEquivalentModifierMask = SRCarbonToCocoaFlags(kc.modifiers);
	
}

- (void)hitHotKey:(id)sender {
    [self newBug:sender];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:object
						change:(NSDictionary *)change context:(void *)context {
	if([keyPath isEqualToString:GlobalHotkeyKeyPath]) {
		[self applyHotkey];
	}
}

#pragma mark URL handling
- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
	// Get the URL
	NSString *urlStr = [[event paramDescriptorForKeyword:keyDirectObject]
						stringValue];
	NSURL *url = [NSURL URLWithString:urlStr];
	
	if ([url.scheme isEqualToString:@"rdar"])
	{
		[self handleRdarURL:url];

	}
	else if ([url.scheme isEqualToString:@"quickradar"])
	{
		// TODO: some way of having the service class register a block for its URL handler. This is a quick-and-dirty method in the mean time.
		
		NSString *urlStr = [url.absoluteString stringByReplacingOccurrencesOfString:@"quickradar://" withString:@""];
		
		if ([urlStr hasPrefix:@"appdotnetauth"])
		{
			NSArray *parts = [url.absoluteString componentsSeparatedByString:@"#"];
			NSString *token = parts[1];
			
			if ([token hasPrefix:@"access_token="])
			{
				token = [token stringByReplacingOccurrencesOfString:@"access_token=" withString:@""];
				[[NSUserDefaults standardUserDefaults] setObject:token forKey:@"appDotNetUserToken"];
			}
			else
			{
				[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"appDotNetUserToken"];
			}
			[[NSNotificationCenter defaultCenter] postNotificationName:@"AppDotNetAuthChangedNotification" object:self];
		}
	}
	
}


- (void)handleRdarURL:(NSURL *)url
{
	// Work out what to do
	
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	NSInteger method = [prefs integerForKey:QRHandleRdarURLsKey];
	
	if (method == rdarURLsMethodDoNothing)
	{
		return;
	}
	
	NSString *rdarId = url.host;
	if ([rdarId isEqualToString:@"problem"]) {
		rdarId = url.lastPathComponent;
	}

	
	if (method == rdarURLsMethodFileDuplicate)
	{
		[self.duplicatesWindowController setRadarNumber:rdarId];
		[self showDuplicateWindow:self];
		[self.duplicatesWindowController OK:self];
	}
	
	if (method == rdarURLsMethodOpenRadar)
	{
		NSURL *openRadarURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://openradar.appspot.com/%@", rdarId]];
		[[NSWorkspace sharedWorkspace] openURL:openRadarURL];
	}
	
}

@end
