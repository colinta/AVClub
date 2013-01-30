//
//  AVClub.m
//  AVClub
//
//  Created by Colin T.A. Gray on 11/16/12.
//  Copyright (c) 2012 colinta. All rights reserved.
//

#import "AVClub.h"
#import "AVCamRecorder.h"
#import "AVCamUtilities.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/CGImageProperties.h>


@interface AVClub (RecorderDelegate) <AVCamRecorderDelegate>
@end


#pragma mark -
@interface AVClub (InternalUtilityMethods)
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition)position;
- (AVCaptureDevice *) frontFacingCamera;
- (AVCaptureDevice *) backFacingCamera;
- (AVCaptureDevice *) audioDevice;
- (NSURL *) tempFileURL;
- (void) removeFile:(NSURL *)outputFileURL;
- (void) copyFileToDocuments:(NSURL *)fileURL;
@end


#pragma mark -
@implementation AVClub


@synthesize session = session;
@synthesize delegate;


- (id) init
{
    self = [super init];
    if (self != nil) {
        self.isRunning = NO;

        __block AVClub *weakSelf = self;
        void (^deviceConnectedBlock)(NSNotification *) = ^(NSNotification *notification) {
            AVCaptureDevice *device = notification.object;

            BOOL sessionHasDeviceWithMatchingMediaType = NO;
            NSString *deviceMediaType = nil;
            if ( [device hasMediaType:AVMediaTypeAudio] )
                deviceMediaType = AVMediaTypeAudio;
            else if ( [device hasMediaType:AVMediaTypeVideo] )
                deviceMediaType = AVMediaTypeVideo;

            if ( deviceMediaType )
            {
                for (AVCaptureDeviceInput *input in [self.session inputs])
                {
                    if ( [input.device hasMediaType:deviceMediaType] )
                    {
                        sessionHasDeviceWithMatchingMediaType = YES;
                        break;
                    }
                }

                if ( ! sessionHasDeviceWithMatchingMediaType )
                {
                    NSError *error;
                    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
                    if ( [session canAddInput:input] )
                        [session addInput:input];
                }
            }

            if ( [delegate respondsToSelector:@selector(clubDeviceConfigurationChanged:)] )
                CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate clubDeviceConfigurationChanged:self]; });
        };
        void (^deviceDisconnectedBlock)(NSNotification *) = ^(NSNotification *notification) {
            AVCaptureDevice *device = notification.object;

            if ( [device hasMediaType:AVMediaTypeAudio] ) {
                [session removeInput:weakSelf.audioInput];
                weakSelf.audioInput = nil;
            }
            else if ( [device hasMediaType:AVMediaTypeVideo] ) {
                [session removeInput:weakSelf.videoInput];
                weakSelf.videoInput = nil;
            }

            if ( [delegate respondsToSelector:@selector(clubDeviceConfigurationChanged:)] )
                CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate clubDeviceConfigurationChanged:self]; });
        };

        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        self.deviceConnectedObserver = [notificationCenter addObserverForName:AVCaptureDeviceWasConnectedNotification object:nil queue:nil usingBlock:deviceConnectedBlock];
        self.deviceDisconnectedObserver = [notificationCenter addObserverForName:AVCaptureDeviceWasDisconnectedNotification object:nil queue:nil usingBlock:deviceDisconnectedBlock];
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [notificationCenter addObserver:self selector:@selector(deviceOrientationDidChange) name:UIDeviceOrientationDidChangeNotification object:nil];
        self.orientation = AVCaptureVideoOrientationPortrait;
    }

    return self;
}

- (void) dealloc
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self.deviceConnectedObserver];
    [notificationCenter removeObserver:self.deviceDisconnectedObserver];
    [notificationCenter removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];

    [self stop_session];
}

- (void) startInView:(UIView*)videoView
{
    // Set torch and flash mode to auto
    if ( self.backFacingCamera.hasFlash )
    {
        if ( [self.backFacingCamera lockForConfiguration:nil] )
        {
            if ( [self.backFacingCamera isFlashModeSupported:AVCaptureFlashModeAuto] )
                [self.backFacingCamera setFlashMode:AVCaptureFlashModeAuto];

            [self.backFacingCamera unlockForConfiguration];
        }
    }
    if ( self.backFacingCamera.hasTorch )
    {
        if ( [self.backFacingCamera lockForConfiguration:nil] )
        {
            if ( [self.backFacingCamera isTorchModeSupported:AVCaptureTorchModeAuto] )
                [self.backFacingCamera setTorchMode:AVCaptureTorchModeAuto];

            [self.backFacingCamera unlockForConfiguration];
        }
    }

    // Init the device inputs
    AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.backFacingCamera error:nil];
    AVCaptureDeviceInput *newAudioInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.audioDevice error:nil];


    // Setup the still image file output
    AVCaptureStillImageOutput *newStillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                    AVVideoCodecJPEG, AVVideoCodecKey,
                                    nil];
    [newStillImageOutput setOutputSettings:outputSettings];


    // Create session (use default AVCaptureSessionPresetHigh)
    AVCaptureSession *newCaptureSession = [[AVCaptureSession alloc] init];


    // Add inputs and output to the capture session
    if ( [newCaptureSession canAddInput:newVideoInput] )
        [newCaptureSession addInput:newVideoInput];

    if ( [newCaptureSession canAddInput:newAudioInput] )
        [newCaptureSession addInput:newAudioInput];

    if ( [newCaptureSession canAddOutput:newStillImageOutput] )
        [newCaptureSession addOutput:newStillImageOutput];

    self.stillImageOutput = newStillImageOutput;
    self.videoInput = newVideoInput;
    self.audioInput = newAudioInput;
    self.session = newCaptureSession;

    // Set up the movie file output
    NSURL *outputFileURL = self.tempFileURL;
    AVCamRecorder *newRecorder = [[AVCamRecorder alloc] initWithSession:self.session outputFileURL:outputFileURL];
    [newRecorder setDelegate:self];

    // Send an error to the delegate if video recording is unavailable
    if ( ! newRecorder.recordsVideo && newRecorder.recordsAudio )
    {
        NSString *localizedDescription = NSLocalizedString(@"Video recording unavailable", @"Video recording unavailable description");
        NSString *localizedFailureReason = NSLocalizedString(@"Movies recorded on this device will only contain audio. They will be accessible through iTunes file sharing.", @"Video recording unavailable failure reason");
        NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                   localizedDescription, NSLocalizedDescriptionKey,
                                   localizedFailureReason, NSLocalizedFailureReasonErrorKey,
                                   nil];
        NSError *noVideoError = [NSError errorWithDomain:@"AVCam" code:0 userInfo:errorDict];
        if ( [delegate respondsToSelector:@selector(club:didFailWithError:)] )
            CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate club:self didFailWithError:noVideoError]; });
    }

    self.recorder = newRecorder;

    // Create video preview layer and add it to the UI
    if ( videoView )
    {
        AVCaptureVideoPreviewLayer *newCaptureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
        CALayer *viewLayer = videoView.layer;
        [viewLayer setMasksToBounds:YES];

        CGRect bounds = videoView.bounds;
        [newCaptureVideoPreviewLayer setFrame:bounds];

        if ( self.recorder.isOrientationSupported )
            [self.recorder setOrientation:AVCaptureVideoOrientationPortrait];

        [newCaptureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];

        [viewLayer insertSublayer:newCaptureVideoPreviewLayer below:[viewLayer.sublayers objectAtIndex:0]];

        self.captureVideoPreviewLayer = newCaptureVideoPreviewLayer;

        // Start the session. This is done asychronously since -startRunning doesn't return until the session is running.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self start_session];
        });

        self.viewFinderView = videoView;
    }
}

- (void) start_session
{
    if ( ! self.isRunning )
    {
        [self.session startRunning];
        self.isRunning = YES;
    }
}

- (void) stop_session
{
    if ( self.isRunning )
    {
        [self.session stopRunning];
        self.isRunning = NO;
    }
}

- (void) startRecording
{
    if ( [[UIDevice currentDevice] isMultitaskingSupported] )
    {
        // Setup background task. This is needed because the captureOutput:didFinishRecordingToOutputFileAtURL: callback is not received until AVCam returns
        // to the foreground unless you request background execution time. This also ensures that there will be time to write the file to the assets library
        // when AVCam is backgrounded. To conclude this background execution, -endBackgroundTask is called in -recorder:recordingDidFinishToOutputFileURL:error:
        // after the recorded file has been saved.
        self.backgroundRecordingID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{}];
    }

    [self removeFile:[self.recorder outputFileURL]];
    [self.recorder startRecordingWithOrientation:self.orientation];
}

- (void) stopRecording
{
    [self.recorder stopRecording];
}

- (void) saveImageToLibrary:(UIImage*)image
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];

    ALAssetsLibraryWriteImageCompletionBlock completionBlock = ^(NSURL *assetURL, NSError *error) {
        if ( [delegate respondsToSelector:@selector(club:assetSavedToURL:error:)] )
            CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate club:self assetSavedToURL:assetURL error:error]; });
    };

    [library writeImageToSavedPhotosAlbum:image.CGImage
                  orientation:(ALAssetOrientation)image.imageOrientation
                completionBlock:completionBlock];
}

- (void) captureStillImage
{
    return [self captureStillImageAnimated:NO];
}
- (void) captureStillImageAnimated:(BOOL)animated
{
    AVCaptureConnection *stillImageConnection = [AVCamUtilities connectionWithMediaType:AVMediaTypeVideo fromConnections:self.stillImageOutput.connections];
    if ( ! stillImageConnection )
        return;

    if ( [stillImageConnection isVideoOrientationSupported] )
        [stillImageConnection setVideoOrientation:self.orientation];

    if ( animated )
    {
        // Flash the screen white and fade it out to give UI feedback that a still image was taken
        UIView *flashView = [[UIView alloc] initWithFrame:self.viewFinderView.window.bounds];
        [flashView setBackgroundColor:[UIColor whiteColor]];
        [self.viewFinderView.window addSubview:flashView];

        [UIView animateWithDuration:.4f
                         animations:^{
                             [flashView setAlpha:0.f];
                         }
                         completion:^(BOOL finished){
                             [flashView removeFromSuperview];
                         }
         ];
    }

    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection
                                                         completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {

                                                             void (^completionBlock)(UIImage*,NSError*) = ^(UIImage *image, NSError *error) {
                                                                 if ( error )
                                                                 {
                                                                     if ( [delegate respondsToSelector:@selector(club:stillImageCaptured:error:)] )
                                                                         CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate club:self stillImageCaptured:nil error:error]; });
                                                                 }
                                                                 else if ( [delegate respondsToSelector:@selector(club:stillImageCaptured:error:)] )
                                                                     CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate club:self stillImageCaptured:image error:nil]; });
                                                             };

                                                             if ( imageDataSampleBuffer )
                                                             {
                                                                 NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];

                                                                 UIImage *image = [[UIImage alloc] initWithData:imageData];
                                                                 completionBlock(image, nil);
                                                             }
                                                             else
                                                                 completionBlock(nil, error);
                                                         }];
}

// Toggle between the front and back camera, if both are present.
- (BOOL) toggleCamera
{
    return [self toggleCameraAnimated:NO];
}
- (BOOL) toggleCameraAnimated:(BOOL)animated;
{
    BOOL success = NO;

    if ( self.cameraCount > 1 )
    {
        NSError *error;
        AVCaptureDeviceInput *newVideoInput;
        AVCaptureDevicePosition position = [[self.videoInput device] position];

        if ( position == AVCaptureDevicePositionBack )
        {
            newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.frontFacingCamera error:&error];
        }
        else if ( position == AVCaptureDevicePositionFront )
        {
            newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.backFacingCamera error:&error];
        }
        else
            goto bail;

        if ( newVideoInput && [self.session canAddInput:newVideoInput] )
        {
            [self.session beginConfiguration];
            [self.session removeInput:self.videoInput];
            [self.session addInput:newVideoInput];
            self.videoInput = newVideoInput;
            [self.session commitConfiguration];
            success = YES;
        }
        else if ( error )
        {
            if ( [delegate respondsToSelector:@selector(club:didFailWithError:)] )
                CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate club:self didFailWithError:error]; });
        }
    }

bail:
    return success;
}


#pragma mark Device Counts
- (NSUInteger) cameraCount
{
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
}

- (NSUInteger) micCount
{
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] count];
}

- (BOOL) hasCamera
{
    return self.cameraCount > 0;
}
- (BOOL) hasMultipleCameras
{
    return self.cameraCount > 1;
}
- (BOOL) hasAudio
{
    return self.micCount > 0;
}
- (BOOL) hasVideo
{
    return self.hasCamera && self.hasAudio;
}


#pragma mark Camera Properties
// Perform an auto focus at the specified point. The focus mode will automatically change to locked once the auto focus is complete.
- (void) autoFocusAtPoint:(CGPoint)point
{
    AVCaptureDevice *device = self.videoInput.device;
    if ( device.isFocusPointOfInterestSupported && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus] ) {
        NSError *error;
        if ( [device lockForConfiguration:&error] )
        {
            [device setFocusPointOfInterest:point];
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
            [device unlockForConfiguration];
        }
        else
        {
            if ([delegate respondsToSelector:@selector(club:didFailWithError:)])
                CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate club:self didFailWithError:error]; });
        }
    }
}

// Switch to continuous auto focus mode at the specified point
- (void) continuousFocusAtPoint:(CGPoint)point
{
    AVCaptureDevice *device = self.videoInput.device;

    if ( device.isFocusPointOfInterestSupported && [device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] )
    {
        NSError *error;
        if ( [device lockForConfiguration:&error] )
        {
            [device setFocusPointOfInterest:point];
            [device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            [device unlockForConfiguration];
        }
        else
        {
            if ( [delegate respondsToSelector:@selector(club:didFailWithError:)] )
                CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate club:self didFailWithError:error]; });
        }
    }
}

// Convert from view coordinates to camera coordinates, where {0,0} represents the top left of the picture area, and {1,1} represents
// the bottom right in landscape mode with the home button on the right.
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates
{
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = self.viewFinderView.frame.size;

    if ( self.recorder.isMirrored )
        viewCoordinates.x = frameSize.width - viewCoordinates.x;

    if ( [[self.captureVideoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize] )
    {
        // Scale, switch x and y, and reverse x
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    }
    else
    {
        CGRect cleanAperture;
        for (AVCaptureInputPort *port in self.videoInput.ports)
        {
            if ( port.mediaType == AVMediaTypeVideo )
            {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture(port.formatDescription, YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;

                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;

                if ( [[self.captureVideoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspect] )
                {
                    if (viewRatio > apertureRatio)
                    {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        // If point is inside letterboxed area, do coordinate conversion; otherwise, don't change the default value returned (.5,.5)
                        if (point.x >= blackBar && point.x <= blackBar + x2) {
                            // Scale (accounting for the letterboxing on the left and right of the video preview), switch x and y, and reverse x
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    }
                    else
                    {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        // If point is inside letterboxed area, do coordinate conversion. Otherwise, don't change the default value returned (.5,.5)
                        if (point.y >= blackBar && point.y <= blackBar + y2) {
                            // Scale (accounting for the letterboxing on the top and bottom of the video preview), switch x and y, and reverse x
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                }
                else if ( [[self.captureVideoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspectFill] )
                {
                    // Scale, switch x and y, and reverse x
                    if ( viewRatio > apertureRatio )
                    {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2; // Account for cropped height
                        yc = (frameSize.width - point.x) / frameSize.width;
                    }
                    else
                    {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2); // Account for cropped width
                        xc = point.y / frameSize.height;
                    }
                }

                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }

    return pointOfInterest;
}

@end


#pragma mark -
@implementation AVClub (InternalUtilityMethods)

// Keep track of current device orientation so it can be applied to movie recordings and still image captures
- (void)deviceOrientationDidChange
{
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];

    if ( deviceOrientation == UIDeviceOrientationPortrait )
        self.orientation = AVCaptureVideoOrientationPortrait;
    else if ( deviceOrientation == UIDeviceOrientationPortraitUpsideDown )
        self.orientation = AVCaptureVideoOrientationPortraitUpsideDown;

    // AVCapture and UIDevice have opposite meanings for landscape left and right (AVCapture orientation is the same as UIInterfaceOrientation)
    else if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
        self.orientation = AVCaptureVideoOrientationLandscapeRight;
    else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
        self.orientation = AVCaptureVideoOrientationLandscapeLeft;

    // Ignore device orientations for which there is no corresponding still image orientation (e.g. UIDeviceOrientationFaceUp)
}

// Find a camera with the specificed AVCaptureDevicePosition, returning nil if one is not found
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ( device.position == position )
            return device;
    }
    return nil;
}

// Find a front facing camera, returning nil if one is not found
- (AVCaptureDevice *) frontFacingCamera
{
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

// Find a back facing camera, returning nil if one is not found
- (AVCaptureDevice *) backFacingCamera
{
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

// Find and return an audio device, returning nil if one is not found
- (AVCaptureDevice *) audioDevice
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ( devices.count > 0 )
        return [devices objectAtIndex:0];
    return nil;
}

- (NSURL *) tempFileURL
{
    return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"output.mov"]];
}

- (void) removeFile:(NSURL *)fileURL
{
    NSString *filePath = fileURL.path;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ( [fileManager fileExistsAtPath:filePath] )
    {
        NSError *error;
        if ( [fileManager removeItemAtPath:filePath error:&error] == NO )
        {
            if ( [delegate respondsToSelector:@selector(club:didFailWithError:)] )
                CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate club:self didFailWithError:error]; });
        }
    }
}

- (void) copyFileToDocuments:(NSURL *)fileURL
{
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
    NSString *destinationPath = [documentsDirectory stringByAppendingFormat:@"/output_%@.mov", [dateFormatter stringFromDate:[NSDate date]]];
    NSError    *error;
    if ( ! [[NSFileManager defaultManager] copyItemAtURL:fileURL toURL:[NSURL fileURLWithPath:destinationPath] error:&error] )
    {
        if ( [delegate respondsToSelector:@selector(club:didFailWithError:)] )
            CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate club:self didFailWithError:error]; });
    }
}

@end


#pragma mark -
@implementation AVClub (RecorderDelegate)

-(void)recorderRecordingDidBegin:(AVCamRecorder *)recorder
{
    if ( [delegate respondsToSelector:@selector(clubRecordingBegan:)] )
        CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate clubRecordingBegan:self]; });
}

-(void)recorder:(AVCamRecorder *)recorder recordingDidFinishToOutputFileURL:(NSURL *)outputFileURL error:(NSError *)error
{
    if ( self.recorder.recordsAudio && ! self.recorder.recordsVideo )
    {
        // If the file was created on a device that doesn't support video recording, it can't be saved to the assets
        // library. Instead, save it in the app's Documents directory, whence it can be copied from the device via
        // iTunes file sharing.
        [self copyFileToDocuments:outputFileURL];

        if ( [[UIDevice currentDevice] isMultitaskingSupported] )
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundRecordingID];

        if ( [delegate respondsToSelector:@selector(clubRecordingFinished:)] )
            CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate clubRecordingFinished:self]; });
    }
    else
    {
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library writeVideoAtPathToSavedPhotosAlbum:outputFileURL
                                    completionBlock:^(NSURL *assetURL, NSError *error) {
                                        if ( error )
                                        {
                                            if ([delegate respondsToSelector:@selector(club:didFailWithError:)])
                                                CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate club:self didFailWithError:error]; });
                                        }

                                        if ( [[UIDevice currentDevice] isMultitaskingSupported] )
                                            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundRecordingID];

                                        if ( [delegate respondsToSelector:@selector(clubRecordingFinished:)] )
                                            CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ [delegate clubRecordingFinished:self]; });
                                    }];
    }
}

@end
