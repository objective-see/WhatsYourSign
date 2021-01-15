//
//  packageKit.h
//  WhatsYourSign
//
//  Created by Patrick Wardle on 12/17/20.
//  Copyright (c) 2020 Patrick Wardle. All rights reserved.
//

#ifndef packageKit_h
#define packageKit_h

#define PACKAGE_KIT @"/System/Library/PrivateFrameworks/PackageKit.framework"

//output from:
// class-dump /System/Library/PrivateFrameworks/PackageKit.framework/PackageKit

@interface PKArchive : NSObject
{
}

+ (id)archiveWithPath:(id)arg1;
+ (id)_allArchiveClasses;
- (BOOL)closeArchive;
- (BOOL)fileExistsAtPath:(id)arg1;
- (BOOL)verifyReturningError:(id *)arg1;
- (id)fileAttributesAtPath:(id)arg1;
- (BOOL)extractItemAtPath:(id)arg1 toPath:(id)arg2 error:(id *)arg3;
- (id)dataForPath:(id)arg1;
- (id)enumeratorAtPath:(id)arg1;
- (id)computedArchiveDigestWithAlgorithm:(id)arg1;
- (id)description;
- (BOOL)_extractFile:(id)arg1 toPath:(id)arg2 error:(id *)arg3;
- (id)initForReadingFromPath:(id)arg1;

@property(readonly) NSString *archiveDigest;
@property(readonly) NSString *archivePath;
@property(readonly) NSDate *archiveSignatureDate;
@property(readonly) NSArray *archiveSignatures;

@end

@interface PKMutableArchive : PKArchive
{
}

- (BOOL)setContentsOfArchive:(id)arg1 forPath:(id)arg2;
- (BOOL)setFile:(id)arg1 forPath:(id)arg2 compressed:(BOOL)arg3;
- (BOOL)setData:(id)arg1 forPath:(id)arg2 compressed:(BOOL)arg3;
- (id)initForWritingToPath:(id)arg1 ofType:(id)arg2 error:(id *)arg3;
- (id)initForWritingToPath:(id)arg1 error:(id *)arg2;
- (BOOL)addIntermediateCertificate:(struct OpaqueSecCertificateRef *)arg1;
- (BOOL)addSignatureBySigningWithIdentity:(struct OpaqueSecIdentityRef *)arg1 algorithm:(id)arg2 usingTSAIfSupported:(BOOL)arg3;
- (BOOL)addSignatureBySigningWithIdentity:(struct OpaqueSecIdentityRef *)arg1 algorithm:(id)arg2;
- (void)setSignatureSize:(int)arg1;

@end

@interface PKXARArchive : PKMutableArchive
{
    NSString *_archivePath;
    struct __xar_t *_xarPtr;
    BOOL _skipsVerify;
}

+ (id)_fileAttributeForXARProperty:(char *)arg1 fileAttributeKey:(id)arg2;
+ (id)_fileAttributeKeyForXARFileType:(id)arg1;
+ (id)_fileAttributeKeyForXARPropertyName:(id)arg1;
- (id)__openOrVerifyErrorForArchiveEntry:(id)arg1;
- (unsigned long long)_fileOffsetForPath:(id)arg1 error:(id *)arg2;
- (BOOL)fileExistsAtPath:(id)arg1;
- (BOOL)verifyReturningError:(id *)arg1;
- (id)fileAttributesAtPath:(id)arg1;
- (BOOL)_extractFile:(id)arg1 toPath:(id)arg2 error:(id *)arg3;
- (id)dataForPath:(id)arg1;
- (id)enumeratorAtPath:(id)arg1;
- (struct __xar_file_t *)_fileStructForSubpath:(id)arg1 error:(id *)arg2;
- (BOOL)_xarFileIsValid:(struct __xar_file_t *)arg1;
- (struct __xar_t *)_xar;
- (BOOL)closeArchive;
- (id)computedArchiveDigestWithAlgorithm:(id)arg1;
- (id)archiveDigest;
- (long long)_archiveFileSize;
- (id)archivePath;
- (void)_setSkipsVerifyIfUnsigned:(BOOL)arg1;
- (void)dealloc;
- (id)initForReadingFromPath:(id)arg1;
- (id)archiveSignatureDate;
- (id)archiveSignatures;

@end


@interface PKArchiveSignature : NSObject
{
    struct __SecTrust *_verifyTrustRef;
}

- (BOOL)_hasSigningCertificate:(struct OpaqueSecCertificateRef *)arg1;
- (id)signatureDataReturningAlgorithm:(id *)arg1;
- (id)signedDataReturningAlgorithm:(id *)arg1;
- (id)description;
- (void)dealloc;
- (struct __SecTrust *)verificationTrustRef;
- (BOOL)verifySignedDataReturningError:(id *)arg1;
- (BOOL)verifySignedData;
- (BOOL)_verifyCMSWithSignedData:(id)arg1 signatureData:(id)arg2 error:(id *)arg3;
- (BOOL)_verifyLegacyWithSignedData:(id)arg1 signatureData:(id)arg2 error:(id *)arg3;

@property(readonly) NSString *algorithmType;
@property(readonly) NSArray *certificateRefs;

@end

@interface PKXARArchiveSignature : PKArchiveSignature
{
    struct __xar_signature_t *_sig;
}

- (BOOL)_hasSigningCertificate:(struct OpaqueSecCertificateRef *)arg1;
- (id)signatureDataReturningAlgorithm:(id *)arg1;
- (id)signedDataReturningAlgorithm:(id *)arg1;
- (id)algorithmType;
- (id)certificateRefs;
- (id)initWithXARSignature:(struct __xar_signature_t *)arg1;

@end

@interface PKTrust : NSObject
{
    struct __SecTrust *_trustRef;
    struct OpaqueSecPolicyRef *_policyRef;
    unsigned int _trustResult;
    int _trustLevel;
    NSDate *_signingDate;
    BOOL _signingDateIsTrusted;
    BOOL _appleRootMode;
    BOOL _allowExpiredCertificates;
    BOOL _allowExpiredRoots;
}

+ (id)stringForTrustLevel:(int)arg1;
- (void)setAllowExpiredRoots:(BOOL)arg1;
- (void)setAllowExpiredCertificates:(BOOL)arg1;
- (BOOL)_isTrustedAsRootCertificate:(struct OpaqueSecCertificateRef *)arg1 inDomain:(unsigned int)arg2;
- (struct OpaqueSecCertificateRef *)_anchorCertificateFromEvaluation;
- (BOOL)_evaluateTrustAtLevel:(int)arg1 isDevelopmentSigned:(char *)arg2;
- (BOOL)_setCurrentPolicyWithOID:(struct cssm_data)arg1;
- (BOOL)_restoreCurrentDateMode;
- (BOOL)_enterDateSignedMode;
- (BOOL)_restoreSystemTrustMode;
- (void)_enterAppleRootMode;
- (id)certificateChain;
- (BOOL)evaluateTrustReturningError:(id *)arg1;
- (int)trustLevel;
- (unsigned int)trustResult;
- (struct __SecTrust *)trustRef;
- (void)dealloc;
- (id)initWithSecTrust:(struct __SecTrust *)arg1 usingAppleRoot:(BOOL)arg2 signatureDate:(id)arg3;
- (id)initWithCertificates:(id)arg1 usingAppleRoot:(BOOL)arg2 signatureDate:(id)arg3;

@end

#endif /* packageKit_h */
