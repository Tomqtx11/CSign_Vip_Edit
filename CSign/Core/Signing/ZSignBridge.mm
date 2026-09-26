#import "ZSignBridge.h"
#import <string>
#import <vector>

// Forward declarations for zsign C++ classes (simplified for the bridge)
class ZSignAsset {
public:
    ZSignAsset();
    bool Init(const std::string& strCertFile, 
              const std::string& strPKeyFile, 
              const std::string& strProvFile, 
              const std::string& strEntitleFile, 
              const std::string& strPassword, 
              bool bAdhoc, 
              bool bSHA256Only, 
              bool bCheck);
};

class ZBundle {
public:
    ZBundle();
    bool SignFolder(ZSignAsset* zsa, 
                    const std::string& strFolder, 
                    const std::string& strBundleId, 
                    const std::string& strBundleVersion, 
                    const std::string& strDisplayName, 
                    const std::vector<std::string>& arrDylibFiles, 
                    const std::vector<std::string>& arrRemoveDylibNames,
                    bool bForce, 
                    bool bWeakInject, 
                    bool bEnableCache,
                    bool bRemoveProvision);
};

@implementation ZSignBridge

+ (BOOL)signIPAAt:(NSString *)ipaPath
      certificate:(NSString *)certPath
         password:(NSString *)password
          profile:(NSString *)profilePath
       bundleName:(nullable NSString *)bundleName
         bundleId:(nullable NSString *)bundleId
       outputPath:(NSString *)outputPath {
    
    std::string strCertFile = certPath.UTF8String ?: "";
    std::string strPassword = password.UTF8String ?: "";
    std::string strProvFile = profilePath.UTF8String ?: "";
    std::string strEntitleFile = ""; 
    std::string strPKeyFile = "";
    
    // Init ZSignAsset
    ZSignAsset zsa;
    bool bInit = zsa.Init(strCertFile, strPKeyFile, strProvFile, strEntitleFile, strPassword, false, false, false);
    
    if (!bInit) {
        NSLog(@"[ZSignBridge] Failed to init ZSignAsset");
        return NO;
    }
    
    // Khởi tạo ZBundle
    ZBundle bundle;
    std::string strFolder = ipaPath.UTF8String; // ipaPath should ideally be the unzipped folder for ZBundle
    std::string strBundleId = bundleId ? bundleId.UTF8String : "";
    std::string strDisplayName = bundleName ? bundleName.UTF8String : "";
    std::string strBundleVersion = "";
    std::vector<std::string> arrDylibFiles;
    std::vector<std::string> arrRemoveDylibNames;
    
    // Gọi lệnh ký của zsign (SignFolder)
    bool bRet = bundle.SignFolder(&zsa, strFolder, strBundleId, strBundleVersion, strDisplayName, arrDylibFiles, arrRemoveDylibNames, true, false, false, false);
    
    return bRet ? YES : NO;
}

@end
