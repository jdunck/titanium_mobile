/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import <UIKit/UIKit.h>
#import "TitaniumModule.h"
#import "TitaniumCmdThread.h"

// TI_VERSION will be set via an external source if not set
// display a warning and set it to 0.0.0

extern BOOL VERBOSE_DEBUG;

#ifndef TI_VERSION
#warning TI_VERSION was undefined!
#define TI_VERSION 0.0.0
#endif

#define _QUOTEME(x) #x
#define STRING(x) _QUOTEME(x)

#define TI_VERSION_STR STRING(TI_VERSION)

@interface TitaniumProxyObject : NSObject
{
	//Stringy ties to the outside world
	NSString * token;
	NSString * javaScriptPath;
	NSString * parentPageToken;
}
@property(nonatomic,readwrite,retain)	NSString * token;
@property(nonatomic,readwrite,retain)	NSString * javaScriptPath;
@property(nonatomic,readwrite,retain)	NSString * parentPageToken;
@end


typedef enum {
	TitaniumAppResourceNoType = 0,
	TitaniumAppResourceFileType = 1,
	TitaniumAppResourceCommandType =	0x10,
	TitaniumAppResourceContinueType =	0x20,
	TitaniumAppResourceBlobType =		0x40,
	TitaniumAppResourceFunctionType = TitaniumAppResourceCommandType | TitaniumAppResourceContinueType,
} TitaniumAppResourceType;

@class TitaniumAppProtocol, TitaniumCmdThread, TitaniumViewController, TitaniumBlobWrapper, TitaniumModule;

#define MAXTHREADDEPTH	5

@interface TitaniumHost : NSObject {
	NSString * appID;
	NSString * appResourcesPath;
	NSURL * appBaseUrl;
	NSString * appDocumentsPath;

	CGFloat keyboardTop;

//Dynamic objects:
	NSInteger lastThreadHash;
	NSMutableDictionary * threadRegistry; //Stack-based Registry based on thread ID
//	NSMutableDictionary * threadForNSThreadDict; //Simple NSThread->TiThread dict.
	TitaniumCmdThread * threadStack[MAXTHREADDEPTH];
	int threadStackCount;
	
	CFMutableDictionaryRef viewControllerRegistry; //Say what? Yeah. Because we don't want to retain views unnecessairly, this will be core foundation!
	
	NSMutableDictionary * nativeModules;

	NSInteger lastBlobHash;
	NSMutableDictionary * blobRegistry;

	NSInteger activityIndicatorLevel; //<= 0 means hidden, >= 1 means visible.

	NSMutableDictionary * titaniumObject;
//Caching objects:
	NSDictionary * appProperties;
	NSMutableDictionary * imageCache;
	NSMutableDictionary * stretchableImageCache;
}

@property(readwrite,copy)	NSString * appID;
@property(readwrite,retain)	NSMutableDictionary * threadRegistry;
@property(readonly,nonatomic)	NSURL * appBaseUrl;
@property(readwrite,copy)	NSString * appResourcesPath;
@property(readonly,retain)	NSMutableDictionary * titaniumObject;
@property(readonly,retain)	NSDictionary * appProperties;

@property (nonatomic, assign)	CGFloat keyboardTop;

+ (TitaniumHost *) sharedHost;

#pragma mark Utilities
- (void) flushCache;

#pragma mark Thread registration
- (void) registerThread:(TitaniumCmdThread *) thread;
- (void) unregisterThread:(TitaniumCmdThread *) thread;
- (TitaniumCmdThread *) threadForToken: (NSString *) token;
- (TitaniumCmdThread *) currentThread;

#pragma mark Module registration
- (TitaniumModule *) moduleNamed: (NSString *) moduleClassName;
- (BOOL) registerModuleNamed: (NSString *) moduleClassName;
- (void) startModules;
- (void) endModules;

#pragma mark View registration
- (void) applyDefaultViewSettings: (UIViewController *) viewController;

- (void) registerViewController: (UIViewController *) viewController forKey: (NSString *) key;
- (void) unregisterViewController: (UIViewController *) viewController;

#pragma mark Blob Management

- (TitaniumBlobWrapper *) blobForToken: (NSString *) token;
- (TitaniumBlobWrapper *) blobForImage: (UIImage *) inputImage;
- (TitaniumBlobWrapper *) blobForFile:	(NSString *) filePath;
- (TitaniumBlobWrapper *) blobForData:	(NSData *) blobData;

#pragma mark Useful Toys

- (NSURL *) resolveUrlFromString:(NSString *) urlString useFilePath:(BOOL) useFilePath;
- (NSString *) filePathFromURL: (NSURL *) url;

- (void) incrementActivityIndicator;
- (void) decrementActivityIndicator;

- (UIImage *) imageForResource: (id) pathString;
- (UIImage *) stretchableImageForResource: (id) pathOrUrl;

#pragma mark JavaScript Generation

- (TitaniumAppResourceType) appResourceTypeForUrl:(NSURL *) url;
- (NSString *) javaScriptForResource: (NSURL *) resourceUrl;
- (NSString *) performFunction: (NSURL *) functionUrl;

- (NSMutableString *) generateJavaScriptWrappingKeyPath: (NSString *) keyPath makeObject: (BOOL) makeObject;

//Executes and returns the string inline with the background thread, or if not in a thread,
//with the main page of the currently visible most foreground page.
- (NSString *) performJavascript: (NSString *) inputString;

//Schedules the main thread to run the code to run for the appropriate page at some later time.
//If no such page exists for the token, the event is dropped on the floor.
//Returns YES if an event was scheduled, NO if no such page was found and scheduled.
- (BOOL) sendJavascript: (NSString *) inputString toPageWithToken: (NSString *) token;

- (BOOL) sendJavascript: (NSString *) inputString;

#pragma mark Convenience methods
- (TitaniumViewController *) visibleTitaniumViewController;
- (TitaniumViewController *) currentTitaniumViewController;
- (TitaniumViewController *) titaniumViewControllerForToken: (NSString *) token;

@end
