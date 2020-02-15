/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RNCImageEditor.h"

#import <UIKit/UIKit.h>

#import <React/RCTConvert.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>

#import <React/RCTImageLoader.h>
#import <React/RCTImageStoreManager.h>
#if __has_include(<RCTImage/RCTImageUtils.h>)
#import <RCTImage/RCTImageUtils.h>
#else
#import "RCTImageUtils.h"
#endif

@implementation RNCImageEditor

RCT_EXPORT_MODULE()

@synthesize bridge = _bridge;

/**
 * Crops an image and adds the result to the image store.
 *
 * @param imageRequest An image URL
 * @param cropData Dictionary with `offset`, `size` and `displaySize`.
 *        `offset` and `size` are relative to the full-resolution image size.
 *        `displaySize` is an optimization - if specified, the image will
 *        be scaled down to `displaySize` rather than `size`.
 *        All units are in px (not points).
 */
RCT_EXPORT_METHOD(cropImage:(NSURLRequest *)imageRequest
                  cropData:(NSDictionary *)cropData
                  successCallback:(RCTResponseSenderBlock)successCallback
                  errorCallback:(RCTResponseErrorBlock)errorCallback)
{
  CGRect rect = {
    [RCTConvert CGPoint:cropData[@"offset"]],
    [RCTConvert CGSize:cropData[@"size"]]
  };

  NSURL *url = [imageRequest URL];
  NSString *urlPath = [url path];
  NSString *extension = [urlPath pathExtension];

  [_bridge.imageLoader loadImageWithURLRequest:imageRequest callback:^(NSError *error, UIImage *image) {
    if (error) {
      errorCallback(error);
      return;
    }

    // Crop image
    CGSize targetSize = rect.size;
    CGRect targetRect = {{-rect.origin.x, -rect.origin.y}, image.size};
    CGAffineTransform transform = RCTTransformFromTargetRect(image.size, targetRect);
    UIImage *croppedImage = RCTTransformImage(image, targetSize, image.scale, transform);

    // Scale image
    if (cropData[@"displaySize"]) {
      targetSize = [RCTConvert CGSize:cropData[@"displaySize"]]; // in pixels
      RCTResizeMode resizeMode = [RCTConvert RCTResizeMode:cropData[@"resizeMode"] ?: @"contain"];
      targetRect = RCTTargetRect(croppedImage.size, targetSize, 1, resizeMode);
      transform = RCTTransformFromTargetRect(croppedImage.size, targetRect);
      croppedImage = RCTTransformImage(croppedImage, targetSize, image.scale, transform);
    }

    // Store image
    NSData *imageData = NULL;
    if([extension isEqualToString:@"png"]){
      imageData = UIImagePNGRepresentation(croppedImage);
    }
    else{
      imageData = UIImageJPEGRepresentation(croppedImage, 1);
    }
    [self->_bridge.imageStoreManager storeImage:croppedImage withBlock:^(NSString *croppedImageTag) {
      if (!croppedImageTag) {
        NSString *errorMessage = @"Error storing cropped image in RCTImageStoreManager";
        RCTLogWarn(@"%@", errorMessage);
        errorCallback(RCTErrorWithMessage(errorMessage));
        return;
      }
      NSString *encodedString = [imageData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
      NSDictionary *dict = @{@"uri" : croppedImageTag, @"base64" : encodedString};
      NSError * err;
      NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&err];
      if (!jsonData) {
          NSString *errorMessage = @"Error storing cropped image in RCTImageStoreManager";
          errorCallback(RCTErrorWithMessage(errorMessage));
      } else {
          NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
          successCallback(@[jsonString]);
      }
    }];
  }];
}

@end
