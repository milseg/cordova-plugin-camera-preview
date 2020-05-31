#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>
#import <Firebase/Firebase.h>

#import "CameraSessionManager.h"
#import "CameraRenderController.h"

@interface CameraPreview : CDVPlugin <TakePictureDelegate, FocusDelegate, Base64Helper>

- (void) startCamera:(CDVInvokedUrlCommand*)command;
- (void) stopCamera:(CDVInvokedUrlCommand*)command;
- (void) showCamera:(CDVInvokedUrlCommand*)command;
- (void) hideCamera:(CDVInvokedUrlCommand*)command;
- (void) getFocusMode:(CDVInvokedUrlCommand*)command;
- (void) setFocusMode:(CDVInvokedUrlCommand*)command;
- (void) getFlashMode:(CDVInvokedUrlCommand*)command;
- (void) setFlashMode:(CDVInvokedUrlCommand*)command;
- (void) setZoom:(CDVInvokedUrlCommand*)command;
- (void) getZoom:(CDVInvokedUrlCommand*)command;
- (void) getHorizontalFOV:(CDVInvokedUrlCommand*)command;
- (void) getMaxZoom:(CDVInvokedUrlCommand*)command;
- (void) getExposureModes:(CDVInvokedUrlCommand*)command;
- (void) getExposureMode:(CDVInvokedUrlCommand*)command;
- (void) setExposureMode:(CDVInvokedUrlCommand*)command;
- (void) getExposureCompensation:(CDVInvokedUrlCommand*)command;
- (void) setExposureCompensation:(CDVInvokedUrlCommand*)command;
- (void) getExposureCompensationRange:(CDVInvokedUrlCommand*)command;
- (void) setPreviewSize: (CDVInvokedUrlCommand*)command;
- (void) switchCamera:(CDVInvokedUrlCommand*)command;
- (void) takePicture:(CDVInvokedUrlCommand*)command;
- (void) setColorEffect:(CDVInvokedUrlCommand*)command;
- (void) getSupportedPictureSizes:(CDVInvokedUrlCommand*)command;
- (void) getSupportedFlashModes:(CDVInvokedUrlCommand*)command;
- (void) getSupportedFocusModes:(CDVInvokedUrlCommand*)command;
- (void) tapToFocus:(CDVInvokedUrlCommand*)command;
- (void) getSupportedWhiteBalanceModes:(CDVInvokedUrlCommand*)command;
- (void) getWhiteBalanceMode:(CDVInvokedUrlCommand*)command;
- (void) setWhiteBalanceMode:(CDVInvokedUrlCommand*)command;
- (void) getCurrentBaseFrame:(CDVInvokedUrlCommand*)command;
- (void) hasStreaming:(CDVInvokedUrlCommand*)command;

- (void) invokeTakePicture:(CGFloat) width withHeight:(CGFloat) height withQuality:(CGFloat) quality;
- (void) invokeTakePicture;

- (void) invokeTapToFocus:(CGPoint) point;
- (NSString *)getBase64Image:(CGImageRef)imageRef withQuality:(CGFloat) quality;
- (NSString *)getBase64FromCIImage:(CIImage*)imageRef;
- (void) getCIImageText:(CIImage*)img completion:(void(^)(NSString* rectxt)) endtxt;

@property (nonatomic) CameraSessionManager *sessionManager;
@property (nonatomic) CameraRenderController *cameraRenderController;
@property (nonatomic) NSString *onPictureTakenHandlerId;
@property FIRVisionTextRecognizer* textRecognizer;
@property FIRVision *mlVision;

@end
