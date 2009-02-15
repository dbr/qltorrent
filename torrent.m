#import "torrent.h"
#import "BEncoding.h"

NSString * stringFromData(NSData *torrent, NSString *key)
{
	NSData *rawkey = [torrent valueForKey:key];
	NSString *strdata = [NSString stringWithCString:[rawkey bytes] encoding:NSUTF8StringEncoding];
	return strdata;
}

NSDictionary *getTorrentInfo(NSURL *url)
{
    NSLog(@"%@", [url path]);
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
	
	NSMutableArray *allFiles = [NSMutableArray array];
	for (int i = 0; i < [filesData count]; i++) {
		NSData *currentFileData = [filesData objectAtIndex:i];
		NSString *currentSize = [currentFileData valueForKey:@"length"];
		NSMutableDictionary *currentFile = [NSMutableDictionary dictionaryWithObject:currentSize forKey:@"size"];
		
		NSData *currentPathData = [[currentFileData valueForKey:@"path"] objectAtIndex:0];
		NSString *currentPath = [NSString stringWithCString:[currentPathData bytes] encoding:NSUTF8StringEncoding];
		[currentFile setObject:currentPath forKey:@"filename"];
		[allFiles addObject:currentFile];
	}
	
	NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    if(length != NULL) [ret setObject:length forKey:@"length"];
	if(announce != NULL) [ret setObject:announce forKey:@"announce"];
	if(torrentName != NULL) [ret setObject:torrentName forKey:@"torrentName"];
	if(isPrivate != NULL) [ret setObject:isPrivate forKey:@"isPrivate"];
	if(allFiles != NULL) [ret setObject:allFiles forKey:@"files"];
	return ret;
}

void replacer(NSMutableString *html, NSString *replaceThis, NSString *withThis) {
    [html replaceOccurrencesOfString:replaceThis
                          withString:withThis
                             options:NSLiteralSearch
                               range:NSMakeRange(0, [html length])];
}

NSData *getTorrentPreview(NSURL *url)
{
	NSString *templateFile = [NSString stringWithContentsOfFile:[[NSBundle bundleWithIdentifier: @"uk.co.dbrweb.qltorrent"]
										pathForResource:@"torrentpreview" ofType:@"html"]];
	NSDictionary *torrentInfo = getTorrentInfo(url);
    NSMutableString *html = [NSMutableString stringWithString:templateFile];
    
    replacer(html,
             @"{TORRENT_NAME}",
             [torrentInfo objectForKey:@"torrentName"]);
    
    NSString *torrentInfoString = [NSString stringWithFormat:@"<ul><li>Size: %@</li></ul>",
                                  [torrentInfo objectForKey:@"length"]];
    replacer(html,
             @"{TORRENT_INFO}",
             torrentInfoString);
    
    NSArray *files = [torrentInfo objectForKey:@"files"];
    NSMutableString *torrentFileString;
    for(int i = 0; i < [files count]; i++)
    {
        NSMutableDictionary *currentFile = [files objectAtIndex:i];
        NSString *currentName = [currentFile objectForKey:@"filename"];
        NSString *currentSize = [currentFile objectForKey:@"length"];
        [torrentFileString appendFormat:@"<tr><td>%@</td><td>%s</td></tr>",
         currentName,
         currentSize
         ];
    }
    replacer(html,
             @"{TORRENT_FILES}",
             torrentFileString);
    
    
    return [html dataUsingEncoding:NSUTF8StringEncoding];
}
