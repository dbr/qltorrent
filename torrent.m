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
	// Read raw file, and de-bencode
	NSData *rawdata = [NSData dataWithContentsOfURL:url];
	//NSData *rawdata = [NSData dataWithContentsOfFile:@"/Users/dbr/Desktop/lost.torrent"];
	NSData *torrent = [BEncoding objectFromEncodedData:rawdata];
	
	NSData *infoData = [torrent valueForKey:@"info"];
	
	// Retrive interesting data
	NSString *announce = stringFromData(torrent, @"announce");
	NSLog(@"announce URL: %@", announce);
	
	NSString *torrentName = stringFromData(infoData, @"name");
	NSLog(@"torrent name: %@", torrentName);
	
	NSNumber *isPrivate;
	if([[infoData valueForKey:@"private"] isNotEqualTo:NULL]){
		NSLog(@"Private");
		isPrivate = [NSNumber numberWithBool:YES];
	}else{
		NSLog(@"Not private");
		isPrivate = [NSNumber numberWithBool:NO];
	}
	NSLog(@"is private: %d", isPrivate);
	
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
	
	NSLog(@"\n%@", allFiles);
	NSMutableDictionary *ret = [NSMutableDictionary dictionary];
	if(announce != NULL) [ret setObject:announce forKey:@"announce"];
	if(torrentName != NULL) [ret setObject:torrentName forKey:@"torrentName"];
	if(isPrivate != NULL) [ret setObject:isPrivate forKey:@"isPrivate"];
	if(allFiles != NULL) [ret setObject:allFiles forKey:@"files"];
	NSLog(@"%@", ret);
	return ret;
}

NSData *getTorrentPreview(NSURL *url)
{
	//NSString *template = [NSString stringWithContentsOfFile:[[NSBundle bundleWithIdentifier: @"uk.co.dbrweb.qltorrent"]
	//									pathForResource:@"torrentpreview" ofType:@"html"]];
	//NSLog(@"%@", template);
	NSDictionary *torrentInfo = getTorrentInfo(url);
    NSString *html = [NSString stringWithFormat:@"<html>"
					  "<head>"
					  "<meta content='text/html; charset=UTF-8' http-equiv='Content-Type' />"
					  "</head>"
					  "<body>%@</body>"
					  "</html>", 
					  [torrentInfo objectForKey:@"torrentName"]];
    
    return [html dataUsingEncoding:NSUTF8StringEncoding];
}