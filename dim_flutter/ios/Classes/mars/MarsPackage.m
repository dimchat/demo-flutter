//
//  MarsPackage.m
//  Runner
//
//  Created by Albert Moky on 2023/5/19.
//

#import "MarsPackage.h"

static inline NSData *int2buf(int number) {
    unsigned char buf[4];
    buf[0] = (number & 0xFF000000) >> 24;
    buf[1] = (number & 0x00FF0000) >> 16;
    buf[2] = (number & 0x0000FF00) >>  8;
    buf[3] = (number & 0x000000FF);
    return [NSData dataWithBytes:buf length:4];
}
static inline int buf2int(NSData *data, NSUInteger offset) {
    assert(offset + 4 <= data.length);
    const UInt8 *bytes = data.bytes;
    return
    (bytes[offset + 0] & 0xFF) << 24 |
    (bytes[offset + 1] & 0xFF) << 16 |
    (bytes[offset + 2] & 0xFF) <<  8 |
    (bytes[offset + 3] & 0xFF);
}


//
//  DIMConstants for Mars Header
//
#define MIN_HEAD_LEN      20
#define MAX_HEAD_LEN      24

#define CURRENT_VERSION   200

#define MAGIC_CODE        MKMHexDecode(@"000000c8000000") /* version = 0xC8 */
#define MAGIC_CODE_OFFSET 4

// cmd
#define SAY_HELLO         1
#define CONV_LST          2
#define SEND_MSG          3
#define NOOP              6
#define PUSH_MESSAGE      10001


@interface MarsHeader ()

@property(nonatomic, strong) NSData *data;

@property(nonatomic, assign) NSUInteger bodyLength;

@end

@implementation MarsHeader

- (instancetype)initWithData:(NSData *)data bodyLength:(NSUInteger)bodyLen {
    if (self = [super init]) {
        self.data = data;
        self.bodyLength = bodyLen;
    }
    return self;
}

- (NSUInteger)length {
    return [_data length];
}

+ (instancetype)create:(int)cmd seq:(int)sn body:(NSData *)payload {
    int headLen = MIN_HEAD_LEN;
    int version = CURRENT_VERSION;
    int bodyLen = (int)[payload length];
    NSMutableData *buffer = [[NSMutableData alloc] initWithCapacity:headLen];
    [buffer appendData:int2buf(headLen)];
    [buffer appendData:int2buf(version)];
    [buffer appendData:int2buf(cmd)];
    [buffer appendData:int2buf(sn)];
    [buffer appendData:int2buf(bodyLen)];
    return [[self alloc] initWithData:buffer bodyLength:bodyLen];
}

+ (instancetype)parse:(NSData *)data {
    // check data length
    int dataLen = (int)data.length;
    if (dataLen < MIN_HEAD_LEN) {
        // too small
        return nil;
    }
    // get fields
    int headLen = buf2int(data, 0);
    int version = buf2int(data, 4);
    int cmd     = buf2int(data, 8);
    int seq     = buf2int(data, 12);
    int bodyLen = buf2int(data, 16);
    NSAssert(headLen >= MIN_HEAD_LEN, @"Mars head length error: %d", headLen);
    NSAssert(version == CURRENT_VERSION, @"Mars version error: %d", version);
    NSAssert(bodyLen >= 0, @"Mars body length error: %d", bodyLen);
    // check head length
    if (dataLen < headLen) {
        // incompleted
        return nil;
    } else if (dataLen > headLen) {
        // cut head
        data = [data subdataWithRange:NSMakeRange(0, headLen)];
    }
    // TODO: get options
    // check body length
    if (bodyLen < 0) {
        return nil;
    }
    return [[self alloc] initWithData:data bodyLength:bodyLen];
}

@end

@interface MarsPackage ()

@property(nonatomic, strong) MarsHeader *head;
@property(nonatomic, strong) NSData *body;

@property(nonatomic, strong) NSData *data;  // head.data + body

@end

@implementation MarsPackage

- (instancetype)initWithData:(NSData *)pack
                        head:(MarsHeader *)header
                        body:(NSData *)payload {
    if (self = [super init]) {
        self.data = pack;
        self.head = header;
        self.body = payload;
    }
    return self;
}

- (NSUInteger)length {
    return [_data length];
}

+ (instancetype)create:(int)cmd seq:(int)sn body:(NSData *)payload {
    MarsHeader *header = [MarsHeader create:cmd seq:sn body:payload];
    NSUInteger packLen = header.length + payload.length;
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:packLen];
    [data appendData:header.data];
    [data appendData:payload];
    return [[self alloc] initWithData:data head:header body:payload];
}

+ (instancetype)parse:(NSData *)data {
    MarsHeader *header = [MarsHeader parse:data];
    if (!header) {
        return nil;
    }
    int headLen = (int)header.length;
    int bodyLen = (int)header.bodyLength;
    int packLen = headLen + bodyLen;
    int dataLen = (int)data.length;
    if (dataLen < packLen) {
        // incompleted
        return nil;
    } else if (dataLen > packLen) {
        // cut the tail
        data = [data subdataWithRange:NSMakeRange(0, packLen)];
    }
    NSData *payload;
    if (bodyLen > 0) {
        payload = [data subdataWithRange:NSMakeRange(headLen, bodyLen)];
    } else {
        payload = nil;
    }
    return [[self alloc] initWithData:data head:header body:payload];
}

@end

int nextOffset(NSData *buffer, int start) {
    return -1;
}

@implementation MarsSeeker

+ (MarsSeekHeaderResult *)seekHeader:(NSData *)buffer {
    NSData *data;
    MarsHeader *head;
    int dataLen = (int)[buffer length];
    int start = 0;
    int offset;
    int remaining;
    while (start < dataLen) {
        remaining = dataLen - start;
        if (start > 0) {
            data = [buffer subdataWithRange:NSMakeRange(start, remaining)];
        } else {
            data = buffer;
        }
        // try to parse header
        head = [MarsHeader parse:data];
        if (head) {
            // got header with start position
            return [[MarsSeekHeaderResult alloc] initWithFirst:head second:@(start)];
        }
        // header not found, check remaining data
        if (remaining < MAX_HEAD_LEN) {
            // waiting for more data
            break;
        }
        // locate next header
        offset = nextOffset(buffer, start + 1);
        if (offset < 0) {
            // header not found
            if (remaining < 65536) {
                // waiting for more data
                break;
            }
            // skip the whole buffer
            return [[MarsSeekHeaderResult alloc] initWithFirst:nil second:@(-1)];
        }
        // try again from new offset
        start += offset;
    }
    // header not found, waiting for more data
    return [[MarsSeekHeaderResult alloc] initWithFirst:nil second:@(start)];
}

+ (MarsSeekPackageResult *)seekPackage:(NSData *)buffer {
    int dataLen = (int)[buffer length];
    // 1. seek header in received data
    MarsSeekHeaderResult *headerResult = [self seekHeader:buffer];
    MarsHeader *head = headerResult.first;
    int offset = headerResult.second.intValue;
    if (offset < 0) {
        // data error, ignore the whle buffer
        return [[MarsSeekPackageResult alloc] initWithFirst:nil second:@(-1)];
    } else if (!head) {
        // header not found
        return [[MarsSeekPackageResult alloc] initWithFirst:nil second:@(offset)];
    } else if (offset > 0) {
        // drop the error part
        dataLen -= offset;
        buffer = [buffer subdataWithRange:NSMakeRange(offset, dataLen)];
    }
    // 2. check length
    int headLen = (int)[head length];
    int bodyLen = (int)[head bodyLength];
    int packLen;
    if (bodyLen < 0) {
        bodyLen = 0;
        packLen = dataLen;
    } else {
        packLen = headLen + bodyLen;
    }
    // check data buffer
    if (dataLen < packLen) {
        // package not completed, waiting for more data
        return [[MarsSeekPackageResult alloc] initWithFirst:nil second:@(offset)];
    } else if (dataLen > packLen) {
        // cut the tail
        buffer = [buffer subdataWithRange:NSMakeRange(0, packLen)];
    }
    // OK
    NSData *body = [buffer subdataWithRange:NSMakeRange(headLen, bodyLen)];
    MarsPackage *mars = [[MarsPackage alloc] initWithData:buffer head:head body:body];
    return [[MarsSeekPackageResult alloc] initWithFirst:mars second:@(offset)];
}

@end
