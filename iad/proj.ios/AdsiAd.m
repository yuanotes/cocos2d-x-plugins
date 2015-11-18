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

#import "AdsiAd.h"
#import "AdsWrapper.h"
#import <iAd/UIViewControlleriAdAdditions.h>

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)


#define OUTPUT_LOG(...)     if (self.debug) NSLog(__VA_ARGS__);

@implementation AdsiAd

@synthesize debug = __debug;
- (void) dealloc
{
    if (nil != self.bannerView) {
        [self.bannerView removeFromSuperview];
        [self.bannerView release];
        self.bannerView = nil;
    }
    
    if (nil != self.interstitialView) {
        [self.interstitialView release];
        self.interstitialView = nil;
    }
    
    
    [super dealloc];
}

#pragma mark InterfaceAds impl

- (void) configDeveloperInfo: (NSMutableDictionary*) devInfo
{
}

- (void) requestAds:(NSMutableDictionary *)info position:(int)pos{
    NSString* strType = [info objectForKey:@"iAdType"];
    int type = [strType intValue];
    switch (type) {
        case kTypeBanner:
        {
            NSString* offsetX = [info objectForKey:@"iAdOffsetX"];
            NSString* offsetY = [info objectForKey:@"iAdOffsetY"];
            
            CGPoint offset = CGPointMake(offsetX.floatValue, offsetY.floatValue);
            
            if (nil == self.bannerView){
                self.bannerView = [[ADBannerView alloc] init];
                self.bannerView.delegate = self;
                [AdsWrapper addAdView:self.bannerView atPos:pos withOffset:offset];
                self.bannerView.hidden = TRUE;
            }
            
            break;
        }
        case kTypeFullScreen:
            if (self.interstitialView == nil){
                self.interstitialView = [[ADInterstitialAd alloc] init];
                self.interstitialView.delegate = self;
                if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7")){
                    [AdsWrapper getCurrentRootViewController].interstitialPresentationPolicy = ADInterstitialPresentationPolicyManual;
                }
            }
            [UIViewController prepareInterstitialAds];            
            break;
        default:
            OUTPUT_LOG(@"The value of 'iAdType' is wrong (should be 1 or 2)");
            break;
    }
}

- (void) showAds: (NSMutableDictionary*) info
{
    NSString* strType = [info objectForKey:@"iAdType"];
    int type = [strType intValue];
    switch (type) {
        case kTypeBanner:
        {            
            if (nil != self.bannerView && self.bannerView.isBannerLoaded){
                self.bannerView.hidden = FALSE;
            }
            break;
        }
        case kTypeFullScreen:
            if (nil != self.interstitialView ){
                if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7")){
                    [[AdsWrapper getCurrentRootViewController] requestInterstitialAdPresentation];
                } else {
                    if (self.interstitialView.loaded){
                        [self.interstitialView presentFromViewController:[AdsWrapper getCurrentRootViewController]];
                    }
                }
            }
            break;
        default:
            OUTPUT_LOG(@"The value of 'iAdType' is wrong (should be 1 or 2)");
            break;
    }
}

- (void) hideAds: (NSMutableDictionary*) info
{
    NSString* strType = [info objectForKey:@"iAdType"];
    int type = [strType intValue];
    switch (type) {
    case kTypeBanner:
        {
            if (nil != self.bannerView) {
                self.bannerView.hidden = TRUE;
            }
            break;
        }
    case kTypeFullScreen:
            OUTPUT_LOG(@"Hide interstitial of iAd is not implemented.");
        break;
    default:
        OUTPUT_LOG(@"The value of 'iAdType' is wrong (should be 1 or 2)");
        break;
    }
}

- (void) removeAds:(NSMutableDictionary *)info{
    NSString* strType = [info objectForKey:@"iAdType"];
    int type = [strType intValue];
    switch (type) {
        case kTypeBanner:
        {
            if (nil != self.bannerView) {
                [self.bannerView removeFromSuperview];
                [self.bannerView release];
                self.bannerView = nil;
            }
            break;
        }
        case kTypeFullScreen:
            if (nil != self.interstitialView){
                [self.interstitialView release];
                self.interstitialView = nil;
            }
            break;
        default:
            OUTPUT_LOG(@"The value of 'iAdType' is wrong (should be 1 or 2)");
            break;
    }
}

- (void) queryPoints
{
    OUTPUT_LOG(@"AdiAd not support query points!");
}

- (void) spendPoints: (int) points
{
    OUTPUT_LOG(@"AdiAd not support spend points!");
}

- (void) setDebugMode: (BOOL) isDebugMode
{
    self.debug = isDebugMode;
}

- (NSString*) getSDKVersion
{
    return @"0.1.0";
}

- (NSString*) getPluginVersion
{
    return @"0.1.0";
}

#pragma mark ADBannerViewDelegate
- (void)bannerViewWillLoadAd:(ADBannerView *)banner{
    OUTPUT_LOG(@"iAd Banner view will load.");
}


- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error{
    OUTPUT_LOG(@"iAd Banner view received failed.");
}

#pragma mark ADInterstitialAdDelegate
- (void)interstitialAd:(ADInterstitialAd *)interstitialAd didFailWithError:(NSError *)error{
    OUTPUT_LOG(@"iAd interstitial view received failed.");

}
- (void)interstitialAdWillLoad:(ADInterstitialAd *)interstitialAd {
    OUTPUT_LOG(@"iAd interstitial view will load.");

}

- (void)interstitialAdDidUnload:(ADInterstitialAd *)interstitialAd{
    OUTPUT_LOG(@"iAd interstitial view is unloaded.");

}


@end
