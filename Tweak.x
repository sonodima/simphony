#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSUserDefaults+Private.h>
#import <UIKit/UIKit.h>



#pragma mark Private Interfaces

// iOS 4, 5, 6
@interface SBStatusBarDataManager : NSObject
+ (id)sharedDataManager;
- (void)_updateTelephonyState;
@end

// iOS 7+
@interface SBStatusBarStateAggregator : NSObject
+ (id)sharedInstance;
- (void)_updateDataNetworkItem;
- (void)_updateServiceItem;
- (void)_updateSignalStrengthItem;
@end



#pragma mark Configuration State

static BOOL enabled;
static BOOL suppressAlerts;
static NSString *carrierName;
static int dataType;
static long signalStrength;



#pragma mark Helper Functions

static BOOL osAtLeast(NSString *version) {
	NSString *sysVersion = [[UIDevice currentDevice] systemVersion];
  return [sysVersion compare:version options:NSNumericSearch] != NSOrderedAscending;
}

static void updateItems() {
	if (osAtLeast(@"7") == YES) {
		Class clsStateAggregator = %c(SBStatusBarStateAggregator);
		if (clsStateAggregator != nil) {
			SBStatusBarStateAggregator *stateAggregator = [clsStateAggregator sharedInstance];
			if (stateAggregator != nil) {
				if ([stateAggregator respondsToSelector:@selector(_updateSignalStrengthItem)]) {
					[stateAggregator _updateSignalStrengthItem];
				}

        if ([stateAggregator respondsToSelector:@selector(_updateServiceItem)]) {
          [stateAggregator _updateServiceItem];
        }

        if ([stateAggregator respondsToSelector:@selector(_updateDataNetworkItem)]) {
          [stateAggregator _updateDataNetworkItem];
        }
			}
		}
	} else {
		Class clsDataManager = %c(SBStatusBarDataManager);
		if (clsDataManager != nil) {
			SBStatusBarDataManager *dataManager = [clsDataManager sharedDataManager];
			if (dataManager != nil) {
				if ([dataManager respondsToSelector:@selector(_updateTelephonyState)]) {
          [dataManager _updateTelephonyState];
        }
			}
		}
	}
}

static int mapDataType(int index) {
	if (osAtLeast(@"7.1")) {
		switch (index) {
			case 0: return 3;
			case 1: return 5;
			case 2: return 6;
			case 3: return 7;
		}
	} else {
		switch (index) {
			case 0: return 2;
			case 1: return 3;
			case 2: return 5;
			case 3: return 6;
		}
	}

	return 0;
}



#pragma mark Common Hooks (for all OS versions)

%group Hooks_Common

%hook SBTelephonyManager

- (int)registrationStatus {
	return enabled ? 2 : %orig;
}

- (BOOL)needsUserIdentificationModule {
	return enabled ? NO : %orig;
}

// Shows the "bars" in non-cellular devices.
- (BOOL)cellularRadioCapabilityIsActive {
	return enabled ? YES : %orig;
}

- (long)signalStrengthBars {
	return enabled ? signalStrength : %orig;
}

- (id)operatorName {
	return enabled ? carrierName : %orig;
}

- (int)dataConnectionType {
	int current = %orig;
	if (enabled && current == 0) {
		current = mapDataType(dataType);
	}

	return current;
}

%end // SBTelephonyManager

%hook SBSIMLockManager

- (BOOL)_shouldSuppressAlert {
	return enabled && suppressAlerts ? YES : %orig;
}

%end // SBSIMLockManager

%end // Hooks_Common



#pragma mark iOS8+ Hooks

%group Hooks_8P

%hook SBTelephonyManager

- (int)cellRegistrationStatus {
	return enabled ? 2 : %orig;
}

%end // SBTelephonyManager

%end // Hooks_8P



#pragma mark Tweak Lifetime

static void notification(CFNotificationCenterRef center,
                         void *observer,
												 CFStringRef name,
												 const void *object,
												 CFDictionaryRef userInfo) {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *options = [defaults persistentDomainForName:@"com.sonodima.simphony"];

	enabled = [options[@"enabled"] ?: @YES boolValue];
	suppressAlerts = [options[@"suppressAlerts"] ?: @YES boolValue];
	carrierName = options[@"carrierName"] ?: @"AT&T";
	dataType = [options[@"dataType"] ?: @3 intValue];
	signalStrength = round([options[@"signalStrength"] ?: @4 floatValue]);

	updateItems();
}

%ctor {
	notification(NULL, NULL, NULL, NULL, NULL);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
	                                NULL,
																	notification,
																	(CFStringRef)@"com.sonodima.simphony/preferences.changed",
																	NULL,
																	CFNotificationSuspensionBehaviorCoalesce);

	%init(Hooks_Common);
	if (osAtLeast(@"8")) { %init(Hooks_8P); }
}
