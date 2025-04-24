// license: https://mit-license.org
//
//  Ming-Ke-Ming : Decentralized User Identity Authentication
//
//                               Written in 2020 by Moky <albert.moky@gmail.com>
//
// =============================================================================
// The MIT License (MIT)
//
// Copyright (c) 2020 Albert Moky
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
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// =============================================================================
//
//  MKMSecKeyHelper.h
//  DIMPlugins
//
//  Created by Albert Moky on 2020/12/15.
//  Copyright © 2020 Albert Moky. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

#define MKMAlgorithm_RSA @"RSA"
#define MKMAlgorithm_ECC @"ECC"

NS_ASSUME_NONNULL_BEGIN

@interface MKMSecKeyHelper : NSObject

/**
 *  Get public key data from PEM content
 *
 * @param pem - key content
 * @param name - "RSA" or 'EC"
 * @return public key data
 */
+ (NSData *)publicKeyDataFromContent:(NSString *)pem algorithm:(NSString *)name;

+ (SecKeyRef)publicKeyFromData:(NSData *)data algorithm:(NSString *)name;

/**
 *  Get private key data from PEM content
 *
 * @param pem - key content
 * @param name - "RSA" or 'EC"
 * @return private key data
 */
+ (NSData *)privateKeyDataFromContent:(NSString *)pem algorithm:(NSString *)name;

+ (SecKeyRef)privateKeyFromData:(NSData *)data algorithm:(NSString *)name;

/**
 *  Get key data
 *
 * @param key - public/private key
 * @return key data
 */
+ (NSData *)dataFromKey:(SecKeyRef)key;

/**
 *  Serialize public key to PEM content
 *
 * @param pKey - public key
 * @param name - "RSA" or 'EC"
 * @return PEM content
 */
+ (NSString *)serializePublicKey:(SecKeyRef)pKey algorithm:(NSString *)name;

/**
 *  Serialize private key to PEM content
 *
 * @param sKey - private key
 * @param name - "RSA" or 'EC"
 * @return PEM content
 */
+ (NSString *)serializePrivateKey:(SecKeyRef)sKey algorithm:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
