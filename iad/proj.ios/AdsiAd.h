/****************************************************************************
 The MIT License (MIT)
 
 Copyright (c) 2015 Yuan Chen
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 ****************************************************************************/

#import <Foundation/Foundation.h>
#import <iAd/iAd.h>
#import "InterfaceAds.h"

typedef enum {
    kTypeBanner = 1,
    kTypeFullScreen,
} iAdType;

@interface AdsiAd : NSObject <InterfaceAds, ADBannerViewDelegate,ADInterstitialAdDelegate>
{
}

@property BOOL debug;
@property (assign, nonatomic) ADBannerView* bannerView;
@property (assign, nonatomic) ADInterstitialAd* interstitialView;


/**
 interfaces from InterfaceAds
 */
- (void) configDeveloperInfo: (NSMutableDictionary*) devInfo;
- (void) requestAds:(NSMutableDictionary *)info position:(int)pos;
- (void) showAds: (NSMutableDictionary*) info;
- (void) hideAds: (NSMutableDictionary*) info;
- (void) removeAds:(NSMutableDictionary *)info;
- (void) queryPoints;
- (void) spendPoints: (int) points;
- (void) setDebugMode: (BOOL) isDebugMode;
- (NSString*) getSDKVersion;
- (NSString*) getPluginVersion;


@end
