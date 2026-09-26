#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZSignBridge : NSObject

/// Cầu nối gọi zsign C++ core. Trả về YES nếu ký thành công, NO nếu thất bại.
+ (BOOL)signIPAAt:(NSString *)ipaPath
      certificate:(NSString *)certPath
         password:(NSString *)password
          profile:(NSString *)profilePath
       bundleName:(nullable NSString *)bundleName
         bundleId:(nullable NSString *)bundleId
       outputPath:(NSString *)outputPath;

@end

NS_ASSUME_NONNULL_END
