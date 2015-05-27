#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "RCTBridgeModule.h"
#import "RCTLog.h"

@interface FileUpload : NSObject <RCTBridgeModule>
@end

@implementation FileUpload

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(upload:(NSDictionary *)obj callback:(RCTResponseSenderBlock)callback)
{
  NSString *uploadUrl = obj[@"uploadUrl"];
  NSDictionary *headers = obj[@"headers"];
  NSDictionary *fields = obj[@"fields"];
  NSArray *files = obj[@"files"];
  
  NSURL *url = [NSURL URLWithString:uploadUrl];
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  [req setHTTPMethod:@"POST"];
  
  // set headers
  NSString *formBoundaryString = [self generateBoundaryString];
  NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", formBoundaryString];
  [req setValue:contentType forHTTPHeaderField:@"Content-Type"];
  for (NSString *key in headers) {
    id val = [headers objectForKey:key];
    if ([val respondsToSelector:@selector(stringValue)]) {
      val = [val stringValue];
    }
    if (![val isKindOfClass:[NSString class]]) {
      continue;
    }
    [req setValue:val forHTTPHeaderField:key];
  }
  
  
  NSData *formBoundaryData = [[NSString stringWithFormat:@"--%@\r\n", formBoundaryString] dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableData* reqBody = [NSMutableData data];
  
  // add fields
  for (NSString *key in fields) {
    id val = [fields objectForKey:key];
    if ([val respondsToSelector:@selector(stringValue)]) {
      val = [val stringValue];
    }
    if (![val isKindOfClass:[NSString class]]) {
      continue;
    }
    
    [reqBody appendData:formBoundaryData];
    [reqBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
    [reqBody appendData:[val dataUsingEncoding:NSUTF8StringEncoding]];
    [reqBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  }
  
  // add files
  for (NSDictionary *file in files) {
    NSString *filename = file[@"filename"];
    NSString *filepath = file[@"filepath"];
    NSString *filetype = file[@"filetype"];
    
    NSData *fileData = [NSData dataWithContentsOfFile:filepath];
    
    [reqBody appendData:formBoundaryData];
    [reqBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", filename, filename] dataUsingEncoding:NSUTF8StringEncoding]];
    
    if (filetype) {
      [reqBody appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n", filetype] dataUsingEncoding:NSUTF8StringEncoding]];
    } else {
      [reqBody appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n", [self mimeTypeForPath:filepath]] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [reqBody appendData:[[NSString stringWithFormat:@"Content-Length: %ld\r\n\r\n", (long)[fileData length]] dataUsingEncoding:NSUTF8StringEncoding]];
    [reqBody appendData:fileData];
    [reqBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  }
  
  // add end boundary
  NSData* end = [[NSString stringWithFormat:@"--%@--\r\n", formBoundaryString] dataUsingEncoding:NSUTF8StringEncoding];
  [reqBody appendData:end];
  
  // send request
  [req setHTTPBody:reqBody];
  NSHTTPURLResponse *response = nil;
  NSData *returnData = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:nil];
  NSInteger statusCode = [response statusCode];
  NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];
  
  NSDictionary *res=[[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInteger:statusCode],@"status",returnString,@"data",nil];
  
  callback(@[[NSNull null], res]);
}

- (NSString *)generateBoundaryString
{
  NSString *uuid = [[NSUUID UUID] UUIDString];
  return [NSString stringWithFormat:@"----%@", uuid];
}

- (NSString *)mimeTypeForPath:(NSString *)filepath
{
  NSString *fileExtension = [filepath pathExtension];
  NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtension, NULL);
  NSString *contentType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);

  if (contentType) {
    return contentType;
  }
  return @"application/octet-stream";
}

@end
