//
//  UIButton+AFNetworking.m
//
//  Created by David Pettigrew on 6/12/12.
//  Copyright (c) 2012 ELC Technologies. All rights reserved.
//

// Based upon UIImageView+AFNetworking.m
//
// Copyright (c) 2011 Gowalla (http://gowalla.com/)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "UIButton+AFNetworking.h"
#import <objc/runtime.h>
#import "SVProgressHUD.h"
#if __IPHONE_OS_VERSION_MIN_REQUIRED

@interface AFButtonImageCache : NSCache
- (UIImage *)cachedImageForRequest:(NSURLRequest *)request;
- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request;
- (void)clearCachedRequest:(NSURLRequest *)request;
- (UIImage *)getCachedImageForURL:(NSURL *)request;
- (void)setCacheImage:(UIImage *)image;
@end

#pragma mark -

static char kAFImageRequestOperationObjectKey;

@interface UIButton (_AFNetworking)
@property (readwrite, nonatomic, retain, setter = af_setImageRequestOperation:) AFImageRequestOperation *af_imageRequestOperation;
@property (readwrite, nonatomic, retain, setter = af_setHTTPRequestOperation:) AFHTTPRequestOperation *af_httpRequestOperation;
@end

@implementation UIButton (_AFNetworking)
@dynamic af_imageRequestOperation;
@end

#pragma mark -
@implementation UIImage (Crop)
- (UIImage *)croppedWithSize:(CGSize)size
{
    return [self croppedWithSize:size alignment:ImageCropAlignmentCener];
}

- (UIImage *)croppedWithSize:(CGSize)size alignment:(ImageCropAlignment)alignment
{
    CGFloat offsetX = 0, offsetY = 0;
    switch (alignment) {
        case ImageCropAlignmentCener: {
            offsetX = [self _centerWithLength:size.width max:self.size.width];
            offsetY = [self _centerWithLength:size.height max:self.size.height];
        }
            break;
        case ImageCropAlignmentTop: {
            offsetX = [self _centerWithLength:size.width max:self.size.width];
        }
            break;
        case ImageCropAlignmentBottom: {
            offsetX = [self _centerWithLength:size.width max:self.size.width];
            offsetY = self.size.height - size.height;
        }
            break;
        case ImageCropAlignmentLeft:  {
            offsetY = [self _centerWithLength:size.height max:self.size.height];
        }
            break;
        case ImageCropAlignmentRight: {
            offsetX = self.size.width - size.width;
            offsetY = [self _centerWithLength:size.height max:self.size.height];
        }
            break;
        default:
            break;
    }
    
    return [self _croppedWithSize:size offset:CGPointMake(offsetX, offsetY)];
}

- (UIImage *)_croppedWithSize:(CGSize)size offset:(CGPoint)offset
{
    CGRect croppingRect = CGRectMake(offset.x, offset.y, size.width, size.height);
    CGImageRef imageRef = CGImageCreateWithImageInRect(self.CGImage, croppingRect);
    UIImage *resultImage =[UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return resultImage;
}

- (CGFloat)_centerWithLength:(CGFloat)length max:(CGFloat)max
{
    CGFloat value = (max-length)/2;
    if (value <0) {
        return -(value);
    }
    return (max-length)/2;
}
@end

@implementation UIButton (AFNetworking)

-(void)downloadImageUsingURL:(NSURL*)strURL placeholderImage:(UIImage *)placeholderImage forState:(UIControlState)state
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:strURL];
    [self setImageUsingURL:request placeholderImage:placeholderImage forState:state success:nil failure:nil];
}
-(void)setImageUsingURL:(NSURLRequest *)urlRequest
                placeholderImage:(UIImage *)placeholderImage
                forState:(UIControlState)state
                success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
     AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:urlRequest];
    [self setImage:nil forState:UIControlStateNormal];
    
    [self cancelImageRequestOperation];
    
    UIImage *cachedImage = [[[self class] af_sharedImageCache] cachedImageForRequest:urlRequest];
    if (cachedImage) {
        [self setImage:cachedImage forState:state];
        self.af_imageRequestOperation = nil;
        
        if (success) {
            success(nil, nil, cachedImage);
        }
    } else{
        [self setImage:placeholderImage forState:state];
        __weak UIButton *weakSelf = self;
        [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            [SVProgressHUD dismiss];
            UIButton *strongSelf = weakSelf;
            UIImage *img =[UIImage imageWithData:responseObject];
            UIImage *cropImage = [img croppedWithSize:CGSizeMake(250,250) alignment:ImageCropAlignmentCener];
            if ([[urlRequest URL] isEqual:[[self.af_imageRequestOperation request] URL]]) {
                [strongSelf setBackgroundImage:cropImage forState:state];
                strongSelf.af_imageRequestOperation = nil;
            }
            
            if (success) {
                success(operation.request, operation.response, responseObject);
            }
            
            [[[strongSelf class] af_sharedImageCache] cacheImage:cropImage forRequest:urlRequest];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            UIButton *strongSelf = weakSelf;
            if ([[urlRequest URL] isEqual:[[self.af_imageRequestOperation request] URL]]) {
                strongSelf.af_imageRequestOperation = nil;
            }
            
            if (failure) {
                failure(operation.request, operation.response, error);
            }
 
            
        }];
        
        //[operation start];
        self.af_httpRequestOperation = operation;
        
        [[[self class] af_sharedImageRequestOperationQueue] addOperation:self.af_httpRequestOperation];
    }
    
}

- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholderImage forState:(UIControlState)state
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    [request setHTTPShouldHandleCookies:NO];
    [request setHTTPShouldUsePipelining:YES];
    
    [self setImageWithURLRequest:request placeholderImage:placeholderImage forState:state success:nil failure:nil];
}
-(void)setBackgroundImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholderImage forState:(UIControlState)state
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    [request setHTTPShouldHandleCookies:NO];
    [request setHTTPShouldUsePipelining:YES];
    
    [self setBackgroundImageWithURLRequest:request placeholderImage:placeholderImage forState:state success:nil failure:nil];
}
- (void)setImageWithURL:(NSURL *)url
       placeholderImage:(UIImage *)placeholderImage
               forState:(UIControlState)state
                success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    [request setHTTPShouldHandleCookies:NO];
    [request setHTTPShouldUsePipelining:YES];
    
    [self setImageWithURLRequest:request placeholderImage:placeholderImage forState:state success:success failure:failure];
}

- (void)setImageWithURLRequest:(NSURLRequest *)urlRequest 
              placeholderImage:(UIImage *)placeholderImage 
                      forState:(UIControlState)state
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    [self setImage:nil forState:UIControlStateNormal];
    
    [self cancelImageRequestOperation];
    
    UIImage *cachedImage = [[[self class] af_sharedImageCache] cachedImageForRequest:urlRequest];
    if (cachedImage) {
        [self setImage:cachedImage forState:state];
        self.af_imageRequestOperation = nil;
        
        if (success) {
            success(nil, nil, cachedImage);
        }
    } else {
        [self setImage:placeholderImage forState:state];
        
        AFImageRequestOperation *requestOperation = [[AFImageRequestOperation alloc] initWithRequest:urlRequest];
        __weak UIButton *weakSelf = self;
        [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            UIButton *strongSelf = weakSelf;
            if ([[urlRequest URL] isEqual:[[self.af_imageRequestOperation request] URL]]) {
                UIImage *img = responseObject;
                [strongSelf setImage:responseObject forState:state];
                strongSelf.af_imageRequestOperation = nil;
            }
            
            if (success) {
                success(operation.request, operation.response, responseObject);
            }
            
            [[[strongSelf class] af_sharedImageCache] cacheImage:responseObject forRequest:urlRequest];
            
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            UIButton *strongSelf = weakSelf;
            if ([[urlRequest URL] isEqual:[[self.af_imageRequestOperation request] URL]]) {
                strongSelf.af_imageRequestOperation = nil;
            }
            
            if (failure) {
                failure(operation.request, operation.response, error);
            }            
        }];
        
        self.af_imageRequestOperation = requestOperation;
        
        [[[self class] af_sharedImageRequestOperationQueue] addOperation:self.af_imageRequestOperation];
    }
}

- (void)setBackgroundImageWithURLRequest:(NSURLRequest *)urlRequest
              placeholderImage:(UIImage *)placeholderImage
                      forState:(UIControlState)state
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    [self cancelImageRequestOperation];
    
    UIImage *cachedImage = [[[self class] af_sharedImageCache] cachedImageForRequest:urlRequest];
    if (cachedImage) {
        [self setBackgroundImage:cachedImage forState:state];
        self.af_imageRequestOperation = nil;
        
        if (success) {
            success(nil, nil, cachedImage);
        }
    } else {
        [self setBackgroundImage:placeholderImage forState:state];
        
        AFImageRequestOperation *requestOperation = [[AFImageRequestOperation alloc] initWithRequest:urlRequest];
        __weak UIButton *weakSelf = self;
        [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            UIButton *strongSelf = weakSelf;
            if ([[urlRequest URL] isEqual:[[self.af_imageRequestOperation request] URL]]) {
                [strongSelf setBackgroundImage:responseObject forState:state];
                strongSelf.af_imageRequestOperation = nil;
            }
            
            if (success) {
                success(operation.request, operation.response, responseObject);
            }
            
            [[[strongSelf class] af_sharedImageCache] cacheImage:responseObject forRequest:urlRequest];
            
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            UIButton *strongSelf = weakSelf;
            if ([[urlRequest URL] isEqual:[[self.af_imageRequestOperation request] URL]]) {
                strongSelf.af_imageRequestOperation = nil;
            }
            
            if (failure) {
                failure(operation.request, operation.response, error);
            }
        }];
        
        self.af_imageRequestOperation = requestOperation;
        
        [[[self class] af_sharedImageRequestOperationQueue] addOperation:self.af_imageRequestOperation];
    }
}

- (AFHTTPRequestOperation *)af_imageRequestOperation {
    return (AFHTTPRequestOperation *)objc_getAssociatedObject(self, &kAFImageRequestOperationObjectKey);
}
- (AFHTTPRequestOperation *)af_httpRequestOperation {
    return (AFHTTPRequestOperation *)objc_getAssociatedObject(self, &kAFImageRequestOperationObjectKey);
}
- (void)af_setImageRequestOperation:(AFImageRequestOperation *)imageRequestOperation {
    objc_setAssociatedObject(self, &kAFImageRequestOperationObjectKey, imageRequestOperation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)af_setHTTPRequestOperation:(AFHTTPRequestOperation *)imageRequestOperation {
    objc_setAssociatedObject(self, &kAFImageRequestOperationObjectKey, imageRequestOperation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
+ (NSOperationQueue *)af_sharedImageRequestOperationQueue {
    static NSOperationQueue *_af_imageRequestOperationQueue = nil;
    
    if (!_af_imageRequestOperationQueue) {
        _af_imageRequestOperationQueue = [[NSOperationQueue alloc] init];
        [_af_imageRequestOperationQueue setMaxConcurrentOperationCount:8];
    }
    
    return _af_imageRequestOperationQueue;
}

+ (AFButtonImageCache *)af_sharedImageCache {
    static AFButtonImageCache *_af_imageCache = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _af_imageCache = [[AFButtonImageCache alloc] init];
    });
    
    return _af_imageCache;
}
- (void)clearImageCacheForURL:(NSURL *)url {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    
    UIImage *cachedImage = [[[self class] af_sharedImageCache] cachedImageForRequest:request];
    if (cachedImage) {
        [[[self class] af_sharedImageCache] clearCachedRequest:request];
    }
}

#pragma mark -

- (void)cancelImageRequestOperation {
    [self.af_imageRequestOperation cancel];
    self.af_imageRequestOperation = nil;
}

@end

#pragma mark -

static inline NSString * AFButtonImageCacheKeyFromURLRequest(NSURLRequest *request) {
    return [[request URL] absoluteString];
}

@implementation AFButtonImageCache

- (UIImage *)cachedImageForRequest:(NSURLRequest *)request {
    switch ([request cachePolicy]) {
        case NSURLRequestReloadIgnoringCacheData:
        case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
            return nil;
        default:
            break;
    }
    
	return [self objectForKey:AFButtonImageCacheKeyFromURLRequest(request)];
}
- (UIImage *)getCachedImageForURL:(NSURL *)request {
    return [self objectForKey:request];
}
- (void)setCacheImage:(UIImage *)image
        forRequest:(NSURL *)request
{
    if (image && request) {
        [self setObject:image forKey:request];
    }
}
- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request
{
    if (image && request) {
        [self setObject:image forKey:AFButtonImageCacheKeyFromURLRequest(request)];
    }
}

- (void)clearCachedRequest:(NSURLRequest *)request {
    if (request) {
        [self removeObjectForKey:AFButtonImageCacheKeyFromURLRequest(request)];
    }
}
@end

#endif