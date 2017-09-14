//
//  pkcs7_union_accessors.h
//  MindNode for Mac
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 Ideas On Canvas GmbH. All rights reserved.
//

// original source https://www.andrewcbancroft.com/2016/06/09/extracting-a-pkcs7-container-for-receipt-validation-with-swift/#prep-pkcs7-union-accessors

#ifndef pkcs7_union_accessors_h
#define pkcs7_union_accessors_h

#include "pkcs7.h"

char *pkcs7_d_char(PKCS7 *ptr);
ASN1_OCTET_STRING *pkcs7_d_data(PKCS7 *ptr);
PKCS7_SIGNED *pkcs7_d_sign(PKCS7 *ptr);
PKCS7_ENVELOPE *pkcs7_d_enveloped(PKCS7 *ptr);
PKCS7_SIGN_ENVELOPE *pkcs7_d_signed_and_enveloped(PKCS7 *ptr);
PKCS7_DIGEST *pkcs7_d_digest(PKCS7 *ptr);
PKCS7_ENCRYPT *pkcs7_d_encrypted(PKCS7 *ptr);
ASN1_TYPE *pkcs7_d_other(PKCS7 *ptr);

#endif /* pkcs7_union_accessors_h */
