/****************************************************************************
 Copyright (c) 2013 cocos2d-x.org
 
 http://www.cocos2d-x.org
 
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

#import "IOSIAP.h"
#define OUTPUT_LOG(...)     if (self.debug) NSLog(__VA_ARGS__);

@implementation IOSIAP
@synthesize debug;
NSSet * _productIdentifiers;
NSArray *_productArray;
bool _isAddObserver = false;
//productsRequest;
SKProductsRequest * _productsRequest;
//productTransation
NSArray * _transactionArray;
// productId
NSString* _productId;

-(void) configDeveloperInfo: (NSMutableDictionary*) cpInfo{}
- (void) payForProduct: (NSMutableDictionary*) cpInfo{
    [self payForProductRequest:cpInfo];
}

- (void)restoreCompletedTransactions {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)addObserver {
    if(!_isAddObserver){
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        _isAddObserver = true;
    }
}

- (void) verifyReceiptValidation:(NSString*)productID withReceipt:(NSString*)receipt{
    NSError *error;
    NSDictionary *requestContents = @{
                                      @"receipt-data": receipt
                                      };
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
                                                          options:0 error:&error];
    if (!requestData) {
        // Handle error
        [IAPWrapper onSubscriptionVerifyResult:self withRet:VerifyReceipDataError withMsg:@""];
        [self finishTransactionByID:productID];
        return;
    }
    
    NSString* expireDateMs = @"";
    
    // Create a POST request with the receipt data.
    NSURL *storeURL = [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
    [storeRequest setHTTPMethod:@"POST"];
    [storeRequest setHTTPBody:requestData];
    // Make a connection to the iTunes Store on a background queue.
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:storeRequest queue:queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   /* ... Handle error ... */
                                   [IAPWrapper onSubscriptionVerifyResult:self withRet:VerifyConnectionError withMsg:@""];
                                   [self finishTransactionByID:productID];
                               } else {
                                   NSError *error;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                   if (!jsonResponse) { /* ... Handle error ...*/ }
                                   /* ... Send a response back to the device ... */
                                   NSDictionary* jsonReceipt = [jsonResponse objectForKey:@"receipt"];
                                   NSArray* jsonInApp = [jsonReceipt objectForKey:@"in_app"];
                                   for (id prod in jsonInApp) {
                                       NSDictionary* product = prod;
                                       NSString* proIDinJson = [product objectForKey:@"product_id"];
                                       if ([proIDinJson isEqual:productID]) {
                                           NSNumber* expireDateMs = [product objectForKey:@"expires_date"];
                                           NSString* msg = [NSString stringWithFormat:@"%@",expireDateMs];
                                           [IAPWrapper onSubscriptionVerifyResult:self withRet:VerifySuccess withMsg:msg];
                                           [self finishTransactionByID:productID];
                                           return;
                                       }
                                       
                                   }
                               }
                           }];
    [IAPWrapper onSubscriptionVerifyResult:self withRet:VerifyReceipDataError withMsg:@""];
    [self finishTransactionByID:productID];
}


- (void) payForProductRequest: (NSMutableDictionary*) cpInfo{
    if(!_isAddObserver){
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        _isAddObserver = true;
    }
    _productId = [cpInfo objectForKey:@"productId"];
    NSArray *producIdArray = [[NSArray alloc] initWithObjects:_productId, nil];
    _productIdentifiers = [[NSSet alloc] initWithArray:producIdArray];
    OUTPUT_LOG(@"param is %@",_productIdentifiers);
    _productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:_productIdentifiers];
    _productsRequest.delegate = self;
    [_productsRequest start];
}

- (void) setDebugMode: (BOOL) _debug{
    self.debug = _debug;
}
- (NSString*) getSDKVersion{
    return @"1.0";
}

- (NSString*) getPluginVersion{
    return @"1.0";
}

#pragma mark Delegates
#pragma mark SKRequestDelegate
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    OUTPUT_LOG(@"Failed to load list of products.");
    [IAPWrapper onRequestProduct:self withRet:RequestFail withProducts:NULL];
    _productsRequest = nil;
}


#pragma mark SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    _productArray = response.products;
    NSArray * skProducts = response.products;
    for (SKProduct * skProduct in skProducts) {
        OUTPUT_LOG(@"Found product: %@ %@ %0.2f",
              skProduct.productIdentifier,
              skProduct.localizedTitle,
              skProduct.price.floatValue);
    }
    if (skProducts == nil || skProducts.count < 1) {
        [IAPWrapper onRequestProduct:self withRet:RequestFail withProducts:skProducts];
    }
    else {
        SKProduct *skProduct = [self getProductById:_productId];
        if(skProduct){
            SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:skProduct];
            [[SKPaymentQueue defaultQueue] addPayment:payment];
            OUTPUT_LOG(@"add PaymentQueue");
        }
    }
}

#pragma mark SKPaymentTransactionObserver
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions{
    _transactionArray = transactions;
    for (SKPaymentTransaction * transaction in transactions) {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                [self purchasedTransaction:transaction];
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            default:
                break;
        }
    };
}


#pragma mark SKPaymentTransactionObserver
/*
 * Restore finished. It may result from failed restore.
 */
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    NSString* productIDList = @"";
    NSArray* transactionArray = [queue transactions];
    for (NSInteger i = 0; i < transactionArray.count; i++) {
        SKPaymentTransaction* tran = [transactionArray objectAtIndex:i];
        if (i != transactionArray.count - 1){
            productIDList = [productIDList stringByAppendingFormat:@"%@,", tran.payment.productIdentifier];
        }
        [queue finishTransaction:tran];
    }
    if (transactionArray.count > 0){
        [IAPWrapper onPayResult:self withRet:PaymentTransactionStateRestored  withMsg:productIDList];
    } else {
        [IAPWrapper onPayResult:self withRet:PaymentTransactionStateFailed withMsg:@"No products."];
    }

}
- (void)paymentQueue:(SKPaymentQueue *) quene restoreCompletedTransactionsFailedWithError:(NSError*) error {
    for (SKPaymentTransaction* tran in quene.transactions){
        [quene finishTransaction:tran];
    }
    [IAPWrapper onPayResult:self withRet:PaymentTransactionStateFailed withMsg:error.localizedDescription];
    
}

#pragma mark Deal with transactions
- (void)purchasedTransaction:(SKPaymentTransaction *)transaction {
    [IAPWrapper onPayResult:self withRet:PaymentTransactionStatePurchased withMsg:transaction.payment.productIdentifier];
}

- (void)restoredTransaction:(SKPaymentTransaction *)transaction {
//    [IAPWrapper onPayResult:self withRet:PaymentTransactionStateRestored withMsg:transaction.payment.productIdentifier];
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    [IAPWrapper onPayResult:self withRet:PaymentTransactionStateFailed withMsg:transaction.error.localizedDescription];
}


-(void) finishTransactionByID:(NSString *)productId{
    SKPaymentTransaction *transaction = NULL;
    for(SKPaymentTransaction *tran in _transactionArray){
        if([tran.payment.productIdentifier isEqualToString:productId]){
            transaction = tran;
        }
    }
    if(transaction){
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
}
#pragma mark Help functions

-(NSString*) getReceiptFromTransaction:(SKPaymentTransaction* ) transaction {
    NSString* receipt = NULL;
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        // iOS 6.1 or earlier.
        // Use SKPaymentTransaction's transactionReceipt.
        receipt = [self encode:(uint8_t *)transaction.transactionReceipt.bytes length:transaction.transactionReceipt.length];        
    } else {
        // iOS 7 or later.
        NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
        NSData *recData = [[NSData dataWithContentsOfURL:receiptURL] base64EncodedDataWithOptions:0];
        receipt = [[NSString alloc] initWithData:recData encoding:NSUTF8StringEncoding];
        if (!receipt) {
            receipt = [self encode:(uint8_t *)transaction.transactionReceipt.bytes length:transaction.transactionReceipt.length];
        }
    }
    return receipt;
}

-(SKProduct *)getProductById:(NSString *)productid{
    for (SKProduct * skProduct in _productArray) {
        if([skProduct.productIdentifier isEqualToString:productid]){
            return skProduct;
        }
    }
    return NULL;
}

- (NSString *)encode:(const uint8_t *)input length:(NSInteger)length {
    static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    
    NSMutableData *data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    uint8_t *output = (uint8_t *)data.mutableBytes;
    
    for (NSInteger i = 0; i < length; i += 3) {
        NSInteger value = 0;
        for (NSInteger j = i; j < (i + 3); j++) {
            value <<= 8;
            
            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }
        
        NSInteger index = (i / 3) * 4;
        output[index + 0] =                    table[(value >> 18) & 0x3F];
        output[index + 1] =                    table[(value >> 12) & 0x3F];
        output[index + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
        output[index + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
    }
    
    return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] ;
}
@end
