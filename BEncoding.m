//
//  BEncoding.m
//  
//  This file is part of the BEncoding framework.
//
//  This framework is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//  
//  This framework is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License
//  along with this framework.  If not, see <http://www.gnu.org/licenses/>.
//
//  Copyright © Nathan Ollerenshaw 2008.
//

#import "BEncoding.h"

typedef struct {
    NSUInteger          length;
    NSUInteger          offset;
    const char          *bytes;
} BEncodingData;

// Private methods
//
// They're not REALLY private, but there is no point exposing them
// in the header.

@interface BEncoding (Private)
+(NSNumber *)numberFromEncodedData:(BEncodingData *)data;
+(NSData *)dataFromEncodedData:(BEncodingData *)data;
+(NSString *)stringFromEncodedData:(BEncodingData *)data;
+(NSArray *)arrayFromEncodedData:(BEncodingData *)data;
+(NSDictionary *)dictionaryFromEncodedData:(BEncodingData *)data;
+(id)objectFromData:(BEncodingData *)data;
@end

@implementation BEncoding

//  +(NSData *)encodeDataFromObject:(id)object
//
//  This method to returns an NSData object that contains the bencoded
//  representation of the object that you send. You can send complex structures
//  such as an NSDictionary that contains NSArrays, NSNumbers and NSStrings, and
//  the encoder will correctly serialise the data in the expected way.
//
//  Supports NSData, NSString, NSNumber, NSArray and NSDictionary objects.
//
//  NSStrings are encoded as NSData objects as there is no way to differentiate
//  between the two when decoding.
//
//  NSNumbers are encoded and decoded with their longLongValue.
//
//  NSDictionary keys must be NSStrings.

+(NSData *)encodedDataFromObject:(id)object
{
    NSMutableData *data = [[NSMutableData alloc] init];
    char buffer[32]; // Small buffer to hold length strings. Needs to hold a 64bit number.
    
    memset(buffer, 0, sizeof(buffer)); // Ensure the buffer is zeroed
    
    if ([object isKindOfClass:[NSData class]]) 
    {
        // Encode a chunk of bytes from an NSData.
        
        snprintf(buffer, 32, "%lu:", [object length]);
        
        [data appendBytes:buffer length:strlen(buffer)];
        [data appendData:object];
        
        return data;
    } 
    if ([object isKindOfClass:[NSString class]]) 
    {
        // Encode an NSString
        
        NSData *stringData = [object dataUsingEncoding:NSUTF8StringEncoding];
        snprintf(buffer, 32, "%lu:", [stringData length]);
        
        [data appendBytes:buffer length:strlen(buffer)];
        [data appendData:stringData];
        
        return data;
    } 
    else if ([object isKindOfClass:[NSNumber class]]) 
    {
        // Encode an NSNumber
        
        snprintf(buffer, 32, "i%llue", [object longLongValue]);
        
        [data appendBytes:buffer length:strlen(buffer)];
        
        return data;
    }
    else if ([object isKindOfClass:[NSArray class]]) 
    {
        // Encode an NSArray
        
        [data appendBytes:"l" length:1];
        
        for (id item in object) {
            [data appendData:[BEncoding encodedDataFromObject:item]];
        }
        
        [data appendBytes:"e" length:1];
        
        return data;
    }
    else if ([object isKindOfClass:[NSDictionary class]]) 
    {
        // Encode an NSDictionary
        
        [data appendBytes:"d" length:1];
        
        for (id key in object) {
            // Assert that the key is a string. It is expected that you'll check before
            // passing this class an array of objects as keys that are not NSStrings.
            
            assert([key isKindOfClass:[NSString class]]);
            
            NSData *stringData = [key dataUsingEncoding:NSUTF8StringEncoding];
            snprintf(buffer, 32, "%lu:", [stringData length]);
            
            [data appendBytes:buffer length:strlen(buffer)];
            [data appendData:stringData];
            [data appendData:[BEncoding encodedDataFromObject:[object objectForKey:key]]];
        }
        
        [data appendBytes:"e" length:1];
        return data;
    }
    
    return nil;
}

+(NSNumber *)numberFromEncodedData:(BEncodingData *)data
{
    NSMutableString *numberString = [[NSMutableString alloc] init];
    long long int   number;
    
    assert(data->bytes[data->offset] == 'i');
    
    data->offset++; // We start on the i so we need to move by one.
    
    while (data->offset < data->length && data->bytes[data->offset] != 'e') {
        [numberString appendFormat:@"%c", data->bytes[data->offset++]];
    }
    
    if (![[NSScanner scannerWithString:numberString] scanLongLong:&number])
        return nil;
    
    data->offset++; // Always move the offset off the end of the encoded item.
    
    return [NSNumber numberWithLongLong:number];
}

+(NSData *)dataFromEncodedData:(BEncodingData *)data
{
    NSMutableString *dataLength = [[NSMutableString alloc] init];
    NSMutableData *decodedData = [[NSMutableData alloc] init];
    
    if (data->bytes[data->offset] < '0' | data->bytes[data->offset] > '9')
        return nil; // Needed because we must fail to create a dictionary if it isn't a string.
    
    // strings are special; they start with a number so we don't move by one.
    
    while (data->offset < data->length && data->bytes[data->offset] != ':') {
        [dataLength appendFormat:@"%c", data->bytes[data->offset++]];
    }
    
    if (data->bytes[data->offset] != ':')
        return nil; // We must have overrun the end of the bencoded string.
    
    data->offset++;
    
    [decodedData appendBytes:data->bytes+data->offset length:[dataLength integerValue]];
    
    data->offset += [dataLength integerValue]; // Always move the offset off the end of the encoded item.
    
    return decodedData;
}

+(NSString *)stringFromEncodedData:(BEncodingData *)data
{
    /* A string is just bencoded data */
    
    NSData *decodedData = [self dataFromEncodedData:data];
    
    if (decodedData == nil)
        return nil;
    
    return [[NSString alloc] initWithBytes:[decodedData bytes] length:[decodedData length] encoding:NSUTF8StringEncoding];
}

+(NSArray *)arrayFromEncodedData:(BEncodingData *)data
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    assert(data->bytes[data->offset] == 'l');
    
    data->offset++; // Move off the l so we point to the first encoded item.
    
    while (data->bytes[data->offset] != 'e') {
        [array addObject:[BEncoding objectFromData:data]];
    }
    
    data->offset++; // Always move off the end of the encoded item.
    
    return array;
}

+(NSDictionary *)dictionaryFromEncodedData:(BEncodingData *)data
{
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    NSString *key = nil;
    id value = nil;
    
    assert(data->bytes[data->offset] == 'd');
    
    data->offset++; // Move off the d so we point to the string key.
    
    while (data->bytes[data->offset] != 'e') {
        if (data->bytes[data->offset] >= '0' && data->bytes[data->offset] <= '9') {
            // Dictionaries are a bencoded string with a bencoded value.
            key = [BEncoding stringFromEncodedData:data];
            value = [BEncoding objectFromData:data];
            if (key != nil && value != nil)
                [dictionary setValue:value forKey:key];
        }
    }
    
    data->offset++; // Move off the e so we point to the next encoded item.
    
    return dictionary;
}

+(id)objectFromData:(BEncodingData *)data
{
    /* Each of the decoders expect that the offset points to the first character
     * of the encoded entity, for example the i in the bencoded integer "i18e" */
    
    switch (data->bytes[data->offset]) {
        case 'l':
            return [BEncoding arrayFromEncodedData:data];
            break;
        case 'd':
            return [BEncoding dictionaryFromEncodedData:data];
            break;
        case 'i':
            return [BEncoding numberFromEncodedData:data];
            break;
        default:
            if (data->bytes[data->offset] >= '0' && data->bytes[data->offset] <= '9')
                return [BEncoding dataFromEncodedData:data];
            break;
    }
    
    // If we reach here, it doesn't appear that this is bencoded data. So, we'll
    // just return nil and advance to the next byte in the hopes we'll decode
    // something useful. Not sure if this is a good strategy.
    
    data->offset++;
    return nil;
}

+(id)objectFromEncodedData:(NSData *)sourceData
{
    BEncodingData data;
    data.bytes = [sourceData bytes];
    data.length = [sourceData length];
    data.offset = 0;
    
    return [BEncoding objectFromData:&data];
}

@end
