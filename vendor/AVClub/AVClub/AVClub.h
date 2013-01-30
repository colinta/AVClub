//
//  AVClub.h
//  AVClub
//
//  Created by Colin T.A. Gray on 11/16/12.
//  Copyright (c) 2012 colinta. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>


@class AVCamRecorder, AVCaptureVideoPreviewLayer;
@protocol AVClubDelegate;


@interface AVClub : NSObject


@property (nonatomic,retain) AVCaptureSession *session;
@property (nonatomic,assign) AVCaptureVideoOrientation orientation;
@property (nonatomic,retain) AVCaptureDeviceInput *videoInput;
@property (nonatomic,retain) AVCaptureDeviceInput *audioInput;
@property (nonatomic,retain) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic,retain) AVCamRecorder *recorder;
@property (nonatomic,assign) id deviceConnectedObserver;
@property (nonatomic,assign) id deviceDisconnectedObserver;
@property (nonatomic,assign) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic,assign) id <AVClubDelegate> delegate;
@property (nonatomic,assign) UIView *viewFinderView;
@property (nonatomic,assign) BOOL isRunning;
@property (nonatomic,retain) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;


- (void) startInView:(UIView*)videoView;
- (void) startSession;
- (void) stopSession;

- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates;
- (void) startRecording;
- (void) stopRecording;
- (void) saveImageToLibrary:(UIImage*)image;
- (void) captureStillImage;
- (void) captureStillImageAnimated:(BOOL)animated;
- (BOOL) toggleCamera;
- (BOOL) toggleCameraAnimated:(BOOL)animated;
- (void) autoFocusAtPoint:(CGPoint)point;
- (void) continuousFocusAtPoint:(CGPoint)point;


- (NSUInteger) cameraCount;
- (NSUInteger) micCount;
- (BOOL) hasCamera;
- (BOOL) hasMultipleCameras;
- (BOOL) hasAudio;
- (BOOL) hasVideo;


@end


// These delegate methods are always called on the main CFRunLoop
@protocol AVClubDelegate <NSObject>
@optional
- (void) club:(AVClub *)club didFailWithError:(NSError *)error;
- (void) clubRecordingBegan:(AVClub *)club;
- (void) clubRecordingFinished:(AVClub *)club;
- (void) club:(AVClub*)club stillImageCaptured:(UIImage*)image error:(NSError*)error;
- (void) club:(AVClub*)club assetSavedToURL:(NSURL*)assetURL error:(NSError*)error;
- (void) clubDeviceConfigurationChanged:(AVClub *)club;
@end
