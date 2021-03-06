/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#ifdef MODULE_TI_MEDIA

#import "MediaModule.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVAudioPlayer.h>
#import <MediaPlayer/MediaPlayer.h>
#import "TitaniumBlobWrapper.h"

NSString * const iPhoneSoundGeneratorFunction = @"function(token){"
	"var result={"
		"_TOKEN:token, _PATH:'titaniumObject.Media._MEDIA.'+token,"
		"_EVT:{complete:[],error:[]},addEventListener:Titanium._ADDEVT,removeEventListener:Ti._REMEVT,"
		"onComplete:Ti._ONEVT,"
		"play:function(){return Ti._TICMD(this._PATH,'play',arguments);},"
		"getVolume:function(){return Ti._TICMD(this._PATH,'getVolume',arguments);},"
		"isLooping:function(){return Ti._TICMD(this._PATH,'isLooping',arguments);},"
		"isPaused:function(){return Ti._TICMD(this._PATH,'isPaused',arguments);},"
		"isPlaying:function(){return Ti._TICMD(this._PATH,'isPlaying',arguments);},"
		"pause:function(){return Ti._TICMD(this._PATH,'pause',arguments);},"
		"reset:function(){return Ti._TICMD(this._PATH,'reset',arguments);},"
		"resume:function(){return Ti._TICMD(this._PATH,'resume',arguments);},"
		"stop:function(){return Ti._TICMD(this._PATH,'stop',arguments);},"
		"setLooping:function(){return Ti._TICMD(this._PATH,'setLooping',arguments);},"
		"setVolume:function(){return Ti._TICMD(this._PATH,'setVolume',arguments);},"
		"release:function(){return Ti.Media._REL(this._TOKEN);},"
	"};"
	"Ti.Media._MEDIA[token]=result;"
	"return result;"
"}";

@interface SoundWrapper : TitaniumProxyObject<AVAudioPlayerDelegate>
{
//Connections to the native side
	AVAudioPlayer * nativePlayer;
	NSURL * soundUrl;
	NSTimeInterval resumeTime;
	CGFloat volume;
	BOOL isLooping;
}

@property(nonatomic,readonly,retain) AVAudioPlayer * nativePlayer;

@end

@implementation SoundWrapper

- (AVAudioPlayer *) nativePlayer;
{
	if (nativePlayer == nil){
		NSError * resultError = nil;
		nativePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:soundUrl error:(NSError **)&resultError];
		[nativePlayer setDelegate:self];
		[nativePlayer prepareToPlay];
		[nativePlayer setVolume:volume];
		[nativePlayer setNumberOfLoops:(isLooping?-1:0)];
		[nativePlayer setCurrentTime:resumeTime];
		if (resultError != nil){
			NSLog(@"ERROR MAKING SOUND: %@ (%@)",soundUrl,resultError);
		}
	}
	return nativePlayer;
}


- (id) initWithContentsOfURL:(NSURL *) newSoundURL;
{
	if ((self = [super init])){
		volume = 1.0;
		soundUrl = [newSoundURL retain];
		if ([self nativePlayer] == nil){
			[self release];
			return nil;
		}
	}
	return self;
}

- (void)flushCache;
{
	if ((nativePlayer == nil) || [nativePlayer isPlaying]) return;
	resumeTime = [nativePlayer currentTime];
	volume = [nativePlayer volume];
	isLooping = ([nativePlayer numberOfLoops] < 0);
	[nativePlayer release];
	nativePlayer = nil;
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag;
{
	NSString * resultString = [NSString stringWithFormat:@"Ti.Media._MEDIA.%@.onComplete({"
							   "type:'complete',success:%@,})",
							   token,(flag ? @"true" : @"false")];
	
	[[TitaniumHost sharedHost] sendJavascript:resultString toPageWithToken:parentPageToken];

}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error;
{
	NSString * resultString = [NSString stringWithFormat:@"Ti.Media._MEDIA.%@.onComplete({"
							   "type:'error',success:false,message:%@})",
							   token,[error localizedDescription]];
	
	[[TitaniumHost sharedHost] sendJavascript:resultString toPageWithToken:parentPageToken];
}

- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player;
{
	NSLog(@"SOUND INTERRUPTION STARTED!");
}

- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player;
{
	NSLog(@"SOUND INTERRUPTION FINISHED!");
}


- (void) dealloc
{
	[nativePlayer stop];
	[nativePlayer release];
	[soundUrl release];
	[super dealloc];
}
- (id) runFunctionNamed: (NSString *) functionName withObject: (id) objectValue error: (NSError **) error;
{
	if ([functionName isEqualToString:@"play"]){ //Resume is mapped to play.
		[[self nativePlayer] setCurrentTime:0];
		[nativePlayer play];
	} else if ([functionName isEqualToString:@"resume"]) {
		[[self nativePlayer] play];
	} else if ([functionName isEqualToString:@"pause"]) {
		[nativePlayer pause];
	} else if ([functionName isEqualToString:@"reset"]) {
//		[[self nativePlayer] stop];
		[nativePlayer setCurrentTime:0];
		resumeTime = 0;
//		[nativePlayer play];
	} else if ([functionName isEqualToString:@"stop"]) {
		if (nativePlayer != nil){
			[nativePlayer stop];
			[nativePlayer setCurrentTime:0];
		}
		resumeTime = 0;

	} else if ([functionName isEqualToString:@"getVolume"]) {
		return [NSNumber numberWithFloat:volume]; //We keep this current.

	} else if ([functionName isEqualToString:@"isLooping"]) {
		if (nativePlayer != nil){
			return [NSNumber numberWithBool:([nativePlayer numberOfLoops] != 0)];			
		}
		return [NSNumber numberWithBool:(isLooping != 0)];

	} else if ([functionName isEqualToString:@"isPaused"]) {
		if (nativePlayer != nil){
			return [NSNumber numberWithBool:![nativePlayer isPlaying] && ([nativePlayer currentTime] != 0)];
		}
		return [NSNumber numberWithBool:resumeTime != 0];

	} else if ([functionName isEqualToString:@"isPlaying"]) {
		return [NSNumber numberWithBool:[nativePlayer isPlaying]];

	} else if ([functionName isEqualToString:@"setLooping"]) {
		id boolObject = nil;
		if ([objectValue isKindOfClass:[NSArray class]] && [objectValue count]>0) boolObject = [objectValue objectAtIndex:0];
		if ([boolObject respondsToSelector:@selector(boolValue)]) {
			isLooping = [boolObject boolValue];
			[nativePlayer setNumberOfLoops:(isLooping?-1:0)];
		}
	} else if ([functionName isEqualToString:@"setVolume"]) {
		id floatObject = nil;
		if ([objectValue isKindOfClass:[NSArray class]] && [objectValue count]>0) floatObject = [objectValue objectAtIndex:0];
		if ([floatObject respondsToSelector:@selector(floatValue)]) {
			volume = [floatObject floatValue];
			[nativePlayer setVolume:volume];
		}
	}
	return nil;
}
@end


@interface MovieWrapper : TitaniumProxyObject
{
	//Connections to the native side
	NSURL *contentURL;
	UIColor *backgroundColor;
	MPMovieScalingMode scalingMode;
	MPMovieControlMode movieControlMode;
	NSTimeInterval initialPlaybackTime;
}

@property(nonatomic, readwrite, retain) NSURL *contentURL;
@property(nonatomic, retain) UIColor *backgroundColor;
@property(nonatomic) MPMovieScalingMode scalingMode;
@property(nonatomic) MPMovieControlMode movieControlMode;
@property(nonatomic) NSTimeInterval initialPlaybackTime;

@end

@implementation MovieWrapper
@synthesize contentURL, backgroundColor, scalingMode, movieControlMode, initialPlaybackTime;

- (MPMoviePlayerController *) newMoviePlayerController;
{
	MPMoviePlayerController * result = [[MPMoviePlayerController alloc] initWithContentURL:contentURL];
	[result setScalingMode:scalingMode];
	[result setMovieControlMode:movieControlMode];
	[result setBackgroundColor:backgroundColor];
#if defined(__IPHONE_3_0)

	[result setInitialPlaybackTime:initialPlaybackTime];
#endif
	return result;
}

- (id) initWithDict: (NSDictionary *) arguments;
{
	NSString * movieUrlString = [arguments objectForKey:@"contentURL"];	
	NSURL * ourUrl = [[TitaniumHost sharedHost] resolveUrlFromString:movieUrlString useFilePath:YES];
	if (ourUrl == nil) {
		[self release]; return nil;
	}

	self = [super init];
	if (self == nil) return nil;
	
	contentURL = [ourUrl retain];
	
	NSNumber * initialPlaybackTimeObject = [arguments objectForKey:@"initialPlaybackTime"];
	if ([initialPlaybackTimeObject respondsToSelector:@selector(floatValue)]) initialPlaybackTime =[initialPlaybackTimeObject floatValue]/1000.0;
	
	NSNumber * movieControlModeObject = [arguments objectForKey:@"movieControlMode"];
	if ([movieControlModeObject respondsToSelector:@selector(intValue)]) movieControlMode =[movieControlModeObject intValue];
	else movieControlMode = MPMovieControlModeDefault;

	NSNumber * scalingModeObject = [arguments objectForKey:@"scalingMode"];
	if ([scalingModeObject respondsToSelector:@selector(intValue)]) scalingMode =[scalingModeObject intValue];
	else scalingMode=MPMovieScalingModeAspectFit;
	
	NSString * colorObject = [arguments objectForKey:@"backgroundColor"];
	backgroundColor =[UIColorWebColorNamed(colorObject) retain];

	return self;
}

- (void) handlePlayerFinished: (NSDictionary *) userInfo;
{
	NSString * commandString = [[NSString alloc] initWithFormat:@"Ti.Media._MEDIA.%@.doEvent({type:'complete'})",token];
	[[TitaniumHost sharedHost] sendJavascript:commandString toPageWithToken:parentPageToken];
	[commandString release];
}

- (void) dealloc
{
	[contentURL release]; [backgroundColor release];
	[super dealloc];
}

@end




@implementation MediaModule
@synthesize imagePickerCallbackParentPageString, currentMovieToken, currentMovieWrapper;

#pragma mark Simple soundthings

- (void) beep;
{
	AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
	//TODO: Use a Titanium-supplied sound.
}

- (void) vibe;
{
	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

#pragma mark Create Sound/Video player

- (void)releaseToken:(NSString *) token;
{
	if (![token isKindOfClass:[NSString class]]) return;
	[self stopMovie:token]; //If a movie, this will stop it.
	[mediaDictionary removeObjectForKey:token]; //If a sound, deallocing will stop it.
}


- (TitaniumJSCode *) createSound: (id) soundResource;
{
	NSString * path = nil;
	SoundWrapper * nativeResult = nil;
	
	if ([soundResource isKindOfClass:[NSString class]]){
		path = soundResource;
	} else if ([soundResource isKindOfClass:[NSDictionary class]]) {
		path = [soundResource objectForKey:@"path"];
		if (![path isKindOfClass:[NSString class]]) return nil;
	}
	
	NSURL * fileUrl = [[TitaniumHost sharedHost] resolveUrlFromString:path useFilePath:YES];
	
	nativeResult = [[SoundWrapper alloc] initWithContentsOfURL:fileUrl];
	
	if(nativeResult==nil){
		return nil;
	}
	
	NSString * soundToken = [NSString stringWithFormat:@"SND%X",nextMediaToken++];
	[nativeResult setToken:soundToken];

	[mediaDictionary setObject:nativeResult forKey:soundToken];
	[nativeResult release];
	
	NSString * result = [NSString stringWithFormat:@"Titanium.Media._SNDGEN('%@')",soundToken];
	return [TitaniumJSCode codeWithString:result];
}

- (NSString *) createMovieProxy: (id) arguments;
{
	if (![arguments isKindOfClass:[NSDictionary class]])return nil;

	NSString * movieUrlString = [arguments objectForKey:@"contentURL"];
	if (![movieUrlString isKindOfClass:[NSString class]]) return nil;

	MovieWrapper * result = [[MovieWrapper alloc] initWithDict:arguments];
	NSString * videoToken = [NSString stringWithFormat:@"MOV%X",nextMediaToken++];
	[result setToken:videoToken];
	[mediaDictionary setObject:result forKey:videoToken];
	[result release];
	[self passivelyPreloadMovie:videoToken];
	
	return videoToken;
}

#pragma mark Movie nannying

- (void) passivelyPreloadMovie: (NSString *) token;
{
	if (currentMovie != nil) return;
	if (![NSThread isMainThread]){
		[self performSelectorOnMainThread:@selector(passivelyPreloadMovie:) withObject:token waitUntilDone:NO];
		return;
	}
	
	[self setCurrentMovieWrapper:[mediaDictionary objectForKey:token]];
	
	currentMovie = [currentMovieWrapper newMoviePlayerController];
	if (currentMovie == nil) return;
	
	[self setCurrentMovieToken:token];
	if (currentMovieIsPlaying) [currentMovie play];
}

- (void) playMovie: (NSString *) token;
{
	if (![token isKindOfClass:[NSString class]]) return;
	if (![NSThread isMainThread]){
		[self performSelectorOnMainThread:@selector(playMovie:) withObject:token waitUntilDone:NO];
		return;
	}
	
	if (![token isEqualToString:currentMovieToken] || currentMovieIsPlaying){ //We're not preloaded.
		//Kill the old movie, and install a new regieme.
		
		[currentMovie stop];[currentMovie release];
		
		currentMovieIsPlaying = NO;
		[self setCurrentMovieWrapper:[mediaDictionary objectForKey:token]];
		currentMovie = [currentMovieWrapper newMoviePlayerController];
		if (currentMovie == nil) return;
		[self setCurrentMovieToken:token];
	}
	
	currentMovieIsPlaying = YES;
	[currentMovie play];
}

- (void) stopMovie: (NSString *) token;
{
	if (![token isKindOfClass:[NSString class]]) return;
	if (![token isEqualToString:currentMovieToken]) return;
	if (![NSThread isMainThread]){
		[currentMovie performSelectorOnMainThread:@selector(stop) withObject:nil waitUntilDone:NO];
		return;
	}
	[currentMovie stop];
}

- (void) handlePlayerNotification: (NSNotification *) theNotification;
{
	if ([theNotification object] != currentMovie) return;
	NSString * notificationType = [theNotification name];
	
	NSLog(@"HandlePlayer: %@ = %@",theNotification,[theNotification userInfo]);
	
	if ([notificationType isEqualToString:MPMoviePlayerPlaybackDidFinishNotification]){
		MovieWrapper * cmw = [mediaDictionary objectForKey:currentMovieToken];
		[cmw handlePlayerFinished:[theNotification userInfo]];
		[currentMovie release]; currentMovie = nil;
		[currentMovieToken release]; currentMovieToken = nil;
		[cmw release]; currentMovieWrapper = nil;
		currentMovieIsPlaying = NO;
	}
	//	MP_EXTERN NSString *const MPMoviePlayerContentPreloadDidFinishNotification; // userInfo contains NSError for @"error" key if preloading fails
	//	MP_EXTERN NSString *const MPMoviePlayerScalingModeDidChangeNotification;
	//	MP_EXTERN NSString *const MPMoviePlayerPlaybackDidFinishNotification;
	
	//	[[TitaniumHost sharedHost] sendJavascript:resultString toPageWithToken:parentPageToken];
}


#pragma mark Image picker

- (id) startPicker: (NSNumber *) isCameraObject options: (id) arguments;
{
	if(currentImagePicker != nil) return [TitaniumJSCode codeWithString:@"{code:Ti.Media.DEVICE_BUSY}"];
	if(![isCameraObject respondsToSelector:@selector(boolValue)])return [TitaniumJSCode codeWithString:@"{code:Ti.Media.UNKOWN_ERROR}"]; //Shouldn't happen.
	BOOL isCamera = [isCameraObject boolValue];
	
	UIImagePickerControllerSourceType ourSource = (isCamera ? UIImagePickerControllerSourceTypeCamera : UIImagePickerControllerSourceTypePhotoLibrary);
	if (![UIImagePickerController isSourceTypeAvailable:ourSource])return [TitaniumJSCode codeWithString:@"{code:Ti.Media.NO_CAMERA}"];
	
	[self setImagePickerCallbackParentPageString:[[[TitaniumHost sharedHost] currentThread] magicToken]];
	currentImagePicker = [[UIImagePickerController alloc] init];
	[currentImagePicker setDelegate:self];
	[currentImagePicker setSourceType:ourSource];

	//The promised land! Let's set stuff up!
	isImagePickerAnimated = YES;
	saveImageToRoll = NO;

	if([arguments isKindOfClass:[NSDictionary class]]){
		NSNumber * animatedObject = [arguments objectForKey:@"animated"];
		NSNumber * imageEditingObject = [arguments objectForKey:@"allowImageEditing"];
		NSNumber * saveToRollObject = [arguments objectForKey:@"saveToPhotoGallery"];

		if([animatedObject respondsToSelector:@selector(boolValue)]){
			isImagePickerAnimated = [animatedObject boolValue];
		}
		
		if([imageEditingObject respondsToSelector:@selector(boolValue)]){
			[currentImagePicker setAllowsImageEditing:[imageEditingObject boolValue]];
		}
		
		if([saveToRollObject respondsToSelector:@selector(boolValue)]){
			saveImageToRoll = [saveToRollObject boolValue];
		}
		
	}

	[self performSelectorOnMainThread:@selector(startPickerInMainThread) withObject:nil waitUntilDone:NO];
	return nil;
}

- (void) startPickerInMainThread;
{
	UIViewController * visibleController = [[TitaniumHost sharedHost] visibleTitaniumViewController];
	[[visibleController navigationController] presentModalViewController:currentImagePicker animated:isImagePickerAnimated];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo;
{
	NSMutableString * resultString = [NSMutableString stringWithString:@"Ti.Media._PIC.success("];
	TitaniumBlobWrapper * ourImageBlob = [[TitaniumHost sharedHost] blobForImage:image];
	if (ourImageBlob != nil) [resultString appendString:[ourImageBlob stringValue]];
	
	if (saveImageToRoll) UIImageWriteToSavedPhotosAlbum(image, nil, nil, NULL);
	
	if (editingInfo != nil) {
		[resultString appendString:@",{"];
		TitaniumBlobWrapper * oldImageBlob = [[TitaniumHost sharedHost] blobForImage:[editingInfo objectForKey:UIImagePickerControllerOriginalImage]];
		if (oldImageBlob != nil){
			[resultString appendFormat:@"oldImage:%@,",[oldImageBlob stringValue]];
		}
		NSValue * ourRectValue = [editingInfo objectForKey:UIImagePickerControllerCropRect];
		if (ourRectValue != nil){
			CGRect ourRect = [ourRectValue CGRectValue];
			[resultString appendFormat:@"cropRect:{x:%f,y:%f,width:%f,height:%f},",
					ourRect.origin.x, ourRect.origin.y, ourRect.size.width, ourRect.size.height];
		}
		[resultString appendString:@"}"];
	}
	[resultString appendString:@")"];

	[[TitaniumHost sharedHost] sendJavascript:resultString toPageWithToken:imagePickerCallbackParentPageString];
	[[picker parentViewController] dismissModalViewControllerAnimated:isImagePickerAnimated];
	[currentImagePicker release];
	currentImagePicker = nil;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
{
	[[TitaniumHost sharedHost] sendJavascript:@"Ti.Media._PIC.cancel()" toPageWithToken:imagePickerCallbackParentPageString];
	[[picker parentViewController] dismissModalViewControllerAnimated:isImagePickerAnimated];
	[currentImagePicker release];
	currentImagePicker = nil;
}

#pragma mark Image storing

- (void)saveImageToRoll: (TitaniumBlobWrapper *) savedImageBlob;
{
	if (![savedImageBlob isKindOfClass:[TitaniumBlobWrapper class]])return;
	UIImage * savedImage = [savedImageBlob imageBlob];
	if (savedImage == nil) return;
	
	UIImageWriteToSavedPhotosAlbum(savedImage, nil, nil, NULL);
}

- (void)flushCache;
{
	if ((currentMovie != nil) && !currentMovieIsPlaying){
		[currentMovie release];
		currentMovie = nil;
	}
	for(id cacheObject in [mediaDictionary objectEnumerator]){
		if ([cacheObject respondsToSelector:@selector(flushCache)]){
			[cacheObject flushCache];
		}
	}
}


#pragma mark Start Module

- (BOOL) startModule;
{
	TitaniumInvocationGenerator * invocGen = [TitaniumInvocationGenerator generatorWithTarget:self];

	[(MediaModule *)invocGen beep];
	NSInvocation * beepInvoc = [invocGen invocation];

	[(MediaModule *)invocGen vibe];
	NSInvocation * vibeInvoc = [invocGen invocation];

	[(MediaModule *)invocGen createSound:nil];
	NSInvocation * newSoundInvoc = [invocGen invocation];

	[(MediaModule *)invocGen createMovieProxy:nil];
	NSInvocation * newMovieInvoc = [invocGen invocation];

	[(MediaModule *)invocGen startPicker:nil options:nil];
	NSInvocation * importImageInvoc = [invocGen invocation];
	
	[(MediaModule *)invocGen playMovie:nil];
	NSInvocation * playMovieInvoc = [invocGen invocation];

	[(MediaModule *)invocGen stopMovie:nil];
	NSInvocation * stopMovieInvoc = [invocGen invocation];
	
	[(MediaModule *)invocGen saveImageToRoll:nil];
	NSInvocation * saveImageInvoc = [invocGen invocation];

	[(MediaModule *)invocGen releaseToken:nil];
	NSInvocation * releaseInvoc = [invocGen invocation];
	

	NSString * showCameraString = @"function(args){if(!args)return false; var err=Ti.Media._NEWPIC(true,args);"
			"if(err!=null){if(typeof(args.error)=='function')args.error(err);return false;}"
			"Ti.Media._PIC=args;return true;}";
	NSString * showPickerString = @"function(args){var err=Ti.Media._NEWPIC(false,args);"
			"if(err!=null){if(typeof(args.error)=='function')args.error(err);return false;}"
			"Ti.Media._PIC=args;return true;}";

	NSString * createVideoString = @"function(args){var tok=Ti.Media._NEWMOV(args);if(tok==null)return null;"
			"var res={_TOKEN:tok,_EVT:{complete:[],error:[],resize:[]},doEvent:Ti._ONEVT,"
				"addEventListener:Ti._ADDEVT,removeEventListener:Ti._REMEVT,"
				"play:function(){return Ti.Media._PLAYMOV(this._TOKEN);},"
				"stop:function(){return Ti.Media._STOPMOV(this._TOKEN);},"
				"release:function(){return Ti.Media._REL(this._TOKEN);},"
			"};return res;}";


	NSNotificationCenter * theNC = [NSNotificationCenter defaultCenter];
	[theNC addObserver:self selector:@selector(handlePlayerNotification:) name:MPMoviePlayerPlaybackDidFinishNotification object:nil];

	mediaDictionary = [[NSMutableDictionary alloc] init];

	NSDictionary * mediaDict = [NSDictionary dictionaryWithObjectsAndKeys:
			beepInvoc, @"beep",
			vibeInvoc, @"vibrate",
			newSoundInvoc, @"createSound",
			[TitaniumJSCode codeWithString:iPhoneSoundGeneratorFunction],@"_SNDGEN",
			[TitaniumJSCode codeWithString:createVideoString],@"createVideoPlayer",
			mediaDictionary,@"_MEDIA",
			importImageInvoc,@"_NEWPIC",
			saveImageInvoc,@"saveToPhotoGallery",
			
			newMovieInvoc,@"_NEWMOV",
			playMovieInvoc,@"_PLAYMOV",
			stopMovieInvoc,@"_STOPMOV",
			releaseInvoc,@"_REL",
			
			[TitaniumJSCode codeWithString:showCameraString],@"showCamera",
			[TitaniumJSCode codeWithString:showPickerString],@"openPhotoGallery",
			
			
			[NSNumber numberWithInt:MediaModuleErrorUnknown],@"UNKNOWN_ERROR",
			[NSNumber numberWithInt:MediaModuleErrorImagePickerBusy],@"DEVICE_BUSY",
			[NSNumber numberWithInt:MediaModuleErrorNoCamera],@"NO_CAMERA",
			
			[NSNumber numberWithInt:MPMovieControlModeDefault],@"VIDEO_CONTROL_DEFAULT",
			[NSNumber numberWithInt:MPMovieControlModeVolumeOnly],@"VIDEO_CONTROL_VOLUME_ONLY",
			[NSNumber numberWithInt:MPMovieControlModeHidden],@"VIDEO_CONTROL_HIDDEN",
			[NSNumber numberWithInt:MPMovieScalingModeNone],@"VIDEO_SCALING_NONE",
			[NSNumber numberWithInt:MPMovieScalingModeAspectFit],@"VIDEO_SCALING_ASPECT_FIT",
			[NSNumber numberWithInt:MPMovieScalingModeAspectFill],@"VIDEO_SCALING_ASPECT_FILL",
			[NSNumber numberWithInt:MPMovieScalingModeFill],@"VIDEO_SCALING_MODE_FILL",
								
			nil];
	[[[TitaniumHost sharedHost] titaniumObject] setObject:mediaDict forKey:@"Media"];
	
	return YES;
}

- (BOOL) endModule;
{
	return YES;
}

- (void) dealloc
{
	[currentMovie stop];
	[currentMovie release];

	[[currentImagePicker parentViewController] dismissModalViewControllerAnimated:NO];
	[currentImagePicker release];

	[imagePickerCallbackParentPageString release];
	[mediaDictionary release];
	[currentMovieToken release];
	
	[super dealloc];
}


@end

#endif