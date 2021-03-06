#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>

#import "CameraPreview.h"

@implementation CameraPreview

-(void) pluginInitialize{
    // start as transparent
    self.webView.opaque = NO;
    self.webView.backgroundColor = [UIColor clearColor];
    @try {
        [FIRApp configure];
    } @catch(NSException* exception) {
        self.visionErr = [self getExceptionAsString: exception];
    }
}

- (void) startCamera:(CDVInvokedUrlCommand*)command {

    CDVPluginResult *pluginResult;
    if (self.sessionManager != nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera already started!"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    NSMutableString *frv_err_mut = [NSMutableString string ];
    NSString *frv_err;
    if(self.visionErr != nil) {
        [frv_err_mut appendString:@"Error initializing fir\n" ];
        [frv_err_mut appendString:[self.visionErr mutableCopy] ];
        [frv_err_mut appendString:@"\n"];
        frv_err = frv_err_mut;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:frv_err];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    @try {
        self.mlVision = [FIRVision vision];
        self.textRecognizer = [_mlVision onDeviceTextRecognizer];
    } @catch(NSException *exception) {
        [frv_err_mut appendString:@"Failure initializing text vision 1\n" ];
        [frv_err_mut appendString:[self getExceptionAsString: exception] ];
        [frv_err_mut appendString:@"\n"];
        frv_err = frv_err_mut;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:frv_err];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    if (command.arguments.count > 3) {
        CGFloat x = (CGFloat)[command.arguments[0] floatValue] + self.webView.frame.origin.x;
        CGFloat y = (CGFloat)[command.arguments[1] floatValue] + self.webView.frame.origin.y;
        CGFloat width = (CGFloat)[command.arguments[2] floatValue];
        CGFloat height = (CGFloat)[command.arguments[3] floatValue];
        NSString *defaultCamera = command.arguments[4];
        BOOL tapToTakePicture = (BOOL)[command.arguments[5] boolValue];
        BOOL dragEnabled = (BOOL)[command.arguments[6] boolValue];
        BOOL toBack = (BOOL)[command.arguments[7] boolValue];
        CGFloat alpha = (CGFloat)[command.arguments[8] floatValue];
        BOOL tapToFocus = (BOOL) [command.arguments[9] boolValue];
        BOOL disableExifHeaderStripping = (BOOL) [command.arguments[10] boolValue]; // ignore Android only
        BOOL storeToFile = (BOOL) [command.arguments[11] boolValue]; // ignore Android only

        // Create the session manager
        self.sessionManager = [[CameraSessionManager alloc] init];

        // render controller setup
        self.cameraRenderController = [[CameraRenderController alloc] init];
        self.cameraRenderController.dragEnabled = dragEnabled;
        self.cameraRenderController.tapToTakePicture = tapToTakePicture;
        self.cameraRenderController.tapToFocus = tapToFocus;
        self.cameraRenderController.sessionManager = self.sessionManager;
        self.cameraRenderController.view.frame = CGRectMake(x, y, width, height);
        self.cameraRenderController.delegate = self;
        self.cameraRenderController.frameB64 = @"";

        [self.viewController addChildViewController:self.cameraRenderController];

        if (toBack) {
            // display the camera below the webview

            // make transparent
            self.webView.opaque = NO;
            self.webView.backgroundColor = [UIColor clearColor];

            [self.webView.superview addSubview:self.cameraRenderController.view];
            [self.webView.superview bringSubviewToFront:self.webView];
        } else {
            self.cameraRenderController.view.alpha = alpha;
            [self.webView.superview insertSubview:self.cameraRenderController.view aboveSubview:self.webView];
        }

        // Setup session
        self.sessionManager.delegate = self.cameraRenderController;

        [self.sessionManager setupSession:defaultCamera completion:^(BOOL started) {
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
        }];

    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid number of parameters"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void) hasStreaming:(CDVInvokedUrlCommand*)command {
  CDVPluginResult *pluginResult;
  if(self.sessionManager != nil) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"YES"];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"NO"];
  }
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) stopCamera:(CDVInvokedUrlCommand*)command {

    NSLog(@"stopCamera");

    [self.cameraRenderController.view removeFromSuperview];
    [self.cameraRenderController removeFromParentViewController];
    self.cameraRenderController = nil;

    [self.commandDelegate runInBackground:^{

        CDVPluginResult *pluginResult;
        if(self.sessionManager != nil) {

            for(AVCaptureInput *input in self.sessionManager.session.inputs) {
                [self.sessionManager.session removeInput:input];
            }

            for(AVCaptureOutput *output in self.sessionManager.session.outputs) {
                [self.sessionManager.session removeOutput:output];
            }

            [self.sessionManager.session stopRunning];
            self.sessionManager = nil;
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
        }

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void) hideCamera:(CDVInvokedUrlCommand*)command {
    NSLog(@"hideCamera");
    CDVPluginResult *pluginResult;

    if (self.cameraRenderController != nil) {
        [self.cameraRenderController.view setHidden:YES];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) showCamera:(CDVInvokedUrlCommand*)command {
    NSLog(@"showCamera");
    CDVPluginResult *pluginResult;

    if (self.cameraRenderController != nil) {
        [self.cameraRenderController.view setHidden:NO];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) switchCamera:(CDVInvokedUrlCommand*)command {
    NSLog(@"switchCamera");
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        [self.sessionManager switchCamera:^(BOOL switched) {

            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];

        }];

    } else {

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void) getSupportedFocusModes:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSArray * focusModes = [self.sessionManager getFocusModes];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:focusModes];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getFocusMode:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSString * focusMode = [self.sessionManager getFocusMode];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:focusMode];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setFocusMode:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    NSString * focusMode = [command.arguments objectAtIndex:0];
    if (self.sessionManager != nil) {
        [self.sessionManager setFocusMode:focusMode];
        NSString * focusMode = [self.sessionManager getFocusMode];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:focusMode ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getSupportedFlashModes:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSArray * flashModes = [self.sessionManager getFlashModes];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:flashModes];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getFlashMode:(CDVInvokedUrlCommand*)command {

    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSInteger flashMode = [self.sessionManager getFlashMode];
        NSString * sFlashMode;
        if (flashMode == 0) {
            sFlashMode = @"off";
        } else if (flashMode == 1) {
            sFlashMode = @"on";
        } else if (flashMode == 2) {
            sFlashMode = @"auto";
        } else {
            sFlashMode = @"unsupported";
        }
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:sFlashMode ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setFlashMode:(CDVInvokedUrlCommand*)command {
    NSLog(@"Flash Mode");
    NSString *errMsg;
    CDVPluginResult *pluginResult;

    NSString *flashMode = [command.arguments objectAtIndex:0];

    if (self.sessionManager != nil) {
        if ([flashMode isEqual: @"off"]) {
            [self.sessionManager setFlashMode:AVCaptureFlashModeOff];
        } else if ([flashMode isEqual: @"on"]) {
            [self.sessionManager setFlashMode:AVCaptureFlashModeOn];
        } else if ([flashMode isEqual: @"auto"]) {
            [self.sessionManager setFlashMode:AVCaptureFlashModeAuto];
        } else if ([flashMode isEqual: @"torch"]) {
            [self.sessionManager setTorchMode];
        } else {
            errMsg = @"Flash Mode not supported";
        }
    } else {
        errMsg = @"Session not started";
    }

    if (errMsg) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setZoom:(CDVInvokedUrlCommand*)command {
    NSLog(@"Zoom");
    CDVPluginResult *pluginResult;

    CGFloat desiredZoomFactor = [[command.arguments objectAtIndex:0] floatValue];

    if (self.sessionManager != nil) {
        [self.sessionManager setZoom:desiredZoomFactor];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getZoom:(CDVInvokedUrlCommand*)command {

    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        CGFloat zoom = [self.sessionManager getZoom];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:zoom ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getHorizontalFOV:(CDVInvokedUrlCommand*)command {

    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        float fov = [self.sessionManager getHorizontalFOV];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:fov ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getMaxZoom:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        CGFloat maxZoom = [self.sessionManager getMaxZoom];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:maxZoom ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getExposureModes:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSArray * exposureModes = [self.sessionManager getExposureModes];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:exposureModes];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getExposureMode:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSString * exposureMode = [self.sessionManager getExposureMode];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:exposureMode ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setExposureMode:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    NSString * exposureMode = [command.arguments objectAtIndex:0];
    if (self.sessionManager != nil) {
        [self.sessionManager setExposureMode:exposureMode];
        NSString * exposureMode = [self.sessionManager getExposureMode];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:exposureMode ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getSupportedWhiteBalanceModes:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSArray * whiteBalanceModes = [self.sessionManager getSupportedWhiteBalanceModes];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:whiteBalanceModes ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getWhiteBalanceMode:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSString * whiteBalanceMode = [self.sessionManager getWhiteBalanceMode];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:whiteBalanceMode ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSString *)getExceptionAsString:(NSException*)ex {
    NSString *ret;
    NSMutableString *x = [NSMutableString string];
    NSString* rs = [ex reason];

    [x appendString:[rs mutableCopy]];
    [x appendString:@"\n"];

    for(NSString* s in [ex callStackSymbols]) {
        [x appendString:[s mutableCopy]];
        [x appendString:@"\n"];
    }
    ret = x;
    return ret;
}

- (void) getCIImageText:(CIImage*)img completion:(void(^)( NSString* rectxt)) success fail:(void(^)(NSString* s)) err{
  if(img == nil) {
    return;
  }
  @try {
    
  CGImageRef finalImage = [self.cameraRenderController.ciContext createCGImage:img fromRect:img.extent];
  UIImage *resultImage = [UIImage imageWithCGImage:finalImage];
  UIImage *processImage = [self resizeImage: resultImage];

  //ML KIT CODE
  FIRVisionImage *firImage = [[FIRVisionImage alloc] initWithImage:processImage];
  CGImageRelease(finalImage); // release CGImageRef to remove memory leaks
  
  // Iterate over each text block.
  
  [self.textRecognizer processImage:firImage
                      completion:^(FIRVisionText *_Nullable result,
                                   NSError *_Nullable error) {
    @try {
      NSString *__block ept = @"";
      int __block count = 0;
      NSMutableString *__block lines = [NSMutableString string];
      NSString *__block ret;

      FIRVisionTextBlock *__block firblock;
      FIRVisionTextLine *__block line;

      if (error != nil) {
        // ...
        NSLog(@"error while get ciimagetext: %@", error);
        success(ept);
        return;        
      }
      if(result == nil) {
        success(ept);
        return;
      }
        for (firblock in result.blocks) {
          for (line in firblock.lines) {
            count++;
            [lines appendString:[line.text mutableCopy]];
            [lines appendString:@"\n"];
          }
        }
        if(count == 0) {
             success(ept);
             return;
        }
        ret = lines;
        success(ret);

      // Recognized text
    }//end block try
    @catch (NSException* exception) { //block catch
        err([self getExceptionAsString: exception]);
        //err(@"Excecao ao reconhecer texto");
    }//end block catch
    }];
  }//end function try
    @catch (NSException* exception) {//Whole function catch
        err([self getExceptionAsString: exception]);
        //err(@"Excecao ao disparar reconhecimento de texto");
    }//end function catch
}

-(UIImage *)resizeImage:(UIImage *)image
{
    float actualHeight = image.size.height;
    float actualWidth = image.size.width;
    float maxHeight = 600;
    float maxWidth = 600;
    float imgRatio = actualWidth/actualHeight;
    float maxRatio = maxWidth/maxHeight;
    float compressionQuality = 0.50;//50 percent compression

    if (actualHeight > maxHeight || actualWidth > maxWidth)
    {
        if(imgRatio < maxRatio)
        {
            //adjust width according to maxHeight
            imgRatio = maxHeight / actualHeight;
            actualWidth = imgRatio * actualWidth;
            actualHeight = maxHeight;
        }
        else if(imgRatio > maxRatio)
        {
            //adjust height according to maxWidth
            imgRatio = maxWidth / actualWidth;
            actualHeight = imgRatio * actualHeight;
            actualWidth = maxWidth;
        }
        else
        {
            actualHeight = maxHeight;
            actualWidth = maxWidth;
        }
    }

    CGRect rect = CGRectMake(0.0, 0.0, actualWidth, actualHeight);
    UIGraphicsBeginImageContext(rect.size);
    [image drawInRect:rect];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    NSData *imageData = UIImageJPEGRepresentation(img, compressionQuality);
    UIGraphicsEndImageContext();
    return [UIImage imageWithData:imageData];

}

- (void) getCurrentBaseFrame:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *__block pluginResult;
    NSString *__block info;
    //NSString* calculateb64;
    NSString *__block baseString;
    NSString *__block txt;
    NSMutableArray *__block params = [[NSMutableArray alloc] init];
    @try { //begin func try 
    if (self.cameraRenderController != nil) {
        /*if(self.cameraRenderController.frameB64 == nil) {
            info = @"nilframe";
            //Fallback to latestFrame
            baseString = [self getBase64FromCIImage:self.cameraRenderController.latestFrame];
        } else if([self.cameraRenderController.frameB64 isEqual: @""]) {
            info = @"nostring";
            //Fallback to latestFrame
            baseString = [self getBase64FromCIImage:self.cameraRenderController.latestFrame];
        } else {//frameB64 OK
            info = @"OK";
            baseString = self.cameraRenderController.frameB64;
        }*/
        info = @"";
        baseString = @"";
        if(self.cameraRenderController.latestFrame == nil){
          txt = @"";
          [params addObject:baseString];
          [params addObject:info];
          [params addObject:txt];
          pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:params];
          [pluginResult setKeepCallbackAsBool:true];
          [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } else {
          [self getCIImageText: self.cameraRenderController.latestFrame completion: ^(NSString* rectxt) {
            @try { //begin block try
                [params addObject:baseString];
                [params addObject:info];
                [params addObject:rectxt];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:params];
                [pluginResult setKeepCallbackAsBool:true];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }//end block try
            @catch(NSException* exception) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[self getExceptionAsString: exception]];
                //pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Excecao ao adicionar string reconhecida"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }//end block catch
            } fail: ^(NSString* s) {
                //pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:s];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Excecao ao tentar reconhecimento de texto"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
          ];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    }//end func try
    @catch(NSException* exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[self getExceptionAsString: exception]];
        //pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Excecao ao incializar reconhecimento do frame"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }//end func catch
}

- (void) setWhiteBalanceMode:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    NSString * whiteBalanceMode = [command.arguments objectAtIndex:0];
    if (self.sessionManager != nil) {
        [self.sessionManager setWhiteBalanceMode:whiteBalanceMode];
        NSString * wbMode = [self.sessionManager getWhiteBalanceMode];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:wbMode ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getExposureCompensationRange:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSArray * exposureRange = [self.sessionManager getExposureCompensationRange];
        NSMutableDictionary *dimensions = [[NSMutableDictionary alloc] init];
        [dimensions setValue:exposureRange[0] forKey:@"min"];
        [dimensions setValue:exposureRange[1] forKey:@"max"];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dimensions];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getExposureCompensation:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        CGFloat exposureCompensation = [self.sessionManager getExposureCompensation];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:exposureCompensation ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setExposureCompensation:(CDVInvokedUrlCommand*)command {
    NSLog(@"Zoom");
    CDVPluginResult *pluginResult;

    CGFloat exposureCompensation = [[command.arguments objectAtIndex:0] floatValue];

    if (self.sessionManager != nil) {
        [self.sessionManager setExposureCompensation:exposureCompensation];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:exposureCompensation];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) takePicture:(CDVInvokedUrlCommand*)command {
    NSLog(@"takePicture");
    CDVPluginResult *pluginResult;

    if (self.cameraRenderController != NULL) {
        self.onPictureTakenHandlerId = command.callbackId;

        CGFloat width = (CGFloat)[command.arguments[0] floatValue];
        CGFloat height = (CGFloat)[command.arguments[1] floatValue];
        CGFloat quality = (CGFloat)[command.arguments[2] floatValue] / 100.0f;

        [self invokeTakePicture:width withHeight:height withQuality:quality];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) setColorEffect:(CDVInvokedUrlCommand*)command {
    NSLog(@"setColorEffect");
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    NSString *filterName = command.arguments[0];

    if(self.sessionManager != nil){
        if ([filterName isEqual: @"none"]) {
            dispatch_async(self.sessionManager.sessionQueue, ^{
                [self.sessionManager setCiFilter:nil];
            });
        } else if ([filterName isEqual: @"mono"]) {
            dispatch_async(self.sessionManager.sessionQueue, ^{
                CIFilter *filter = [CIFilter filterWithName:@"CIColorMonochrome"];
                [filter setDefaults];
                [self.sessionManager setCiFilter:filter];
            });
        } else if ([filterName isEqual: @"negative"]) {
            dispatch_async(self.sessionManager.sessionQueue, ^{
                CIFilter *filter = [CIFilter filterWithName:@"CIColorInvert"];
                [filter setDefaults];
                [self.sessionManager setCiFilter:filter];
            });
        } else if ([filterName isEqual: @"posterize"]) {
            dispatch_async(self.sessionManager.sessionQueue, ^{
                CIFilter *filter = [CIFilter filterWithName:@"CIColorPosterize"];
                [filter setDefaults];
                [self.sessionManager setCiFilter:filter];
            });
        } else if ([filterName isEqual: @"sepia"]) {
            dispatch_async(self.sessionManager.sessionQueue, ^{
                CIFilter *filter = [CIFilter filterWithName:@"CISepiaTone"];
                [filter setDefaults];
                [self.sessionManager setCiFilter:filter];
            });
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Filter not found"];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setPreviewSize: (CDVInvokedUrlCommand*)command {

    CDVPluginResult *pluginResult;

    if (self.sessionManager == nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    if (command.arguments.count > 1) {
        CGFloat width = (CGFloat)[command.arguments[0] floatValue];
        CGFloat height = (CGFloat)[command.arguments[1] floatValue];

        self.cameraRenderController.view.frame = CGRectMake(0, 0, width, height);

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid number of parameters"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getSupportedPictureSizes:(CDVInvokedUrlCommand*)command {
    NSLog(@"getSupportedPictureSizes");
    CDVPluginResult *pluginResult;

    if(self.sessionManager != nil){
        NSArray *formats = self.sessionManager.getDeviceFormats;
        NSMutableArray *jsonFormats = [NSMutableArray new];
        int lastWidth = 0;
        int lastHeight = 0;
        for (AVCaptureDeviceFormat *format in formats) {
            CMVideoDimensions dim = format.highResolutionStillImageDimensions;
            if (dim.width!=lastWidth && dim.height != lastHeight) {
                NSMutableDictionary *dimensions = [[NSMutableDictionary alloc] init];
                NSNumber *width = [NSNumber numberWithInt:dim.width];
                NSNumber *height = [NSNumber numberWithInt:dim.height];
                [dimensions setValue:width forKey:@"width"];
                [dimensions setValue:height forKey:@"height"];
                [jsonFormats addObject:dimensions];
                lastWidth = dim.width;
                lastHeight = dim.height;
            }
        }
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:jsonFormats];

    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSString *)getBase64Image:(CGImageRef)imageRef withQuality:(CGFloat) quality {
    NSString *base64Image = nil;

    @try {
        UIImage *image = [UIImage imageWithCGImage:imageRef];
        NSData *imageData = UIImageJPEGRepresentation(image, quality);
        base64Image = [imageData base64EncodedStringWithOptions:0];
    }
    @catch (NSException *exception) {
        NSLog(@"error while get base64Image: %@", [exception reason]);
    }

    return base64Image;
}

- (void) tapToFocus:(CDVInvokedUrlCommand*)command {
    NSLog(@"tapToFocus");
    CDVPluginResult *pluginResult;

    CGFloat xPoint = [[command.arguments objectAtIndex:0] floatValue];
    CGFloat yPoint = [[command.arguments objectAtIndex:1] floatValue];

    if (self.sessionManager != nil) {
        [self.sessionManager tapToFocus:xPoint yPoint:yPoint];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (double)radiansFromUIImageOrientation:(UIImageOrientation)orientation {
    double radians;

    switch ([[UIApplication sharedApplication] statusBarOrientation]) {
        case UIDeviceOrientationPortrait:
            radians = M_PI_2;
            break;
        case UIDeviceOrientationLandscapeLeft:
            radians = 0.f;
            break;
        case UIDeviceOrientationLandscapeRight:
            radians = M_PI;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            radians = -M_PI_2;
            break;
    }

    return radians;
}

-(CGImageRef) CGImageRotated:(CGImageRef) originalCGImage withRadians:(double) radians {
    CGSize imageSize = CGSizeMake(CGImageGetWidth(originalCGImage), CGImageGetHeight(originalCGImage));
    CGSize rotatedSize;
    if (radians == M_PI_2 || radians == -M_PI_2) {
        rotatedSize = CGSizeMake(imageSize.height, imageSize.width);
    } else {
        rotatedSize = imageSize;
    }

    double rotatedCenterX = rotatedSize.width / 2.f;
    double rotatedCenterY = rotatedSize.height / 2.f;

    UIGraphicsBeginImageContextWithOptions(rotatedSize, NO, 1.f);
    CGContextRef rotatedContext = UIGraphicsGetCurrentContext();
    if (radians == 0.f || radians == M_PI) { // 0 or 180 degrees
        CGContextTranslateCTM(rotatedContext, rotatedCenterX, rotatedCenterY);
        if (radians == 0.0f) {
            CGContextScaleCTM(rotatedContext, 1.f, -1.f);
        } else {
            CGContextScaleCTM(rotatedContext, -1.f, 1.f);
        }
        CGContextTranslateCTM(rotatedContext, -rotatedCenterX, -rotatedCenterY);
    } else if (radians == M_PI_2 || radians == -M_PI_2) { // +/- 90 degrees
        CGContextTranslateCTM(rotatedContext, rotatedCenterX, rotatedCenterY);
        CGContextRotateCTM(rotatedContext, radians);
        CGContextScaleCTM(rotatedContext, 1.f, -1.f);
        CGContextTranslateCTM(rotatedContext, -rotatedCenterY, -rotatedCenterX);
    }

    CGRect drawingRect = CGRectMake(0.f, 0.f, imageSize.width, imageSize.height);
    CGContextDrawImage(rotatedContext, drawingRect, originalCGImage);
    CGImageRef rotatedCGImage = CGBitmapContextCreateImage(rotatedContext);

    UIGraphicsEndImageContext();

    return rotatedCGImage;
}

- (void) invokeTapToFocus:(CGPoint)point {
    [self.sessionManager tapToFocus:point.x yPoint:point.y];
}

- (void) invokeTakePicture {
    [self invokeTakePicture:0.0 withHeight:0.0 withQuality:0.85];
}

- (void) invokeTakePictureOnFocus {
    // the sessionManager will call onFocus, as soon as the camera is done with focussing.
    [self.sessionManager takePictureOnFocus];
}

- (void) invokeTakePicture:(CGFloat) width withHeight:(CGFloat) height withQuality:(CGFloat) quality{
    AVCaptureConnection *connection = [self.sessionManager.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    [self.sessionManager.stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef sampleBuffer, NSError *error) {

        NSLog(@"Done creating still image");

        if (error) {
            NSLog(@"%@", error);
        } else {
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:sampleBuffer];
            UIImage *capturedImage  = [[UIImage alloc] initWithData:imageData];

            CIImage *capturedCImage;
            //image resize

            if(width > 0 && height > 0){
                CGFloat scaleHeight = width/capturedImage.size.height;
                CGFloat scaleWidth = height/capturedImage.size.width;
                CGFloat scale = scaleHeight > scaleWidth ? scaleWidth : scaleHeight;

                CIFilter *resizeFilter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
                [resizeFilter setValue:[[CIImage alloc] initWithCGImage:[capturedImage CGImage]] forKey:kCIInputImageKey];
                [resizeFilter setValue:[NSNumber numberWithFloat:1.0f] forKey:@"inputAspectRatio"];
                [resizeFilter setValue:[NSNumber numberWithFloat:scale] forKey:@"inputScale"];
                capturedCImage = [resizeFilter outputImage];
            }else{
                capturedCImage = [[CIImage alloc] initWithCGImage:[capturedImage CGImage]];
            }

            CIImage *imageToFilter;
            CIImage *finalCImage;

            //fix front mirroring
            if (self.sessionManager.defaultCamera == AVCaptureDevicePositionFront) {
                CGAffineTransform matrix = CGAffineTransformTranslate(CGAffineTransformMakeScale(1, -1), 0, capturedCImage.extent.size.height);
                imageToFilter = [capturedCImage imageByApplyingTransform:matrix];
            } else {
                imageToFilter = capturedCImage;
            }

            CIFilter *filter = [self.sessionManager ciFilter];
            if (filter != nil) {
                [self.sessionManager.filterLock lock];
                [filter setValue:imageToFilter forKey:kCIInputImageKey];
                finalCImage = [filter outputImage];
                [self.sessionManager.filterLock unlock];
            } else {
                finalCImage = imageToFilter;
            }

            NSMutableArray *params = [[NSMutableArray alloc] init];

            CGImageRef finalImage = [self.cameraRenderController.ciContext createCGImage:finalCImage fromRect:finalCImage.extent];
            UIImage *resultImage = [UIImage imageWithCGImage:finalImage];

            double radians = [self radiansFromUIImageOrientation:resultImage.imageOrientation];
            CGImageRef resultFinalImage = [self CGImageRotated:finalImage withRadians:radians];

            CGImageRelease(finalImage); // release CGImageRef to remove memory leaks

            NSString *base64Image = [self getBase64Image:resultFinalImage withQuality:quality];

            CGImageRelease(resultFinalImage); // release CGImageRef to remove memory leaks

            [params addObject:base64Image];

            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:params];
            [pluginResult setKeepCallbackAsBool:true];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onPictureTakenHandlerId];
        }
    }];
}

- (NSString *)getBase64FromCIImage:(CIImage*)imageRef {
    CGImageRef finalImage = [self.cameraRenderController.ciContext createCGImage:imageRef fromRect:imageRef.extent];
    /*UIImage *resultImage = [UIImage imageWithCGImage:finalImage];

    double radians = [self radiansFromUIImageOrientation:resultImage.imageOrientation];
    CGImageRef resultFinalImage = [self CGImageRotated:finalImage withRadians:radians];*/

    //CGImageRelease(finalImage); // release CGImageRef to remove memory leaks

    NSString *base64Image = [self getBase64Image:finalImage withQuality:0.3];

    CGImageRelease(finalImage); // release CGImageRef to remove memory leaks
    return base64Image;
}
@end
