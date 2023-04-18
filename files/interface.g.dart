// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interface.dart.hbs';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      provider: json['provider'] as String?,
      providerId: json['providerId'] as String?,
      userId: json['userId'] as String?,
      name: json['name'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      middleName: json['middleName'] as String?,
      nickName: json['nickName'] as String?,
      preferredUsername: json['preferredUsername'] as String?,
      profile: json['profile'] as String?,
      picture: json['picture'] as String?,
      website: json['website'] as String?,
      email: json['email'] as String?,
      emailVerified: json['emailVerified'] as bool?,
      gender: json['gender'] as String?,
      birthDate: json['birthDate'] as String?,
      zoneInfo: json['zoneInfo'] as String?,
      locale: json['locale'] as String?,
      location: json['location'] as String?,
      roles:
          (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList(),
      customAttributes: (json['customAttributes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      customClaims: json['customClaims'] as Map<String, dynamic>?,
      accessToken: json['accessToken'] as Map<String, dynamic>?,
      rawAccessToken: json['rawAccessToken'] as String?,
      idToken: json['idToken'] as Map<String, dynamic>?,
      rawIdToken: json['rawIdToken'] as String?,
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'provider': instance.provider,
      'providerId': instance.providerId,
      'userId': instance.userId,
      'name': instance.name,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'middleName': instance.middleName,
      'nickName': instance.nickName,
      'preferredUsername': instance.preferredUsername,
      'profile': instance.profile,
      'picture': instance.picture,
      'website': instance.website,
      'email': instance.email,
      'emailVerified': instance.emailVerified,
      'gender': instance.gender,
      'birthDate': instance.birthDate,
      'zoneInfo': instance.zoneInfo,
      'locale': instance.locale,
      'location': instance.location,
      'roles': instance.roles,
      'customAttributes': instance.customAttributes,
      'customClaims': instance.customClaims,
      'accessToken': instance.accessToken,
      'rawAccessToken': instance.rawAccessToken,
      'idToken': instance.idToken,
      'rawIdToken': instance.rawIdToken,
    };

UploadResponse _$UploadResponseFromJson(Map<String, dynamic> json) =>
    UploadResponse(
      fileKeys:
          (json['fileKeys'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$UploadResponseToJson(UploadResponse instance) =>
    <String, dynamic>{
      'fileKeys': instance.fileKeys,
    };
