#import "torrent.h"
#import "BEncoding.h"

NSString *stringFromFileSize(NSInteger theSize)
{
    /*
     From http://snippets.dzone.com/posts/show/3038
     */
    float floatSize = theSize;
    if (theSize<1023)
        return([NSString stringWithFormat:@"%i bytes",theSize]);
    floatSize = floatSize / 1024;
    if (floatSize<1023)
        return([NSString stringWithFormat:@"%1.1f KB",floatSize]);
    floatSize = floatSize / 1024;
    if (floatSize<1023)
        return([NSString stringWithFormat:@"%1.1f MB",floatSize]);
    floatSize = floatSize / 1024;
    
    return([NSString stringWithFormat:@"%1.1f GB",floatSize]);
}

NSString *stringFromData(NSData *torrent, NSString *key)
{
    NSData *rawkey = [torrent valueForKey:key];
    NSString *strdata = [NSString stringWithUTF8String:[rawkey bytes]];
    return strdata;
}

void replacer(NSMutableString *html, NSString *replaceThis, NSString *withThis, NSString *defaultString) {
    if(withThis == nil) withThis = defaultString;
    [html replaceOccurrencesOfString:replaceThis
                          withString:withThis
                             options:NSLiteralSearch
                               range:NSMakeRange(0, [html length])];
}

NSDictionary *getTorrentInfo(NSURL *url)
{
    // Read raw file, and de-bencode
    NSData *rawdata = [NSData dataWithContentsOfURL:url];
    NSData *torrent = [BEncoding objectFromEncodedData:rawdata];
    
    NSData *infoData = [torrent valueForKey:@"info"];

    // Retrive interesting data
    NSString *announce = stringFromData(torrent, @"announce");
    
    NSString *torrentName = stringFromData(infoData, @"name");

    NSString *length = [infoData valueForKey:@"length"];

    NSNumber *isPrivate;
    if([[infoData valueForKey:@"private"] isNotEqualTo:NULL]){
        isPrivate = [NSNumber numberWithBool:YES];
    }else{
        isPrivate = [NSNumber numberWithBool:NO];
    }

    // Get filenames/sizes
    NSArray *filesData = [infoData valueForKey:@"files"];

    NSInteger totalSize = 0;
    NSMutableArray *allFiles = [NSMutableArray array];
    for (int i = 0; i < [filesData count]; i++) {
        NSData *currentFileData = [filesData objectAtIndex:i];
        NSString *currentSize = [currentFileData valueForKey:@"length"];
        
        NSMutableDictionary *currentFile = [NSMutableDictionary dictionaryWithObject:currentSize forKey:@"length"];

        totalSize = totalSize + [currentSize integerValue];

        NSMutableString *currentFilePath = [NSMutableString string];
        
        // Looping over path segments"
        for(int path_i = 0; path_i < [[currentFileData valueForKey:@"path"] count] ; path_i++) {
            NSData *currentSegmentData = [[currentFileData valueForKey:@"path"] objectAtIndex:path_i];
            
            NSString *currentPathSegment = [NSString stringWithUTF8String:[currentSegmentData bytes]];
            [currentFilePath appendFormat:@"/%@", currentPathSegment];
        }
        [currentFile setObject:currentFilePath forKey:@"filename"];
        [allFiles addObject:currentFile];
    }
    
    // Store interesting data in dictionary, and return it

    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    if(length != NULL) [ret setObject:length forKey:@"length"];
    if(announce != NULL) [ret setObject:announce forKey:@"announce"];
    if(torrentName != NULL) [ret setObject:torrentName forKey:@"torrentName"];
    if(isPrivate != NULL) [ret setObject:isPrivate forKey:@"isPrivate"];
    if(allFiles != NULL) [ret setObject:allFiles forKey:@"files"];
    [ret setObject:[NSNumber numberWithInteger:totalSize] forKey:@"totalSize"];

    return ret;
}

NSData *getTorrentPreview(NSURL *url)
{
    // Load template HTML
    NSString *templateFile = [NSString stringWithContentsOfFile:[[NSBundle bundleWithIdentifier: @"uk.co.dbrweb.qltorrent"]
                                        pathForResource:@"torrentpreview" ofType:@"html"]];
    NSDictionary *torrentInfo = getTorrentInfo(url);
    NSMutableString *html = [NSMutableString stringWithString:templateFile];

    
    // Replace torrentName
    replacer(html,
             @"{TORRENT_NAME}",
             [torrentInfo objectForKey:@"torrentName"],
             @"[Unknown]");

    // Replace torrent size witht length or totalSize
    NSNumber *size;
    if([torrentInfo objectForKey:@"length"] != NULL){
         size = [torrentInfo objectForKey:@"length"];
    }else{
        size = [torrentInfo objectForKey:@"totalSize"];
    }
    NSString *torrentInfoString = [NSString stringWithFormat:@"<ul><li>Size: %@</li></ul>",
                                   stringFromFileSize([size integerValue])];

    replacer(html,
             @"{TORRENT_INFO}",
             torrentInfoString,
             @"[Unknown]");

    // Replace files
    NSMutableArray *files = [torrentInfo objectForKey:@"files"];
    if(files != NULL)
    {
        NSMutableString *torrentFileString = [NSMutableString string];
        for(int i = 0; i < [files count]; i++)
        {
            NSMutableDictionary *currentFile = [files objectAtIndex:i];
            NSString *currentName = [currentFile objectForKey:@"filename"];
            NSString *currentSizeData = [currentFile objectForKey:@"length"];
            NSString *currentSize;
            if(currentSizeData == NULL){
                currentSize = [NSString stringWithString:@"N/a"];
            }
            else
            {
                currentSize = [NSString stringWithString:stringFromFileSize([currentSizeData integerValue])];
            }
            [torrentFileString appendString:[NSString stringWithFormat: @"<tr><td>%@</td><td>%@</td></tr>\n",
                                             currentName,
                                             currentSize]
             ];
       }
        replacer(html,
                 @"{TORRENT_FILES}",
                 torrentFileString,
                 @"<tr><td>[Cannot list files]</td><td>N/a</td></tr>"
                 );
    }

    return [html dataUsingEncoding:NSUTF8StringEncoding];
}
