안녕하세요.
이동의즐거움 김주형입니다.

당사가 사용하고 있는 더존 그룹웨어에서 아래와 같은 방식으로 SSO 연동이 가능하다고하는데,

프로젝트 착수 시, 가능 여부 회신 부탁드립니다.

안녕하세요.
​
더존비즈온 김두현 과장입니다.

Bizbox Alpha는 파라미터 기반 SSO를 지원하고,

Amaranth 10 은 SAML 방식도 지원합니다.

각각 제공하는 문서를 먼저 공유드리며, 관련하여 추가 문의사항은 연락주시면 답변드리겠습니다.

감사합니다.

감사합니다.

---

Bizbox Alpha
Date :
2021.02.25
더존비즈온
UC개발본부
더존비즈온_솔루션개발센터
_
Copyright Douzon corp. All rights reserved.
Douzon 의 사전 승인 없이 본 내용의 전부 또는 일부에 대한 복사, 전재, 배포, 사용을 금합니다.
◎ 외부 SSO링크메뉴 설정가이드
메뉴 정보관리 메뉴에서 외부URL 링크메뉴를 신규 생성할 수 있습니다.
SSO 사용여부가 미사용인 경우에는 저장한 메뉴URL링크만 제공합니다.
◎ 외부 SSO링크메뉴 설정가이드
SSO 사용 시 세부항목이 활성화되며
연동방식을 선택하고 항목별 파라이터명을 설정할 수 있습니다.
◎ 외부 SSO링크메뉴 설정가이드
암호화 적용범위 체크항목을 선택 시 암호화 방식에 따라 Encode 가능합니다.
기준시간 연결을 설정한 경우 선택한 시간타입이 연결된 문자열로 암호화하여
외부시스템에서 Decode하여 SSO요청시간을 체크할 수 있습니다.
Ex) 기준시간 설정한 경우 복호화 결과값 예시 (그룹웨어 기준 로그인계정이 duzon 인 경우)
OutSystemID 키 Value 복호화 결과 : 20210225093000duzon
◎ 외부 SSO링크메뉴 설정가이드
메뉴 URL 설정항목에서 외부링크 View타입을 설정합니다.
외부링크(I-Frame) > 그룹웨어 레이아웃 컨텐츠 영역에 View
외부링크(PopUp) > 새창으로 View
◎ 외부 SSO링크메뉴 설정가이드
외부링크(I-Frame) 선택 시 내부 컨텐츠 영역에 IFRAME으로 보여집니다.
◎ 외부 SSO링크메뉴 설정가이드
Get방식으로 설정한 경우 Url에 설정한 파라미터명으로 계정관련 정보를 전달합니다.
Post방식으로 설정한 경우 설정한 파라미터명으로 Submit합니다.

---

AES(CBC) 암호화 샘플코드(JAVA)
import javax.crypto.BadPaddingException;
import javax.crypto.Cipher;
import javax.crypto.IllegalBlockSizeException;
import javax.crypto.NoSuchPaddingException;
import javax.crypto.SecretKey;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.apache.commons.codec.binary.Base64;
final static String secretKey =
“암호화키";
// 암호화
public static String AES_Encode(String str)
throws java.io.UnsupportedEncodingException,
NoSuchAlgorithmException, NoSuchPaddingException,
InvalidKeyException, InvalidAlgorithmParameterException,
IllegalBlockSizeException, BadPaddingException {
byte[] keyData = secretKey.getBytes();
SecretKey secureKey = new SecretKeySpec(keyData, "AES");
Cipher c = Cipher.getInstance("AES/CBC/PKCS5Padding");
c.init(Cipher.ENCRYPT_MODE, secureKey,
new IvParameterSpec(secretKey.getBytes()));
byte[] encrypted = c.doFinal(str.getBytes("UTF-8"));
String enStr = new String(Base64.encodeBase64(encrypted));
return enStr;
}
// 복호화
public static String AES_Decode(String str)
throws java.io.UnsupportedEncodingException,
NoSuchAlgorithmException, NoSuchPaddingException,
InvalidKeyException, InvalidAlgorithmParameterException,
IllegalBlockSizeException, BadPaddingException {
byte[] keyData = secretKey.getBytes();
SecretKey secureKey = new SecretKeySpec(keyData, "AES");
Cipher c = Cipher.getInstance("AES/CBC/PKCS5Padding");
c.init(Cipher.DECRYPT_MODE, secureKey,
new IvParameterSpec(secretKey.getBytes("UTF-8")));
byte[] byteStr = Base64.decodeBase64(str.getBytes());
return new String(c.doFinal(byteStr), "UTF-8");
}
◎ AES(ECB) 암호화 샘플코드(JAVA)
import javax.crypto.BadPaddingException;
import javax.crypto.Cipher;
import javax.crypto.IllegalBlockSizeException;
import javax.crypto.NoSuchPaddingException;
import javax.crypto.SecretKey;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.apache.commons.codec.binary.Base64;
final static String secretKey =
“암호화키";
// 외부연동용 암호화 AES128
public static String AES128EX_Encode(String str, String Key)
throws java.io.UnsupportedEncodingException,
NoSuchAlgorithmException, NoSuchPaddingException,
InvalidKeyException, InvalidAlgorithmParameterException,
IllegalBlockSizeException, BadPaddingException {
byte[] crypted = null;
try{
SecretKeySpec skey = new SecretKeySpec(Key.getBytes(), "AES");
Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding");
cipher.init(Cipher.ENCRYPT_MODE, skey);
crypted = cipher.doFinal(str.getBytes());
}catch(Exception e){
System.out.println(e.toString());
}
return new String(Base64.encodeBase64(crypted));
}
// 외부연동용 암호화 AES128
public static String AES128EX_Decode(String str, String Key)
throws java.io.UnsupportedEncodingException,
NoSuchAlgorithmException, NoSuchPaddingException,
InvalidKeyException, InvalidAlgorithmParameterException,
IllegalBlockSizeException, BadPaddingException {
byte[] output = null;
try{
SecretKeySpec skey = new SecretKeySpec(Key.getBytes(), "AES");
Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding");
cipher.init(Cipher.DECRYPT_MODE, skey);
output = cipher.doFinal(Base64.decodeBase64(str.getBytes()));
}catch(Exception e){
System.out.println(e.toString());
}
return new String(output);
}
